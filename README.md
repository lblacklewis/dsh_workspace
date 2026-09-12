# DSH Workspace

DSH 工作区配置 + 项目代码同步仓库。

## 📁 项目

| 分支 | 内容 |
|------|------|
| **3.0** | StorApp（CRMEB Java 开源商城 品牌定制版） |
| **master** | DSH 配置同步 |

## 🚀 使用说明

### 首次部署（在新机器上）

1. 安装 Git、Node.js、pnpm
2. 确保 DSH 已安装
3. 克隆仓库并运行部署脚本：

```powershell
git clone git@github.com:lblacklewis/dsh_workspace.git
cd dsh_workspace
.\setup.ps1
```

4. 配置 API key：
   - 复制 `.dsh\.credentials.yaml.example` 为 `.dsh\.credentials.yaml`
   - 填入你的 DeepSeek API Key 和 Secret

### 更新配置

```powershell
.\sync.ps1
git add -A
git commit -m "更新 DSH 配置"
git push
```

## ⚠️ 安全说明

- **`.credentials.yaml`** 包含 API key，**不会**上传到 Git
- 每次在新机器上部署后，需要重新配置 API key