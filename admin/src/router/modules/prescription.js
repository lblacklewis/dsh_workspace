// +----------------------------------------------------------------------
// | StorApp 健康药房 —— 处方管理路由
// +----------------------------------------------------------------------

import Layout from '@/layout';

const prescriptionRouter = {
  path: '/prescription',
  component: Layout,
  redirect: '/prescription/index',
  name: 'Prescription',
  alwaysShow: true,
  meta: {
    title: '处方管理',
    icon: 'clipboard',
  },
  children: [
    {
      path: 'index',
      component: () => import('@/views/prescription/index'),
      name: 'PrescriptionIndex',
      meta: { title: '处方审核' },
    },
  ],
};

export default prescriptionRouter;
