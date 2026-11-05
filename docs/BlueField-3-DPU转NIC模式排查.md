# BlueField-3 从 DPU 模式切回 NIC 模式 —— 排查与操作记录

> **日期**：2026-11-05
> **主机**：`node20-39`（`10.17.21.85`，Ubuntu 22.04.4 LTS，kernel `5.15.0-105-generic`，DOCA/OFED 3.2.2）
> **登录**：`root` / 密码见密码管理器（**不要写进仓库**）
> **结论**：✅ **已修复**。BF3 现为双口 100GbE 网卡，`enp59s0f1np1` 以 100 Gb/s 上线。

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
【修复】mlxconfig 切 SEPARATED_HOST + 断电冷启动
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

### 3.2 切到 NIC 模式

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

**`INTERNAL_CPU_MODEL` 是上电时锁存的，任何软件复位都改不动它。**
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

```bash
mlxconfig -d /dev/mst/mt41692_pciconf0 -y set INTERNAL_CPU_MODEL=EMBEDDED_CPU
# 同样必须断 AC 冷启动才生效
```

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
| `BF_MODE` | `DPU mode` / NIC 模式 —— 判断模式是否真的生效的**权威字段** |
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

### 6.6 顺带修好的

`openibd.service` 原本是 **`failed`** 状态（inbox → OFED 驱动切换时的残留），
`systemctl restart openibd` 后恢复 `enabled / active`。

---

## 七、如果冷启动后仍然 -110

那就干净地排除了模式问题，定性为**固件损坏**，按顺序退：

1. **重刷固件**：`flint -d /dev/mst/mt41692_pciconf0 -i <fw.bin> burn`
   （需匹配 PSID `MT_0000001115` 的固件包）
2. **装 BFB 恢复**：通过 rshim 通道装一个匹配该 PSID 的 BFB
3. **报修换卡**

> 补充：这台服务器**没有外网**（`github.com` 解析不了，apt 只有 sugon 镜像 + 本地 DOCA 仓），
> BFB / 固件包需要从别处传上去。`bfb-tool` 只能对已有的 BFB/bf-bundle 做拆包重组，**不负责下载**。
