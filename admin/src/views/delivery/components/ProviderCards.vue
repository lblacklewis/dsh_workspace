<template>
  <el-card :bordered="false" shadow="never" class="ivu-mt" :body-style="{ padding: '16px 20px' }">
    <div slot="header" class="clearfix">
      <span style="font-weight: 600">运力商</span>
      <el-alert
        type="warning"
        :closable="false"
        show-icon
        title="未接入的运力商即使启用也无法真正发单；凭证到位后再启用"
        style="margin-top: 10px"
      ></el-alert>
    </div>
    <div class="pv-grid">
      <div v-for="p in providers" :key="p.code" class="pv-cell">
        <div class="pv-card" :class="{ 'pv-on': p.isEnable }">
          <div class="pv-head">
            <span class="pv-name">{{ p.name }}</span>
            <el-tag size="mini" :type="p.isEnable ? 'success' : 'info'">
              {{ p.isEnable ? '已启用' : '未启用' }}
            </el-tag>
          </div>
          <div class="pv-code">code: {{ p.code }}</div>
          <div class="pv-remark">{{ p.remark || '-' }}</div>
          <el-button size="mini" :type="p.isEnable ? 'danger' : 'primary'" plain @click="toggle(p)">
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
  created() {
    // 在 created 里取（早于 mounted），并让本组件自己持有数据
    this.load();
  },
  methods: {
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
.pv-remark {
  font-size: 12px;
  color: #606266;
  min-height: 34px;
  margin-bottom: 8px;
}
.pv-empty {
  padding: 8px 6px;
  color: #909399;
  font-size: 13px;
}
</style>
