# BlueField-3 主机重装 OS 与 DPU 恢复手册

> **日期**：2026-11-10
> **适用**：重装对象 `10.17.20.237`（hostname `ubuntu`）；参照/备份源 `10.17.21.85`（`node20-39`）
> **登录**：`root` / 密码见密码管理器（**不要写进仓库**）
> 前情：[`BlueField-3-DPU转NIC模式排查.md`](BlueField-3-DPU转NIC模式排查.md) ·
> [`BlueField-3-安装BFB启用DPU.md`](BlueField-3-安装BFB启用DPU.md)

---

## 🟢 2026-11-11 09:10 更新：重装完成、BFB 已刷入、两条硬指标均达成（本次会话新增）

> ✅ **`10.17.20.237` 主机重装 + DPU 侧全部完工。** hostname 已从 `ubuntu` 改为 **`node99`**。

1. ✅ **重装结果与老机器对齐**：Ubuntu **22.04.4 LTS** / 内核 **`5.15.0-105-generic`** /
   DOCA **`3.2.2-035000-25.10-ubuntu2204`** / OFED **`25.10-2.4.1`** / `mft 4.34.1-18` /
   `rshim 2.5.10`；DKMS 对 **105 与 185 双内核**都编好了。
   （唯一差异：新系统上**没有** `doca-installer`，老机器有 `1.3.10-1`。）
2. ✅✅ **两条硬指标达成，并且刷完 BFB 后与刷前基线逐行 `diff` 完全一致**：
   ```
   INTERNAL_CPU_OFFLOAD_ENGINE   ENABLED(0)   ENABLED(0)   ENABLED(0)
   ens21f0np0 UP / ens21f1np1 UP
   ```
3. ⭐⭐⭐ **`3.2.1` BFB 已成功刷入 DPU 的 eMMC**（日志 `Anolis installation completed` →
   `Installation finished`），并**用 DPU 本体实测钉死了它的身份**（不再是推断，见 §2）：
   ```
   /etc/mlnx-release : bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527
   PRETTY_NAME       : "Anolis OS 8.6"
   uname -r          : 5.10.134-13.1.an8.aarch64
   ```
4. ⭐⭐⭐ **这个 Anolis 包里唯一的登录账号是 `root`** —— **没有 `ubuntu`、也没有 `anolis`**。
   ⇒ 之前所有 `Permission denied` 的真因是**账号根本不存在**，不是密码错。
   （另有 `dmsuser`（DOCA DMS 服务号）、`openvswitch`。）
5. ⭐⭐ **重装后 `rshim.service` 是 `disabled` + `inactive`** ⇒ **必须先起它**，否则
   `/dev/rshim0/*` 与 `tmfifo_net0` 都不存在，DPU 完全看不见（§6.3）。
6. ⭐⭐ **tmfifo 的 `192.168.100.1/24` 做成了 systemd 单元**，主机重启后不再丢（§6.3）。
7. ⭐⭐ **刷 BFB 的正确姿势** —— `bf.cfg` 里用 **`bfb_modify_os()` 通用钩子**（不依赖只适用
   Ubuntu BFB 的 `ubuntu_PASSWORD`），并跳过 **4 个需要 BMC 密码的步骤**，见 §9.3。
8. ⚠️ **重装会把存储网 IP 抹掉**（netplan 回落到安装器默认的 `dhcp4: true`，且无 DHCP ⇒ 只剩 IPv6）。
   原值为 `ens21f0np0 = 20.17.20.237/23`、`ens21f1np1 = 30.17.20.237/23`，需自行补回（§6.4）。
9. ⭐ **官方兜底**：BFB 装失败或中途被打断，**重跑一次 `bfb-install` 即可恢复**（§9.2）。

---

## 🟢 2026-11-10 17:20 重大更新（本次会话新增）

1. ⭐ **`10.17.20.237` 的 DPU 已经装好了 `3.2.1` 那个包**（Anolis 8.6 + DOCA 3.2.1 + FW `32.47.1088`），
   而 `3.2.1` **正是 host 用 DOCA 3.2.2 时官方验证过的搭配** ⇒ **DPU 侧一个包都不用装**。
2. ⛔ **`bf-bundle-3.5.0-89`（`_ubuntu-24.04_64k_`）不要用**，三条官方理由：
   - 它把固件顶到 `32.50.1002`（26.07 一代），**DOCA 3.2.2 的互操作清单里没有 3.5.0**
   - 它是 **64k 页**变体，而 NVIDIA **已知问题**明确写着：把 Ubuntu 24.04 64K 页的 BFB
     装到 BF-3 的 eMMC 上，**`bfb-install` 报成功但 DPU 起不来**（无 workaround）
   - 混 LTS（host 3.2.x）与非 LTS（DPU 3.5）本身也是配置管理风险
3. ⭐⭐ **重装 host OS 完全不动 DPU** ⇒ 「恢复」只需把 host 侧工具链装回来。
4. ⭐⭐ **发现存储客户端 = 曙光 ParaStor `4.2.2SP2` 的私有客户端 `/clistorage/`（1.9 GB）** ——
   它**不是 deb、就在会被抹掉的根分区上**，必须一并备份；且它的 `sysid` 绑定老机器，
   **不能照抄给 237**（见 §7）。
5. ⭐ **重装所需的包在 `10.17.21.85` 上全都齐了、而且离线可用**（见 §5.2）。

---

## 0. 三条必须先懂的事实（不然一定白折腾）

### 0.1 重装 host OS **完全不动 DPU**

BlueField-3 是**两台电脑插在一块卡上**：

| 谁 | 系统装在哪 | 重装 host OS 会怎样 |
|---|---|---|
| **host**（x86 服务器） | 服务器自己的 `sda` | 被抹掉、重装 |
| **DPU / Arm** | **卡上的 eMMC**（独立） | ✅ **完全不受影响**，照常运行 |
| 卡上的 NIC / BMC / CEC 固件 | 卡上 Flash | ✅ 不受影响 |
| 卡上 `mlxconfig` 的配置 | 卡上 Flash | ✅ 不受影响 |

⇒ 「重装 host OS」**不需要重新装 BFB**。本机实测为证：`/dev/rshim0/misc` 的引导日志走完
BL1 → UEFI → `INFO[MISC]: Linux up` → `INFO[MISC]: DPU is ready`，DPU 是独立起来的。

### 0.2 **BFB 决定的是 DPU 侧**，与 host 的 DOCA 版本是两个独立选择

| 谁决定 | 决定了什么 |
|---|---|
| **BFB（bf-bundle）** | DPU 的 **Arm 操作系统**、**Arm 侧 DOCA**、**NIC/BMC/CEC 固件**、BSP/ATF/UEFI |
| **host 上的 DOCA 安装包** | host 的 **mlx5_core 驱动**、DOCA 库/服务、`mft`、`rshim` |

