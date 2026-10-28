// +----------------------------------------------------------------------
// | StorApp 健康药房 —— 处方审核（后台）
// +----------------------------------------------------------------------

import request from '@/utils/request';

// 处方列表（默认待审核）
export function prescriptionList(params) {
  return request({
    url: '/admin/prescription/list',
    method: 'get',
    params: { ...params },
  });
}

// 处方详情
export function prescriptionDetail(id) {
  return request({
    url: `/admin/prescription/detail/${id}`,
    method: 'get',
  });
}

// 药师审核（pass=true 通过，false 驳回；驳回必须填原因）
export function prescriptionAudit(data) {
  return request({
    url: '/admin/prescription/audit',
    method: 'post',
    params: { ...data },
  });
}

// 把处方绑定到订单（合规留痕）
export function prescriptionBindOrder(data) {
  return request({
    url: '/admin/prescription/bind/order',
    method: 'post',
    params: { ...data },
  });
}

// 查某订单用到的处方
export function prescriptionByOrder(orderId) {
  return request({
    url: `/admin/prescription/order/${orderId}`,
    method: 'get',
  });
}
