# BlueField-3 从 DPU 模式切回 NIC 模式 —— 排查与操作记录

> **日期**：2026-11-05（首版）· 2026-11-10（两次重要更正 + 官方路径实测）
> **主机**：`node20-39`（`10.17.21.85`，Ubuntu 22.04.4 LTS，kernel `5.15.0-105-generic`，DOCA/OFED 3.2.2）
> **登录**：`root` / 密码见密码管理器（**不要写进仓库**）
>
> ## 🔴 当前状态（2026-11-10 15:35）：**卡不可用，等用户决策**
>
> | 层面 | 实测值 | 结论 |
> |---|---|---|
> | flash（`Next Boot` 列） | `OFFLOAD_ENGINE=DISABLED(1)` + 三个 `EXT_HOST_PF(1)` | **NIC 模式** |
> | 运行中（`Current` 列） | 同上（已断电冷启动锁定） | **NIC 模式** ✅ |
> | 卡侧寄存器（`BF_MODE`） | **`NIC mode`** | ATF 已认账 ✅ |
> | **host PF** | ❌ `-110`（`wait_fw_init` 120s 超时） | **网卡不出现** |
> | `mlxconfig q INTERNAL_CPU_OFFLOAD_ENGINE` | `DISABLED(1)` | **参数可见** ✅ 用户要求①已满足 |
>
> **配置这条路已经走到头了 —— 三个层面全是 NIC 模式，PF 依然起不来。**
> 剩下的唯一物理阻塞是 **8-pin ATX +12V 辅助供电未接**（卡自报
> `ATX power not detected! Halting system!!`），而且**官方 NIC 模式路径同样需要它**
> —— 见 §6.9 与 §6.10。
>
> **待决三选一**（用户 2026-11-10 15:35 选择「先别动，我再想想」）：
>
> | 方案 | `OFFLOAD_ENGINE` 可见 | 网卡可用 | 代价 |
> |---|---|---|---|
> | **A. 接 8-pin ATX 辅助供电线** ⭐ **已被对照机正面验证（§6.11）** | ✅ | ✅ | 开箱接线（**EPS 12V 8-pin，不是 PCIe 6+2**） |
> | B. 回退弃用的 `SEPARATED_HOST` | ❌ 参数会消失 | ✅ | 走 §3.2b 老路，11-05 验证过 |
> | C. 拔卡 / BIOS 屏蔽该槽 | — | — | 顺带根治「开机 4 分钟所有 Mellanox 网卡消失」 |
>
> ⚠️ 首版标的「✅ 已修复」**只对 11-05 那次（弃用参数路径）成立**，现在不成立，故已作废。
> ⚠️ 首版还写过「NIC 模式不需要那根 ATX 线」—— **对官方路径而言是错的**，见 §6.9 / §6.10。
>
> ## 🟢 2026-11-10 16:20 重大更新：ATX 的作用已被**另一台机器正面验证**
>
> 用户提供了一台**已接好 8-pin ATX** 的同型号机器（`10.17.20.237`）。在那台机器的 SoC 上
> 下发 `SW_RESET` 后，引导链**完整跑通、没有任何 ATX 报错**：
>
> | 阶段 | 老机器 `10.17.21.85`（**没接线**） | 对照机 `10.17.20.237`（**接了线**） |
> |---|---|---|
> | `BL31: runtime` / `MB ping success` | ✅ | ✅ |
> | `UEFI: eMMC init` / `eMMC probed` | ✅ | ✅ |
> | **ATX 电源检查** | ❌ `ERR[BL31]: ATX missing - initiating halt sequence...`<br>❌ `ASSERT[BL31]: ATX power not detected! Halting system!!` | ✅ **完全没有报错** |
> | `UEFI: UPVS valid` → `PCIe enum` → `Secure Boot` → `Redfish enabled` | ⛔ 停在 halt，到不了 | ✅ 全部走完 |
>
> ⇒ **方案 A（接 8-pin ATX）不再是推断，而是已被另一台机器证实。**
> 对照机甚至还演示了完整闭环：**ATX 已接 + Arm 有系统 ⇒ host PF 正常起来、netdev 出现**。
> 详见 **§6.11**（完整对照日志 · 对照机档案 · 一个新故障模式 · 一个新恢复手法）。
>
> ⚠️ 同时修正一条旧旁证：`lspci` 的 `AuxPwr-` / `SlotPowerLimit 0W`
> **在接线与没接线的机器上完全一样** ⇒ **与 8-pin ATX 无关，不能用来判断**（见 §6.11(2)）。

---

## ⚠️ 重要更正（2026-11-10）：模式开关是 `INTERNAL_CPU_OFFLOAD_ENGINE`

**本文 §3.2 用的 `INTERNAL_CPU_MODEL=SEPARATED_HOST` 能修好，但走的是 NVIDIA 明确弃用的参数。**

BlueField-3 的 **DPU/NIC 模式开关正式名称是 `INTERNAL_CPU_OFFLOAD_ENGINE`**：

| 值 | 模式 |
|---|---|
| `ENABLED(0)` | **DPU 模式** |
| `DISABLED(1)` | **NIC 模式** |
| 带 `RO` 前缀（`RO INTERNAL_CPU_OFFLOAD_ENGINE ...`） | DPU 模式 + Zero Trust（只读） |

官方命令行切法（**BF3 只需这一个参数**）：

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=DISABLED   # → NIC 模式
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED    # → DPU 模式
```

官方对 `SEPARATED_HOST` 的原话：

> **"Separated Host Mode is obsolete for BlueField DPU/SuperNIC SKUs and should not be used**,
> even if it remains visible in some configuration menus or options.
> Separated Host Mode is available only for BlueField controller SKUs,
> where the BlueField Arm OS is the sole CPU/OS in the chassis."

**本文其它部分（故障链条、证据、硬件清单、冷启动验证、A/B/A 实验）都仍然有效** ——
只有"用哪个参数切模式 / 怎么判断当前模式"这两条需要更正。详见 §3.2 与 §6.7。

### ⚠️⚠️ 追加更正（2026-11-10 晚）：官方路径**没能**修好本卡

光把 `INTERNAL_CPU_OFFLOAD_ENGINE` 改成 `DISABLED`，**不足以**让本卡的网卡回来：

| 尝试时刻 | 配置 | 冷启动 | 结果 |
|---|---|---|---|
| 11-10 14:23 | 只 `OFFLOAD_ENGINE=DISABLED` | ✅ 15:16 断 AC | ❌ 仍 `-110`（但 `BF_MODE` 已变 `NIC mode`） |
| 11-10 14:41 | 再补 `PAGE_SUPPLIER` / `ESWITCH_MANAGER` / `IB_VPORT0` = `EXT_HOST_PF(1)` | ✅ 15:16 断 AC | ❌ 仍 `-110` |

**不是参数选错了，而是物理供电没到位**（ATX 未接）。

⚠️ **所以本文档的正确读法变了：**

- 官方 `INTERNAL_CPU_OFFLOAD_ENGINE` 是 **"必要不充分" 条件** ——
  它能满足"参数可见"，但**本卡还差接那根 ATX 线**才可能让网卡回来；
- 11-05 之所以用弃用参数能修好，是因为 `SEPARATED_HOST` 把"内嵌 CPU 掌管网卡"这条路
  **整个删掉**，绕过了 Arm 与 PF 的交接 —— 代价是 `OFFLOAD_ENGINE` 一起消失。
  详见 §6.10 的机制分析。

来源：[NVIDIA · BlueField Modes of Operation（DOCA 3.2.3）](https://networking-docs.nvidia.com/doca/archive/3-2-3/bluefield-modes-of-operation.md)

---

## 一、症状

`mst` 能看到卡，但系统里完全没有网卡和 IB 设备 —— 这是最迷惑人的地方。

| 命令 | 表现 |
|---|---|
| `mst status` | ✅ 能看到 `/dev/mst/mt41692_pciconf0`（BF3 的 3b:00.0/.1） |
| `ip a` / `ip -br link` | ❌ **没有任何 3b:00 的网卡** |
| `ibstat` | ⚠️ 只有 `mlx5_0..3`（CX7 + CX5），**没有 BF3** |
| `lspci` | ✅ 三个 function 都在：`3b:00.0/.1`（MT43244 网络 PF）、`3b:00.2`（SoC 管理口） |
| `/sys/bus/pci/devices/0000:3b:00.{0,1}/driver` | ❌ **NONE**（没有任何驱动绑定） |

核心 dmesg（两个 PF 表现完全一致）：

```
mlx5_core 0000:3b:00.0: firmware version: 32.47.1088
mlx5_core 0000:3b:00.0: wait_fw_init:291: Waiting for FW pre-initializing, timeout abort in 100s (0x87010000)
mlx5_core 0000:3b:00.0: wait_fw_init:291: Waiting for FW pre-initializing, timeout abort in 79s (0x87010000)
... 每 20 秒重复一次 ...
mlx5_core 0000:3b:00.0: wait_fw_init:281: Firmware over 120000 MS in pre-initializing state, aborting
mlx5_core 0000:3b:00.0: probe_one:2425: mlx5_init_one failed with error code -110
mlx5_core: probe of 0000:3b:00.0 failed with error -110
```

### ⭐ 为什么 `mst` 能看到但 `ip a` 看不到

| | 走的通道 | 需要驱动吗 |
|---|---|---|
| `mst` / `mlxconfig` / `mlxlink` / `flint` | PCI **配置空间裸访问**（`_pciconf`） | **不需要** |
| `ip a` / `ibstat` | 需要 `mlx5_core` 探测成功并创建 netdev / IB 设备 | **需要** |

所以「`mst status` 有卡 + `ip a` 没网卡」这个组合，第一嫌疑就是**固件初始化失败**，直接看 dmesg。

---

## 二、根因

一句话：**卡被配成 DPU 模式，但 DPU 的 ARM 侧没有任何可启动系统，导致 host PF 的固件初始化永远等不到 ARM 供给资源。**

### 证据链

**1. 卡在 DPU 模式**（⭐ 用 NVIDIA 官方判据，2026-11-10 更正）

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 q INTERNAL_CPU_OFFLOAD_ENGINE
#   INTERNAL_CPU_OFFLOAD_ENGINE                 ENABLED(0)     ← ★ 官方判据：DPU 模式
```

