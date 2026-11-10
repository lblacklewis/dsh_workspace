# BlueField-3 安装 BFB：让 DPU 侧的 ARM 跑起来

> **前置状态**：本机 BF3 曾处于 DPU 模式（`INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED(0)`），
> 但 eMMC 里没有可引导系统 → host PF 探测 `-110`、网卡消失。
> 本文解决"给 ARM 装一个系统"这一步。
> 前情与故障链条见 [`BlueField-3-DPU转NIC模式排查.md`](BlueField-3-DPU转NIC模式排查.md)。
>
> ## 🔴 2026-11-10 晚 状态更新：**卡现在是 NIC 模式，但网卡依然不可用**
>
> | 层面 | 值（实测） |
> |---|---|
> | flash（`Next Boot`）/ 运行中（`Current`）/ 卡侧（`BF_MODE`） | **NIC 模式**：`OFFLOAD_ENGINE=DISABLED(1)` + 三个 `EXT_HOST_PF(1)` |
> | host PF | ❌ **仍 `-110`**（`wait_fw_init` 120s 超时，网卡不出现） |
>
> ⚠️ **所以"装 BFB"目前不是当前任务** —— 用户已在 2026-11-10 决定走 **NIC 模式**
> （放弃了 DPU 功能）。**本文保留，作为将来若接上 ATX 线、想回头上 DPU 时的操作手册。**
>
> ⭐ **但本文第六节第 1 条（ATX）现在对两条路都适用** ——
> **官方 NIC 模式路径同样需要那根线**（实测见排查文档 §6.9 / §6.10）。
>
> ## 🟢 2026-11-10 16:20 更新：**ATX 的作用已被另一台机器正面验证**
>
> 用户提供的对照机 `10.17.20.237`（已接 8-pin ATX、同型号 BF3、同 FW `32.47.1088`）
> 上，引导链**完整跑通、没有任何 ATX 报错**，一路走到
> `UEFI: PCIe enum end` / `Secure Boot` / `Redfish enabled`；
> 而老机器在同一位置报 `ERR[BL31]: ATX missing` → `ATX power not detected! Halting system!!`。
>
> ⇒ **"ATX 未接"这个阻塞已被证实**，本文第六节第 1 条的结论成立。
> ⚠️ 而且对照机还演示了：**ATX 已接 + Arm 有系统 ⇒ host PF 正常起来、netdev 出现**，
> 即 DPU 模式本身没问题 —— 前提是 **Arm 必须真的引导起系统**。
> 完整对照日志见 [`BlueField-3-DPU转NIC模式排查.md` §6.11](BlueField-3-DPU转NIC模式排查.md)。

---

## 一、结论摘要

