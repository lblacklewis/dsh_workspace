// +----------------------------------------------------------------------
// | StorApp 健康药房 —— 配送管理路由
// +----------------------------------------------------------------------

import Layout from '@/layout';

const deliveryRouter = {
  path: '/delivery',
  component: Layout,
  redirect: '/delivery/index',
  name: 'Delivery',
  alwaysShow: true,
  meta: {
    title: '配送管理',
    icon: 'clipboard',
  },
  children: [
    {
      path: 'index',
      component: () => import('@/views/delivery/index'),
      name: 'DeliveryIndex',
      meta: { title: '同城配送' },
    },
  ],
};

export default deliveryRouter;
