<template>
  <div class="divBox stat-row" style="padding-bottom: 0">
    <el-row :gutter="16" class="baseInfo">
      <el-col v-for="(item, i) in cards" :key="i" v-bind="grid" class="ivu-mb">
        <el-card :bordered="false" dis-hover :padding="0" class="stat-card" :class="'tone-' + item.tone">
          <div class="stat-card__top">
            <span class="stat-card__icon" :class="'is-' + item.tone">
              <span class="iconfont" :class="item.icon"></span>
            </span>
            <span class="stat-card__label">{{ item.label }}</span>
            <span class="stat-card__tag">今日</span>
          </div>
          <div class="stat-card__value" v-if="viewData">
            <span class="num">{{ viewData[item.key] }}</span>
            <span class="unit" v-if="item.unit">{{ item.unit }}</span>
          </div>
          <div class="stat-card__foot">
            <span class="foot-label">昨日</span>
            <span class="foot-value">{{ viewData ? viewData[item.prevKey] : '-' }}{{ item.unit ? ' ' + item.unit : '' }}</span>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
<script>
import { viewModelApi } from '@/api/dashboard';
export default {
  data() {
    return {
      grid: { xl: 6, lg: 6, md: 12, sm: 12, xs: 24 },
      viewData: {},
      // 四张卡：图标 + 口径 + 主数值 + 昨日对照
      cards: [
        { label: '销售额', key: 'sales', prevKey: 'yesterdaySales', icon: 'iconxiaoshoue', tone: 'teal' },
        { label: '用户访问量', key: 'pageviews', prevKey: 'yesterdayPageviews', icon: 'iconyonghu', tone: 'blue' },
        { label: '订单量', key: 'orderNum', prevKey: 'yesterdayOrderNum', icon: 'icondingdan', tone: 'amber', unit: '单' },
        { label: '新增用户', key: 'newUserNum', prevKey: 'yesterdayNewUserNum', icon: 'iconxinzengyonghu', tone: 'violet', unit: '人' },
      ],
    };
  },
  methods: {
    statisticsOrder() {
      viewModelApi().then(async (res) => {
        this.viewData = res;
      });
    },
  },
  mounted() {
    this.statisticsOrder();
  },
};
</script>
<style scoped lang="scss">
/* ============================================================
 * StorApp 重绘 —— 控制台顶部 4 张数据卡
 * 原来：标题 + 灰底大数字 + el-divider 横线，四张卡一模一样、没有视觉锚点。
 * 现在：色块图标 + 主数值放大 + 「昨日」做成底部对照条。
 * ============================================================ */
.stat-row {
  .ivu-mb {
    margin-bottom: 16px;
  }
}

.baseInfo ::v-deep .el-card__body {
  padding: 0 !important;
}

.stat-card {
  border-radius: 12px !important;
  border: 1px solid #edf1f5 !important;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 10px 28px -22px rgba(15, 23, 42, 0.35) !important;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 2px 4px rgba(15, 23, 42, 0.05), 0 16px 32px -20px rgba(15, 23, 42, 0.4) !important;
  }

  &__top {
    display: flex;
    align-items: center;
    padding: 16px 18px 0;
  }
  &__icon {
    width: 34px;
    height: 34px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 10px;
    flex: 0 0 auto;
    .iconfont {
      font-size: 18px;
      color: #fff;
    }
    &.is-teal {
      background: linear-gradient(135deg, #14b8a6, #0d9488);
    }
    &.is-blue {
      background: linear-gradient(135deg, #60a5fa, #3b82f6);
    }
    &.is-amber {
      background: linear-gradient(135deg, #fbbf24, #f59e0b);
    }
    &.is-violet {
      background: linear-gradient(135deg, #a78bfa, #8b5cf6);
    }
  }
  &__label {
    font-size: 14px;
    font-weight: 600;
    color: #0f172a;
    flex: 1;
    white-space: nowrap;
  }
  &__tag {
    font-size: 12px;
    color: #94a3b8;
    background: #f1f5f9;
    border-radius: 999px;
    padding: 2px 8px;
    flex: 0 0 auto;
  }
  &__value {
    padding: 14px 18px 12px;
    display: flex;
    align-items: baseline;
    .num {
      font-size: 32px;
      font-weight: 700;
      line-height: 1;
      color: #0f172a;
      font-family: 'DIN Alternate', 'SF Pro Display', PingFangSC-Semibold, PingFang SC, sans-serif;
      letter-spacing: -0.5px;
    }
    .unit {
      font-size: 13px;
      color: #64748b;
      margin-left: 4px;
    }
  }
  &__foot {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 9px 18px;
    background: #f8fafc;
    border-top: 1px solid #f1f5f9;
    .foot-label {
      font-size: 12px;
      color: #94a3b8;
    }
    .foot-value {
      font-size: 13px;
      font-weight: 600;
      color: #475569;
    }
  }
}
</style>
