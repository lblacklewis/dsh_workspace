<template>
	<view class="rx-page">
		<!-- 顶部说明：处方药需凭方购买，这句话要一直可见 -->
		<view class="rx-notice">
			<text class="rx-notice-icon">℞</text>
			<view class="rx-notice-text">
				<text class="rx-notice-title">处方药需凭处方购买</text>
				<text class="rx-notice-sub">上传处方后由执业药师审核，通过后即可下单</text>
			</view>
		</view>

		<!-- 状态筛选 -->
		<view class="rx-tabs">
			<view v-for="(t, i) in tabs" :key="i" class="rx-tab" :class="{ 'rx-tab-on': activeTab === t.value }"
				@tap="switchTab(t.value)">
				<text>{{ t.label }}</text>
			</view>
		</view>

		<!-- 列表 -->
		<view v-if="list.length > 0" class="rx-list">
			<view v-for="(item, i) in list" :key="i" class="rx-card" @tap="goDetail(item.id)">
				<view class="rx-card-head">
					<text class="rx-no">处方号 {{ item.rxNo }}</text>
					<text class="rx-status" :class="statusClass(item.auditStatus)">{{ item.auditStatusDesc }}</text>
				</view>
				<view class="rx-card-body">
					<view class="rx-row">
						<text class="rx-label">患者</text>
						<text class="rx-value">{{ item.patientName || '-' }}</text>
					</view>
					<view class="rx-row">
						<text class="rx-label">诊断</text>
						<text class="rx-value">{{ item.diagnosis || '-' }}</text>
					</view>
					<view class="rx-row">
						<text class="rx-label">提交时间</text>
						<text class="rx-value">{{ item.createTime || '-' }}</text>
					</view>
				</view>
				<view v-if="item.auditStatus === 1" class="rx-tip rx-tip-ok">
					<text>✓ 审核通过，可购买处方药</text>
				</view>
				<view v-else-if="item.auditStatus === 0" class="rx-tip rx-tip-wait">
					<text>⏱ 药师审核中，通常 30 分钟内完成</text>
				</view>
				<view v-else class="rx-tip rx-tip-fail">
					<text>✕ 审核未通过，请重新上传</text>
				</view>
			</view>
		</view>

		<!-- 空态 -->
		<view v-else-if="!loading" class="rx-empty">
			<view class="rx-empty-icon">℞</view>
			<text class="rx-empty-title">还没有处方</text>
			<text class="rx-empty-sub">上传线下处方，或在线问诊开方</text>
		</view>

		<view v-else class="rx-loading"><text>加载中...</text></view>

		<!-- 底部操作 -->
		<view class="rx-footer">
			<view class="rx-btn rx-btn-ghost" @tap="goConsult">
				<text>在线问诊开方</text>
			</view>
			<view class="rx-btn rx-btn-main" @tap="goUpload">
				<text>上传处方</text>
			</view>
		</view>
	</view>
</template>

<script>
	import {
		getPrescriptionList
	} from '@/api/prescription.js';

	export default {
		data() {
			return {
				tabs: [
					{ label: '全部', value: '' },
					{ label: '待审核', value: 0 },
					{ label: '已通过', value: 1 },
					{ label: '未通过', value: 2 }
				],
				activeTab: '',
				list: [],
				loading: true
			};
		},
		onShow() {
			// 用 onShow 而不是 onLoad：上传完返回本页要能刷新
			this.loadList();
		},
		methods: {
			loadList() {
				this.loading = true;
				getPrescriptionList(this.activeTab).then(res => {
					this.list = res.data || [];
				}).catch(() => {
					this.list = [];
				}).finally(() => {
					this.loading = false;
				});
			},
			switchTab(v) {
				this.activeTab = v;
				this.loadList();
			},
			statusClass(s) {
				if (s === 1) return 'rx-status-ok';
				if (s === 2) return 'rx-status-fail';
				return 'rx-status-wait';
			},
			goUpload() {
				uni.navigateTo({ url: '/pages/prescription/upload' });
			},
			goDetail(id) {
				// 详情暂用弹窗展示关键信息，避免再多一个页面
				const item = this.list.find(i => i.id === id);
				if (!item) return;
				uni.showModal({
					title: '处方详情',
					content: '处方号：' + item.rxNo + '\n患者：' + (item.patientName || '-') +
						'\n诊断：' + (item.diagnosis || '-') +
						'\n状态：' + item.auditStatusDesc,
					showCancel: false
				});
			},
			goConsult() {
				uni.showModal({
					title: '在线问诊',
					content: '在线问诊需要对接合作互联网医院，当前为演示环境尚未开通。\n您可以先使用「上传处方」。',
					showCancel: false
				});
			}
		}
	};
</script>