> ⚠️ **首版这里写的是 `INTERNAL_CPU_MODEL = EMBEDDED_CPU` → 错。**
> `INTERNAL_CPU_MODEL` 的出厂默认值**本来就是 `EMBEDDED_CPU(1)`**（`mlxconfig -e q` 的
> `Default` 列实测确认），它**不是模式指示器**。详见 §6.7。

当时 `BF_MODE` 也显示 `DPU mode`，与上式一致（但它的可信边界见 §6.7）。

**DPU 模式下的完整配置快照**（`mlxconfig -e q`，三列语义见 §6.10）：

```
Configurations:                        Default          Current           Next Boot
        INTERNAL_CPU_MODEL             EMBEDDED_CPU(1)  EMBEDDED_CPU(1)   EMBEDDED_CPU(1)
        INTERNAL_CPU_PAGE_SUPPLIER      ECPF(0)          ECPF(0)           ECPF(0)
        INTERNAL_CPU_ESWITCH_MANAGER    ECPF(0)          ECPF(0)           ECPF(0)
        INTERNAL_CPU_IB_VPORT0          ECPF(0)          ECPF(0)           ECPF(0)
        INTERNAL_CPU_OFFLOAD_ENGINE     ENABLED(0)       ENABLED(0)        ENABLED(0)
```

> ⭐ **`Default` 列 = DPU 模式** ⇒ 这张卡**出厂就是 DPU 模式**，与它是 DPU SKU（B3210E）吻合。

**2. ARM 侧没有系统在跑**（三条独立证据）

| 探测 | 结果 | 含义 |
|---|---|---|
| `cat /dev/rshim0/console`（采样 30 秒） | **零字节输出** | 串口没有任何引导/运行输出 |
| `rshim -c -i 0 -m`（bfdump） | **Timeout** | 发给 ARM 的命令没有响应 |
| `/dev/rshim0/misc` 的 `OPN_STR` | **`N/A`** | 正常应读到卡型号字符串，说明 ARM/UEFI 没走到填它的阶段 |

另外 `BOOT_MODE = 1 (emmc)` —— 配置为从板载 eMMC 引导，但 eMMC 里没有可启动的 BFB。

**3. DPU 模式下 host PF 依赖 ARM** —— 这组配置就是绑定关系的直接体现

```
INTERNAL_CPU_MODEL            EMBEDDED_CPU(1)   ← DPU 模式
INTERNAL_CPU_PAGE_SUPPLIER    ECPF(0)           ← host PF 的固件内存页由 ARM 供给 ★
INTERNAL_CPU_ESWITCH_MANAGER  ECPF(0)           ← 交换机由 ARM 管理
INTERNAL_CPU_IB_VPORT0        ECPF(0)           ← IB vport0 归 ARM ★
PORT_OWNER                    True(1)           ← 物理口归 ARM
```

打 ★ 的两条是关键：**host 侧 PF 要用的"页"（固件内部内存资源）和 IB vport0 都由 ARM（ECPF）提供。**
ARM 不干活 → 页供给不上 → 固件永远停在 `pre-initializing (0x87010000)`。

**4. 反证**：切到 NIC 模式后，上面这 4 个派生参数**直接从配置列表里消失了** ——
证明它们本来就是 DPU 模式专属、由 ARM 承担的职责。

### 因果链全图

```
⭐ 最深一层根因（2026-11-10 实测确认）：
   本卡 900-9D3B6-00CC-EA_Ax = B3210E，NVIDIA 官方规格明写
   「Requires a supplementary 8-pin ATX power supply connectivity」
   而那根线**没接** → ATF/BL31 直接 halt：
      ERR[BL31]: ATX missing - initiating halt sequence...
      ASSERT[BL31]: CRITICAL ERROR: ATX power not detected! Halting system!!
        ↓
   ARM 根本起不来（跟有没有 OS 无关）→ ECPF 永不初始化
        ↓
═══════════════════════════════════════════════════
BF3 配成 DPU 模式（BOOT_MODE=emmc，但 eMMC 里也没有可启动的 BFB）
        ↓
ARM 侧没有任何 OS 在跑（console 静默 / bfdump Timeout / OPN_STR=N/A）
        ↓
host PF 的固件初始化需要 ECPF 供给 page + IB vport0 → 供给不上
        ↓
固件永远停在 pre-initializing (0x87010000)，驱动等 120s 后 -110 超时
        ↓
probe 失败 → ip a 没有 / ibstat 没有     （mst 仍能看到，因为只需 PCI 配置空间）
        ↓
【11-05 当时修复】mlxconfig 切 SEPARATED_HOST + 断电冷启动
    ⚠️ 走的是已弃用参数（见 §3.2）。它之所以能**在没有 ATX 供电时**也修好，
       是因为 SEPARATED_HOST 把「内嵌 CPU 掌管网卡」这条路整个删掉，
       **绕过了 Arm → PF 的交接**，Arm 起不起来都无所谓
        ↓
mlx5_core 绑定成功 → enp59s0f0np0 / enp59s0f1np1 出现，ibstat 的 CA 数 4 → 6
```

> ### ⚠️⚠️ 2026-11-10 实测推翻了一条推论
>
> 首版这里曾写：**"NIC 模式下 Arm 核心本来就不需要工作，接不接那根线都不影响"**。
> **这只对弃用的 `SEPARATED_HOST` 路径成立，对官方 `OFFLOAD_ENGINE` 路径不成立。**
>
> 官方路径下 `INTERNAL_CPU_MODEL` 仍是 `EMBEDDED_CPU`（且是出厂默认、不建议改），
> 卡仍声明"本芯片有内嵌 CPU 掌管网卡" ⇒ **Arm 必须启动完成向 PF 的交接**。
> ATX 未接 ⇒ BL31 halt ⇒ 交接永远完不成 ⇒ PF 卡在 `pre-initializing` ⇒ `-110`。
>
> **实测（15:16 断电冷启动后）：flash / `Current` / `BF_MODE` 三个层面全都已是 NIC 模式，
> PF 依然起不来。** 完整的验证过程与机制分析见 §6.10。

> ⚠️ **重要含义**：ATX 辅助供电没接 ⇒ **装 BFB 也救不了 DPU 模式**。
> 2026-11-10 实测：`bfb-install` 推流直接失败（`cat: write error: Connection timed out`
> → `Failed to push boot stream via local rshim`），连安装阶段都进不去。
> 想用 DPU 功能，**必须先接 8-pin ATX 辅助供电线**（物理操作，软件无解）。详见 §6.9。

---

## 三、修复步骤

### 3.1 先备份配置

```bash
DEV=/dev/mst/mt41692_pciconf0
mlxconfig -d $DEV q > /root/bf3-mlxconfig-BEFORE-$(date +%Y%m%d-%H%M%S).txt
```

### 3.2 ⚠️ 更正：BlueField-3 切 NIC 模式的**正确**命令（2026-11-10 追加）

