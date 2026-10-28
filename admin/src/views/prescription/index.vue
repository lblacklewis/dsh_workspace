<template>
  <div class="divBox">
    <el-card :bordered="false" shadow="never" class="ivu-mt" :body-style="{ padding: 0 }">
      <div class="padding-add">
        <el-form inline size="small" label-width="80px">
          <el-form-item label="审核状态：">
            <el-select v-model="tableFrom.auditStatus" class="selWidth" @change="getList">
              <el-option label="待审核" :value="0"></el-option>
              <el-option label="已通过" :value="1"></el-option>
              <el-option label="已驳回" :value="2"></el-option>
            </el-select>
          </el-form-item>
          <el-form-item>
            <el-button type="primary" size="small" @click="getList">查询</el-button>
            <el-button size="small" @click="refresh">刷新</el-button>
          </el-form-item>
          <el-form-item>
            <el-alert
              type="warning"
              :closable="false"
              show-icon
              title="处方药须凭执业药师审核通过的处方销售；处方及审核记录按规定留存，请勿删除"
              style="margin-bottom: 0"
            ></el-alert>
          </el-form-item>
        </el-form>
      </div>
    </el-card>

    <el-card :bordered="false" shadow="never" class="mt15" :body-style="{ padding: 0 }">
      <el-table v-loading="loading" :data="list" size="small" style="width: 100%">
        <el-table-column prop="id" label="ID" width="70"></el-table-column>
        <el-table-column prop="rxNo" label="处方号" min-width="180" show-overflow-tooltip></el-table-column>
        <el-table-column prop="patientName" label="患者" width="100"></el-table-column>
        <el-table-column prop="diagnosis" label="诊断" min-width="140" show-overflow-tooltip></el-table-column>
        <el-table-column prop="doctorName" label="开方医师" width="110"></el-table-column>
        <el-table-column label="来源" width="100">
          <template slot-scope="scope">
            <el-tag size="mini" :type="scope.row.source === 1 ? 'info' : 'success'">
              {{ sourceText(scope.row.source) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="审核状态" width="110">
          <template slot-scope="scope">
            <el-tag size="mini" :type="statusType(scope.row.auditStatus)">
              {{ statusText(scope.row.auditStatus) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="提交时间" width="160"></el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template slot-scope="scope">
            <el-button type="text" size="small" @click="showDetail(scope.row)">查看</el-button>
            <el-button
              v-if="scope.row.auditStatus === 0"
              type="text"
              size="small"
              @click="openAudit(scope.row, true)"
              >通过</el-button
            >
            <el-button
              v-if="scope.row.auditStatus === 0"
              type="text"
              size="small"
              class="red"
              @click="openAudit(scope.row, false)"
              >驳回</el-button
            >
          </template>
        </el-table-column>
      </el-table>
      <div class="block-pagination">
        <el-pagination
          background
          :page-size="20"
          layout="total, prev, pager, next"
          :total="list.length"
        ></el-pagination>
      </div>
    </el-card>

    <!-- 处方详情：图片是审核的核心依据，必须能放大看 -->
    <el-dialog :visible.sync="detailVisible" title="处方详情" width="720px">
      <div v-if="current">
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="处方号">{{ current.rxNo }}</el-descriptions-item>
          <el-descriptions-item label="患者">{{ current.patientName }}</el-descriptions-item>
          <el-descriptions-item label="身份证">{{ current.patientIdcard || '-' }}</el-descriptions-item>
          <el-descriptions-item label="诊断">{{ current.diagnosis || '-' }}</el-descriptions-item>
          <el-descriptions-item label="开方医师">{{ current.doctorName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="医师所属医院">{{ current.doctorHospital || '-' }}</el-descriptions-item>
          <el-descriptions-item label="处方有效期">{{ current.validStart }} ~ {{ current.validEnd || '-' }}</el-descriptions-item>
          <el-descriptions-item label="审核状态">
            <el-tag size="mini" :type="statusType(current.auditStatus)">{{ statusText(current.auditStatus) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="审核意见" :span="2">{{ current.auditRemark || '-' }}</el-descriptions-item>
        </el-descriptions>
        <div class="img-wrap">
          <div v-for="(img, i) in imageList" :key="i" class="img-box">
            <el-image :src="img" :preview-src-list="imageList" fit="contain" style="width: 100%; height: 100%">
              <div slot="error" class="img-err">图片无法加载</div>
            </el-image>
          </div>
          <div v-if="imageList.length === 0" class="img-err">该处方没有图片</div>
        </div>
      </div>
    </el-dialog>

    <!-- 审核弹窗 -->
    <el-dialog :visible.sync="auditVisible" :title="auditPass ? '审核通过' : '驳回处方'" width="480px">
      <el-alert
        v-if="auditPass"
        type="success"
        :closable="false"
        show-icon
        title="通过后该用户可凭此处方购买处方药"
        style="margin-bottom: 16px"
      ></el-alert>
      <el-input
        v-model="auditRemark"
        type="textarea"
        :rows="4"
        :placeholder="auditPass ? '审核意见（选填）' : '驳回原因（必填）'"
      ></el-input>
      <span slot="footer">
        <el-button size="small" @click="auditVisible = false">取消</el-button>
        <el-button size="small" type="primary" :loading="submitting" @click="doAudit">确定</el-button>
      </span>
    </el-dialog>
  </div>
</template>

<script>
import { prescriptionList, prescriptionAudit } from '@/api/prescription';

export default {
  name: 'PrescriptionAudit',
  data() {
    return {
      loading: false,
      list: [],
      tableFrom: { auditStatus: 0, limit: 50 },
      detailVisible: false,
      auditVisible: false,
      auditPass: true,
      auditRemark: '',
      submitting: false,
      current: null,
    };
  },
  computed: {
    imageList() {
      if (!this.current || !this.current.images) return [];
      try {
        const arr = JSON.parse(this.current.images);
        return Array.isArray(arr) ? arr : [];
      } catch (e) {
        // 后端存的是 JSON 字符串，解析失败时按单张图处理，不要让页面白屏
        return this.current.images ? [this.current.images] : [];
      }
    },
  },
  mounted() {
    this.getList();
  },
  methods: {
    getList() {
      this.loading = true;
      prescriptionList(this.tableFrom)
        .then((res) => {
          this.list = res.data || [];
        })
        .catch(() => {
          this.list = [];
        })
        .finally(() => {
          this.loading = false;
        });
    },
    refresh() {
      this.getList();
    },
    showDetail(row) {
      this.current = row;
      this.detailVisible = true;
    },
    openAudit(row, pass) {
      this.current = row;
      this.auditPass = pass;
      this.auditRemark = '';
      this.auditVisible = true;
    },
    doAudit() {
      if (!this.auditPass && !this.auditRemark.trim()) {
        this.$message.warning('驳回必须填写原因');
        return;
      }
      this.submitting = true;
      prescriptionAudit({
        id: this.current.id,
        pass: this.auditPass,
        remark: this.auditRemark.trim(),
      })
        .then(() => {
          this.$message.success(this.auditPass ? '已通过' : '已驳回');
          this.auditVisible = false;
          this.getList();
        })
        .catch((err) => {
          this.$message.error(err.msg || '操作失败');
        })
        .finally(() => {
          this.submitting = false;
        });
    },
    sourceText(s) {
      return { 1: '用户上传', 2: '互联网医院', 3: '线下医院' }[s] || '未知';
    },
    statusText(s) {
      return { 0: '待审核', 1: '已通过', 2: '已驳回' }[s] || '未知';
    },
    statusType(s) {
      return { 0: 'warning', 1: 'success', 2: 'danger' }[s] || 'info';
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
  width: 160px;
}
.red {
  color: #f56c6c;
}
.block-pagination {
  padding: 16px;
  text-align: right;
}
.img-wrap {
  display: flex;
  flex-wrap: wrap;
  margin-top: 16px;
}
.img-box {
  width: 200px;
  height: 260px;
  margin: 0 12px 12px 0;
  border: 1px solid #ebeef5;
  border-radius: 4px;
  overflow: hidden;
}
.img-err {
  color: #909399;
  font-size: 13px;
  text-align: center;
  line-height: 260px;
}
</style>
