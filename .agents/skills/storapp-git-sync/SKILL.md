---
name: storapp-git-sync
description: 项目改动总结 → 生成文档 → Git提交推送。当用户说"保存进度"、"提交代码"、"总结会话"、"push git"时使用此技能。
---

# StorApp Git Sync 工作流

每次开发会话结束时执行以下步骤。

## 步骤

### 1. 检查改动
```bash
git status --short
git diff --stat
```

### 2. 生成/更新会话总结
创建或更新 `docs/项目会话总结.md`，包含：
- 本次做了什么
- 改动文件清单
- 环境/配置变更
- 当前状态和待办

### 3. 暂存并提交
```bash
git add -A
git commit -m "<简短描述>"
```

提交信息格式：`分类: 做了什么`，如 `前端: 登录页品牌定制`。

### 4. 推送
```bash
git push origin <branch>
```

> 首次推送前确认 `git remote -v` 指向自己的仓库，而非原始CRMEB仓库。如需修改：
> ```bash
> git remote set-url origin <你的仓库地址>
> ```

## 项目关键路径速查

| 目录 | 用途 |
|------|------|
| `admin/src/views/` | 管理后台页面 |
| `admin/src/config/brand.js` | 品牌配置 |
| `app/config/app.js` | 移动端API地址 |
| `app/pages/` | 移动端页面 |
| `crmeb/crmeb-admin/` | 后台API |
| `crmeb/crmeb-front/` | 前台API |
| `crmeb/crmeb-service/` | 业务逻辑 |
| `docs/` | 文档和模板 |