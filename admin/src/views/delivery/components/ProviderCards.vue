<template>
  <el-card :bordered="false" shadow="never" class="ivu-mt" :body-style="{ padding: '16px 20px' }">
    <div slot="header" class="clearfix">
      <span style="font-weight: 600">运力商</span>
      <el-alert
        v-if="brokenCount > 0"
        type="error"
        :closable="false"
        show-icon
        :title="'有 ' + brokenCount + ' 个运力商「已启用但代码未实现」，发单必然失败，请停用它们'"
        style="margin-top: 10px"
      ></el-alert>
      <el-alert
        v-else
        type="warning"
        :closable="false"
        show-icon
        title="灰色「未接入」的运力商代码里还没有实现，无法启用；完成对接后再开启"
        style="margin-top: 10px"
      ></el-alert>
    </div>
    <div class="pv-grid">
      <div v-for="p in providers" :key="p.code" class="pv-cell">
        <div
          class="pv-card"
          :class="{ 'pv-on': p.isEnable && p.implemented, 'pv-broken': p.configBroken, 'pv-na': !p.implemented }"
        >
          <div class="pv-head">
            <span class="pv-name">{{ p.name }}</span>
            <el-tag size="mini" :type="statusTag(p).type">{{ statusTag(p).text }}</el-tag>
          </div>
          <div class="pv-code">
            code: {{ p.code }}
            <span v-if="p.inUse" class="pv-using">当前生效</span>
          </div>
          <div class="pv-remark">{{ p.remark || '-' }}</div>
          <div v-if="!p.implemented" class="pv-hint">代码未接入，无法启用</div>
          <el-button
            size="mini"
            :type="p.isEnable ? 'danger' : 'primary'"
            plain
            :disabled="!p.implemented && !p.isEnable"
            @click="toggle(p)"
          >
            {{ p.isEnable ? '停用' : '启用' }}
          </el-button>
        </div>
      </div>
      <div v-if="providers.length === 0" class="pv-empty">
        {{ loadError ? '运力商列表加载失败：' + loadError : '暂无运力商配置' }}
      </div>
    </div>
  </el-card>
</template>

<script>
import { deliveryProviderList, deliveryProviderToggle } from '@/api/delivery';

export default {
  name: 'DeliveryProviderCards',
  data() {
    return {
      providers: [],
      loadError: '',
    };
  },
  computed: {
    brokenCount() {
      return this.providers.filter((p) => p.configBroken).length;
    },
  },
  created() {
    // 在 created 里取（早于 mounted），并让本组件自己持有数据
    this.load();
  },
  methods: {
    // 状态标签必须区分「能用」和「只是配置开着」——
    // 之前 5 个卡片全显示「已启用」，操作员根本看不出哪个发单会失败
    statusTag(p) {
      if (p.implemented) {
        return p.isEnable ? { type: 'success', text: '已启用' } : { type: 'info', text: '未启用' };
      }
      return p.isEnable
        ? { type: 'danger', text: '已启用·未接入' }
        : { type: 'info', text: '未接入' };
    },
    load() {
      this.loadError = '';
      deliveryProviderList()
        .then((res) => {
          this.providers = res || [];
        })
        .catch((err) => {
          this.providers = [];
          this.loadError = (err && (err.message || err.msg)) || '未知错误';
        });
    },
    toggle(p) {
      const enable = !p.isEnable;
      this.$confirm(`确定要${enable ? '启用' : '停用'}「${p.name}」吗？`, '提示', { type: 'warning' })
        .then(() => {
          deliveryProviderToggle({ code: p.code, enable })
            .then(() => {
              this.$message.success('操作成功');
              this.load();
              this.$emit('changed');
            })
            .catch((err) => this.$message.error((err && err.msg) || '操作失败'));
        })
        .catch(() => {});
    },
  },
};
</script>

<style scoped>
.pv-grid {
  display: flex;
  flex-wrap: wrap;
  margin: 0 -6px;
}
.pv-cell {
  box-sizing: border-box;
  width: 25%;
  padding: 0 6px 12px;
}
.pv-card {
  border: 1px solid #ebeef5;
  border-radius: 6px;
  padding: 12px 14px;
}
.pv-on {
  border-color: #67c23a;
  background: #f0f9eb;
}
.pv-broken {
  border-color: #f56c6c;
  background: #fef0f0;
}
.pv-na {
  background: #fafafa;
  opacity: 0.75;
}
.pv-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}
.pv-name {
  font-weight: 600;
  font-size: 13px;
}
.pv-code {
  font-size: 12px;
  color: #909399;
  margin-bottom: 4px;
}
.pv-using {
  margin-left: 6px;
  padding: 0 4px;
  border-radius: 3px;
  background: #0d9488;
  color: #fff;
  font-size: 11px;
}
.pv-remark {
  font-size: 12px;
  color: #606266;
  min-height: 34px;
  margin-bottom: 8px;
}
.pv-hint {
  font-size: 12px;
  color: #f56c6c;
  margin-bottom: 8px;
}
.pv-empty {
  padding: 8px 6px;
  color: #909399;
  font-size: 13px;
}
</style>
