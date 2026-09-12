// ============================================================
// 🎨 品牌定制配置文件 —— 改这里即可全局生效
// 医药主题：现代、干净、专业
// ============================================================

const BRAND = {
  // --- 品牌名称 ---
  name: 'StorApp',                    // 系统名称（显示在标题栏、登录页等）
  shortName: 'StorApp',               // 简称（侧边栏等窄位置）

  // --- Logo ---
  logo: '/favicon.ico',               // 登录页/侧边栏 Logo（替换为你的 logo 地址）
  loginBg: '',                        // 登录页背景图 URL（留空用默认）

  // --- 医药主题色 ---
  primaryColor: '#0D9488',            // 主色调 teal（医学/健康感）

  // --- 版权信息 ---
  copyright: `© ${new Date().getFullYear()} StorApp. All rights reserved.`,

  // --- 联系方式 ---
  supportEmail: 'support@storapp.com',
};

export default BRAND;