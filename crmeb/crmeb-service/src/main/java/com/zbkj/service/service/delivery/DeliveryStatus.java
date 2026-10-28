package com.zbkj.service.service.delivery;

/**
 * 配送状态常量
 * 与 eb_delivery_order.status 一一对应
 */
public class DeliveryStatus {

    /** 待发单（订单已支付，尚未向运力商下单） */
    public static final int PENDING = 0;
    /** 已发单（已调用运力商接口，等待骑手接单） */
    public static final int DISPATCHED = 1;
    /** 骑手已接单 */
    public static final int ACCEPTED = 2;
    /** 骑手已取货 */
    public static final int PICKED = 3;
    /** 配送中 */
    public static final int DELIVERING = 4;
    /** 已送达 */
    public static final int FINISHED = 5;
    /** 已取消 */
    public static final int CANCELED = 6;
    /** 发单失败 */
    public static final int FAILED = 7;

    private DeliveryStatus() {
    }

    /**
     * 终态：到达后不再接受状态流转
     */
    public static boolean isFinal(Integer status) {
        return status != null && (status == FINISHED || status == CANCELED || status == FAILED);
    }

    /**
     * 状态中文描述，用于给用户展示
     */
    public static String desc(Integer status) {
        if (status == null) {
            return "未知";
        }
        switch (status) {
            case PENDING:
                return "待发单";
            case DISPATCHED:
                return "等待骑手接单";
            case ACCEPTED:
                return "骑手已接单";
            case PICKED:
                return "骑手已取货";
            case DELIVERING:
                return "配送中";
            case FINISHED:
                return "已送达";
            case CANCELED:
                return "已取消";
            case FAILED:
                return "发单失败";
            default:
                return "未知";
        }
    }
}