**官方口径**：装 BFB 的前提是 host 上「装好 DOCA **或** 装好 RShim」——
只要 RShim 在跑就行（最小 `doca-runtime` 都够），`bfb-install` 的文档语法里
**没有任何 DOCA 版本检查参数**。
→ [Deploying BlueField Software from Host](https://networking-docs.nvidia.com/bsp/latest/deploying-bluefield-software-from-host)

### 0.3 但 DPU 的固件必须与 **Arm 侧** DOCA 对齐，且 host/DPU 应成对

- 官方：*"Make sure that the BlueField firmware versions are aligned to the same release with
  the running DOCA version on the BlueField Arm."*
  → [Types and Methods of Updating](https://networking-docs.nvidia.com/bsp/latest/types-and-methods-of-updating-bluefield-software-image)
- 官方 LTS 矩阵把 **DOCA-Host / DOCA / BF-3 FW** 三者按季度成对发布（见 §3.1）——
  这才是「该怎么配」的权威依据。

---

## 1. 两台机器的实测版本对照

| 项 | 老机器 `10.17.21.85`（node20-39） | 对照机 `10.17.20.237`（ubuntu） |
|---|---|---|
| OS | **Ubuntu 22.04.4 LTS**（jammy） | **Ubuntu 24.04.3 LTS**（noble） |
| 运行内核 | **`5.15.0-105-generic`**（`linux-generic` 却是 `5.15.0.185`） | `6.8.0-147-generic` |
| **DOCA** | **3.2.2-035000** | **3.2.3-019000** |
| `doca-host` | `3.2.2-035000-25.10-ubuntu2204` | `3.2.3-019000-25.10-ubuntu2404` |
| OFED / `mlx5_core` | **`25.10-2.4.1`** | **`25.10-3.1.8`** |
| `mft` / `kernel-mft-dkms` | `4.34.1-18` / `4.34.1.18-1` | `4.34.1-25` |
| `rshim` | `2.5.10-0.g66a72a8.2510241` | `2.5.11-0.g6041176.2510318` |
| `doca-installer` | ✅ `1.3.10-1` | ❌ 缺 |
| ⭐ **存储客户端** | ✅ **`/clistorage/`** ParaStor `4.2.2SP2`（`oMgcd_client`；**今天 11:36 刚装**） | ❓ 未见 |
| ⭐⭐ **存储网（数据口）** | 4 个口全 `NO-CARRIER` ⇒ 存储网**还没接** | ⭐ **已接**：`ens21f0np0 = 20.17.20.237/23`、`ens21f1np1 = 30.17.20.237/23`（**2026-11-10 16:49 配置；用户确认这两条就是存储网**） |
| ⭐ **DPU 侧 Arm OS** | ❓ 本次未查 | ⭐ **Anolis 8.6**（RHEL 8 系）—— 见 §2 六条证据 |
| OS 软件源 | ⭐ **`https://mirrors.sugon.com/ubuntu/`**（内网，`10.2.100.102`） | 待核 |
| 启动方式 | Legacy BIOS（无 EFI 分区） | Legacy BIOS（无 EFI 分区） |
| Secure Boot | 未开（无 `mokutil`） | 未开（无 `mokutil`） |
| 系统盘 | `sda` 558.9G，`/` = 100G（用 28%） | `sda` 894.3G，`/` = 100G（用 19%） |
| 卡 OPN / PSID | `900-9D3B6-00CC-EA_Ax` / `MT_0000001115` | `900-9D3B6-00SV-A_Ax` / `MT_0000000965` |
| 手上的 BFB | 只有 `3.5.0-89` | ⭐ **`3.2.1-31`（独一份）+ `3.5.0-89`** |

> ⭐ 两台机器的 DOCA **本来就是同一代（3.2.x）**、OFED **同一条线（25.10）**，
> 差的只是一个补丁号和一个 Ubuntu 大版本。

### 1.1 老机器上真正卡住版本的是「存储客户端」

```
oMgcd_client   /clistorage/bin/oMgcd_client -m storage -a 0 -d 0
python         /clistorage//tools/conf/update_node_conf.py --state=0 --modulename=storage --sysid=1126096423
```

| 事实 | 值 |
|---|---|
| 部署路径 | **`/clistorage/`**（**不是 deb 包**，dpkg 里查不到 ⇒ 是整目录部署/脚本安装） |
| 相关挂载点 | `/mnt/fs1`（空，存储文件系统的挂载点） |
| 已装的内核相关件 | `srptools`、`libisns0`（IB 存储） |
| DKMS 模块 | `mlnx-ofed-kernel 25.10.OFED.25.10.2.4.1`、`iser`、`isert`、`srp`、`xpmem`、`knem` |
| RDMA 设备 | `mlx5_0` ~ `mlx5_3`（4 个） |
| ⚠️ 当前连通性 | **4 个口全是 `NO-CARRIER` / DOWN** ⇒ 存储网**当前没接**，`/mnt/fs1` 空 |

⇒ **「适配比较严格」= 这套存储客户端只认 `5.15.0-105` 内核 + OFED 25.10 驱动。**
⇒ 这也决定了 237 重装的目标版本（§3）。

---

## 2. ⭐⭐⭐ 已定论：`10.17.20.237` 的 DPU 装的就是 3.2.1 那个包

> ⭐⭐⭐ **2026-11-11 09:09 终局证据** —— 刷完 BFB 后 `ssh root@192.168.100.2` 直接读到：
> ```
> /etc/mlnx-release = bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527
> PRETTY_NAME       = "Anolis OS 8.6"
> uname -r          = 5.10.134-13.1.an8.aarch64
> ```
> 与手上那份 BFB 文件名**逐字符相同**。⇒ 下面当初用来**推断**它的证据链至此全部被证实；
> **前六条可以只当"在还没有账号时怎么先判断"的方法论看**，第 7 条才是终局证据。

七条互相印证的证据（第 6、7 条是**从 DPU 本体直接取到的**，最硬）：

| 证据 | `bf-bundle-3.2.1-31` 包里的值 | `10.17.20.237` 实测 | |
|---|---|---|---|
| `BF3_NIC_FW` | `32.47.1088` | `32.47.1088`（`flint q` 另给 `FW Release Date: 9.12.2025` ⇒ 落在 LTS U1 窗口内） | ✅ |
| `BF3_BSP` / `BF3_ATF` / `BF3_UEFI` | `4.13.1.13827` / `4.13.1-0-g5fcb148df` / `4.13.1-14-g8a01157b7f` | 卡上 console 显示完全一致 | ✅ |
| **Arm 操作系统** | **Anolis 8.6** | ⭐ GRUB 报错 `/EFI/anolis/grubenv' not found` ⇒ **Anolis** | ✅ |
| Arm 侧 DOCA | `3.2.1025-1.an8.25.10.1.7.0.0.bf.4.13.1.13827` | 与 host 的 3.2.3 同代 | ✅ |
| 运行状态 | — | `INFO[MISC]: Linux up` / `INFO[MISC]: DPU is ready` | ✅ |
| ⭐⭐ **DPU 本体的 SSH 指纹** | Anolis 8.6（RHEL 8 系） | ⭐ **`OpenSSH_8.0`** + 认证方法含 `gssapi-keyex,gssapi-with-mic` | ✅ |
| ⭐⭐⭐ **`/etc/mlnx-release`（终局）** | `bf-bundle-3.2.1-31_25.11_anolis-8.6_prod` | ⭐ **完全相同**；`Anolis OS 8.6`、Arm 内核 `5.10.134-13.1.an8.aarch64` | ✅ |

> ⭐⭐ **第 6 条为什么最硬**：`OpenSSH_8.0` 是 **RHEL 8 / Anolis 8** 的版本；
> Ubuntu 22.04 是 8.9、Ubuntu 24.04 是 9.6 ⇒ **DPU 侧绝不是 Ubuntu**。
> 且 `gssapi-*` 是 **RHEL 系 OpenSSH 的默认编译选项**，Ubuntu 默认不提供。
> 这条是**从 DPU 自己身上取到的**，不依赖任何 bundle 文件 —— 取法见 §6.2。

> ⚠️ 排除「是不是 rshim 推流带进去的 Anolis」这个可能：`BOOT_MODE = 1 (emmc)`
> 且引导日志里 `INFO[BL2]: boot mode (emmc)` ⇒ **走的是卡上 eMMC 自己的系统**。
> 且 15:36 那次 rshim 推流只持续 3 秒（失败），推不动 1.4G 镜像。

### 两个包的内容对照（`bfb-tool info --all -j` 读出）

| 组件 | `bf-bundle-3.2.1-31_25.11_anolis-8.6` | `bf-bundle-3.5.0-89_26.07_ubuntu-24.04_64k` |
|---|---|---|
| **DOCA（DPU 侧）** | **`3.2.1025-1`** | **`3.5.0098`** |
| BF3_NIC_FW | **`32.47.1088`** ← 与卡现状相同 | `32.50.1002` ← **会升级** |
| BF3_BSP | `4.13.1.13827` | `4.16.0.14075` |
| BF3_ATF | `4.13.1-0-g5fcb148df` | `4.16.0-8-gda930bca9` |
| BF3_UEFI | `4.13.1-14-g8a01157b7f` | `4.16.0-48-g3e1cb60aa0` |
| BF3_BMC_FW | `25.10-15` | `26.07-8` |
| BF3_CEC_FW | `00.02.0195.0000` | `00.02.0208.0000` |
| Arm OS | **Anolis 8.6** | **Ubuntu 24.04（64k 页）** |

---

## 3. 官方依据：到底该用哪个版本

### 3.1 官方 LTS 发布矩阵（这才是配对依据）

| 产品 | 2026-06（U3） | 2026-02（U2） | ⭐ **2025-11（U1）** | 2025-10（GA） |
|---|---|---|---|---|
| **BF-3 DPU 固件**（bf-fwbundle 里的） | `32.47.3576` | `32.47.2682` | ⭐ **`32.47.1088`** | `32.47.1026` |
| **DOCA** | `3.2.3` | `3.2.2` | ⭐ **`3.2.1`** | `3.2.0` |
| **DOCA-Host** | `3.2.3-019000` | `3.2.2-035000` | `3.2.1-044000` | `3.2.0-125000` |

→ [Long-Term Support (LTS) Releases](https://networking-docs.nvidia.com/software/lts-releases)

⭐⭐ **这张表把两台机器的状态完全解释清楚了：**

| 机器 | host DOCA | 卡上 FW | 对应 LTS 批次 | 是否配对 |
|---|---|---|---|---|
| `10.17.21.85` | 3.2.2（U2） | `32.47.1088`（U1） | 跨 U1/U2 | ⚠️ 差一个 U，都在 32.47.x 内 |
| `10.17.20.237` | 3.2.3（U3） | `32.47.1088`（U1） | host U3 / DPU U1 | ⚠️ 差两个 U |

### 3.2 ⭐ DOCA 3.2.2 的「已验证互操作版本」清单（决定性的那条）

DOCA 3.2.2 官方列出的、**在多版本环境下经过测试验证**的搭配只有：

```
DOCA-OFED 3.2.1, 3.2.0, 24.10-4.1.4.0 (2.9.4), 23.10-6.1.6.0 (2.5.5)
```

→ [DOCA 3.2.2 General Support](https://networking-docs.nvidia.com/doca/archive/3-2-2/general-support)

⭐⭐ **对照我们的两个包：**

| 包 | 它的 DPU 侧 DOCA | 在 3.2.2 的验证清单里？ |
|---|---|---|
| ⭐ `3.2.1-31` | `3.2.1025-1` ⇒ **DOCA-OFED 3.2.1** | ✅ **在清单里** |
| ⛔ `3.5.0-89` | `3.5.0098` | ❌ **不在清单里** |

⭐⭐⭐ **这就是「用哪个包」的官方法定结论：host 用 DOCA 3.2.2 时，DPU 该配 `3.2.1` 那个包。**

### 3.3 ⛔ 为什么 `3.5.0-89` 这个文件尤其不能碰：它是 **64k 页**变体

NVIDIA 已知问题（BSP 4.15.0 报告，4.16.0 仍未修，**workaround: N/A**）：

> *"Installing the Ubuntu 24.04 **64K page size** BFB image onto the eMMC on a BlueField-3 DPU
> results in a **boot failure** even though the `bfb-install` utility reports that the
> installation finished successfully."*

→ [BlueField BSP Known Issues](https://networking-docs.nvidia.com/bsp/latest/known-issues)

我们的文件正好是 `…_ubuntu-24.04_**64k**_prod.bfb` ⇒ **精准命中这条已知问题**。
（官方文档也确认 64k 是 DPU 侧默认镜像形态：
*"The default operating system provided with the BlueField bundle… is Ubuntu 24.04 64k."*
→ [DOCA 3.5 General Support](https://networking-docs.nvidia.com/doca/archive/3-5-0/general-support)）

### 3.4 其它官方事实（备查）

| 事实 | 出处 |
|---|---|
| **DOCA 3.5 仍然支持 Ubuntu 22.04 host**（`22.04.x (x<=5)`，内核 5.15/6.8-HWE）——被砍掉的是 20.04 | [DOCA 3.5 General Support](https://networking-docs.nvidia.com/doca/archive/3-5-0/general-support) |
| DOCA 3.5 是**非 LTS**（GA 2026-07）；LTS 分支才是 3.2.x | [DOCA 3.5 Release Notes](https://networking-docs.nvidia.com/doca/archive/3-5-0/doca-release-notes) |
| FW 32.47.1xxx 起**不再兼容老 MFT**（4.31.0-149 / 4.30.0-139），"may cause unexpected behavior or prevent device detection" | [DOCA 3.2.2 Known Issues](https://networking-docs.nvidia.com/doca/archive/3-2-2/known-issues) |
| 固件可以**单独刷**（`bf-fwbundle-*.bfb` 只含固件、不含 Arm OS/DOCA）；也可用 `flint -d <dev> -i <img> burn` | [BSP Types and Methods](https://networking-docs.nvidia.com/bsp/latest/types-and-methods-of-updating-bluefield-software-image) |
| 降级警告：*"Downgrading to lower BFB/firmware versions may result in anomalous behavior."* | [BlueField BSP](https://networking-docs.nvidia.com/bsp/latest) |
| ⭐ `bf.cfg` 里写 **`WITH_NIC_FW_UPDATE=no`** 可**跳过 NIC 固件更新**（保 FW 不动） | [BSP Types and Methods](https://networking-docs.nvidia.com/bsp/latest/types-and-methods-of-updating-bluefield-software-image) |

> ⚠️ **官方未确认的两点**（不要当成规则用）：
> 1. 找不到「host DOCA 与 DPU DOCA 必须完全相同」的明文要求；
>    能查到的是**顺序**要求（先升 host DOCA，再装 BF-bundle）和 **DPU 侧自对齐**要求。
> 2. 找不到 FW 32.50.x 的「驱动最低版本」表 —— BF-3 固件发行说明库只到 32.43.2402。
>    ⇒ **FW 32.50.1002 与 25.10 驱动的组合，官方没有任何验证背书。**

### 3.5 ✅ 最终结论

| 方案 | host | DPU | 评价 |
|---|---|---|---|
| ⭐⭐ **A. 这就是要做的** | Ubuntu **22.04.4** + 内核 **5.15.0-105** + DOCA **3.2.2** + OFED **25.10-2.4.1** | **不动**（保留 Anolis 8.6 + DOCA 3.2.1 + FW `32.47.1088`） | ✅ **host/DPU 都落在 LTS 3.2.x，且 3.2.1 在 3.2.2 的验证清单里**；满足存储客户端的内核要求 |
| ⛔ B. 装 `3.5.0-89` | 任意 | Ubuntu 24.04 64k + DOCA 3.5 + FW 32.50.1002 | ⛔ **三条否决**：不在 3.2.2 验证清单 / 64k 已知 eMMC 启动失败 / 非 LTS 混搭 |
| ⛔ C. host 降 22.04 **+** 3.5 包 | 22.04 + 3.2.2 | DOCA 3.5 + FW 32.50 | ⛔ 最差：**跨代 + 新固件配老驱动**，存储客户端的适配矩阵也保不住 |
| 🔶 D. 将来想上 3.5（非本项目目标） | Ubuntu 22.04 或 24.04 + DOCA **3.5** | 3.5.0 BFB（⚠️ 先确认 64k 那条已知问题是否已修） | 需要 host/DPU 一起换，且 **FW 一跳就动了存储适配**，本项目不做 |

---

## 4. ⚠️⚠️ 重装之前必做：备份（按重要性排序，别跳）

| # | 备份什么 | 在哪 | 为什么 / 注意 |
|---|---|---|---|
| **1** | ⭐⭐⭐ **`bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527.bfb`（1.4 GB）** | `10.17.20.237:/root/` | **全网只剩这一份**。它是这台 DPU 现在「Anolis 8.6 + DOCA 3.2.1 + FW 32.47.1088」状态的**唯一恢复源**，而这正是官方验证过的搭配。老机器上没有。**不拷走就永久丢了** |
| **2** | ⭐⭐⭐ **ParaStor 私有客户端：`/clistorage/`（1.9 GB）+ `/etc/storage_conf.xml` + `/etc/crontab` 第 24–26 行 + `/mnt/fs1` 挂载方式** | `10.17.21.85`（237 上待核） | **整目录部署，不是 deb** ⇒ dpkg 装不回来。⚠️ `sysid` / `bb_<sysid>` / `posix_client_<sysid>.conf` 是**老机器专属节点身份**，**不能照抄给 237**（见 §7.2） |
| 3 | ⭐ **`/root/doca-host_3.2.2-035000-25.10-ubuntu2204_amd64.deb`** | `10.17.21.85:/root/` | 重装后装 DOCA 3.2.2 的**离线唯一来源**（它自带本地仓库，见 §5.2）。237 上没有 |
| 4 | ⭐ **内核钉版信息**（怎么让机器启动到 105） | `10.17.21.85`：`GRUB_DEFAULT=saved` + `GRUB_SAVEDEFAULT=true` | ⚠️ **不是靠 apt hold**（`apt-mark showhold` 为空、无 pin 文件）——**是靠 GRUB 记住上次选择**。见 §5.3 |
| 5 | `bf-bundle-3.5.0-89...bfb`（1.6 GB） | 两台都有 | 丢了还能从老机器找回来；**本项目不用它**，但当最后兜底 |
| 6 | 卡配置快照 | 两台卡的 `mlxconfig -e q` | 记录 `INTERNAL_CPU_*` 基线 |
| 7 | 卡固件档案 | `mlxfwmanager … --query`、`flint … q` | PSID / OPN / FW / BSP 基线 |
| 8 | rshim / 网络配置 | `/etc/systemd/network/10-tmfifo-net.link`、`/etc/netplan/`、`/etc/hosts`（⭐ 内有内网镜像映射）、`/etc/apt/sources.list.d/doca.list` | 重装后要重建 |
| 9 | 完整已装包清单 | `dpkg --get-selections > pkgs.txt` | 重装后逐项对 |

### 4.1 备份命令

```bash
# ① 独一份的 BFB：237 → 老机器（两台互通，实测 0.13ms）
#    在 10.17.20.237 上执行：
scp /root/bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527.bfb root@10.17.21.85:/root/

# ② 存储客户端 + DOCA 安装包 + 内核钉版信息：从老机器取到 237（或先取到本机/移动盘）
#    在 10.17.21.85 上执行：
tar czf /root/clistorage-backup-$(date +%Y%m%d).tar.gz /clistorage
tar czf /root/grub-and-apt-backup-$(date +%Y%m%d).tar.gz \
    /etc/default/grub /boot/grub/grub.cfg /etc/apt/sources.list.d/ \
    /etc/apt/sources.list /etc/hosts /etc/fstab /etc/netplan
dpkg --get-selections > /root/dpkg-selections-$(date +%Y%m%d).txt
ls -l /root/doca-host_3.2.2-035000-25.10-ubuntu2204_amd64.deb
```

```bash
# ③ 校验（两边 md5 必须一致）
md5sum /root/bf-bundle-3.2.1-31_*.bfb
# ④ 卡基线
mlxconfig -d /dev/mst/mt41692_pciconf0 -e q > /root/bf3-mlxconfig-baseline-$(date +%Y%m%d).txt
mlxfwmanager -d /dev/mst/mt41692_pciconf0 --query > /root/bf3-fw-baseline-$(date +%Y%m%d).txt
```

> ⚠️ 全部这些都在会被抹掉的根分区上 ⇒ **必须拷到别的机器/介质**。
> 注意：**存储客户端 `/clistorage/` 大概率只能从老机器取** —— 先确认存储厂商有没有原始安装包，
> 没有的话这份目录备份就是唯一来源。

---

## 5. 重装 host OS 的步骤与注意点

### 5.1 装机前

1. ✅ **确认 §4 的备份全部完成**（尤其第 1、2、3 项）
2. 记录现在这台机器的网络参数（重装后要配回去）：
   - `ens3f1`：**DHCP 拿到 `10.17.20.237/23`**，网关 `10.17.21.254`
     （静态路由 `10.2.100.250`、`10.2.101.250` 也是 DHCP 下发的）
   - hostname：`ubuntu`
3. ⭐ **OS 装 Ubuntu 22.04.4 LTS** —— 与老机器一致（存储客户端的要求）
4. ⚠️ 本机是 **Legacy BIOS 启动**（`/sys/firmware/efi` 不存在、无 EFI 分区），
   装机时保持 Legacy 或改 UEFI 都行 —— **与卡、与 DPU 无关**
5. ⚠️ **Secure Boot 未开**（`mokutil` 都没装）⇒ 装 DOCA 时不会弹
   「secure boot password」那一套，省事

### 5.2 ⭐ 重装所需的包：老机器上全都有，而且离线可用

```bash
# 老机器的 /etc/apt/sources.list.d/doca.list 指向一个【本地文件仓库】：
deb [signed-by=/usr/share/doca-host-3.2.2-035000-25.10-ubuntu2204/repo/doca_keyring.gpg] \
    file:/usr/share/doca-host-3.2.2-035000-25.10-ubuntu2204/repo ./
```

| 包 | 老机器上的版本 | 来源 |
|---|---|---|
| `doca-host` | `3.2.2-035000-25.10-ubuntu2204` | ⭐ `/root/doca-host_3.2.2-…ubuntu2204_amd64.deb`（**自带上面那个本地仓库**） |
| `doca-installer` | `1.3.10-1` | 本地仓库 |
| `mft` | `4.34.1-18` | 本地仓库 |
| `kernel-mft-dkms` | `4.34.1.18-1` | 本地仓库 |
| `rshim` | `2.5.10-0.g66a72a8.2510241` | 本地仓库 |
| OS 内核 | ⭐ `linux-image-5.15.0-105-generic` `5.15.0-105.115` | ⭐ **`https://mirrors.sugon.com/ubuntu/` jammy-updates**（内网，**还留着老内核**，这是关键） |

⇒ **重装后只要把那个 `doca-host` deb 拷过去 `dpkg -i`，DOCA 3.2.2 + MFT + rshim + doca-installer
一次全回来**（本地仓库会覆盖整套依赖）。

⚠️ 但**内网镜像 `mirrors.sugon.com` 必须在 `/etc/hosts` 里有映射**（老机器上写死
`10.2.100.102 mirrors.sugon.com`）—— 重装后记得补回去，否则 apt 用不了。

### 5.3 ⭐⭐ 怎么让机器启动到 `5.15.0-105`（老机器的真实做法）

老机器上**没有**用 apt 钉版：

```
apt-mark showhold                    → 空
/etc/apt/preferences.d/              → 只有 Ubuntu Pro 自带的两个文件
/etc/default/grub:
    GRUB_DEFAULT=saved               ← ⭐
    GRUB_SAVEDEFAULT=true            ← ⭐
grub.cfg 的默认项                    → vmlinuz-5.15.0-185-generic（最新那个）
运行中                               → 5.15.0-105-generic
```

⇒ **机制是靠 GRUB 的 `saved_entry` 记住「上次手动选的那个内核」**。
所以复现步骤是：

```bash
# 1) 装回老内核（内网镜像里还有）
apt-get install -y linux-image-5.15.0-105-generic linux-headers-5.15.0-105-generic \
                   linux-modules-5.15.0-105-generic

# 2) 让 GRUB 记住 105 为默认
#    老机器是 GRUB_SAVEDEFAULT=true + 手动在菜单里选一次；
#    脚本化可以用 grub-set-default（更确定）：
grep -vE '^\s*#' /etc/default/grub | grep -q "GRUB_DEFAULT=saved" || \
  sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
grep -q "GRUB_SAVEDEFAULT" /etc/default/grub || echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
update-grub
grub-set-default "gnulinux-5.15.0-105-generic-advanced-$(grep -oP 'gnulinux-simple-\K[0-9a-f-]+' /boot/grub/grub.cfg | head -1)"
update-grub
grub-editenv list          # 确认 saved_entry 指向 105
```

⚠️ 注意：
- **新内核仍会被装上**（`unattended-upgrades` 是 enabled+active）——
  老机器就是「装了 185 但启动 105」，这个状态是 OK 的；
  只要 `saved_entry` 不动，重启还是 105。
- DOCA 的 DKMS 模块**会为每个内核分别编译**（老机器上 `mlnx-ofed-kernel`/`iser`/`srp`/
  `xpmem`/`knem`/`kernel-mft-dkms` 对 105 和 185 都装了）⇒ 多内核共存没问题，
  但**装完新内核要确认 DKMS 编译成功**：`dkms status`。
- ⚠️ 装完 OFED/DOCA 后**务必确认当前内核的模块是从 updates/dkms 来的**：
  `modinfo mlx5_core | grep filename` → 应为 `/lib/modules/5.15.0-105-generic/updates/dkms/mlx5_core.ko`

### 5.4 ⚠️ 重装**不会**影响的东西（别去"修"它们）

- ❌ **不用**重新装 BFB（DPU 的 eMMC 原样保留）
- ❌ **不用**刷卡的固件、不用动 DPU 的 BMC / CEC
- ✅ 卡上 `mlxconfig` 的配置（`INTERNAL_CPU_*` 等）也保留在卡上

---

## 6. 重装之后：把 host 侧装回来（按顺序）

```bash
# ── 第 0 步：先把内网镜像补回去，否则 apt 全废 ──
grep -q mirrors.sugon.com /etc/hosts || echo "10.2.100.102 mirrors.sugon.com" >> /etc/hosts
# 确认 /etc/apt/sources.list 指向 https://mirrors.sugon.com/ubuntu/ jammy
apt-get update

# ── 第 1 步：老内核 ──
apt-get install -y linux-image-5.15.0-105-generic linux-headers-5.15.0-105-generic \
                   linux-modules-5.15.0-105-generic
# 然后按 §5.3 把 GRUB 默认指到 105，重启

# ── 第 2 步：DOCA 3.2.2 全家桶（一个 deb 搞定，含 MFT/rshim/doca-installer）──
dpkg -i /root/doca-host_3.2.2-035000-25.10-ubuntu2204_amd64.deb
# 它会铺开本地仓库并让你 apt 装上：
apt-get update
apt-get install -y doca-host doca-installer mft kernel-mft-dkms rshim
# ⭐ 或按老机器原样用 doca-installer：
#    doca-installer --help   （老机器上是 1.3.10-1）

# ── 第 3 步：确认 OFED 模块对当前内核编译成功 ──
dkms status
modinfo mlx5_core | grep -E "^version|^filename"
#   期望：version 25.10-2.4.1，filename /lib/modules/5.15.0-105-generic/updates/dkms/mlx5_core.ko

# ── 第 4 步：MFT / rshim 起来 ──
mst start && mst status -v
systemctl enable --now rshim
dd if=/dev/rshim0/misc of=/tmp/misc.txt bs=262144 count=1 iflag=nonblock   # ⚠️ 别用 cat，见 §8.1

# ── 第 5 步：恢复存储客户端 ──
#   按备份还原 /clistorage/、systemd 单元、/etc 引用、/mnt/fs1 挂载
#   ⚠️ 优先用存储厂商的原始安装包；没有才用目录备份
```

### 6.1 恢复后的验证清单

```bash
# ① 内核与驱动
uname -r                                   # 期望 5.15.0-105-generic
modinfo mlx5_core | grep ^version          # 期望 25.10-2.4.1
dkms status                                # 期望全部 installed

# ② 卡能被看见（不依赖驱动）
mst start && mst status -v                 # 期望 BlueField3(rev:1) 99:00.0/.1

# ③ 固件/PSID 与备份一致
mlxfwmanager -d /dev/mst/mt41692_pciconf0 --query | grep -E "PSID|Part Number"
#    期望：PSID MT_0000000965、OPN 900-9D3B6-00SV-A_Ax

# ④ 卡配置没变
mlxconfig -d /dev/mst/mt41692_pciconf0 -e q     # 与 §4 的 baseline 逐行对

# ⑤ rshim 通道 + DPU 状态
dd if=/dev/rshim0/misc of=/tmp/misc.txt bs=262144 count=1 iflag=nonblock
grep -E "BF_MODE|OPN_STR|UP_TIME|BOOT_MODE" /tmp/misc.txt
#    期望：BF_MODE = DPU mode、BOOT_MODE = 1 (emmc)、UP_TIME 在走

# ⑥ 网卡出现
ip -br link | grep -E "ens[0-9]+f[0-9]+np[0-9]"
ibstat -l
#    期望：两个 PF netdev + mlx5_0 / mlx5_1
#    ⚠️ 若等了很久还没有，见 §8.2

# ⑦ 进 DPU 的 Arm 系统（详见 §6.2）
ip addr add 192.168.100.1/24 dev tmfifo_net0
ping -c2 192.168.100.2
ssh <用户>@192.168.100.2 'cat /etc/mlnx-release'

# ⑧ 存储客户端
ps -eo comm,args | grep -iE "clistorage|oMgcd"
mount | grep fs1
```

### 6.2 ⭐ 进 DPU 的 Arm 系统（2026-11-10 18:41 实测走通）

```bash
# ① 给 tmfifo 管理口加地址（只增不改，重启即失；tmfifo_net0 不受 netplan 管）
ip addr add 192.168.100.1/24 dev tmfifo_net0
ip -br addr show tmfifo_net0           # 期望 inet 192.168.100.1/24

# ② 通不通
ping -c3 192.168.100.2                 # 实测 3/3，rtt 3–16 ms

# ③ ⭐ 不登录也能拿到 OS 指纹（判断 DPU 是 Anolis 还是 Ubuntu 最省事的办法）
ssh -vv -o BatchMode=yes -o PreferredAuthentications=none -o NumberOfPasswordPrompts=0 \
    probe@192.168.100.2 exit 2>&1 | grep -iE "remote software version|Authentications that can continue"
#   实测输出：
#     remote software version OpenSSH_8.0
#     Authentications that can continue: publickey,gssapi-keyex,gssapi-with-mic,password
#   ⇒ OpenSSH 8.0 + gssapi-* ⇒ RHEL 8 系（Anolis 8），**不是 Ubuntu**
#     （对照：Ubuntu 22.04 = OpenSSH 8.9，Ubuntu 24.04 = OpenSSH 9.6）

# ④ 读确切版本（需要 DPU 的用户名/密码）
ssh <用户>@192.168.100.2 'cat /etc/mlnx-release; head -3 /etc/os-release; uname -r'
```

| 实测项 | 值 |
|---|---|
| `ping 192.168.100.2` | ✅ 3/3，rtt 3–16 ms |
| DPU 监听端口 | **22 开**；80 / 443 / 8080 / 623 全关 |
| SSH 服务端版本 | ⭐ **`OpenSSH_8.0`** ⇒ RHEL 8 系 = **Anolis** |
| 认证方式 | `publickey,gssapi-keyex,gssapi-with-mic,password` |
| ⚠️ 缺什么 | **DPU 的登录账号密码** —— host 上**没有**密钥可用（`/root/.ssh/authorized_keys` 是 **0 字节空文件**），`known_hosts` 里也没有 `192.168.100.2` 的记录 |
| ⚠️ 串口 console 走不通 | 读 `/dev/rshim0/console` 得到 **0 字节**，往里写换行也逼不出新 banner ⇒ 想靠串口看发行版**不可行** |

> ⚠️ **登录账号密码不要写进本文件。** 装机后向现场/前一位安装人索取，或看 BFB 的 `bf.cfg` 预设。

### 6.3 ⭐⭐ 重装后让「进 DPU」这条路稳定可用（2026-11-11 实测补齐）

上面 §6.2 那些步骤在**重装之后会整套失效**，有两件事重装不会替你做：

#### ① `rshim.service` 重装后是 `disabled` + `inactive` —— 必须手动起

```bash
systemctl is-enabled rshim     # 重装后：disabled
systemctl enable --now rshim   # ⭐ 必须，且要开机自启
ls -l /dev/rshim0/             # 起来后才有 boot / console / misc / rshim
ip -br link show tmfifo_net0   # 起来后才有这张网卡
```

> ⚠️ **不起 rshim 的后果**：`/dev/rshim0/misc` 不存在 ⇒ **读不到 `BF_MODE` / `UP_TIME`**；
> `tmfifo_net0` 不存在 ⇒ `ping 192.168.100.2` **100% 丢包** ⇒ 看起来像「DPU 没了」，
> 其实只是**通道没建**。
> ⚠️ **但此时 `mlxconfig` 照样能用**（它走 PCI conf，不走 rshim）—— **别被这个迷惑**，
> 两件事要分开看。

#### ② `192.168.100.1/24` 手动 `ip addr add` 会丢 —— 做成 systemd 单元

```bash
cat > /etc/systemd/system/bf3-tmfifo-ip.service <<'EOF'
[Unit]
Description=Add 192.168.100.1/24 to tmfifo_net0 so the BlueField DPU is reachable
After=rshim.service network.target
Wants=rshim.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for i in $(seq 1 30); do [ -e /sys/class/net/tmfifo_net0 ] && break; sleep 1; done; /sbin/ip addr replace 192.168.100.1/24 dev tmfifo_net0'
ExecStop=/bin/sh -c '/sbin/ip addr del 192.168.100.1/24 dev tmfifo_net0 || true'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now bf3-tmfifo-ip.service
ip -br addr show tmfifo_net0     # 期望看到 192.168.100.1/24
```

> ⭐ 用 **`ip addr replace`** 而不是 `add` ⇒ 幂等，重复执行不报错。
> ⭐ `ExecStart` 里那个 `sleep` 循环**别删** —— rshim 建出 `tmfifo_net0` 有延迟，不等就会失败。

#### ③ 别名 + 免密（登录体验）

```bash
ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -C "$(hostname)-host"   # 只需一次
cat >> /root/.ssh/config <<'EOF'

Host bf3-dpu dpu
    HostName 192.168.100.2
    User root
    StrictHostKeyChecking accept-new
EOF
chmod 600 /root/.ssh/config
```

> ⚠️ **重装 host OS 或刷 BFB 之后，DPU 的主机密钥都会变** ⇒ 客户端报
> `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`，并且**会顺带禁用密码登录**（防 MITM），
> 于是看起来像"密码错了"。清掉即可：
> ```bash
> ssh-keygen -f /root/.ssh/known_hosts -R 192.168.100.2
> ssh-keygen -f /root/.ssh/kh_dpu     -R 192.168.100.2   # 若曾用独立 known_hosts
> rm -f /root/.ssh/*.old
> ```

#### ④ ⭐⭐⭐ 账号：这个 Anolis 包**只有 `root`**

```
DPU 侧 /etc/passwd 实测（非系统账号）：
  root        (uid=0,   home=/root)
  dmsuser     (uid=986, home=/home/dmsuser)      ← DOCA Management Service 服务号
  openvswitch (uid=994, home=/)
```

⇒ **`ssh ubuntu@192.168.100.2` / `ssh anolis@…` 必然 `Permission denied`，
因为账号不存在，不是密码错。** 用 **`root@`**。

**最终验收（一条命令）：**

```bash
ssh bf3-dpu 'hostname; cat /etc/mlnx-release; uname -r'
# 期望：Anolis OS 8.6 / bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527 / 5.10.134-13.1.an8.aarch64
```

### 6.4 ⚠️ 重装会抹掉存储网 IP（需自行补回）

重装后 `/etc/netplan/` 只剩安装器写的 `00-installer-config.yaml`，BF3 两个口回落成
`dhcp4: true`，而存储网**没有 DHCP** ⇒ **只剩 IPv6 链路本地地址，没有 IPv4**。

| 口 | 重装前的值（务必照抄回） |
|---|---|
| `ens21f0np0` | `20.17.20.237/23` |
| `ens21f1np1` | `30.17.20.237/23` |

> ⚠️ 这两条是 `20.17.20.0/23` 与 `30.17.20.0/23`（用户确认：**这两条是存储网**）。
> ⚠️ 补的时候注意三件事：① 安装器的默认文件里用的是**已弃用的 `gateway4`**，
> 应改写成 `routes: - to: default` + `via:`；② **按 MAC 固定接口名**
> （`match: {macaddress: …}` + `set-name:`），重装后网卡枚举顺序可能变；
> ③ netplan 文件必须 **`chmod 600`、UTF-8 无 BOM、LF 换行**，否则 netplan 拒绝加载。
> 改完用 `netplan try`（有回滚），别直接 `netplan apply`。

---

## 7. 存储客户端恢复（ParaStor 私有客户端）

### 7.1 它是什么（实测）

| 项 | 值 |
|---|---|
| 产品 | ⭐ **曙光 ParaStor 分布式存储的「私有客户端」**（`/clistorage/cli/pscli` ⇒ ParaStor） |
| 版本 | ⭐ **`4.2.2SP2`**，`cluster_version = 4.2.2SP2-111106`，包时间 `20261106_094819`（`/clistorage/system_version.xml`） |
| 部署形态 | **整目录部署 `/clistorage/`（1.9 GB）**，不是 deb ⇒ `apt`/`dpkg` 装不回来 |
| 自带安装器 | ✅ `/clistorage/install.py` → `_install` / `_install.py`(74 KB)；卸载 `remove.py` / `_remove` |
| ⭐ 节点身份 | `sysid = 1126096423`；`/clistorage/conf/posix_client_1126096423.conf`、`backup_node_1126096423.xml`、`bb_1126096423/` |
| 主配置 | ⭐ `/etc/storage_conf.xml`（648 B；标签含 `sysid`/`ip`/`ips`/`name`/`install_dir`/`storage_system`/`mgr_port`/`mgcd_nal_port_*`/`only_ctrl_network`/`alloc_mem`/`hybrid_client`/`resource_limit`；**实测 0 个密码类标签**） |
| 定时任务 | ⭐ `/etc/crontab` 第 **24–26 行**三条，全部指向 `/clistorage/tools/...` 与 `bin/mgcd_ha_client.sh` |
| 部署钩子 | `/clistorage/service_deployment_config.xml`（chronyd / log_compress / service_env 的 install/uninstall 钩子，`filter=true`） |
| 运行进程 | `oMgcd_client -m storage -a 0 -d 0`、`update_node_conf.py --state=0 --modulename=storage --sysid=1126096423`、`update_client_conf.py` |
| 挂载点 | `/mnt/fs1`（当前空） |
| 依赖 | 内核 `5.15.0-105` + OFED `25.10` 的 `srp`/`iser`/`isert`/`xpmem`/`knem` 模块 |
| ⚠️ 当前状态 | 4 个 RDMA 口全 `NO-CARRIER` ⇒ 连不上集群，`update_node_conf.py` 在反复重试（外面包着 `timeout -s 9 120`） |

> ⭐ 部署时间戳：`/clistorage` 下文件是 **2026-11-10 11:36–12:02** ⇒
> **这套客户端是今天刚装到 `10.17.21.85` 上的**，说明团队正在往节点上铺客户端。

### 7.2 ⭐⭐ 最重要的提醒：**不要直接把老机器那份拷到 237 上用**

`sysid` / `bb_<sysid>` / `posix_client_<sysid>.conf` / `/etc/storage_conf.xml` 里的
`sysid` + `ip` + `name` 都**绑定了「老机器是哪个节点」**。
ParaStor 的私有客户端要靠**集群侧先为这个节点分配 ID 与挂载/配额配置**才能连上。

⇒ **正确做法**：

1. 找存储管理员**为 237 单独分配节点 ID（sysid）与客户端配置**
2. 用**存储厂商给的原始客户端包**在 237 上装（`install.py`），**而不是照抄 21.85 的目录**
3. 备份 21.85 的 `/clistorage/` 只为两件事：
   **（a）确认要装哪些文件、哪些 cron、哪些 `/etc` 改动；（b）原始包找不到时当参考**

### 7.3 恢复顺序

1. ⭐ **先装内核 `5.15.0-105` + DOCA 3.2.2 / OFED 25.10**（客户端依赖这些内核模块）
2. 再装/恢复客户端（优先用原始包）
3. 核对 `/etc/crontab` 三条、`/etc/storage_conf.xml`、`/mnt/fs1`
4. 收尾验证：

```bash
ps -eo comm,args | grep -iE "clistorage|oMgcd"
dkms status | grep -E "srp|iser|xpmem|knem"
ibstat | grep -E "State:|Physical state:"
mount | grep fs1
```

---

## 8. 排障速查（本次会话踩出来的，都是真金白银）

### 8.1 读 `/dev/rshim0/misc` 的正确姿势

```bash
# ❌ cat /dev/rshim0/misc     —— 永远阻塞（字符设备不返回 EOF），
#                                连 timeout 都杀不掉 D 状态的读，还会把 ssh 通道占住
# ✅ 这样读：
echo "DISPLAY_LEVEL 2" > /dev/rshim0/misc     # ⭐ 不设这个，Log Messages 段是空的！
dd if=/dev/rshim0/misc of=/tmp/misc.txt bs=262144 count=1 iflag=nonblock
cat /tmp/misc.txt
echo "DISPLAY_LEVEL 0" > /dev/rshim0/misc     # 用完还原
```

### 8.2 ⭐ 网卡"全没了"的两个不同病因，别搞混

| 症状 | 判据 | 解药 |
|---|---|---|
| **推流撞车** | `dmesg -T` 里有 **`SW reset semaphore is already in use`**（有人写 `/dev/rshim0/boot`，与 `mlx5_core` 复位路径抢信号量 ⇒ 驱动 teardown） | ✅ `echo "SW_RESET 1" > /dev/rshim0/misc`（实测约 100 秒后 netdev/RDMA 全部回来） |
| **开机 4 分钟无网卡** | `wait_fw_init` 串行等待，每个 PF 等 FW pre-init 超时（老机器 120s × 2 = 240s） | 只能等；缓解：`vfio-pci.ids=15b3:a2dc` / BIOS 屏蔽槽位 |

### 8.3 判断 ATX 辅助供电接没接

- ✅ **唯一可信判据**：卡自己的引导日志里有没有
  `ERR[BL31]: ATX missing` / `ATX power not detected! Halting system!!`
- ❌ **不能用**：`lspci` 的 `DevSta: AuxPwr-`、`SlotPowerLimit 0.000W`
  —— 实测**接了线的机器也显示 `AuxPwr-`**（那是 PCIe 3.3Vaux，与 8-pin ATX 无关）
- ⚠️ 也**不能用**「BL 链能跑 / `UP_TIME` 会走 / `SW_RESET` 有效」来排除 ——
  这些都发生在 CPU 域之前，**到 BL31(ATF) 才做电源检查**

### 8.4 一个尚未解释的差异

同样是 FW `32.47.1088`，两台机器的 `wait_fw_init` 超时差了 47 倍：

| 机器 | 超时 | 并行/串行 |
|---|---|---|
| 老机器 | **120 s**（两 PF 串行 = 240 s） | 串行 |
| 对照机 | ⚠️ **~5700 s（≈95 分钟）** | 并行 |

原因未确认，`/sys/module/mlx5_core/parameters/fw_init_timeout` 两台都读不出值。**待查证。**

---

### 8.5 ⭐⭐ "DPU 好像没了" —— 先查 rshim 有没有起来（2026-11-11 补）

重装 host OS 后最容易误判的一种情况：**`rshim.service` 是 `disabled` + `inactive`**。

| 现象 | 真相 |
|---|---|
| `/dev/rshim0/misc` 不存在 ⇒ 读不到 `BF_MODE` / `UP_TIME` | rshim 没起，**管理通道没建**，不是 DPU 挂了 |
| `tmfifo_net0` 不存在 ⇒ `ping 192.168.100.2` **100% 丢包** | 同上 |
| ⚠️ **但 `mlxconfig` 照样读得出 `INTERNAL_CPU_OFFLOAD_ENGINE`** | 它走 **PCI conf**、不经 rshim ⇒ **别被这个迷惑** |

```bash
systemctl enable --now rshim
ls -l /dev/rshim0/            # 应出现 boot / console / misc / rshim
ip -br link show tmfifo_net0  # 应出现
```

⇒ 地址持久化、别名、账号（**只有 `root`**）见 **§6.3**。

---

## 9. 装 BFB（2026-11-11 在 `10.17.20.237` 上**实测跑通**，全程约 15 分钟）

> ⭐ **这一节是实战版**：2026-11-11 09:0x 用 `bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527.bfb`
> 把 DPU 的 eMMC 整个重刷了一遍。**刷完两条硬指标与刷前逐行 `diff` 完全一致** —— 即"重刷 BFB
> 不会破坏 `cpuoffload` 与网卡"这件事，已经有了实测依据，不用再靠推理。

### 9.1 开刷前的三条硬性准备

```bash
# ① rshim 必须在跑（⭐ 重装 host OS 后默认是 disabled！）
systemctl enable --now rshim
ls -l /dev/rshim0/                 # 要有 boot / console / misc / rshim

# ② 留基线，刷完才能证明卡配置没被动
mlxconfig -d /dev/mst/mt41692_pciconf0 -e q > /root/pre-bfb-mlxconfig.txt
flint -d /dev/mst/mt41692_pciconf0 q | grep -E "FW Version|PSID"

# ③ 生成 host→DPU 的公钥（后面要写进 bf.cfg）
ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -C "$(hostname)-host"
cat /root/.ssh/id_ed25519.pub
```

> ⚠️ **`bfb-tool info` 需要 `jq`**，新装的 Ubuntu 22.04 上**没有** ⇒ 先 `apt install jq`，
> 否则报 `ERROR: jq is required`（**不影响 `bfb-install`**）。
> ⚠️ **`bfb-install` / `bfb-tool` 是 `rshim` 这个 deb 包提供的**，不是 `doca-installer`
> （新系统上 `doca-installer` 缺失也不影响刷机）。

### 9.2 ⭐⭐⭐ `bf.cfg` 要用 `bfb_modify_os()` 通用钩子（**本节最关键**）

官方 `bf.cfg` 里那个 `ubuntu_PASSWORD` **明确标注 `Relevant for Ubuntu BFB only`**，
而我们的包是 **Anolis** ⇒ **不能用它**。

✅ **正确做法：用 `bfb_modify_os()`** —— 安装时目标 rootfs 挂在 **`/mnt`**，
可以在里面任意改文件、**与发行版无关**。（另有 `bfb_pre_install()` 在格式化前、
`bfb_post_install()` 在最后一步但**分区已卸载**，改文件必须用 `bfb_modify_os`。）

```bash
cat > /root/bf.cfg <<'CFGEOF'
# ⭐ 注释行必须在开头（官方要求）
WITH_NIC_FW_UPDATE=no        # ⭐ NIC FW 已是同版本 ⇒ 跳过，顺带避免 NIC reset
UPDATE_BMC_FW=no             # ⭐ 下面这四个都需要 BMC 密码，
UPDATE_CEC_FW=no             #    拿不到就必须显式跳过，否则会卡住/超时
UPDATE_CERTIFICATES=no
RESET_BMC_RSHIM_LOG=no

NODE_PW='__PWHASH__'         # openssl passwd -1 生成的 hash（⭐ 必须单引号）
NODE_PUB='__PUBKEY__'

bfb_modify_os()
{
    log "--- os-release ---";   head -n 3 /mnt/etc/os-release
    log "--- mlnx-release ---"; cat /mnt/etc/mlnx-release
    log "--- users ---";        awk -F: '$3>=1000 || $1=="root" {print $1":"$3":"$6}' /mnt/etc/passwd
    log "--- /home ---";        ls -la /mnt/home

    for u in root ubuntu anolis admin; do
        if grep -q "^$u:" /mnt/etc/passwd; then
            sed -i "s|^$u:[^:]*:|$u:${NODE_PW}:|" /mnt/etc/shadow
            log "password set for user: $u"
        fi
    done
    chmod 000 /mnt/etc/shadow

    for h in /mnt/root /mnt/home/*; do
        [ -d "$h" ] || continue
        mkdir -p "$h/.ssh"
        echo "${NODE_PUB}" >> "$h/.ssh/authorized_keys"
        chmod 700 "$h/.ssh"; chmod 600 "$h/.ssh/authorized_keys"
        log "pubkey installed -> $h/.ssh/authorized_keys"
    done

    sed -i -e 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
           -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
           -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
           /mnt/etc/ssh/sshd_config

    [ -f /mnt/etc/selinux/config ] && \
        sed -i 's/^SELINUX=.*/SELINUX=permissive/' /mnt/etc/selinux/config
    log "##### customize END #####"
}
CFGEOF

# 注入 hash 与公钥
HASH=$(openssl passwd -1 '你的密码')
PUB=$(cat /root/.ssh/id_ed25519.pub)
sed -i "s|__PWHASH__|$HASH|; s|__PUBKEY__|$PUB|" /root/bf.cfg
chmod 600 /root/bf.cfg
```

> ⚠️⚠️ **`hash` 里带 `$`（形如 `$1$salt$hash`）**，这是最容易写坏的地方：
> - 在 `bf.cfg` 里必须 **单引号** `NODE_PW='$1$…'`，函数里引用 **`${NODE_PW}`**。
>   若把 hash 直接内联进双引号字符串，shell 会把 `$1` / `$salt` / `$hash` 当变量展开 ⇒ **密码是坏的**。
> - 官方还提醒：**`=` 两边不能有空格**。
>
> ⭐ **为什么要动 SELinux**：Anolis 是 RHEL 系，`SELINUX=enforcing` 会因 context 问题
> 拒掉 `~/.ssh/authorized_keys` ⇒ 免密登录失败。测试机上设 `permissive` 最省事。
> ⭐ `chmod 000 /mnt/etc/shadow` 是 RHEL 系的正确权限（`sed -i` 会改掉它）。

### 9.3 正式开刷

```bash
bfb-install -b /root/<你的.bfb> -c /root/bf.cfg -r rshim0
```

> ⚠️⚠️ **中途绝对不能打断、不能重启主机。** 官方原话：安装未完成就重启，可能导致
> **`bfb-install` 报成功、但 DPU 起不来 / SSH 不通**。
> ✅ **兜底：真出这种事，重跑一次 `bfb-install` 就能恢复。**
>
> ⭐ 长任务用 `setsid nohup … > log 2>&1 &` 起、再单独轮询日志 —— 别让 SSH 断线把它带走。
> ⭐ `bfb-install` 会清空 rshim 日志，但另存一份到 **`/tmp/bfb-install-rshim0.log`**。
> ⭐ 有 `pv` 才显示推送进度条；没有只提示 `Warn: 'pv' command not found`，**不影响**。

**成功日志（本次实测原文节选）：**

```
Checking if local host has root access...
Checking if rshim driver is running locally...
Pushing bfb + cfg
...
INFO[MISC]: Found bf.cfg
INFO[MISC]: Anolis installation started                              ← 包里是哪个发行版，这里直说
INFO[MISC]: Running bfb_modify_os from bf.cfg
INFO[MISC]: password set for user: root                              ← 钩子生效
INFO[MISC]: pubkey installed -> /mnt/root/.ssh/authorized_keys       ← 钩子生效
INFO[MISC]: sshd_config patched (PermitRootLogin yes)
INFO[MISC]: SELinux -> permissive
INFO[MISC]: Anolis installation completed                            ← 装完了
WARN[MISC]: Skipping BMC components upgrade.                         ← 因为显式跳过了 BMC
INFO[MISC]: Installation finished
...
INFO[MISC]: Linux up
INFO[MISC]: DPU is ready                                             ← 看到这个才算成
```

### 9.4 刷完的验收（**四条都要过**）

```bash
# ① 卡配置没变（与刷前基线逐行 diff）
mlxconfig -d /dev/mst/mt41692_pciconf0 -e q > /tmp/after.txt
diff /root/pre-bfb-mlxconfig.txt /tmp/after.txt && echo "✅ 完全一致"

# ② 硬指标一：cpuoffload 可见
mlxconfig -d /dev/mst/mt41692_pciconf0 -e q | grep -i cpu_offload

# ③ 硬指标二：网卡可见
ip -br link | grep -E 'np[0-9]'

# ④ DPU 能进，且确认它到底是什么系统（这一步顺便回答"卡里是哪个包"）
ssh bf3-dpu 'cat /etc/mlnx-release; uname -r'
```

> ⭐ 本次实测：**①逐行完全一致、②③④全过**；`FW Version` 仍为 `32.47.1088`（因为跳过了 NIC FW）。

> ⚠️ 出现 **`ERR[BL31]: ATX missing - initiating halt sequence...`** ⇒
> **8-pin ATX 辅助供电没接**，先接线，刷什么都没用（见 §8.3）。
>
> ⚠️ 出现 **`Error: Failed to push boot stream via local rshim`** 且 rshim 日志里
> `boot open` → `boot close` **只有几秒** ⇒ 推流失败，先查 ATX，再查是不是撞车（§8.2）。

### 9.5 ⚠️ NIC 模式要换格式

`bfb-tool` 帮助里写得很明白：

> `--output-format <format>` — **Bundle format is the format for DPU mode (default).
> Flat format is the format for NIC mode.**

⇒ **要做 NIC 模式，先用 `bfb-tool repack` 转成 flat 格式**，别直接推 bundle 格式的包。

```bash
bfb-tool repack --bfb /root/<bundle>.bfb --psid MT_0000000965 \
                --output-format flat --output-bfb /root/<flat>.bfb
```

### 9.6 常用 `bfb-tool` / `doca-installer` 命令

```bash
# 看包里到底有什么版本（不装也能看）
bfb-tool info --bfb /root/<bundle>.bfb --all -j | less
# 看这个包支不支持你的卡
bfb-tool info --bfb /root/<bundle>.bfb --psid MT_0000000965
# 取出包里的 bf.cfg（如果有）
bfb-tool extract --bfb /root/<bundle>.bfb --psid MT_0000000965 --extract-bfcfg

# ⭐ 装之前先比对「包里要刷什么」vs「设备现在是什么」（doca-installer ≥ 某版本才有）
doca-installer -b <bundle>.bfb --show-target-fw     # 包里目标固件版本
doca-installer --show-running-fw                    # 设备当前固件版本
doca-installer -b <bundle>.bfb --compare            # 两者差异

# 装完后核对
flint -d /dev/mst/mt41692_pciconf0 q
```

---

## 10. 回滚 / 兜底

| 想回到 | 怎么做 |
|---|---|
| DPU 回到现在的 3.2.1/Anolis 状态 | 用备份出的 **`3.2.1` 包**重跑 `bfb-install` |
| host 工具链回到现状 | 按 §6 重装；版本对照见 §1 |
| 卡配置回到基线 | `mlxconfig -d … -y set <参数>=<值>`（用 §4 的 baseline 逐项对） |
| 卡彻底起不来 | `SW_RESET`（§8.2）→ 重装 BFB（§9）→ 报修换卡 |

> ⚠️ 两个**不要**：
> 1. **不要在 DPU 正在推流/复位时**去动 `/sys/bus/pci/.../bind`、`rescan`，
>    或再写一次 `/dev/rshim0/boot` —— 会撞车（§8.2）。
> 2. **不要用 `INTERNAL_CPU_MODEL=SEPARATED_HOST`** —— NVIDIA 明确弃用，
>    且会让 `INTERNAL_CPU_OFFLOAD_ENGINE` 参数从配置里消失。

---

## 附：一页纸速查

```
① 备份（缺一不可）
   /root/bf-bundle-3.2.1-31_...anolis-8.6...bfb             ← 237 独一份
   /clistorage/                                            ← 21.85，存储客户端
   /root/doca-host_3.2.2-035000-25.10-ubuntu2204_amd64.deb ← 21.85
   GRUB(saved_entry) + /etc/hosts + apt sources            ← 21.85

② 重装 237 → Ubuntu 22.04.4 LTS（Legacy BIOS）
③ 补 /etc/hosts 的 mirrors.sugon.com → apt update
④ 装 linux-image-5.15.0-105-generic + GRUB 默认指 105 → 重启
⑤ dpkg -i doca-host_3.2.2-...ubuntu2204.deb → apt 装 doca-host/mft/rshim
⑥ dkms status 全绿 + modinfo mlx5_core = 25.10-2.4.1
⑦ 验证两条硬指标（§6.1）：
     mlxconfig -d /dev/mst/mt41692_pciconf0 -e q | grep -i cpu_offload  → ENABLED(0)
     ip -br link | grep np[0-9]                                        → 2 个 UP
⑧ ⭐⭐ 开 rshim（重装后默认 disabled！）+ tmfifo 地址持久化（§6.3）
     systemctl enable --now rshim
     systemctl enable --now bf3-tmfifo-ip.service
     ssh bf3-dpu 'cat /etc/mlnx-release'      ← ⭐ 账号只有 root，没有 ubuntu/anolis
⑨ 恢复 /clistorage/ 与 /mnt/fs1；补回存储网 IP（§6.4）
⑩ （可选）刷 BFB：写 bf.cfg（§9.2）→ bfb-install -b <bfb> -c bf.cfg -r rshim0（§9.3）
⑪ ⛔ DPU 侧不用装 DOCA；3.5 那个 64k 的 BFB 不要用

── 2026-11-11 09:10 已完成 ────────────────────────────────
✅ 237 = node99 / Ubuntu 22.04.4 LTS / 5.15.0-105 / DOCA 3.2.2-035000 / OFED 25.10-2.4.1
✅ 两条硬指标达成；刷完 3.2.1 BFB 后与刷前逐行 diff 完全一致，FW 仍 32.47.1088
✅ DPU = Anolis OS 8.6 / 内核 5.10.134-13.1.an8.aarch64
     /etc/mlnx-release = bf-bundle-3.2.1-31_25.11_anolis-8.6_prod.20260527（实测确认）
✅ ssh bf3-dpu 免密 / 密码 / 别名 三条全通
⚠️ 未做：存储网 IP 由用户自行补回（§6.4）
```