> **本节是更正。** 原先我只用 `INTERNAL_CPU_MODEL=SEPARATED_HOST` 就修好了，而且能 A/B/A 复现，
> 但那是 NVIDIA **明确弃用**的参数。官方
> [BlueField Modes of Operation](https://networking-docs.nvidia.com/doca/archive/3-2-3/bluefield-modes-of-operation.md)
> 原文：
>
> > **"Separated Host Mode is obsolete for BlueField DPU/SuperNIC SKUs and should not be used**,
> > even if it remains visible in some configuration menus or options.
> > Separated Host Mode is available only for BlueField controller SKUs,
> > where the BlueField Arm OS is the sole CPU/OS in the chassis."
>
> 官方给的命令行切法（**BlueField-3**）：

```bash
# DPU 模式 → NIC 模式（BlueField-3）
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=DISABLED
# NIC 模式 → DPU 模式（BlueField-3）
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED
```

> 只有 **BlueField-2** 才需要四个参数一起设
> （`INTERNAL_CPU_PAGE_SUPPLIER` + `ESWITCH_MANAGER` + `IB_VPORT0` + `OFFLOAD_ENGINE`）。
>
> ⚠️ 我那条 `SEPARATED_HOST` 走法的副作用：**它会让 `INTERNAL_CPU_OFFLOAD_ENGINE`
> 从 `mlxconfig q` 里整个消失** —— 而那正是 NVIDIA 指定的模式判据（详见 §6.7）。
>
> 🔴 **实测补记（2026-11-10 晚）**：上面这条官方命令**在本卡没能修好网卡** ——
> 写上 `DISABLED` 后 `BF_MODE` 确实变成 `NIC mode`、`mlxconfig -e q` 的 `Current` 列也变了，
> 但 host PF 依然 `-110`。后来又补了 BF2 那三个参数（`EXT_HOST_PF`）**依然无效** ——
> 因为**卡上没接那根 8-pin ATX 线**。
> **完整实验记录见 §6.10，根因见 §6.9。**

### 3.2b 当时实际用的命令（已弃用路径，仅作历史记录）

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_MODEL=SEPARATED_HOST
```

预期输出：

```
Configurations:                                    Next Boot            New
        INTERNAL_CPU_MODEL                  EMBEDDED_CPU(1)      SEPARATED_HOST(0)
Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
```

> 注意 `-y` 是必须的（否则会交互式等待输入，非交互场景会挂住）。

### 3.3 ⚠️ 必须断电冷启动 —— 这一步不能省

**`INTERNAL_CPU_MODEL` 是上电时锁存的，任何软件复位都改不动它。**（实测结论）

官方对"改模式"的说法一致：**"For the configuration to take effect, Arm and NIC components
must undergo a reset. Power cycle is recommended."** —— 推荐上电循环。

另外官方还提供两条**可能不需要断 AC** 的路径（本卡有集成 BMC，值得一试）：

- ⭐ **DPU-BMC Redfish**：
  `POST https://<bmc_ip>/redfish/v1/Systems/Bluefield/Oem/Nvidia/Actions/Mode.Set`
  body `{"Mode": "NicMode"}` 或 `{"Mode": "DpuMode"}`
  → 官方说明 **"two consecutive Arm reboots are required"**（**没提断 AC**）
- **主机 UEFI (HII) 菜单**：`BlueField Internal Cpu Configuration` → 设 `Internal Cpu Offload Engine`

以下路径全部试过并失败，**下次不要再浪费时间**：

| 尝试 | 结果 |
|---|---|
| `mlxfwreset -l 4 -t 0 reset`（全芯片热重启） | ❌ `fsm sync timed out` |
| `mlxfwreset --sync 1` | ❌ 被工具自己忽略：`reset sync argument is ignored when reset level is not PCI_RESET` |
| `mlxfwreset reset_fsm_register` 清卡死 FSM | ⚠️ `FSM register was reset successfully`，但重试**仍然** `fsm sync timed out` |
| rshim `echo "SW_RESET 1" > /dev/rshim0/misc` | ⚠️ **确实重启了 SoC**（`UP_TIME` 21941s → 42s），但 `BF_MODE` 仍是 `DPU mode` |
| PCIe 槽位电源 `/sys/bus/pci/slots/3/power` | ❌ 未暴露（槽位下只有 `address`，无 `power`/`attention`） |
| PCI PM D3hot→D0 | ❌ 设备 `NoSoftRst+` 置位，明确不触发内部复位 |

**`fsm sync timed out` 的成因值得记一下**：BF 的复位 FSM 会打印

```
Waiting for mlxfwreset to run on all other hosts, press 'ctrl+c' to abort
```

它要等**所有 host 应答**（BF 内部有多个 host：ARM 是一个，x86 是一个）。
ARM 没系统 → 永远不应答 → 死锁。**这个死锁本身就是"卡在 DPU 模式"的直接后果**，不是独立故障。

#### 正确做法：断 AC

```bash
# 1) 优雅关机（可选）
poweroff
# 2) 两路电源都要断（只断一路 PSU 不够，另一路还在给槽位供电）
# 3) 等 30~60 秒 —— 让槽位和卡上的电容/辅助电彻底放掉，这是"冷"的关键
# 4) 上电，耐心等 5~15 分钟（内存训练 + 卡首次冷启动探测）
```

> **⚠️ 三种断电方式的区别**（别赌前两种）：
>
> | 方式 | 够不够 |
> |---|---|
> | `reboot`（热重启） | ❌ PCIe 槽供电不断，卡不会冷启 |
> | `poweroff` + 按电源键 | ⚠️ **不一定够** —— S5 下槽位常保留辅助供电，而且这张卡自带 integrated BMC，平台很可能给它留着电 |
> | **断 AC**（拔两路电源线 / PDU 下电，等 30 秒再上） | ✅ **唯一确定有效的方式** |

### 3.4 冷启动后验证

```bash
lspci -D | grep -i MT43244                     # 三个 function 在

for f in 0 1; do
  printf "3b:00.%s -> " $f
  basename "$(readlink -f /sys/bus/pci/devices/0000:3b:00.$f/driver)" 2>/dev/null || echo NONE
done                                           # 期望：mlx5_core

ip -br link | grep enp59                       # 期望：出现 enp59s0f0np0 / enp59s0f1np1
ibstat | grep -c '^CA '                        # 期望：4 → 6
```

实测结果：

```
3b:00.0 -> mlx5_core
3b:00.1 -> mlx5_core
enp59s0f0np0   a4:a6:4e:49:0e:fa
enp59s0f1np1   a4:a6:4e:49:0e:fb
ibstat CA 总数 = 6      （mlx5_0 / mlx5_1 = BF3，FW 32.47.1088）
```

### 3.5 把端口拉起来 + 持久化

冷启动后 `enp59*` 是 **admin down** 的。原因：`/etc/netplan/00-installer-config.yaml`
只收录了 `eno1/eno2/enp175s0f0np0/enp175s0f1np1/enp216s0f0np0/enp216s0f1np1`，
**没有 `enp59`**，于是 systemd-networkd 把它当 `unmanaged`，永远不会拉起来。

> **区分两种 down**（这是快速定位的关键）：
> ```
> enp59s0f0np0  DOWN  <BROADCAST,MULTICAST>                  ← admin down（没有 UP 标志）
> enp175s0f0np0 DOWN  <NO-CARRIER,BROADCAST,MULTICAST,UP>    ← admin up 但没信号
> ```
> admin down 时 `/sys/class/net/<if>/carrier` 读出来是**空的**，别误判成"链路不通"。

临时拉起：`ip link set enp59s0f1np1 up`

**持久化方案：只保链路 up，不配 IP、不发 DHCP** —— 新增独立 `.network` 文件，
**不改动 netplan**（最小侵入）：

```bash
cat > /etc/systemd/network/20-bf3-nic.network <<'EOF'
[Match]
Name=enp59s0f0np0 enp59s0f1np1

[Link]
ActivationPolicy=up
RequiredForOnline=no

[Network]
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
EOF

# 用 reload 而不是 restart —— 避免动到承载 SSH 的 eno1
networkctl reload
networkctl list        # enp59 应从 unmanaged 变成 configured
```

> `/etc/systemd/network/` 的优先级高于 netplan 生成的 `/run/systemd/network/`，
> 且这里只 match `enp59*`，与 netplan 的 `10-netplan-*.network` 无交集。
>
> 以后若要给它配 IP，别直接照抄其他卡的 `dhcp4: true` —— 那会往生产网里凭空发 DHCP 请求。

---

## 四、最终状态

> ⚠️ **本节描述的是 2026-11-05 那次（弃用 `SEPARATED_HOST` 路径）的终态，不是当前状态。**
> 当前状态见文首「🔴 当前状态」框 —— **网卡不可用**。

| 端口 | 网卡 | 状态 |
|---|---|---|
| **端口 2** | `enp59s0f1np1` | ✅ **UP，`Speed: 100000Mb/s`，全双工**，`carrier=1`，`<UP,LOWER_UP>`，`Link detected: yes` |
| 端口 1 | `enp59s0f0np0` | ⚪ `NO-CARRIER` —— 该笼子确实**没插模块/线**（物理事实，非故障） |

端口 1 是"没插线"，三方证据一致：

```
mlxlink -d 0000:3b:00.0
  State                         : Disable
  Supported Cable Speed (Ext.)  : 0x00000000 ()
  Recommendation                : Cable is unplugged
```
- `ethtool enp59s0f0np0` → `Link detected: no (No cable)`
- dmesg 里**没有** `3b:00.0 Port module event: Cable plugged`（而 `3b:00.1` 有）
- `ethtool -m` 读模块 EEPROM 报 `query_mcia_reg failed: status 0x3`（笼子空的）

端口 2 的物理层诊断：

```
mlxlink -d 0000:3b:00.1
  State    : Active                        Speed : 100G
  Width    : 4x                            FEC   : Standard RS-FEC - RS(528,514)
  Recommendation : No issue was observed
```

dmesg 上线记录：

```
mlx5_core 0000:3b:00.1 enp59s0f1np1: Link up
mlx5_core 0000:3b:00.1 mlx5_1: Port: 1 Link ACTIVE
IPv6: ADDRCONF(NETDEV_CHANGE): enp59s0f1np1: link becomes ready
```

> 补充：`3b:00.2`（SoC 管理口）在 NIC 模式下**依然存在**，这是正常的 ——
> 卡的 ARM/BMC 还在，`INTERNAL_CPU_RSHIM ENABLED` 保留了 rshim 管理通道，方便以后刷固件。
> 它已不再干扰 host PF。
>
> 所以 `INTERNAL_CPU_RSHIM` **不要关**：它跟 PF 探测失败无关，
> 而且正是它让我们能读到 DPU 状态。关掉只会自断排障通道。

---

## 五、回滚（想切回 DPU 模式）

**BlueField-3 的正确写法**（2026-11-10 更正）：

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED
# 官方：配置生效需 Arm 与 NIC 侧复位，推荐上电循环
```

当时实际用的是**已弃用参数**的等价写法（也能用，但别学）：

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_MODEL=EMBEDDED_CPU
```

> ✅ 而且 `INTERNAL_CPU_MODEL` 的**出厂默认值就是 `EMBEDDED_CPU(1)`**
> （`mlxconfig -e q` 的 `Default` 列实测），所以"还原"其实就是**回到默认值**。
>
> ⚠️ **注意：2026-11-10 晚的当前状态是 NIC 模式**（`OFFLOAD_ENGINE = DISABLED(1)`），
> **不是** DPU 模式 —— 见文首「🔴 当前状态」框。

完整旧配置快照在目标机：`/root/bf3-mlxconfig-BEFORE-20261105-191847.txt`

> ⚠️ **切回 DPU 模式后网卡不会自己回来** —— 必须给 ARM 装上可启动的 BFB 并配好转发，
> 否则又会回到本文描述的故障状态。如果只是想当普通网卡用，**不要切回去**。

---

## 六、关键知识点（下次省时间）

### 6.1 rshim 不需要内核模块

`rshim` 包（2.5.10，来自 DOCA 本地仓 `/usr/share/doca-host-3.2.2-*/repo`）**只装用户态**，
`/usr/src` 里没有 DKMS 源码 —— 但这**根本不是问题**：

> rshim 的 PCIe 后端自己通过 `resource0` 直映射 BAR 访问 `3b:00.2`
> （或退到 `uio_pci_generic` / `vfio_pci`），不需要 `rshim.ko`。

```bash
# 直接可用，无需安装任何东西
PCIE_HAS_VFIO=1 setsid /usr/sbin/rshim -b pcie -l 2 -f > /tmp/rshim.log 2>&1 &
sleep 8
cat /dev/rshim0/misc          # 读 DPU 状态
ls /dev/rshim0/               # boot  console  misc  rshim
```

`rshim.service` 是 **disabled** 的，需要时手动拉起。

> ⚠️ **绝对不要写 `/dev/rshim0/boot`** —— 那个一写就会让 DPU 从 rshim 引导（复位它）。
> 读状态只用 `misc` 和 `console`。

### 6.2 rshim 关键字段速查

| 字段 | 含义 |
|---|---|
| `BF_MODE` | `DPU mode` / `NIC mode` —— **跟随 `INTERNAL_CPU_OFFLOAD_ENGINE`，不跟随 `INTERNAL_CPU_MODEL`**；可信边界见 6.7 节 |
| `BOOT_MODE` | `0:rshim  1:emmc  2:emmc-boot-swap` —— 从哪引导 |
| `OPN_STR` | 卡型号字符串；`N/A` = ARM/UEFI 没走到填它的阶段 |
| `UP_TIME` | DPU 上电秒数 —— **复位是否真的发生的铁证**（软复位成功会归零） |
| `SW_RESET` | 写 `SW_RESET 1` 可软复位 SoC（但改不动 `INTERNAL_CPU_MODEL`） |

### 6.3 排除掉的无辜嫌疑（**别重复怀疑**）

| 嫌疑 | 为什么排除 |
|---|---|
| 槽位供电不足 | `SlotPowerLimit 0.000W` 在**全部 7 个设备**上都一样，包括正常工作的 CX7/CX5 |
| PCIe 降速 | `8GT/s (downgraded)` 在正常工作的 `af:00.0` 上也一样；DMI 显示整机槽位全是 "PCI Express 3" |
| 驱动版本混装 | 磁盘上只有一份 `mlx5_core.ko`（`updates/dkms/`），srcversion 与已加载的一致 |
| 驱动没绑定 | 是**结果**不是原因 —— 手动 `bind` 也会失败，因为固件没就绪 |
| 槽位是 NVMe 位 | BF3 在 `Slot03-NVMe0`，而正常工作的 CX7 在 `Slot09-NVMe4`，同为 x16 PCIe3 槽位 |
| 缺 rshim 内核模块 | rshim 的 PCIe 后端是用户态直映射，根本不需要内核模块 |

### 6.4 无关但要认识的两条日志

- **`mlx5_ib: disagrees about version of symbol ...` / `Unknown symbol ... (err -22)`**
  开机时 Ubuntu 先加载**内核自带**的 `mlx5_ib`，与 DKMS 的 `mlx5_core` 版本对不上；
  `openibd` 随后重新加载即自愈（`lsmod` 能看到 `mlx5_ib`，IB 设备齐全）。
  **这是改之前就存在的历史现象，与本故障无关。**
- **`Detected insufficient power on the PCIe slot (27W)`**
  CX7/CX5 上也有，是平台特性，链路照常能起。

### 6.5 硬件清单（留档）

| PCI | 设备 | ID | 驱动 | 网卡 |
|---|---|---|---|---|
| `3b:00.0/.1` | **BF3 网络 PF** | `15b3:a2dc` MT43244 | `mlx5_core` | `enp59s0f0np0` / `enp59s0f1np1` |
| `3b:00.2` | BF3 SoC 管理口 | `15b3:c2d5` MT43244 | 无（rshim 用户态直访问） | — |
| `af:00.0/.1` | ConnectX-7 | `15b3:1021` | `mlx5_core` | `enp175s0f0np0` / `enp175s0f1np1` |
| `d8:00.0/.1` | ConnectX-5 | `15b3:1017` | `mlx5_core` | `enp216s0f0np0` / `enp216s0f1np1` |

**BF3 信息**

- 型号：`900-9D3B6-00CC-EA_Ax`（BlueField-3 B3210E E-Series FHHL DPU，双口 QSFP112，16 Arm 核，32GB DDR，integrated BMC）
- PSID：`MT_0000001115`　Base MAC：`a4a64e490efa`　FW：`32.47.1088`（2025-09-12）　security：`secure-fw`
- 所在槽位：`Slot03-NVMe0`（根端口 `0000:3a:00.0`，x16 PCI Express 3）
- 网络配置：`LINK_TYPE_P1/P2 = ETH(2)`、`NUM_OF_PF = 2`

### 6.6 `openibd.service` 的 `failed` 是**症状**，不是独立问题（2026-11-10 更正）

先前这里记为「inbox → OFED 驱动切换时的残留」，**不准确**。真实原因是**启动超时**：

`openibd.service` 有 **180 秒**启动超时，而 BF3 故障时两个 PF 各要卡满 **120 秒**
的 pre-init 等待（2×120s = 240s > 180s）→ 脚本**等不到设备就超时失败**：

```
Nov 10 11:58:27  openibd.service: Starting openibd - configure Mellanox devices...
Nov 10 11:58:46  mlx5_core 0000:3b:00.0: Waiting for FW pre-initializing, timeout abort in 100s
Nov 10 12:01:27  openibd.service: start operation timed out. Terminating.
Nov 10 12:01:27  openibd.service: Failed with result 'timeout'.
Nov 10 12:02:26  mlx5_core: probe of 0000:3b:00.1 failed with error -110
```

三次观测完全一致 —— **BF3 坏 → `failed`，BF3 好 → `active`，BF3 又坏 → 又 `failed`**：

| 时间 | BF3 状态 | openibd |
|---|---|---|
| 11-05 修复前 | ❌ `-110` | `failed` |
| 11-05 修复后 | ✅ 网卡正常 | `enabled / active` |
| 11-10 还原后 | ❌ `-110` | `failed` |

> **推论**：以后看到 `openibd` failed，**先查 Mellanox 卡的 dmesg 有没有 probe 失败**，
> 别去查"驱动版本残留"。手动 `systemctl restart openibd` 之所以能"修好"，
> 只是因为那时内核的 probe 早已失败完毕、脚本没有设备可等 —— **治标不治本**。

### 6.7 `BF_MODE` 的真相：跟随 `INTERNAL_CPU_OFFLOAD_ENGINE`（2026-11-10 二次更正）

> **本节经历了两次更正**，第一版结论（"它是噪音、不可信"）**也是错的**。
> 最终结论在下面「最终结论」小节。过程保留，因为这个坑很容易再踩。

**第一版观察到的症状**：`INTERNAL_CPU_MODEL = SEPARATED_HOST(0)`、host PF 正常绑定、
100G 链路已 up，但 `cat /dev/rshim0/misc` 里的 `BF_MODE` 依然显示 **`DPU mode`**。

**实现**（rshim 源码 —— 仓库名是 **`Mellanox/rshim-user-space`**，不是 `Mellanox/rshim`；
实现在 `src/rshim_fuse.c`）：

```c
const char* bf3_bf_mode_str[] = { "Unknown", "DPU mode", "NIC mode", "Reserved" };

const char* bf3_get_bf_mode(rshim_backend_t* bd) {
  uint64_t value;
  int rc = bd->read_rshim(bd, RSHIM_CHANNEL, bd->regs->scratchpad2, &value,
                          RSHIM_REG_SIZE_8B);
  if (rc || RSHIM_BAD_CTRL_REG(value)) return bf3_bf_mode_str[0];
  return bf3_bf_mode_str[BF3_RSH_SCRATCHPAD2__BF_MODE(value)];
}
```

- `BF_MODE` 读的是 rshim 的 **`SCRATCHPAD2` 暂存寄存器**；
- 它**由 DPU 侧（ARM / ATF）写入上报**，主机侧的 `mlxconfig` 不碰它；
- 这一行只在 `ver_id == RSHIM_BLUEFIELD_3` 时才打印。

#### ⭐ 最终结论（第三个数据点推翻了前两个）

| 数据点 | `INTERNAL_CPU_MODEL` | `INTERNAL_CPU_OFFLOAD_ENGINE` | `BF_MODE` | 网卡 |
|---|---|---|---|---|
| ① 11-05 切成 NIC 模式后 | `SEPARATED_HOST(0)` | `ENABLED(0)`（**从未被改**，仍是出厂值） | `DPU mode` | ✅ 正常 |
| ② 11-10 还原后 | `EMBEDDED_CPU(1)` | `ENABLED(0)` | `DPU mode` | ❌ 消失 |
| ③ **11-10 走官方路径后** | `EMBEDDED_CPU(1)` | **`DISABLED(1)`** | **`NIC mode`** ✅ | ❌ 仍消失 |

⭐ **`BF_MODE` 与 `INTERNAL_CPU_OFFLOAD_ENGINE` 100% 一致 —— 它其实是可信的！**

真相：

1. `BF_MODE` **跟随 flash 里的 `INTERNAL_CPU_OFFLOAD_ENGINE`**
   （ATF 在 BL31 读取配置后写入 `SCRATCHPAD2`）；
2. 它**不跟随 `INTERNAL_CPU_MODEL`**；
3. ① 之所以显示 `DPU mode`，是因为当时走的是弃用路径，
   **`OFFLOAD_ENGINE` 根本没被改过**（仍是出厂默认 `ENABLED(0)`）——
   **所以 `BF_MODE` 当时报得没错**，是我拿它去跟 `INTERNAL_CPU_MODEL` 比，
   才得出"不可信"的错误结论。

**⚠️ 但 `BF_MODE` 有一个重要边界**：它只反映**"ATF 认为该用哪个模式"**（≈ flash 配置），
**不代表 PF 真的初始化成功**。数据点 ③ 就是铁证：`BF_MODE = NIC mode`、
`mlxconfig` 的 `Current` 列也是 NIC 模式，**PF 依然 `-110`**
（原因见 §6.9 / §6.10）。**模式对了 ≠ 网卡能出来。**

#### 判断模式该看什么

| 判据 | 权威性 |
|---|---|
| ⭐ **`mlxconfig -d <dev> q INTERNAL_CPU_OFFLOAD_ENGINE`** | ✅✅ **NVIDIA 官方指定的模式判据**（下表），也是"参数可见性"要求的那一个 |
| `mlxconfig -d <dev> -e q` 的 **`Current` 列** | ✅ 正在运行的值，比 `Next Boot` 更能说明"是否已生效"（见 §6.10） |
| `BF_MODE` | ✅ 能反映官方开关（见上），但**不能证明 PF 可用** |
| `INTERNAL_CPU_MODEL` | ❌ **不能当模式判据** —— 出厂默认就是它，见下 |
| 那 4 个派生参数是否消失 | ⚠️ 只对"用弃用参数切走"这一条路径有效 |
| host PF 是否绑上 `mlx5_core` 并产出 netdev | ✅✅ **最终事实** |

⭐⭐ **官方判据（原文照抄）**：

```bash
host# mlxconfig -d /dev/mst/<device> q INTERNAL_CPU_OFFLOAD_ENGINE
```

| 输出 | 含义 |
|---|---|
| `ENABLED(0)` | **DPU 模式** |
| `DISABLED(1)` | **NIC 模式** |
| 带 `RO` 前缀（`RO INTERNAL_CPU_OFFLOAD_ENGINE ENABLED(0)`） | **DPU 模式 + Zero Trust**（只读，被限制） |

> ⚠️ **`INTERNAL_CPU_MODEL` 为什么不能当判据**：
> 它的**出厂默认值就是 `EMBEDDED_CPU(1)`**（`mlxconfig -e q` 的 `Default` 列实测），
> 卡片无论处于 DPU 还是 NIC 模式，它都不变；只有走弃用的 `SEPARATED_HOST` 路径时它才变，
> 而那纯粹是**副作用**（且会让 `OFFLOAD_ENGINE` 一起消失）。

> 顺带纠正另一个容易误读的字段：misc 里的 `SECURE_NIC_MODE` 取自 `bd->locked_mode`，
> 是 **rshim 的归属锁（ownership lock）**，跟"网卡模式"毫无关系。

> 顺带说明 `UP_TIME` 的正确用法：**温重启（`reboot`）不会让它归零**。
> 2026-11-09 16:34 主机重启过一次（主机 `uptime` 只 19 小时），DPU 的 `UP_TIME`
> 仍是 4.66 天 —— 说明卡一直带电。2026-11-10 断电后它归零到 543s（≈9 分钟，
> 与上电时刻吻合）—— **只有归零才证明卡真的断过电**，这是判断"冷启动是否真发生"的铁证。

### 6.8 ⭐ A/B/A 对照实验：因果性已被证实

2026-11-10 的一次「还原 → 冷启动」意外构成了一次完整对照实验，
把结论从「改了 X 就好了」升级为**「反复拨动 X，症状精确跟随」**：

| | `INTERNAL_CPU_MODEL` | 是否冷启动 | `enp59` 网卡 | `ibstat` CA 数 | dmesg |
|---|---|---|---|---|---|
| **A**　11-05 修复前 | `EMBEDDED_CPU(1)` | — | ❌ 无 | 4 | `-110` |
| **B**　11-05 修复后 | `SEPARATED_HOST(0)` | ✅ 断 AC | ✅ 有，100G up | 6 | 正常 |
| **A'** 11-10 还原后 | `EMBEDDED_CPU(1)` | ✅ 断 AC | ❌ 无 | 4 | `-110` |

三点全部吻合，并且**排除了「其实只是冷启动的功劳」这一竞争假设** —— 因为 A' 同样冷启动了。

同时验证了：那 4 个派生参数在切回 DPU 模式时**会自己回来**，无需手工恢复。
A' 实测与 BEFORE 快照逐字一致：

```
INTERNAL_CPU_PAGE_SUPPLIER    ECPF(0)
INTERNAL_CPU_ESWITCH_MANAGER  ECPF(0)
INTERNAL_CPU_IB_VPORT0        ECPF(0)
INTERNAL_CPU_OFFLOAD_ENGINE   ENABLED(0)
```

> ⚠️ 还原很容易，但**每切一次都要付一次断 AC 的代价**。
> 本文写作时该机器处于 **A' 状态（DPU 模式，网卡不可用）**。
> 想回到 B：`mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_OFFLOAD_ENGINE=DISABLED`
> + **再断一次 AC**（官方推荐上电循环）。
> ⚠️ **别再用 `INTERNAL_CPU_MODEL=SEPARATED_HOST`** —— 那是弃用参数，见 §3.2。

---

### 6.9 ⭐ 终极根因：ATX +12V 辅助供电未接（2026-11-10 实测确认）

**NVIDIA 官方规格**（BF3 平台用户指南 · Specifications），本卡 OPN 精确命中：

| OPN 分组 | 供电要求 |
|---|---|
| B3140H / B3140L / B3220L / B3210L **SuperNIC** | 仅 PCIe x16 槽位 **75W** |
| B3220 / B3240 / B3210 / **B3210E** DPU | ⚠️ **须外接 8-pin ATX 辅助供电** |

> **B3210E DPUs Specifications**（原文）：
> "**Requires a supplementary 8-pin ATX power supply connectivity available through
> the external power supply connector.**"

本卡 = `900-9D3B6-00CC-EA_Ax`（B3210E）→ **属于必须外接的那一组**。

**实测证据**（2026-11-10 13:57，`bfb-install` 尝试，rshim 日志原文）：

```
INFO[PSC]: PSC BL1 START
INFO[BL2]: start
INFO[BL2]: boot mode (rshim)
INFO[BL2]: DDR POST passed
INFO[BL2]: UEFI loaded
INFO[BL31]: start
INFO[BL31]: lifecycle GA Secured
INFO[BL31]: runtime
INFO[BL31]: MB ping success
INFO[UEFI]: eMMC init
INFO[UEFI]: eMMC probed
ERR[BL31]: ATX missing - initiating halt sequence...
ASSERT[BL31]: CRITICAL ERROR: ATX power not detected! Halting system!!
```

> ⚠️ **注意 BL1/BL2/BL31 全都跑起来了。**
> 所以**千万别再用"BL 链能跑 / `UP_TIME` 会走 / `SW_RESET` 有效"来排除这根线**
> —— 这些都发生在 CPU 域之前，根本不需要那根线。**到 BL31(ATF) 才做电源检查然后 halt。**
> §六 里我先前正是这么误判的。

**旁证（主机侧 —— ⚠️ 2026-11-10 16:20 被 §6.11(2) 推翻，仅作历史记录）**：

| 检查 | 结果 | 含义 |
|---|---|---|
| `lspci` `DevSta` | `AuxPwr-`（`.0` 和 `.1` 都是） | ⚠️ **无效旁证** —— 接了线的对照机同样显示 `AuxPwr-` |
| `lspci` | `SlotPowerLimit 0.000W` | ⚠️ **无效旁证** —— 对照机同样如此 |
| BMC `+12V` | `12 Volts ok` | 主机 12V 主轨正常（**不是**辅助口那一路） |
| BMC `Sys_Total_Power` | `231 W` | 偏低，与 ARM 未运行一致 |
| BMC `PCIe_NIC_Temp` | `61 °C` | 卡是通电的、在发热 |
| eMMC 是否被写入 | `安装动作计数: 0` | ✅ **失败没伤卡**（还没进到写盘阶段） |

**结论（2026-11-10 晚二次更正 · 16:20 由 §6.11 对照机正面验证）**：

- ✅ **【已被实测证明】** 接了线的对照机引导链**完整跑通、无任何 ATX 报错**（§6.11(1)）
  ⇒ **这根线就是那个物理阻塞**，不再是推断
- ❌ 没接这根线 ⇒ **ARM 永远起不来 ⇒ DPU 模式永远不可能工作**，装 BFB 也救不了
- ⚠️ **更正**：首版这里写的"NIC 模式不需要它"——**只对弃用的 `SEPARATED_HOST` 路径成立**。
  **官方的 `INTERNAL_CPU_OFFLOAD_ENGINE=DISABLED` 路径同样需要它**（§6.10 有实测为证）：
  该路径下 `INTERNAL_CPU_MODEL` 仍是 `EMBEDDED_CPU`，Arm 必须启动完成向 PF 的交接。
- ✅ 所以：**想同时满足「参数可见 + 网卡可用」，必须先接这根 8-pin ATX 线**
  （物理操作，软件无解）

**这根线是什么**：卡上的外部供电连接器吃 **8-pin ATX(EPS 12V)**，
**不是** PCIe 6+2。服务器上要从电源引一路空闲的 CPU 8-pin 供电过去。
参考 [BF3 平台用户指南 · Pinouts Description](https://networking-docs.nvidia.com/bf3dpu/pinouts-description)。

---

### 6.10 ⭐ 官方路径实测全记录（2026-11-10 14:00–15:35）

这一节是「官方参数到底够不够」的完整实验记录，也是判定"是否只剩 ATX"的全部依据。

#### (1) `mlxconfig -e q` 的三列语义 —— 别再判反了

```
Configurations:                        Default          Current           Next Boot
        INTERNAL_CPU_MODEL             EMBEDDED_CPU(1)  EMBEDDED_CPU(1)   EMBEDDED_CPU(1)
   *    INTERNAL_CPU_PAGE_SUPPLIER      ECPF(0)          EXT_HOST_PF(1)    EXT_HOST_PF(1)
   *    INTERNAL_CPU_ESWITCH_MANAGER    ECPF(0)          EXT_HOST_PF(1)    EXT_HOST_PF(1)
   *    INTERNAL_CPU_IB_VPORT0          ECPF(0)          EXT_HOST_PF(1)    EXT_HOST_PF(1)
   *    INTERNAL_CPU_OFFLOAD_ENGINE     ENABLED(0)       DISABLED(1)       DISABLED(1)
```

| 列 / 前缀 | 含义 |
|---|---|
| `Default` | **出厂默认值** |
| `Current` | **当前正在运行的值** ← **判断"是否已生效"只看这一列** |
| `Next Boot` | 下次复位后采用的值（`mlxconfig set` 改的就是它） |
| 行首 `*` | 该行**与 `Default` 不同**（即被改过） |
| 行首 `RO` | 只读参数 |

**两个重要事实：**

1. **`Default` 列 = DPU 模式** ⇒ 这张卡出厂就是 DPU 模式（DPU SKU 的正常出厂态）。
2. ⭐ **`Current` 列也已经是 NIC 模式** ⇒ **配置确确实实已经生效了。**

> ⚠️ 排查中我曾把列判反，误判成"配置没生效"，白折腾了一轮。
> **记住：`-e q` 有 `Default / Current / Next Boot` 三列，判断生效只看 `Current`。**
> 普通 `mlxconfig q` 只有 `Next Boot` 一列，**不能用来判断是否已生效**。

#### (2) 实验：官方路径到底能不能修好本卡

| 步骤 | 时刻 | 动作 | 结果 |
|---|---|---|---|
| 1 | 11-10 14:23 | `set INTERNAL_CPU_OFFLOAD_ENGINE=DISABLED` | 写 flash 成功 |
| 2 | 11-10 14:41 | `set INTERNAL_CPU_PAGE_SUPPLIER=1 INTERNAL_CPU_ESWITCH_MANAGER=1 INTERNAL_CPU_IB_VPORT0=1` | ✅ 三个都变 `EXT_HOST_PF(1)`，**六行参数全在** |
| 3 | 11-10 15:16 | **用户断 AC 冷启动** | 配置锁定（`Current` = NIC 模式） |
| 4 | 11-10 15:19 | 主机开机，`mlx5_core` 探测 | ❌ **两个 PF 依然各 120s 超时 → `-110`** |

冷启动后**三个层面全部确认是 NIC 模式**，而 PF 依然起不来：

```
mlxconfig -e q   Current 列   → OFFLOAD_ENGINE=DISABLED(1) + 三个 EXT_HOST_PF(1)
/dev/rshim0/misc BF_MODE      → NIC mode
mlxfwreset q     Reset-reason → Cold reset        ← 证明真的冷复位过
最终结果                      → 3b:00.0/.1 无驱动、无 netdev、ibstat 仍只有 4 个 CA
```

> ⭐ 那三个参数的**有效值名是 `EXT_HOST_PF(1)`**（不是文档里常见的 `HOST(1)`）。
> `mlxconfig set <param>=1` 的数值写法能用，但**读输出要认得这个名字**。

#### (3) `mlxfwreset` 在本卡的支持情况（查过，这次用不上）

```
mlxfwreset -d /dev/mst/mt41692_pciconf0 -l 4 -t 0 q
  Reset-levels:
    0: Driver, PCI link, network link will remain up ("live-Patch")  -Not Supported
    1: Only ARM side will not remain up ("Immediate reset")          -Not Supported
    3: Driver restart and PCI reset                                  -Not Supported
    4: Warm Reboot                                                   -Supported (default)
  Reset-types:
    0: Full chip reset                                               -Supported (default)
    1: Phy-less reset                                                -Not Supported
    2: NIC only reset (for SoC devices)                              -Not Supported
    3: ARM only reset                                                -Not Supported
    4: ARM OS shut down                                              -Not Supported
  Reset-reason:                                                      Cold reset
```

- ✅ `-l 4 -t 0`（Warm Reboot / Full chip reset）是**本卡唯一支持的复位组合**，
  也是"改了配置不想断 AC"时的官方手段；
- ⚠️ **但本卡这次用不上** —— `Current` 列早已是 NIC 模式，复位改变不了任何东西，
  问题不在"没生效"。**别再拿它当救命稻草。**

#### (4) 🔴 新发现的运维影响：**每次开机 4 分钟，所有 Mellanox 网卡都消失**

`mlx5_core` 的 PCI 探测是**串行**的。BF3 坏在 `pre-init` 时，驱动每个 PF 要干等 120 秒，
两个 PF = **240 秒**，后面的 CX7/CX5 全部排队：

```
15:19:22  3b:00.0: firmware version: 32.47.1088    ← 轮到 BF3，开始等
15:21:22  3b:00.0: -110（120s 超时）
15:21:22  3b:00.1: firmware version: 32.47.1088    ← 再等
15:23:22  3b:00.1: -110（又 120s）
15:23:22  af:00.0: firmware version: 28.47.2682    ← CX7 这才轮到
15:23:23  af:00.0 enp175s0f0np0: renamed from eth0 ← 网卡这才出现
```

**后果**：这台存储节点**每次重启后头 4 分钟内，`ip a` 只有 `lo / eno1 / eno2`**，
`enp175s*`、`enp216s*` 全都**不存在**（不是 DOWN，是根本没被创建）。

> ⚠️ 以后若再看到"网卡都没了"，**先算一下"开机时刻 + 4 分钟"** —— 大概率就是这个，
> 不是新故障。**它也是"必须处理掉这张 BF3"的最强理由。**
>
> 缓解方向（**未实施**）：内核参数把 BF3 的 PCI ID 交给 `vfio-pci` 占住
> （`vfio-pci.ids=15b3:a2dc`）或 BIOS 屏蔽该槽，让 `mlx5_core` 不去碰它 ⇒ 不再阻塞。

#### (5) 附：`tmfifo_net0` 是什么

rshim 启动后会多出一张 `tmfifo_net0`（TMFIFO = Tiny Management FIFO），
是**主机 ↔ BF3 内部 Arm 的带外管理虚拟网卡**，走 rshim 传输层，**不是真网卡**：

| 项 | 说明 |
|---|---|
| 谁创建 | `rshim` 用户态进程（**`rshim.service` 是 disabled，不自启**） |
| 固定 MAC | `00:1a:ca:ff:ff:02`（主机侧）/ `...:01`（DPU 侧） |
| 典型用途 | `bfb-install --rshim rshim0` 刷 BFB、看 DPU console、主机↔DPU 的 `192.168.100.1 ↔ 192.168.100.2` 管理网 |
| 速度 | `UNKNOWN`（FIFO，带宽很低） |
| 生命周期 | **rshim 一停它就消失** |
| 与业务网 | 完全无关 |

> ⚠️ 它**没有 IPv4 是正常的**：`192.168.100.1/24` 本来该由 `rshim.service` 配，
> 而该服务是 disabled、需手动起，所以只有 IPv6 链路本地。
> `mlxconfig` 走的是 MST PCI 设备（`/dev/mst/mt41692_pciconf0`），**不经过它**。

#### (6) 本轮操作留痕（目标机 `/root/`）

| 文件 | 内容 |
|---|---|
| `/root/bf3-mlxconfig-NICMODE2-BEFORE-20261110-144141.txt` | 补那三个 `EXT_HOST_PF` 之前的完整快照 |
| `/root/bf3-mlxconfig-NICMODE-BEFORE-20261110-142348.txt` | 改 `OFFLOAD_ENGINE` 之前的完整快照 |
| `/root/bf3-mlxconfig-BEFORE-20261105-191847.txt` | 11-05 最初的 DPU 模式快照 |
| `/root/bfb-install-20261110-135048.log` | BFB 安装失败日志（708 B） |

---

### 6.11 ⭐⭐ ATX 铁证：同型号机器 A/B 对照（2026-11-10 16:12）

用户提供了一台**据称已接 8-pin ATX** 的机器（`10.17.20.237`）。对它的 SoC 下发一次
`SW_RESET` 后，拿到了**完整、无 ATX 报错**的引导日志 —— 与老机器逐行对照，
**ATX 就是唯一差异**。

#### (1) 对照日志（同一段 BL/UEFI 代码，同一 FW 版本 `32.47.1088`）

| 阶段 | 老机器 `10.17.21.85`（**没接线**） | 对照机 `10.17.20.237`（**接了线**） |
|---|---|---|
| `INFO[PSC]: PSC BL1 START` | ✅ | ✅ |
| `INFO[BL2]: DDR POST passed` / `UEFI loaded` | ✅ | ✅ |
| `INFO[BL31]: start` / `lifecycle GA Secured` | ✅ | ✅ |
| `INFO[BL31]: runtime` / `MB ping success` | ✅ | ✅ |
| `INFO[UEFI]: eMMC init` / `eMMC probed` | ✅ | ✅ |
| **ATX 电源检查** | ❌ `ERR[BL31]: ATX missing - initiating halt sequence...`<br>❌ `ASSERT[BL31]: CRITICAL ERROR: ATX power not detected! Halting system!!` | ✅ **完全没有报错** |
| `INFO[UEFI]: UPVS valid` | ⛔ 到不了 | ✅ |
| `INFO[UEFI]: PCIe enum start` / `end` | ⛔ | ✅ |
| `INFO[UEFI]: UEFI Secure Boot (disabled)` / `PK configured` | ⛔ | ✅ |
| `INFO[UEFI]: Redfish enabled` / `DPU-BMC RF credentials found` | ⛔ | ✅ |
| console 上认出 SoC | ⛔ | ✅ `Mellanox BlueField-3 [A1] A78(D42) 16 Cores r0p1` |

> ⭐ 这就是「**ATX 未接 = 唯一物理阻塞**」的**正面证明**，不再是推断。
> 也再次印证 §6.9 的机制：ATF(BL31) 会先跑起来（所以 `BF_MODE` 可读、`UP_TIME` 会走），
> **到 ATX 检查那一步才 halt。**

#### (2) 对照机档案（留档备查）

| 项 | 对照机 `10.17.20.237` | 老机器 `10.17.21.85` |
|---|---|---|
| 主机 | hostname `ubuntu`，Ubuntu 24.04，kernel `6.8.0-147-generic` | `node20-39`，Ubuntu 22.04，`5.15.0-105` |
| BF3 PCI 位置 | **`99:00.0` / `99:00.1`**（+ `99:00.2` SoC mgmt） | `3b:00.0` / `3b:00.1` |
| OPN / PSID | `900-9D3B6-00SV-A_Ax` / `MT_0000000965` | `900-9D3B6-00CC-EA_Ax` / `MT_0000001115` |
| FW | `32.47.1088` | `32.47.1088` |
| PCIe 链路 | ✅ **32 GT/s (Gen4) x16**，`504.112 Gb/s` | ⚠️ 降级 `8 GT/s (Gen3) x16` |
| 模式 | **DPU 模式**（`OFFLOAD_ENGINE=ENABLED(0)`，出厂态、从未改过） | 已改 NIC 模式 |
| rshim | `2.5.11`，`active` **且 `enabled`** | 同版本但 **disabled** |
| `lspci` `AuxPwr` | `AuxPwr-` | `AuxPwr-` ← ⚠️ **两边一模一样** |
| 网卡（恢复后） | ✅ `ens21f0np0` / `ens21f1np1` + `mlx5_0` / `mlx5_1` | ❌ 无 |

> ⚠️ **重要修正（推翻 §6.9 的一条旁证）**：
> `lspci` 的 `DevSta: AuxPwr-` 与 `SlotPowerLimit 0.000W`
> **在"接了线"和"没接线"的两台机器上完全相同** ⇒ 那是 PCIe 的 3.3Vaux 状态，
> **与 8-pin ATX(+12V) 无关，不能作为判断依据。**
> **唯一可信的判据：BL31 有没有 `ATX missing` / `ATX power not detected!`。**

#### (3) 附带确认：`BF_MODE` 跟随 `INTERNAL_CPU_OFFLOAD_ENGINE`（第三个独立数据点）

对照机复位前 `BF_MODE = Unknown`，`SW_RESET` 之后变成 **`DPU mode`** ——
而它的配置正是 `INTERNAL_CPU_OFFLOAD_ENGINE=ENABLED(0)`（出厂 DPU 态）。
⇒ 与 §6.7 结论一致，**又一台机器上验证通过**。

#### (4) ⭐ 新发现：DPU 模式下，**Arm 一跑起来 host PF 就起来了**

对照机走完了一个完整闭环，值得记住：

```
15:36:07   ⚠️ 有人往 /dev/rshim0/boot 推引导流，撞上 mlx5_core 的复位  → 见 (5)
~15:36     mlx5_core teardown，两个 PF 的 netdev 全部消失
16:04      ip -br link 只剩 lo/ens3f0/ens3f1/tmfifo_net0；ibstat -l 空
16:12:13   ★ 对 SoC 下发 SW_RESET
16:13:54   ✅ mlx5_core 0000:99:00.0: health recovery succeeded → ens21f0np0
16:13:57   ✅ mlx5_core 0000:99:00.1: health recovery succeeded → ens21f1np1
```

**两条结论：**

1. ⭐ **DPU 模式 + ATX 已接 + Arm 有系统（eMMC 里本来就有，无需装 BFB）
   ⇒ host PF 正常初始化、netdev 出现。**
   （驱动是走 `mlx5_health_try_recover` → `mlx5_pci_slot_reset` 重新 init 一遍才拿到的。）
2. ⚠️ **`INTERNAL_CPU_MODEL=EMBEDDED_CPU` 下，Arm 必须真的启动到能"交班"。**
   对照机在 Arm 还停在 UEFI、eMMC 系统没起来时，PF 一直卡在 `wait_fw_init`；
   **系统一起来 PF 立刻就好。** 这是老机器"接上 ATX 之后还需要什么"的直接参考。

> ⚠️ 但对照机 eMMC 里**本来就有系统**（同事确认一直好用、无需装 BFB）。
> **老机器 eMMC 里有没有系统尚未确认** —— 接上 ATX 后若 PF 仍不来，
> 下一步就查 Arm 是否真的引导了系统（`OPN_STR` 是否还是 `N/A`、console 有没有 Linux 启动）。

#### (5) ⭐ 新故障模式：「推流撞车」会让**所有 BF3 网卡瞬间消失**

对照机 15:36 的故障现场（`dmesg -T`，绝对时间）：

```
[Tue Nov 10 15:36:07] mlx5_core 0000:99:00.1: SW reset semaphore is already in use   ← ★ 关键
[Tue Nov 10 15:36:07] mlx5_core 0000:99:00.1: handling bad device here
[Tue Nov 10 15:36:07] mlx5_core 0000:99:00.1: mlx5_handle_bad_state: starting teardown
[Tue Nov 10 15:36:07] mlx5_core 0000:99:00.1: mlx5_error_sw_reset: start / end
[Tue Nov 10 15:36:08] mlx5_core 0000:99:00.0: starting health recovery flow
[Tue Nov 10 15:36:08] rshim[2738]: rshim0 boot open      ← 有人推引导流（写 /dev/rshim0/boot）
[Tue Nov 10 15:36:11] rshim[2738]: rshim0 boot close     ← 3 秒就断 = 推流失败
```

**机制**：rshim 推引导流要复位 SoC/设备，而 `mlx5_core` 也在复位路径上
（被判定异常的卡会走 `mlx5_error_sw_reset`）——
**两者抢同一个 SW reset 信号量**，卡被拖进"坏设备"流程 teardown，**netdev 全没**。

> ⭐ 这与老机器"开机 4 分钟无网卡"（§6.10(4) 的串行等待）**机制不同，别混为一谈**。
> 判据：`dmesg` 里有没有 **`SW reset semaphore is already in use`**。

#### (6) ⭐⭐ 新恢复手法：`SW_RESET` 能救回"推流撞车"僵死的卡

```bash
# 救活僵死的 BF3（实测约 100 秒后 netdev / RDMA 全部回来）
echo "SW_RESET 1" > /dev/rshim0/misc
```

⚠️ 但它**不是万能的**，适用范围必须收窄：

| 故障 | `SW_RESET` 有用吗 |
|---|---|
| 推流撞车 ⇒ `mlx5_core` teardown、netdev 消失 | ✅ **有用**（对照机 16:12 实测，100s 后 `health recovery succeeded`） |
| ATX 未接 ⇒ BL31 halt | ❌ **没用**（老机器试过，改变不了 halt） |

> ⚠️ **所以本文早先"`SW_RESET` 没用"的说法要收窄** ——
> 它救不了 **ATX 缺线**，但**能救"推流撞车 / 驱动僵死"**。
> 判断顺序：**先看 BL31 有没有 ATX 报错，再看是不是撞车。**

#### (7) 尚未解释的差异：`wait_fw_init` 超时 120s vs ~5700s

| 机器 | `wait_fw_init` 超时 | FW | 并行/串行 |
|---|---|---|---|
| 老机器 `10.17.21.85` | **120 s**（两个 PF 串行 = 240 s） | `32.47.1088` | 串行 |
| 对照机 `10.17.20.237` | ⚠️ **~5700 s（≈95 分钟）** | `32.47.1088` | **并行**（两条日志同步打印） |

**FW 版本相同、超时差 47 倍 —— 原因未确认。**
运维含义：对照机开机后 BF3 的 PF 会阻塞约 95 分钟；不过那台机器**只有这张 Mellanox 卡**
（没有 CX7/CX5 在后面排队），影响面比老机器小得多。
`/sys/module/mlx5_core/parameters/fw_init_timeout` 在该机读出来是**空值**，
超时来源未定（FW 上报 / 模块参数 / DOCA 版本差异皆有可能）。**留待查证，不凭猜下结论。**

#### (8) 本轮在对照机上做过什么（如实留痕）

| 操作 | 说明 | 破坏性 |
|---|---|---|
| 只读侦察若干轮 | `mst status -v`、`mlxconfig -e q`、`dmesg`、`journalctl`、`dd if=/dev/rshim0/misc … iflag=nonblock` | 否 |
| `mst start` | 加载 MST 模块、暴露 `/dev/mst/*` | 否 |
| 写 `DISPLAY_LEVEL 2` → 读 → 还原 `0` | 只提升 `/dev/rshim0/misc` 的日志显示级别（**不是** flash 配置） | 否（已还原） |
| **写 `SW_RESET 1`** | ⭐ 复位 SoC。**本轮唯一的破坏性操作**，在发现 PF 卡死后作为排障手段下发；**结果把机器修好了** | ⚠️ 是（已恢复） |

> ⚠️ 两个操作陷阱（都踩过）：
> 1. `cat /dev/rshim0/misc` 是**阻塞设备、永不返回 EOF** —— 必须用
>    `dd … bs=262144 count=1 iflag=nonblock`，否则会把排障脚本挂死
>    （`timeout` 也杀不掉 D 状态的读，还会把 ssh 通道一起占住）。
> 2. `DISPLAY_LEVEL=0` 时 `misc` 里的 `Log Messages` 段是**空的** ——
>    要看到引导日志，必须先提到 `DISPLAY_LEVEL 2`。

---

## 七、如果冷启动后仍然 -110

> ⚠️ **2026-11-10 更新：这个情况已经真实发生过了** —— 官方路径 + 断 AC 冷启动后
> **依然是 `-110`**，而**结论不是固件损坏，是 ATX 辅助供电未接**（见 §6.9 / §6.10）。
> **所以别急着刷固件 —— 先确认那根 8-pin ATX 线接了没有。**

**正确的排查顺序：先排物理，再排"驱动僵死"，最后才排固件。**

0. **⭐ 先把日志级别打开再读 `misc`** —— `DISPLAY_LEVEL=0` 时 `Log Messages` 段是**空的**，
   看不到引导链（§6.11(8)）：

   ```bash
   echo "DISPLAY_LEVEL 2" > /dev/rshim0/misc      # 提到 log 级别
   dd if=/dev/rshim0/misc of=/tmp/misc.txt bs=262144 count=1 iflag=nonblock
   cat /tmp/misc.txt                              # 现在才有 BL1/BL2/BL31/UEFI 日志
   echo "DISPLAY_LEVEL 0" > /dev/rshim0/misc      # 用完还原
   ```

   ⚠️ **必须用 `dd … iflag=nonblock`** —— `cat /dev/rshim0/misc` 会**永远阻塞**
   （该字符设备不返回 EOF，`timeout` 也杀不掉 D 状态的读）。

1. **看卡自己怎么说 ATX**：上面日志里有没有
   `ERR[BL31]: ATX missing` / `ATX power not detected! Halting system!!`
   —— **有 ⇒ 先接那根 8-pin ATX，刷任何固件都没用。**
   ⚠️ **别再用 `lspci` 的 `AuxPwr-` / `SlotPowerLimit` 判断** —— 接了线也一样（§6.11(2)）。

2. **⭐ 没有 ATX 报错、但 netdev 全没了 ⇒ 先怀疑"推流撞车"**：

   ```bash
   dmesg -T | grep "SW reset semaphore"     # 有 "is already in use" 就是撞车（§6.11(5)）
   ```

   解药是复位 SoC（§6.11(6)，实测约 100 秒后 netdev / RDMA 全部回来）：

   ```bash
   echo "SW_RESET 1" > /dev/rshim0/misc
   ```

3. **确认模式真的已生效**：`mlxconfig -d <dev> -e q` 看 **`Current` 列**
   （**不是** `Next Boot` 列），以及 `/dev/rshim0/misc` 的 `BF_MODE`。
   ⚠️ 即使模式、`BF_MODE` 全对，**Arm 没启动到能"交班"之前 PF 也不会来**（§6.11(4)）——
   DPU 模式下要确认 Arm 真的把 eMMC 里的系统引导起来了。

4. **前三条都确认无误后，才轮到怀疑固件**，按顺序退：

   - **重刷固件**：`flint -d /dev/mst/mt41692_pciconf0 -i <fw.bin> burn`
     （需匹配 PSID `MT_0000001115` 的固件包）
   - **装 BFB 恢复**：通过 rshim 通道装一个匹配该 PSID 的 BFB
   - **报修换卡**

> 补充：这台服务器**没有外网**（`github.com` 解析不了，apt 只有 sugon 镜像 + 本地 DOCA 仓），
> BFB / 固件包需要从别处传上去。`bfb-tool` 只能对已有的 BFB/bf-bundle 做拆包重组，**不负责下载**。
