// +----------------------------------------------------------------------
// | StorApp 医药版 - 营销菜单精简（无砍价/拼团/积分）
// +----------------------------------------------------------------------

/** When your routing table is too long, you can split it into small modules **/

import Layout from '@/layout';

const marketingRouter = {
  path: '/marketing',
  component: Layout,
  redirect: '/marketing/coupon/list',
  name: 'Marketing',
  meta: {
    title: '营销',
    icon: 'clipboard',
  },
  children: [
    {
      path: 'coupon',
      component: () => import('@/views/marketing/coupon/index'),
      name: 'Coupon',
      meta: { title: '优惠券', icon: '' },
      children: [
        {
          path: 'template',
          component: () => import('@/views/marketing/coupon/couponTemplate/index'),
          name: 'couponTemplate',
          hidden: true,
          meta: { title: '优惠券模板', icon: '' },
        },
        {
          path: 'list/save/:id?',
          name: 'couponAdd',
          meta: {
            title: '优惠劵添加',
            noCache: true,
            activeMenu: `/marketing/coupon/list`,
          },
          hidden: true,
          component: () => import('@/views/marketing/coupon/list/creatCoupon'),
        },
        {
          path: 'list',
          component: () => import('@/views/marketing/coupon/list/index'),
          name: 'List',
          meta: { title: '优惠券列表', icon: '' },
        },
        {
          path: 'record',
          component: () => import('@/views/marketing/coupon/record/index'),
          name: 'Record',
          meta: { title: '领取记录', icon: '' },
        },
      ],
    },
    {
      path: 'seckill',
      component: () => import('@/views/marketing/seckill/index'),
      name: 'Seckill',
      meta: { title: '秒杀管理', icon: '' },
      children: [
        {
          path: 'config',
          component: () => import('@/views/marketing/seckill/seckillConfig/index'),
          name: 'SeckillConfig',
          meta: { title: '秒杀配置', icon: '' },
        },
        {
          path: 'list/:timeId?',
          component: () => import('@/views/marketing/seckill/seckillList/index'),
          name: 'SeckillList',
          meta: { title: '秒杀商品', icon: '', noCache: true, activeMenu: `/marketing/seckill/list` },
        },
        {
          path: 'creatSeckill/:name?/:timeId?/:id?/:type?',
          component: () => import('@/views/marketing/seckill/seckillList/creatSeckill'),
          name: 'CreatSeckill',
          meta: { title: '添加秒杀商品', icon: '', noCache: true, activeMenu: `/marketing/seckill/list` },
        },
      ],
    },
  ],
};

export default marketingRouter;