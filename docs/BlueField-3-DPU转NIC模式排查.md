# BlueField-3 从 DPU 模式切回 NIC 模式 —— 排查与操作记录

> **日期**：2026-11-05
> **主机**：`node20-39`（`10.17.21.85`，Ubuntu 22.04.4 LTS，kernel `5.15.0-105-generic`，DOCA/OFED 3.2.2）
> **登录**：`root` / 密码见密码管理器（**不要写进仓库**）
> **结论**：✅ **已修复**。BF3 现为双口 100GbE 网卡，`enp59s0f1np1` 以 100 Gb/s 上线。
>
> ⚠️ **但修复用的参数后来发现是 NVIDIA 已弃用的** —— 见下方更正框。

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

**1. 卡在 DPU 模式**（两条独立途径互相印证）

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 q | grep INTERNAL_CPU_MODEL
#   INTERNAL_CPU_MODEL           EMBEDDED_CPU(1)          ← DPU 模式

cat /dev/rshim0/misc | grep BF_MODE
#   BF_MODE                      DPU mode
```

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
BF3 配成 DPU 模式（BOOT_MODE=emmc，但 eMMC 里没有可启动的 BFB）
        ↓
ARM 侧没有任何 OS 在跑（console 静默 / bfdump Timeout / OPN_STR=N/A）
        ↓
host PF 的固件初始化需要 ECPF 供给 page + IB vport0 → 供给不上
        ↓
固件永远停在 pre-initializing (0x87010000)，驱动等 120s 后 -110 超时
        ↓
probe 失败 → ip a 没有 / ibstat 没有     （mst 仍能看到，因为只需 PCI 配置空间）
        ↓
【修复】mlxconfig 切 SEPARATED_HOST + 断电冷启动   ⚠️ 走的是**已弃用**参数，见 §3.2 更正
        ↓
mlx5_core 绑定成功 → enp59s0f0np0 / enp59s0f1np1 出现，ibstat 的 CA 数 4 → 6
```

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
> 2026-11-10 该卡已还原为默认的 DPU 模式，`INTERNAL_CPU_OFFLOAD_ENGINE = ENABLED(0)`。

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
| `BF_MODE` | `DPU mode` / `NIC mode` —— ⚠️ **在本卡上不可信，见 6.7 节** |
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

### 6.7 ⚠️ `BF_MODE` 在本卡上不可信 —— 别被它误导（重要更正）

**症状**：`INTERNAL_CPU_MODEL = SEPARATED_HOST(0)`、host PF 正常绑定、100G 链路已 up，
但 `cat /dev/rshim0/misc` 里的 `BF_MODE` 依然显示 **`DPU mode`**。

**原因**（查证 rshim 源码 —— 仓库名是 **`Mellanox/rshim-user-space`**，不是 `Mellanox/rshim`；
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

- `BF_MODE` 读的是 rshim 的 **`SCRATCHPAD2` 普通暂存寄存器**；
- 它**由 DPU 侧（ARM / ATF / UEFI）写入上报**，**主机侧的 `mlxconfig` 根本不碰它**；
- 而且这一行只在 `ver_id == RSHIM_BLUEFIELD_3` 时才打印。

**本卡的 ARM 从来没能启动**（`BOOT_MODE=1(emmc)` 但 eMMC 里没有 BFB），
于是**没有任何人会去更新 SCRATCHPAD2** → 它保留的是残留/默认值，
与 `INTERNAL_CPU_MODEL` 之间**没有因果关系**。

**结论 —— 本卡上判断模式只认这三条**：

⭐⭐ **官方判据（原文照抄，2026-11-10 更正）**：

```bash
host# mlxconfig -d /dev/mst/<device> q INTERNAL_CPU_OFFLOAD_ENGINE
```

| 输出 | 含义 |
|---|---|
| `ENABLED(0)` | **DPU 模式** |
| `DISABLED(1)` | **NIC 模式** |
| 带 `RO` 前缀（`RO INTERNAL_CPU_OFFLOAD_ENGINE ENABLED(0)`） | **DPU 模式 + Zero Trust**（只读，被限制） |

| 判据 | 权威性 |
|---|---|
| ⭐ **`INTERNAL_CPU_OFFLOAD_ENGINE`** | ✅✅ **NVIDIA 官方指定的模式判据**（上表） |
| `INTERNAL_CPU_MODEL` | ❌ **不能当模式判据** —— 见下方说明 |
| 那 4 个派生参数是否消失 | ⚠️ 只对"用弃用参数切走"这一条路径有效 |
| host PF 是否绑上 `mlx5_core` 并产出 netdev | ✅ 最终事实 |

> ⚠️ **我原先写的"看 `INTERNAL_CPU_MODEL` + 看 4 个派生参数是否消失"是次优甚至误导的：**
> - 一旦用了弃用的 `SEPARATED_HOST` 路径，`INTERNAL_CPU_OFFLOAD_ENGINE` 会**整个消失**，
>   官方判据就用不了了；
> - 而走官方路径（只改 `OFFLOAD_ENGINE`）时，`INTERNAL_CPU_MODEL` **大概率始终是
>   `EMBEDDED_CPU`**，根本区分不出模式。
>
> 所以 `INTERNAL_CPU_MODEL` 变化只是我那条弃用路径的**副作用**，不是模式指示器。

`BF_MODE` 只在 **DPU 侧有正常运行的 OS** 时才有参考价值。本卡这种「ARM 无系统」的场景下
**它是噪音 —— 看到 `DPU mode` 不要慌、更不要据此去重切模式。**

> 顺带纠正另一个容易误读的字段：misc 里的 `SECURE_NIC_MODE` 取自 `bd->locked_mode`，
> 是 **rshim 的归属锁（ownership lock）**，跟"网卡模式"毫无关系。

**实测：两个数据点证明它不跟随 `INTERNAL_CPU_MODEL`**（2026-11-10 补测）

| 数据点 | `INTERNAL_CPU_MODEL` | `BF_MODE` | 网卡 |
|---|---|---|---|
| ① 11-05 切成 NIC 模式后 | `SEPARATED_HOST(0)` | **`DPU mode`** | ✅ 正常 |
| ② 11-10 还原成 DPU 模式后 | `EMBEDDED_CPU(1)` | **`DPU mode`** | ❌ 消失 |

**同一个 `BF_MODE` 值对应两种截然不同的模式** —— 足以排除它作为模式判据。
含义：ARM 无系统时这个寄存器恒为其默认值 `DPU mode`，与 `INTERNAL_CPU_MODEL` 无关。

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

## 七、如果冷启动后仍然 -110

那就干净地排除了模式问题，定性为**固件损坏**，按顺序退：

1. **重刷固件**：`flint -d /dev/mst/mt41692_pciconf0 -i <fw.bin> burn`
   （需匹配 PSID `MT_0000001115` 的固件包）
2. **装 BFB 恢复**：通过 rshim 通道装一个匹配该 PSID 的 BFB
3. **报修换卡**

> 补充：这台服务器**没有外网**（`github.com` 解析不了，apt 只有 sugon 镜像 + 本地 DOCA 仓），
> BFB / 固件包需要从别处传上去。`bfb-tool` 只能对已有的 BFB/bf-bundle 做拆包重组，**不负责下载**。
