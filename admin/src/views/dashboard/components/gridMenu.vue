<template>
  <div class="divBox">
    <el-row :gutter="16">
      <el-col :xs="24" :sm="24" :md="24" :lg="12">
        <el-card class="box-card panel">
          <div class="panel-head">
            <div class="panel-title">快捷入口</div>
            <div class="panel-sub">常用操作，一点直达</div>
          </div>
          <div class="quick-grid">
            <div class="quick-item" v-for="(item, index) in permList" :key="index" @click="navigatorTo(item.url)">
              <div class="quick-icon" :style="{ background: item.soft, color: item.bgColor }">
                <span class="iconfont" :class="item.icon"></span>
              </div>
              <span class="quick-label">{{ item.title }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="24" :md="24" :lg="12">
        <el-card class="box-card panel">
          <div class="panel-head">
            <div class="panel-title">经营数据</div>
            <div class="panel-sub">待办与库存一览</div>
          </div>
          <div class="biz-grid">
            <div
              class="biz-item"
              :class="{ 'is-warn': item.warn && item.num > 0 }"
              v-for="(item, index) in businessList"
              :key="index"
              @click="navigatorTo(item.path)"
            >
              <p class="biz-num">{{ item.num }}</p>
              <p class="biz-label">{{ item.title }}</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
<script>
import echartsNew from '@/components/echartsNew/index';
import { businessData } from '@/api/dashboard';
import { checkPermi } from '@/utils/permission'; // 权限判断函数
export default {
  components: {
    echartsNew,
  },
  data() {
    return {
      grid: {
        xl: 3,
        lg: 3,
        md: 6,
        sm: 8,
        xs: 8,
      },
      nav_list: [
        {
          bgColor: '#0D9488',
          soft: '#F0FDFA',
          icon: 'iconhuiyuanguanli',
          title: '用户管理',
          url: '/user/index',
          perms: ['admin:user:list'],
        },
        {
          bgColor: '#3B82F6',
          soft: '#EFF6FF',
          icon: 'iconxitongshezhi',
          title: '系统设置',
          url: '/operation/setting',
          perms: ['admin:system:config:info'],
        },
        {
          bgColor: '#F59E0B',
          soft: '#FFFBEB',
          icon: 'iconshangpinguanli',
          title: '商品管理',
          url: '/store/index',
          perms: ['admin:product:list'],
        },
        {
          bgColor: '#EF4444',
          soft: '#FEF2F2',
          icon: 'icondingdanguanli',
          title: '订单管理',
          url: '/order/index',
          perms: ['admin:order:list'],
        },
        {
          bgColor: '#8B5CF6',
          soft: '#F5F3FF',
          icon: 'iconduanxinpeizhi',
          title: '一号通',
          url: '/operation/onePass',
          perms: ['admin:pass:login'],
        },
        {
          bgColor: '#0EA5E9',
          soft: '#F0F9FF',
          icon: 'iconwenzhangguanli',
          title: '文章管理',
          url: '/content/articleManager',
          perms: ['admin:article:list'],
        },
        {
          bgColor: '#14B8A6',
          soft: '#F0FDFA',
          icon: 'iconfenxiaoguanli',
          title: '分销管理',
          url: '/distribution/index',
          perms: ['admin:retail:list'],
        },
        {
          bgColor: '#6366F1',
          soft: '#EEF2FF',
          icon: 'iconyouhuiquan',
          title: '优惠券',
          url: '/marketing/coupon/list',
          perms: ['admin:coupon:list'],
        },
      ],
      // warn: 数量 > 0 时用暖色提示，让「待办」自己跳出来
      statisticData: [
        { title: '待发货订单', num: 0, path: '/order/index', perms: ['admin:order:list'], warn: true },
        { title: '退款中订单', num: 0, path: '/order/index', perms: ['admin:order:list'], warn: true },
        { title: '待核销订单', num: 0, path: '/order/index', perms: ['admin:order:list'], warn: true },
        { title: '库存预警', num: 0, path: '/store/index', perms: ['admin:product:list'], warn: true },
        { title: '上架商品', num: 0, path: '/store/index', perms: ['admin:product:list'] },
        { title: '仓库商品', num: 0, path: '/store/index', perms: ['admin:product:list'] },
        { title: '提现待审核', num: 0, path: '/financial/commission/template', perms: ['admin:finance:apply:list'], warn: true },
        { title: '账户充值', num: 0, path: '/financial/record/charge', perms: ['admin:recharge:list'] },
      ],
      optionData: {},
      applyNum: 0,
      style: { height: '250px' },
    };
  },
  computed: {
    //鉴权处理
    permList: function () {
      let arr = [];
      this.nav_list.forEach((item) => {
        if (this.checkPermi(item.perms)) {
          arr.push(item);
        }
      });
      return arr;
    },
    businessList: function () {
      let arr = [];
      this.statisticData.forEach((item) => {
        if (this.checkPermi(item.perms)) {
          arr.push(item);
        }
      });
      return arr;
    },
  },
  mounted() {
    this.getbusinessData();
  },
  methods: {
    checkPermi,
    navigatorTo(path) {
      this.$router.push(path);
    },
    getbusinessData() {
      businessData().then((res) => {
        this.statisticData[0].num = res.notShippingOrderNum; //待发货订单
        this.statisticData[1].num = res.refundingOrderNum; //退款中订单
        this.statisticData[2].num = res.notWriteOffOrderNum; //待核销订单
        this.statisticData[3].num = res.vigilanceInventoryNum; //库存预警
        this.statisticData[4].num = res.onSaleProductNum; //上架商品
        this.statisticData[5].num = res.notSaleProductNum; //仓库商品
        this.statisticData[6].num = res.notAuditNum; //提现待审核
        this.statisticData[7].num = res.totalRechargeAmount; //账户充值
      });
    },
  },
};
</script>
<style lang="scss" scoped>
/* ============================================================
 * StorApp 重绘 —— 快捷入口 / 经营数据 两张面板
 * 原来：58px 高饱和色块 + 居中数字，卡片高矮不齐、信息层级扁平。
 * 现在：浅色底图标块 + 统一网格，待办项数量 > 0 时数字变暖色。
 * ============================================================ */
.panel {
  border-radius: 12px !important;
  border: 1px solid #edf1f5 !important;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 10px 28px -22px rgba(15, 23, 42, 0.35) !important;
  height: 100%;
  ::v-deep .el-card__body {
    padding: 18px 18px 12px !important;
  }
}
.panel-head {
  display: flex;
  align-items: baseline;
  margin-bottom: 6px;
}
.panel-title {
  font-size: 15px;
  font-weight: 600;
  color: #0f172a;
  position: relative;
  padding-left: 11px;
  &::before {
    position: absolute;
    content: '';
    width: 3px;
    height: 14px;
    border-radius: 2px;
    background: #0d9488;
    top: 2px;
    left: 0;
  }
}
.panel-sub {
  font-size: 12px;
  color: #94a3b8;
  margin-left: 10px;
}

/* 快捷入口：4 列 */
.quick-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  margin-top: 8px;
}
.quick-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 14px 4px 12px;
  border-radius: 10px;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease;
  &:hover {
    background: #f8fafc;
    transform: translateY(-2px);
  }
}
.quick-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  .iconfont {
    font-size: 22px;
  }
}
.quick-label {
  margin-top: 8px;
  font-size: 13px;
  color: #334155;
  white-space: nowrap;
}

/* 经营数据：4 列 2 行 */
.biz-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-top: 8px;
}
.biz-item {
  padding: 12px 6px;
  border-radius: 10px;
  background: #f8fafc;
  text-align: center;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease;
  &:hover {
    background: #f1f5f9;
    transform: translateY(-2px);
  }
  .biz-num {
    font-size: 22px;
    font-weight: 700;
    line-height: 1.1;
    color: #0f172a;
    font-family: 'DIN Alternate', PingFangSC-Semibold, PingFang SC, sans-serif;
  }
  .biz-label {
    margin-top: 5px;
    font-size: 12px;
    color: #64748b;
    white-space: nowrap;
  }
  /* 有待办时用暖色跳出来 */
  &.is-warn {
    background: #fff7ed;
    .biz-num {
      color: #ea580c;
    }
    .biz-label {
      color: #c2410c;
    }
  }
}
</style>