<style lang="scss" scoped>
	.rx-page {
		min-height: 100vh;
		background: #F5F7FA;
		padding-bottom: 180rpx;
	}

	/* 顶部提示条 */
	.rx-notice {
		display: flex;
		align-items: center;
		margin: 24rpx;
		padding: 28rpx 30rpx;
		background: linear-gradient(135deg, #0D9488 0%, #14B8A6 100%);
		border-radius: 20rpx;
	}

	.rx-notice-icon {
		width: 72rpx;
		height: 72rpx;
		line-height: 72rpx;
		text-align: center;
		background: rgba(255, 255, 255, 0.22);
		border-radius: 50%;
		color: #fff;
		font-size: 40rpx;
		margin-right: 22rpx;
		flex-shrink: 0;
	}

	.rx-notice-text {
		display: flex;
		flex-direction: column;
	}

	.rx-notice-title {
		color: #fff;
		font-size: 30rpx;
		font-weight: 600;
		margin-bottom: 6rpx;
	}

	.rx-notice-sub {
		color: rgba(255, 255, 255, 0.85);
		font-size: 24rpx;
	}

	/* 状态筛选 */
	.rx-tabs {
		display: flex;
		margin: 0 24rpx 20rpx;
		background: #fff;
		border-radius: 16rpx;
		padding: 8rpx;
	}

	.rx-tab {
		flex: 1;
		text-align: center;
		padding: 18rpx 0;
		font-size: 26rpx;
		color: #64748B;
		border-radius: 12rpx;
	}

	.rx-tab-on {
		background: #0D9488;
		color: #fff;
		font-weight: 600;
	}

	/* 处方卡片 */
	.rx-list {
		padding: 0 24rpx;
	}

	.rx-card {
		background: #fff;
		border-radius: 20rpx;
		padding: 28rpx 30rpx;
		margin-bottom: 20rpx;
	}

	.rx-card-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 22rpx;
		border-bottom: 1rpx solid #F1F5F9;
	}

	.rx-no {
		font-size: 26rpx;
		color: #334155;
		font-weight: 600;
	}

	.rx-status {
		font-size: 24rpx;
		padding: 6rpx 18rpx;
		border-radius: 24rpx;
	}

	.rx-status-ok {
		color: #0D9488;
		background: rgba(13, 148, 136, 0.1);
	}

	.rx-status-wait {
		color: #D97706;
		background: rgba(217, 119, 6, 0.1);
	}

	.rx-status-fail {
		color: #DC2626;
		background: rgba(220, 38, 38, 0.1);
	}

	.rx-card-body {
		padding: 20rpx 0 4rpx;
	}

	.rx-row {
		display: flex;
		margin-bottom: 14rpx;
	}

	.rx-label {
		width: 150rpx;
		font-size: 26rpx;
		color: #94A3B8;
		flex-shrink: 0;
	}

	.rx-value {
		flex: 1;
		font-size: 26rpx;
		color: #334155;
	}

	.rx-tip {
		margin-top: 16rpx;
		padding: 16rpx 20rpx;
		border-radius: 12rpx;
		font-size: 24rpx;
	}

	.rx-tip-ok {
		background: rgba(13, 148, 136, 0.08);
		color: #0D9488;
	}

	.rx-tip-wait {
		background: rgba(217, 119, 6, 0.08);
		color: #B45309;
	}

	.rx-tip-fail {
		background: rgba(220, 38, 38, 0.08);
		color: #B91C1C;
	}

	/* 空态 */
	.rx-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 140rpx 0;
	}

	.rx-empty-icon {
		width: 140rpx;
		height: 140rpx;
		line-height: 140rpx;
		text-align: center;
		border-radius: 50%;
		background: rgba(13, 148, 136, 0.08);
		color: #0D9488;
		font-size: 70rpx;
		margin-bottom: 28rpx;
	}

	.rx-empty-title {
		font-size: 30rpx;
		color: #334155;
		margin-bottom: 10rpx;
	}

	.rx-empty-sub {
		font-size: 25rpx;
		color: #94A3B8;
	}

	.rx-loading {
		text-align: center;
		padding: 120rpx 0;
		color: #94A3B8;
		font-size: 26rpx;
	}

	/* 底部按钮 */
	.rx-footer {
		position: fixed;
		left: 0;
		right: 0;
		bottom: 0;
		display: flex;
		padding: 20rpx 24rpx calc(20rpx + env(safe-area-inset-bottom));
		background: #fff;
		box-shadow: 0 -4rpx 20rpx rgba(15, 23, 42, 0.06);
	}

	.rx-btn {
		flex: 1;
		text-align: center;
		padding: 26rpx 0;
		border-radius: 44rpx;
		font-size: 30rpx;
	}

	.rx-btn-ghost {
		color: #0D9488;
		border: 2rpx solid #0D9488;
		margin-right: 20rpx;
	}

	.rx-btn-main {
		color: #fff;
		background: #0D9488;
		font-weight: 600;
	}
</style>