| 问题 | 答案 |
|---|---|
| 要装什么 | NVIDIA 官方 **BF-bundle**（BFB），版本要跟主机 DOCA 同一 train |
| 从哪拿 | [NVIDIA DOCA Downloads](https://developer.nvidia.com/doca-downloads) |
| ⚠️ 必须签名 | 本卡 `Security Attributes: secure-fw`，**只能用 NVIDIA 官方签名镜像** |
| 本机能否下载 | ❌ **不能** —— 见第二节实测 |
| 怎么送进来 | 见第四节（三条通道） |
| 装多久 | 文件 1.5–2.5 GB；推送 + 安装约 **10–20 分钟** |
| 要不要再断 AC | ✅ **不需要** —— rshim 装 BFB 会让 SoC 自己从 rshim 引导一次 |

**最小可行路径**（就这四步）：

```bash
# 1) 在【有外网的机器】上下载 BF-bundle（约 1.5–2.5 GB）
# 2) 传到服务器
scp bf-bundle-<版本>_ubuntu-22.04_prod.bfb root@10.17.21.85:/root/
# 3) 装（服务器上执行，10–20 分钟）
bfb-install --rshim rshim0 --bfb /root/bf-bundle-<版本>_ubuntu-22.04_prod.bfb
# 4) 等 90 秒后确认
cat /dev/rshim0/misc | tail -20      # 期待 INFO[MISC]: Linux up / DPU is ready
```

---

## 二、本机现状实测（2026-11-10）

### 卡与固件

```
型号          900-9D3B6-00CC-EA_Ax   (BlueField-3 B3210E E-Series FHHL)
PSID          MT_0000001115
FW            32.47.1088   (2025-09-12)
Security      secure-fw                     ← ⚠️ 只能用签名镜像
Base MAC      a4a64e490efa
PCI          3b:00.0 / .1 (PF) · 3b:00.2 (SoC 管理口)
mlxconfig     INTERNAL_CPU_OFFLOAD_ENGINE = ENABLED(0)   ← ⭐ DPU 模式（官方判据）
              INTERNAL_CPU_MODEL = EMBEDDED_CPU(1)       ← 出厂默认值，仅参考
派生参数      PAGE_SUPPLIER/ESWITCH_MANAGER/IB_VPORT0 = ECPF(0)
```

> ⭐ **判断 DPU/NIC 模式只认这一条**（NVIDIA 官方指定）：
>
> ```bash
> mlxconfig -d /dev/mst/mt41692_pciconf0 q INTERNAL_CPU_OFFLOAD_ENGINE
> #   ENABLED(0)  = DPU 模式   ← 本机当前
> #   DISABLED(1) = NIC 模式
> #   带 RO 前缀  = DPU 模式 + Zero Trust（只读）
> ```
>
> ⚠️ `INTERNAL_CPU_MODEL` **不是**模式判据；`SEPARATED_HOST` 是 NVIDIA 已弃用的参数，别用。
> 详见 [`BlueField-3-DPU转NIC模式排查.md`](BlueField-3-DPU转NIC模式排查.md) §3.2 / §6.7。

### rshim 通道：已就绪

```
/dev/rshim0/boot  /dev/rshim0/console  /dev/rshim0/misc  /dev/rshim0/rshim
BOOT_MODE    1 (emmc)          ← 想从 eMMC 引导，但 eMMC 是空的
OPN_STR      N/A               ← ARM/UEFI 从未走到填它的阶段
tmfifo_net0  00:1a:ca:ff:ff:02  ← 主机↔DPU 虚拟网口（装完后靠它进 DPU）
```

拉起 rshim（当前已在跑）：

```bash
PCIE_HAS_VFIO=1 rshim -b pcie -f
```

### 工具链：齐全

| 工具 | 路径 | 用途 |
|---|---|---|
| `bfb-install` | `/usr/sbin/bfb-install` | **主用** —— 装 BFB |
| `bfb-tool` | `/usr/sbin/bfb-tool` | `extract` / `repack` / `info`，按 PSID 选载荷 |
| `doca-installer` | `/usr/bin/doca-installer` ✅ **已装**（`1.3.10-1`，2026-11-10 离线装） | 多卡并行装，支持 `--psid` 分组 |
| `rshim` | `/usr/sbin/rshim` | 用户态，直映射 BAR，不需要内核模块 |

`doca-installer` 已离线装好（走本地 `file:` 源，不动网络）：

```bash
apt-get install -y doca-installer      # 已完成
```

已核实的参数（与官方文档一致）：

```
-b/--image-bundle    -r/--rshim        -c/--config-file    -p/--psid
--exclude            --show-target-fw  --compare          --show-running-fw
--show-doca-info     --runtime         --deferred         --activate
--export-yaml
```

> 基线记录：`doca-installer --show-running-fw` 当前**返回空** ——
> DPU 侧没有系统可应答。装完 BFB 后它应该能列出 ATF/UEFI/BMC/NIC FW 版本。

### ⚠️ 网络：BFB 拿不到，必须外部送进来

| 探测 | 结果 |
|---|---|
| `mirrors.sugon.com` | 标题 **"内网镜像"**；只有 `ubuntu`（`/ubuntu/dists/jammy` = 200） |
| `/nvidia` `/doca` `/bfb` `/bluefield` `/mellanox` | **全部 404** |
| `10.2.100.102`（DNS，80/443 开着） | openresty，12 字节占位页，不是仓库 |
| apt 代理 / nexus / artifactory 痕迹 | 零 |
| 出口路由 | **只有 `eno1` → `10.17.21.254`**；其余 6 个口 `carrier=0`（没插线） |
| 外部站点（阿里云 / NVIDIA / GitHub） | 全部连不上 |

### 主机环境

```
整机     Sugon I620-G30   BMC 10.17.21.39 (Firmware 4.03)
系统     Ubuntu 22.04.4 LTS   kernel 5.15.0-105-generic
DOCA     doca-host-3.2.2-035000-25.10-ubuntu2204   ← 3.2.x / 25.10 train
磁盘     70G 可用      内存 125G
```

> DOCA 文档要求：**先更新 host 侧 DOCA，再在 BlueField 上装 BF-bundle**。
> 本机 host 侧已是 3.2.2，与目标 train 一致 ✅

---

## 三、要下载哪个 BFB

### 版本匹配

到 [NVIDIA DOCA Downloads](https://developer.nvidia.com/doca-downloads)，
选与主机**同一 DOCA train** 的 **BlueField-3 BF-bundle（Ubuntu 22.04）**：

- 主机是 `doca-host-3.2.2-035000-25.10` → 选 **DOCA 3.2.x / 25.10**
- 文件名形如 `bf-bundle-<版本>_<train>_ubuntu-22.04_prod.bfb`
  （NVIDIA 文档示例为 `bf-bundle-2.7.0_24.04_ubuntu-22.04_prod.bfb`）

### 拿到后先验，别急着装

```bash
# 1) 看包里带什么版本 / 覆盖哪些 OPN·PSID
bfb-tool info --bfb <file> --all

# 2) 看它带的固件版本（和卡上 32.47.1088 对比）
doca-installer -b <file> --show-target-fw
```

### 如果 PSID 不匹配（多 OPN 包）→ repack

```bash
bfb-tool repack --bfb <file> --psid MT_0000001115 \
                --output-format bundle --output-bfb /root/bf3-custom.bfb
```

- `--output-format bundle` = **DPU 模式**（默认）
- `--output-format flat` = NIC 模式
- ⚠️ repack **只挑载荷、不重新签名**；官方组件自身的签名保留，安全启动仍能过

### ⚠️ 绝对不要用 `bfb-build` 自建镜像

本卡 `secure-fw`（UEFI 安全启动开启是默认值）。按 [NVIDIA 文档](https://networking-docs.nvidia.com/doca/archive/3-2-3/bf-bundle-installation-and-upgrade.md)：

> 要在 UEFI 安全启动开启的 BlueField 上引导定制镜像，镜像必须**已用 UEFI DB 中已有的密钥签名**
> （例如 Microsoft 密钥）；做不到就必须**关闭安全启动**。

自建镜像（[Mellanox/bfb-build](https://github.com/Mellanox/bfb-build/)）过不了验签。
**用官方签名包，路最短。**

---

## 四、把 BFB 送进来的三条通道

### 通道 A：从你的电脑直接传（**推荐**）

在能上网的机器上下载，然后传进 `/root/`：

```powershell
# Windows（server 上没装 ssh 客户端的话用 WinSCP / pscp 也行）
scp .\bf-bundle-3.2.2_25.10_ubuntu-22.04_prod.bfb root@10.17.21.85:/root/
```

传完**务必校验**（1.5GB+ 传坏了会浪费一次安装）：

```bash
ls -l /root/*.bfb
sha256sum /root/*.bfb      # 与下载页给的校验值比对
```

### 通道 B：BMC 虚拟介质（`10.17.21.39`）

Sugon BMC 的 **Virtual Media** 可以挂 ISO。把 BFB 打成 ISO 后挂载，
主机侧 `mount /dev/sr0 /mnt` 拷出来即可。
（不用从它引导，只是当个"只读 U 盘"用。）

- 优点：不依赖能 SCP 的机器
- 缺点：得先在本地做 ISO；1.5GB+ 通过 BMC 传输较慢

### 通道 C：从另一台 Linux 远程推送

`bfb-install` 支持远程模式（`-m scp|nc|ncpipe`、`-r [<ip>:<port>:]rshim<N>`）。
在一台**有 BFB、能 SSH 到本机**的 Linux 上：

```bash
bfb-install -b <file> -r 10.17.21.85:22:rshim0 -m scp
```

- 优点：服务器上不用落地这个文件
- 缺点：需要另一台 Linux + 免密 SSH；具体参数组合建议先 `bfb-install --help` 核对

---

## 五、安装步骤

```bash
# 0) 确认 rshim 在跑、设备节点在
pgrep -f '/usr/sbin/rshim' || PCIE_HAS_VFIO=1 rshim -b pcie -f &
ls -l /dev/rshim0/

# 1)（可选）准备 bf.cfg —— 预设 ubuntu 密码，免去首次登录强制改密
openssl passwd -1                 # 交互输入密码，拿到 hash
echo "ubuntu_PASSWORD='<上一步的hash>'" > /root/bf.cfg

# 2) 开装
bfb-install --rshim rshim0 --bfb /root/<bfb文件> --config /root/bf.cfg

# 3) 盯输出（约 10–20 分钟）。正常会依次看到：
#    INFO[PSC]: PSC BL1 START
#    INFO[BL2]: boot mode (rshim)
#    INFO[BL31]: lifecycle GA Secured
#    INFO[UEFI]: eMMC probed
#    INFO[MISC]: Ubuntu installation started / completed
#    INFO[MISC]: Updating NIC firmware... / NIC firmware update done
#    INFO[MISC]: Installation finished

# 4) 等 90 秒，确认 DPU 侧系统起来了
cat /dev/rshim0/misc | tail -20   # 期待 INFO[MISC]: Linux up / DPU is ready

# 5) 通过 tmfifo 进 DPU 系统
ip addr add 192.168.100.1/24 dev tmfifo_net0
ssh ubuntu@192.168.100.2
```

> `bfb-install` 默认会清空 rshim 日志并存到 `/tmp/bfb-install-rshim0.log`。
> 想保留现场加 `--keep-log`。

### ⚠️ 关于 `bf.cfg` 里的 BMC_* 参数

若写入 `BMC_USER` / `BMC_PASSWORD` / `BMC_REBOOT="yes"`，安装会**顺带升级卡上的 BMC 固件**
（默认密码 `0penBmc`）。**首次安装建议只写 `ubuntu_PASSWORD`**，把事情做简单；
BMC 固件以后单独升。

### 这一步顺带做的事

BF-bundle 会**覆盖整个引导分区**（装 Ubuntu 22.04）**并升级 BlueField 与 NIC 固件**，
同时配置好 OVS bridge。所以这是"重装 + 刷固件"一体的操作。

---

## 六、⚠️ 两个最容易卡住的点

### 1. ⛔ ATX +12V 辅助供电 —— **本机实测就卡在这里**（2026-11-10 确认）

NVIDIA 文档明确写着：

> **The ATF will not boot 150W BlueField-3 platforms if the ATX +12V power supply is not connected.**

**而且本卡 OPN 精确落在"必须外接"那一组**（BF3 平台用户指南 · Specifications）：

| OPN 分组 | 供电要求 |
|---|---|
| B3140H / B3140L / B3220L / B3210L **SuperNIC** | 仅 PCIe x16 槽位 75W |
| B3220 / B3240 / B3210 / **B3210E** DPU | ⚠️ **须外接 8-pin ATX 辅助供电** |

> **B3210E DPUs Specifications**（原文）：
> "**Requires a supplementary 8-pin ATX power supply connectivity available through
> the external power supply connector.**"

本卡 = `900-9D3B6-00CC-EA_Ax`（B3210E）→ **必须外接**。

**2026-11-10 13:57 实测结果：⛔ 卡住了**（`bfb-install` 推流直接失败）：

```
Pushing bfb
cat: write error: Connection timed out
Error: Failed to push boot stream via local rshim
...
INFO[BL31]: MB ping success
INFO[UEFI]: eMMC init
INFO[UEFI]: eMMC probed
ERR[BL31]: ATX missing - initiating halt sequence...
ASSERT[BL31]: CRITICAL ERROR: ATX power not detected! Halting system!!
```

> ⚠️ **更正**：本节原先写"BL 链能跑 → 大概率不缺这根线"，**是错的**。
> BL1/BL2/BL31 会跑起来、`UP_TIME` 会走、`SW_RESET` 也有效 ——
> 这些都发生在 CPU 域之前，**不需要那根线**。到 BL31(ATF) 才做电源检查然后 halt。
> 我已经被这一点误导过一次，不要再被误导。

**好消息**：失败没伤到卡（还没进到写 eMMC 的阶段，`安装动作计数: 0`），
主机、rshim 通道、eMMC 原有内容都完好。

**要做的**：把 **8-pin ATX(EPS 12V) 辅助供电线**接上（**不是** PCIe 6+2），再重跑 `bfb-install`。
参考 [BF3 平台用户指南 · Pinouts Description](https://networking-docs.nvidia.com/bf3dpu/pinouts-description)。

> ⭐ **2026-11-10 晚补充：这根线同样卡住"官方 NIC 模式"路径。**
>
> 实测：`OFFLOAD_ENGINE=DISABLED(1)` + 三个 `EXT_HOST_PF(1)` + 断 AC 冷启动后，
> **flash / `Current` 列 / `BF_MODE` 三个层面全部确认是 NIC 模式，host PF 依然 `-110`**。
> 机制：官方 NIC 路径下 `INTERNAL_CPU_MODEL` 仍是 `EMBEDDED_CPU`
> （那是它的出厂默认值，也是"参数不消失"的前提），卡仍声明"有内嵌 CPU 掌管网卡"
> ⇒ **Arm 必须启动完成向 PF 的交接**；ATX 未接 ⇒ BL31 halt ⇒ 交接完不成。
>
> **结论：想同时拿到「`OFFLOAD_ENGINE` 参数可见」+「网卡可用」，同样必须接这根线。**
> 唯一能绕过它的是弃用的 `SEPARATED_HOST`，代价是 `OFFLOAD_ENGINE` 从配置里消失。
> 完整实验记录见排查文档 §6.10。
>
> ⭐ **2026-11-10 16:20 补：这条结论已被对照机正面证实。**
> 对照机 `10.17.20.237`（**已接 8-pin ATX**）的 BL31 **没有任何 ATX 报错**，
> 一路走到 `UEFI: PCIe enum end` / `Redfish enabled` / 认到 `A78 16 Cores`；
> 老机器同一位置则 halt。⇒ **接线就是那个缺失条件**（对照日志见排查文档 §6.11(1)）。
>
> ⚠️ **同时修正一条旧旁证**：`lspci` 的 `AuxPwr-` / `SlotPowerLimit 0W`
> 在**接线与没接线**的机器上**完全相同** ⇒ **不能用来判断这根线接没接**。
> 唯一判据是 **BL31 日志里有没有 `ATX missing` / `ATX power not detected!`**。
>
> ⚠️ **还有一个前提**：对照机 eMMC 里**本来就有系统**（无需装 BFB），
> **Arm 引导起系统之后** host PF 才起来。所以接上 ATX 后若 PF 仍不来，
> 先确认 Arm 是否真的在跑系统，再考虑装 BFB。

### 2. 安全启动签名

见第三节末尾。**只用官方签名 BF-bundle，不要自建镜像。**

---

## 七、装完怎么验证

### DPU 侧

```bash
cat /dev/rshim0/misc | grep -E "Linux up|DPU is ready|OPN_STR"
```

- `OPN_STR` 应该**不再是 `N/A`**（UEFI 走到了填它的阶段）
- 出现 `INFO[MISC]: Linux up` / `DPU is ready`

登进 DPU 看版本：

```bash
ssh ubuntu@192.168.100.2
bf-info        # ATF / UEFI / BSP / NIC Firmware / BMC Firmware / 驱动 / DOCA 版本一览
```

### host 侧（这才是我们真正要的）

```bash
for f in 0 1; do
  printf "3b:00.%s -> " $f
  basename "$(readlink -f /sys/bus/pci/devices/0000:3b:00.$f/driver 2>/dev/null)" 2>/dev/null || echo NONE
done
ip -br link | grep enp59
ibstat | grep -c '^CA '
```

**期望**：两个 PF 都绑上 `mlx5_core`，出现 `enp59s0f0np0` / `enp59s0f1np1`，
`ibstat` CA 数 6。

> ⚠️ 如果**仍在 `-110`**：说明 ARM 起来了但 DPU 侧软件栈还没就绪。
> 别急着重装 —— 先等几分钟，再登进 DPU 查 `mlx5` 相关服务状态。
> DPU 模式下 host PF 的固件初始化**依赖 ARM 侧供给资源**，这是设计如此。

### 链路

`/etc/systemd/network/20-bf3-nic.network` 还在，`enp59*` 一出现就会自动 up。
端口 2 插着模块，MHZ 应协商到 100G。

---

## 八、顺序（和切模式的关系）

| 步骤 | 状态 |
|---|---|
| 1. 确保处于 DPU 模式<br>（`INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED(0)`） | ✅ 已完成（且已是出厂默认） |
| 2. 断 AC 冷启动 | ✅ 已完成（卡 `UP_TIME` 已归零验证过） |
| 3. **装 BFB** | ⬜ **待办 ← 本文** |
| 4. ARM 起 OS 后，host PF 自动可用 | ⬜ |

### 两条关键结论

1. **BFB 是走 rshim / SoC 管理口装的，与 DPU/NIC 模式开关
   （`INTERNAL_CPU_OFFLOAD_ENGINE`）无关** ——
   两种模式下都能装。既然要 DPU 模式且已经是 DPU 模式，**直接装，不要再切模式。**
   > ⚠️ **但两种模式都必须先接 ATX 线** —— 2026-11-10 实测：没接就直接
   > `Error: Failed to push boot stream via local rshim` + BL31 `ATX power not detected!`。
   > 详见第六节第 1 条。
2. **装 BFB 不需要再断 AC** —— rshim 装 BFB 会让 SoC 自己从 rshim 引导一次完成安装。
   这是好消息：走 DPU 路线比走 NIC 路线**少付一次断电的代价**。

> 对比：**切模式**（`INTERNAL_CPU_OFFLOAD_ENGINE`）官方要求
> *"Arm and NIC components must undergo a reset. Power cycle is recommended."* ——
> 推荐上电循环（本机实测 `INTERNAL_CPU_MODEL` 那条路径确实躲不过断电，见排查文档 §3.3）；
> **装 BFB 不需要**，因为它通过 rshim 通道让 SoC 主动引导。

---

## 九、参考

- [NVIDIA DOCA Downloads](https://developer.nvidia.com/doca-downloads) —— BF-bundle 下载入口
- ⭐ [NVIDIA · BlueField Modes of Operation（DOCA 3.2.3）](https://networking-docs.nvidia.com/doca/archive/3-2-3/bluefield-modes-of-operation.md) —— **DPU/NIC 模式开关与判据的权威来源**；也解释了为什么 DPU 模式下 ARM 没系统时 host 驱动必然 `-110`
- [BF-Bundle Installation and Upgrade（DOCA 3.2.3）](https://networking-docs.nvidia.com/doca/archive/3-2-3/bf-bundle-installation-and-upgrade.md) —— 安装步骤、`bf.cfg`、`doca-installer`、150W 供电与安全启动要求
- [Deploying BlueField Software from Host（BSP 4.10）](https://docs.nvidia.com/networking/display/nvidia-bluefield-bsp-v4-10-0.0.pdf) —— 安全启动签名说明
- [Mellanox/bfb-build](https://github.com/Mellanox/bfb-build/) —— 自建 BFB（**本卡不适用**）
- [BlueField-3 平台用户指南 · 引脚与供电](https://docs.nvidia.com/networking/display/bf3dpu/pinouts+description) —— +12V 辅助供电连接器
