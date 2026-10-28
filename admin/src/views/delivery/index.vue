<template>
  <div class="divBox">
    <!-- 运力商状态：一眼看清哪家开着，避免"配置开了但发单必然失败" -->
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
            <el-button
              size="mini"
              :type="p.isEnable ? 'danger' : 'primary'"
              plain
              @click="toggleProvider(p)"
            >
              {{ p.isEnable ? '停用' : '启用' }}
            </el-button>
          </div>
        </div>
      </div>
    </el-card>

    <el-card :bordered="false" shadow="never" class="mt15" :body-style="{ padding: 0 }">
      <div class="padding-add">
        <el-form inline size="small" label-width="80px">
          <el-form-item label="配送状态：">
            <el-select v-model="tableFrom.status" class="selWidth" @change="getList">
              <el-option v-for="(v, k) in statusMap" :key="k" :label="v.text" :value="Number(k)"></el-option>
            </el-select>
          </el-form-item>
          <el-form-item label="订单ID：">
            <el-input v-model="dispatchOrderId" placeholder="填入订单ID后点发单" class="selWidth" clearable></el-input>
          </el-form-item>
          <el-form-item>
            <el-button type="primary" size="small" @click="getList">查询</el-button>
            <el-button size="small" :loading="dispatching" @click="doDispatch">发单给骑手</el-button>
          </el-form-item>
        </el-form>
      </div>
    </el-card>

    <el-card :bordered="false" shadow="never" class="mt15" :body-style="{ padding: 0 }">
      <el-table v-loading="loading" :data="list" size="small" style="width: 100%">
        <el-table-column prop="orderId" label="订单ID" width="90"></el-table-column>
        <el-table-column prop="orderNo" label="订单号" min-width="200" show-overflow-tooltip></el-table-column>
        <el-table-column prop="provider" label="运力商" width="110"></el-table-column>
        <el-table-column prop="outerNo" label="运力单号" min-width="170" show-overflow-tooltip></el-table-column>
        <el-table-column label="状态" width="110">
          <template slot-scope="scope">
            <el-tag size="mini" :type="statusType(scope.row.status)">{{ statusText(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="骑手" width="150">
          <template slot-scope="scope">
            <span v-if="scope.row.riderName">{{ scope.row.riderName }} {{ scope.row.riderPhone }}</span>
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="fee" label="配送费" width="90"></el-table-column>
        <el-table-column prop="createTime" label="发单时间" width="160"></el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template slot-scope="scope">
            <el-button type="text" size="small" @click="showDetail(scope.row)">详情</el-button>
            <el-button
              v-if="scope.row.status !== 5 && scope.row.status !== 6"
              type="text"
              size="small"
              class="red"
              @click="doCancel(scope.row)"
              >取消</el-button
            >
          </template>
        </el-table-column>
      </el-table>
      <div class="block-pagination">
        <el-pagination background layout="total" :total="list.length"></el-pagination>
      </div>
    </el-card>

    <el-dialog :visible.sync="detailVisible" title="配送详情" width="640px">
      <el-descriptions v-if="current" :column="2" border size="small">
        <el-descriptions-item label="订单号">{{ current.orderNo }}</el-descriptions-item>
        <el-descriptions-item label="运力商">{{ current.provider }}</el-descriptions-item>
        <el-descriptions-item label="运力单号">{{ current.outerNo || '-' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ current.statusDesc }}</el-descriptions-item>
        <el-descriptions-item label="骑手">{{ current.riderName || '-' }}</el-descriptions-item>
        <el-descriptions-item label="骑手电话">{{ current.riderPhone || '-' }}</el-descriptions-item>
        <el-descriptions-item label="收货人">{{ current.receiverName }}</el-descriptions-item>
        <el-descriptions-item label="收货电话">{{ current.receiverPhone }}</el-descriptions-item>
        <el-descriptions-item label="收货地址" :span="2">{{ current.receiverAddress }}</el-descriptions-item>
        <el-descriptions-item label="配送费">{{ current.fee }}</el-descriptions-item>
        <el-descriptions-item label="预计送达">{{ current.estimateMin ? current.estimateMin + ' 分钟' : '-' }}</el-descriptions-item>
        <el-descriptions-item label="发单时间">{{ current.createTime }}</el-descriptions-item>
        <el-descriptions-item label="最近回调">{{ current.callbackTime || '-' }}</el-descriptions-item>
        <el-descriptions-item v-if="current.failReason" label="失败原因" :span="2">
          <span class="red">{{ current.failReason }}</span>
        </el-descriptions-item>
      </el-descriptions>
    </el-dialog>
  </div>
</template>

<script>
import {
  deliveryProviderList,
  deliveryProviderToggle,
  deliveryList,
  deliveryInfo,
  deliveryDispatch,
  deliveryCancel,
} from '@/api/delivery';

export default {
  name: 'DeliveryOrder',
  data() {
    return {
      loading: false,
      dispatching: false,
      providers: [],
      list: [],
      tableFrom: { status: 1, limit: 50 },
      dispatchOrderId: '',
      detailVisible: false,
      current: null,
      // 与后端 DeliveryStatus 保持一致
      statusMap: {
        1: { text: '已发单', type: 'warning' },
        2: { text: '已接单', type: 'primary' },
        3: { text: '已取货', type: 'primary' },
        4: { text: '配送中', type: 'primary' },
        5: { text: '已送达', type: 'success' },
        6: { text: '已取消', type: 'info' },
        7: { text: '配送失败', type: 'danger' },
      },
    };
  },
  mounted() {
    this.getProviders();
    this.getList();
  },
  methods: {
    getProviders() {
      deliveryProviderList()
        .then((res) => {
          this.providers = res || [];
        })
        .catch(() => {
          this.providers = [];
        });
    },
    toggleProvider(p) {
      const enable = !p.isEnable;
      this.$confirm(`确定要${enable ? '启用' : '停用'}「${p.name}」吗？`, '提示', { type: 'warning' })
        .then(() => {
          deliveryProviderToggle({ code: p.code, enable })
            .then(() => {
              this.$message.success('操作成功');
              this.getProviders();
            })
            .catch((err) => this.$message.error(err.msg || '操作失败'));
        })
        .catch(() => {});
    },
    getList() {
      this.loading = true;
      deliveryList(this.tableFrom)
        .then((res) => {
          this.list = res || [];
        })
        .catch(() => {
          this.list = [];
        })
        .finally(() => {
          this.loading = false;
        });
    },
    doDispatch() {
      const id = parseInt(this.dispatchOrderId, 10);
      if (!id) {
        this.$message.warning('请先填写订单ID');
        return;
      }
      this.dispatching = true;
      // 后端做了幂等：同一订单重复发单会返回同一条，不会重复扣配送费
      deliveryDispatch({ orderId: id })
        .then((res) => {
          const d = res || {};
          if (d.provider) {
            this.$message.success(`已发单给「${d.provider}」，运力单号 ${d.outerNo || '-'}`);
          } else {
            this.$message.success('发单成功');
          }
          this.getList();
        })
        .catch((err) => this.$message.error(err.msg || '发单失败'))
        .finally(() => {
          this.dispatching = false;
        });
    },
    doCancel(row) {
      this.$prompt('请输入取消原因', '取消配送', { inputValue: '商家取消' })
        .then(({ value }) => {
          deliveryCancel({ orderId: row.orderId, reason: value })
            .then(() => {
              this.$message.success('已取消');
              this.getList();
            })
            .catch((err) => this.$message.error(err.msg || '取消失败'));
        })
        .catch(() => {});
    },
    showDetail(row) {
      // 重新拉一次而不是直接用行数据：详情里有骑手实时状态，行数据是列表快照
      deliveryInfo(row.orderId)
        .then((res) => {
          this.current = res || row;
          this.detailVisible = true;
        })
        .catch(() => {
          this.current = row;
          this.detailVisible = true;
        });
    },
    statusText(s) {
      return (this.statusMap[s] || {}).text || '未知';
    },
    statusType(s) {
      return (this.statusMap[s] || {}).type || 'info';
    },
  },
};
</script>

<style scoped>
.padding-add {
  padding: 20px;
}
.mt15 {
  margin-top: 15px;
}
.selWidth {
  width: 170px;
}
.red {
  color: #f56c6c;
}
.muted {
  color: #909399;
}
.block-pagination {
  padding: 16px;
  text-align: right;
}
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
</style>
