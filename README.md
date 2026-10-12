# DSH Workspace

DSH 配置 + 会话记忆同步仓库（Web 版 / 桌面版通用）。

> 本仓库**只保留配置与记忆**：`.dsh/`（profiles/settings/sessions/storages）、
> `todo-widget/`（待办悬浮组件插件包）、`docs/`、`.agents/`。
> 工程类项目（termdeck、admin、app、crmeb 等）已移出 git 跟踪，见 `.gitignore`。

## 🚀 首次部署（在新机器上）

1. 安装 Git、Node.js、pnpm（Web 版还需要 DSH CLI）
2. 确保 DSH 已安装（Web 版 `dsh web` 或桌面版 DSH Desktop）
3. 克隆仓库并运行部署脚本：

```powershell
git clone git@github.com:lblacklewis/dsh_workspace.git
cd dsh_workspace
.\setup.ps1              # 自动识别 Web / 桌面版
```

部署脚本会自动判断本机是 **Web 版**还是**桌面版**（检测 `~/.dsh/profiles/desktop` 是否存在）：

| 模式 | 行为 |
|------|------|
| `web` | 复制完整 settings.yaml（含 remote-web-ui 等）+ `profiles/web` |
| `desktop` | 只复制**通用** settings（无 remote-web-ui）+ 会话记忆，**不碰** `profiles/`（桌面版 profile 由 Electron 独占管理） |

也可手动指定：

```powershell
.\setup.ps1 -Mode desktop    # 家里那台（DSH Desktop）
.\setup.ps1 -Mode web        # 公司这台（dsh web）
```

4. 配置 API key（**必须，否则模型请求失败**）：
   - 复制 `.dsh\.credentials.yaml.example` 为 `~/.dsh/.credentials.yaml`
   - 填入 `DEEPSEEK_API_KEY`（官方）与 `SCNET_API_KEY`（scnet 网关）

## 🖥️ 桌面版（DSH Desktop）特别注意

**桌面版 ≠ Web 版**，两者的 profile 与插件体系不同：

| 项目 | Web 版 | 桌面版 |
|------|--------|--------|
| profile 目录 | `~/.dsh/profiles/web/` | `~/.dsh/profiles/desktop/`（Electron 独占） |
| 插件安装 | `dsh plugin --profile web add <pkg>` | 桌面版**应用内**插件管理（CLI 禁止操作 desktop profile） |
| settings.yaml | **共享** `~/.dsh/settings.yaml` | **同一份** ⚠️ |

### ⚠️ 已知坑：桌面版报 403（client 相关）

原因是 Web 版配置里的 **`remote-web-ui`**（随 `@linxin666/dsh-web-all` 全家桶安装）：
1. `lanBind: true` 会把 webserver 绑到 `0.0.0.0`
2. 同时启用**配对门控**（`requirePairingForLan` 默认 true）
3. 桌面版 Electron 渲染进程访问 `/api` 被判为"未配对来源" → **HTTP 403**

**避免方式**：
- 桌面版机器用 `.\setup.ps1 -Mode desktop`（不含 remote-web-ui 配置）
- **不要**在桌面版上安装 `@linxin666/dsh-web-all` / `remote-web-ui`（那是 Web 远程访问专用）

## 🔄 更新配置

```powershell
.\sync.ps1                                  # 从 ~/.dsh 回收到仓库
git add -A
git commit -m "更新 DSH 配置"
git push
```

## ⚠️ 安全与编码约定

- **`.credentials.yaml`** 含 API key，**不会**上传 Git（每次部署后需重新配置）
- **编码规则**（踩过坑）：
  | 文件 | 编码 |
  |------|------|
  | `settings.yaml` / `package.json` / `*.yml` | **UTF-8 无 BOM**（有 BOM 会导致解析失败、服务起不来） |
  | `*.ps1` 脚本 | **UTF-8 with BOM**（PowerShell 5.1 才能正确显示中文） |
