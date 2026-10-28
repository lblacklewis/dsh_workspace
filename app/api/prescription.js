// +----------------------------------------------------------------------
// | StorApp 健康药房 —— 互联网处方
// +----------------------------------------------------------------------
// 合规：处方药"先方后药"，必须凭有效处方购买。
// 上传后进入药师审核，审核通过（auditStatus=1）才可用于下单。

import request from "@/utils/request.js";

/**
 * 上传处方（拍照上传线下处方）
 * @param object {patientName, idcard, images, diagnosis}
 */
export function uploadPrescription(data) {
	return request.post("prescription/upload", data);
}

/**
 * 发起在线问诊（跳转合作互联网医院）
 * @param object {patientName, idcard, extra}
 */
export function createConsult(data) {
	return request.post("prescription/consult", data);
}

/**
 * 我的处方列表
 * @param int auditStatus 0待审核 1通过 2驳回，不传为全部
 */
export function getPrescriptionList(auditStatus) {
	let url = "prescription/list";
	if (auditStatus !== undefined && auditStatus !== null && auditStatus !== "") {
		url += "?auditStatus=" + auditStatus;
	}
	return request.get(url);
}

/**
 * 处方详情
 * @param int id
 */
export function getPrescriptionDetail(id) {
	return request.get(`prescription/detail/${id}`);
}

/**
 * 校验这批商品是否都已有有效处方覆盖
 * @param array productIds
 * @return {passed, missingProductIds}
 */
export function checkPrescriptionCover(productIds) {
	return request.post("prescription/check", {
		productIds: (productIds || []).join(",")
	});
}
