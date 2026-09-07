# DSH Workspace 配置同步仓库

将 DeepSeek Harness (DSH) 的配置、会话历史和工作区设置同步到 Git 仓库，方便在不同终端/机器之间迁移。

## 📁 目录结构

```
dsh_workspace/
├── .gitignore          # Git 忽略规则
├── README.md           # 本文件
├── setup.ps1           # 部署脚本（新机器上运行）
│
└── .dsh/               # DSH 配置（对应 ~/.dsh 目录）
    ├── .anonymous-user-id      # 匿名用户标识
    ├── .credentials.yaml.example  # 凭证模板（需自行填写）
    ├── settings.yaml           # DSH 设置
    │
    ├── sessions/               # 会话历史（对话记录）
    ├── storages/               # 工作区映射数据
    │
    └── profiles/web/           # Web profile 配置
        ├── cordis.yml
        ├── cordis.patch.yml
        ├── package.json
        └── pnpm-workspace.yaml
```

## 🚀 使用说明

### 首次部署（在新机器上）

1. 安装 Git、Node.js、pnpm
2. 确保 DSH 已安装（参考 DSH 文档）
3. 克隆仓库并运行部署脚本：

```powershell
git clone git@github.com:lblacklewis/dsh_workspace.git
cd dsh_workspace
.\setup.ps1
```

4. 配置 API key：
   - 复制 `.dsh\.credentials.yaml.example` 为 `.dsh\.credentials.yaml`
   - 填入你的 DeepSeek API Key 和 Secret

### 更新配置（从本机同步到远程）

```powershell
.\sync.ps1
git add -A
git commit -m "更新 DSH 配置"
git push
```

### 恢复配置（新机器上拉取）

```powershell
git pull
.\setup.ps1
```

## ⚠️ 安全说明

- **`.credentials.yaml`** 包含 API key 等敏感信息，**不会**上传到 Git
- 每次在新机器上部署后，需要重新配置 API key
- 请妥善保管你的 API key