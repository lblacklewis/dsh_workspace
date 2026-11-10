# BlueField-3 安装 BFB：让 DPU 侧的 ARM 跑起来

> **前置状态**：本机 BF3 已处于 DPU 模式（`INTERNAL_CPU_MODEL=EMBEDDED_CPU`），
> 但 eMMC 里没有可引导系统 → host PF 探测 `-110`、网卡消失。
> 本文解决"给 ARM 装一个系统"这一步。
> 前情与故障链条见 [`BlueField-3-DPU转NIC模式排查.md`](BlueField-3-DPU转NIC模式排查.md)。

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
mlxconfig     INTERNAL_CPU_MODEL = EMBEDDED_CPU(1)      ← DPU 模式，正是我们要的
派生参数      PAGE_SUPPLIER/ESWITCH_MANAGER/IB_VPORT0 = ECPF(0)
              OFFLOAD_ENGINE = ENABLED(0)
```

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
| `doca-installer` | 未装，**本地 DOCA 仓里有** `1.3.10-1` | 多卡并行装，支持 `--psid` 分组 |
| `rshim` | `/usr/sbin/rshim` | 用户态，直映射 BAR，不需要内核模块 |

离线安装 doca-installer：

```bash
apt-get install -y doca-installer      # 走本地 file: 源
```

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

### 1. 150W 平台需要 ATX +12V 辅助供电

NVIDIA 文档明确写着：

> **The ATF will not boot 150W BlueField-3 platforms if the ATX +12V power supply is not connected.**

**症状**：安装输出停在

```
INFO[PSC]: PSC BL1 START
INFO[BL2]: start
```

然后**等不到 `INFO[BL31]`** —— ARM 根本没起来。

**排查**：看卡上/机箱里那根 **+12V 辅助供电线**有没有接。

- 本机证据：SoC 此前能被 rshim 读到 `UP_TIME`（4.66 天）、且 `SW_RESET` 真的重启了 SoC
  → **BL 链是能跑的**，大概率不缺这根线
- 但仍需在安装时留意，因为这是**文档写明的硬阻塞**

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
| 1. `mlxconfig set INTERNAL_CPU_MODEL=EMBEDDED_CPU` | ✅ 已完成 |
| 2. 断 AC 冷启动 | ✅ 已完成（卡 `UP_TIME` 已归零验证过） |
| 3. **装 BFB** | ⬜ **待办 ← 本文** |
| 4. ARM 起 OS 后，host PF 自动可用 | ⬜ |

### 两条关键结论

1. **BFB 是走 rshim / SoC 管理口装的，与 `INTERNAL_CPU_MODEL` 无关** ——
   两种模式下都能装。既然要 DPU 模式且已经设好，**直接装，不要再切模式。**
2. **装 BFB 不需要再断 AC** —— rshim 装 BFB 会让 SoC 自己从 rshim 引导一次完成安装。
   这是好消息：走 DPU 路线比走 NIC 路线**少付一次断电的代价**。

> 对比：切模式（`INTERNAL_CPU_MODEL`）**必须**断 AC，因为它是上电锁存的；
> 装 BFB **不需要**，因为它是通过 rshim 通道让 SoC 主动引导。

---

## 九、参考

- [NVIDIA DOCA Downloads](https://developer.nvidia.com/doca-downloads) —— BF-bundle 下载入口
- [BF-Bundle Installation and Upgrade（DOCA 3.2.3）](https://networking-docs.nvidia.com/doca/archive/3-2-3/bf-bundle-installation-and-upgrade.md) —— 安装步骤、`bf.cfg`、`doca-installer`、150W 供电与安全启动要求
- [Deploying BlueField Software from Host（BSP 4.10）](https://docs.nvidia.com/networking/display/nvidia-bluefield-bsp-v4-10-0.0.pdf) —— 安全启动签名说明
- [Mellanox/bfb-build](https://github.com/Mellanox/bfb-build/) —— 自建 BFB（**本卡不适用**）
- [BlueField-3 平台用户指南 · 引脚与供电](https://docs.nvidia.com/networking/display/bf3dpu/pinouts+description) —— +12V 辅助供电连接器
