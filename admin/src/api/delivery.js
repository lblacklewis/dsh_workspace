// +----------------------------------------------------------------------
// | StorApp 健康药房 —— 同城即时配送（后台）
// +----------------------------------------------------------------------

import request from '@/utils/request';

// 运力商列表（含启用状态与配置）
export function deliveryProviderList() {
  return request({
    url: '/admin/delivery/provider/list',
    method: 'get',
  });
}

// 启用/停用运力商
export function deliveryProviderToggle(data) {
  return request({
    url: '/admin/delivery/provider/toggle',
    method: 'post',
    params: { ...data },
  });
}

// 按状态列出配送单（1已发单 2已接单 3已取货 4配送中 5已送达 6已取消 7失败）
export function deliveryList(params) {
  return request({
    url: '/admin/delivery/list',
    method: 'get',
    params: { ...params },
  });
}

// 配送详情（按订单 id）
export function deliveryInfo(orderId) {
  return request({
    url: `/admin/delivery/info/${orderId}`,
    method: 'get',
  });
}

// 发单：把订单派给骑手
export function deliveryDispatch(data) {
  return request({
    url: '/admin/delivery/dispatch',
    method: 'post',
    params: { ...data },
  });
}

// 取消配送
export function deliveryCancel(data) {
  return request({
    url: '/admin/delivery/cancel',
    method: 'post',
    params: { ...data },
  });
}
