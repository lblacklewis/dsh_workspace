<template>
	<view class="mi-page">
		<!-- 顶部导航 -->
		<view class="mi-nav">
			<view class="mi-nav-back" @tap="goBack"><text class="mi-nav-back-ic"></text></view>
			<text class="mi-nav-title">医保电子凭证</text>
			<view class="mi-nav-right" @tap="showHelp"><text>说明</text></view>
		</view>

		<!-- 未登录 -->
		<view v-if="!isLogin" class="mi-login">
			<view class="mi-login-ic"><text>医</text></view>
			<text class="mi-login-t">请先登录后查看医保电子凭证</text>
			<text class="mi-login-s">凭证与参保人实名信息绑定，需登录后展示</text>
			<view class="mi-login-btn" @tap="toLogin"><text>去登录</text></view>
		</view>

		<block v-else>
			<!-- ===== 凭证卡面 ===== -->
			<view class="mi-card">
				<view class="mi-card-top">
					<view class="mi-card-brand">
						<view class="mi-card-logo"><text>医</text></view>
						<view class="mi-card-brand-tx">
							<text class="mi-card-brand-t">医保电子凭证</text>
							<text class="mi-card-brand-s">国家医保信息平台 · 全国通用</text>
						</view>
					</view>
					<view class="mi-card-badge" :class="'is-' + profile.insuranceStatusCode">
						<text>{{ profile.insuranceStatus }}</text>
					</view>
				</view>

				<view class="mi-card-info">
					<view class="mi-card-row">
						<text class="mi-card-k">参保人</text>
						<text class="mi-card-v">{{ profile.maskedName }}</text>
					</view>
					<view class="mi-card-row">
						<text class="mi-card-k">证件号</text>
						<text class="mi-card-v">{{ profile.maskedCardId }}</text>
					</view>
					<view class="mi-card-row">
						<text class="mi-card-k">参保地</text>
						<text class="mi-card-v">{{ profile.insuranceRegion }}</text>
					</view>
					<view class="mi-card-row">
						<text class="mi-card-k">参保险种</text>
						<text class="mi-card-v mi-card-v-sm">{{ profile.insuranceType }}</text>
					</view>
				</view>

				<view v-if="!profile.hasRealName" class="mi-card-tip">
					<text>当前账号未填写实名信息，展示内容为演示数据</text>
				</view>
			</view>

			<!-- ===== 动态二维码 ===== -->
			<view class="mi-code">
				<view class="mi-code-head">
					<text class="mi-code-title">医保码（动态）</text>
					<text class="mi-code-hint">扫码结算</text>
				</view>

				<view class="mi-code-box">
					<image v-if="qrSrc" class="mi-code-img" :src="qrSrc" mode="widthFix" @tap="refreshCode" />
					<view v-else class="mi-code-loading"><text>生成中…</text></view>

					<!-- 倒计时环 / 数字 -->
					<view class="mi-code-timer">
						<text class="mi-code-sec" :class="{ 'is-urgent': secondsLeft <= 10 }">{{ secondsLeft }}</text>
						<text class="mi-code-sec-u">秒</text>
					</view>
				</view>

				<!-- 进度条：把 60 秒的可视化出来，用户能感知到码在变 -->
				<view class="mi-code-bar">
					<view class="mi-code-bar-in" :style="{ width: barPercent + '%' }" :class="{ 'is-urgent': secondsLeft <= 10 }"></view>
				</view>

				<view class="mi-code-foot">
					<text class="mi-code-refresh" @tap="refreshCode">立即刷新</text>
					<text class="mi-code-tick">有效至 {{ expiresAtText }}</text>
				</view>

				<!-- 安全提示：官方明确「截图即失效」 -->
				<view class="mi-code-warn">
					<text class="mi-code-warn-ic">!</text>
					<text class="mi-code-warn-tx">动态码有效期 1 分钟，截图转发即失效；请勿将本码交给他人使用。</text>
				</view>
			</view>

			<!-- ===== 个人账户 ===== -->
			<view class="mi-panel">
				<view class="mi-panel-head">
					<text class="mi-panel-title">医保个人账户</text>
					<text class="mi-panel-sub">截至 {{ today }}</text>
				</view>

				<view class="mi-balance">
					<view class="mi-balance-main">
						<text class="mi-balance-label">账户余额</text>
						<view class="mi-balance-num">
							<text class="mi-balance-unit">¥</text>
							<text class="mi-balance-val">{{ fmtMoney(account.balance) }}</text>
						</view>
					</view>
					<view class="mi-balance-side">
						<view class="mi-balance-item">
							<text class="mi-balance-k">本年划入</text>
							<text class="mi-balance-v mi-in">+{{ fmtMoney(account.yearIncome) }}</text>
						</view>
						<view class="mi-balance-item">
							<text class="mi-balance-k">本年支出</text>
							<text class="mi-balance-v mi-out">-{{ fmtMoney(account.yearExpense) }}</text>
						</view>
					</view>
				</view>

				<view class="mi-grid">
					<view class="mi-grid-item">
						<text class="mi-grid-v">¥{{ fmtMoney(account.payBase, 0) }}</text>
						<text class="mi-grid-k">缴费基数({{ account.payBaseMonth }})</text>
					</view>
					<view class="mi-grid-item">
						<text class="mi-grid-v">¥{{ fmtMoney(account.personalPay, 0) }}</text>
						<text class="mi-grid-k">个人月缴</text>
					</view>
					<view class="mi-grid-item">
						<text class="mi-grid-v">{{ profile.insuredMonths }} 个月</text>
						<text class="mi-grid-k">累计参保</text>
					</view>
				</view>

				<view class="mi-rows">
					<view class="mi-row">
						<text class="mi-row-k">参保单位</text>
						<text class="mi-row-v">{{ profile.employer }}</text>
					</view>
					<view class="mi-row">
						<text class="mi-row-k">首次参保</text>
						<text class="mi-row-v">{{ profile.firstInsuredMonth }}</text>
					</view>
					<view class="mi-row">
						<text class="mi-row-k">最近缴费</text>
						<text class="mi-row-v">{{ account.lastPayMonth }}（单位 ¥{{ fmtMoney(account.companyPay, 0) }} / 个人 ¥{{ fmtMoney(account.personalPay, 0) }}）</text>
					</view>
					<view class="mi-row">
						<text class="mi-row-k">社保卡号</text>
						<text class="mi-row-v">{{ profile.socialSecurityNo }}</text>
					</view>
				</view>

				<view class="mi-stats">
					<view class="mi-stat">
						<text class="mi-stat-v">{{ account.visitCountYear }}</text>
						<text class="mi-stat-k">本年就诊(次)</text>
					</view>
					<view class="mi-stat">
						<text class="mi-stat-v">¥{{ fmtMoney(account.visitTotalYear) }}</text>
						<text class="mi-stat-k">本年医疗费</text>
					</view>
					<view class="mi-stat">
						<text class="mi-stat-v mi-in">¥{{ fmtMoney(account.fundPayYear) }}</text>
						<text class="mi-stat-k">统筹支付</text>
					</view>
					<view class="mi-stat">
						<text class="mi-stat-v mi-out">¥{{ fmtMoney(account.selfPayYear) }}</text>
						<text class="mi-stat-k">个人自付</text>
					</view>
				</view>
			</view>

			<!-- ===== 记录（tab 切换） ===== -->
			<view class="mi-panel">
				<view class="mi-tabs">
					<view
						v-for="(t, i) in tabs"
						:key="i"
						class="mi-tab"
						:class="{ 'is-on': activeTab === t.value }"
						@tap="activeTab = t.value"
					>
						<text>{{ t.label }}</text>
					</view>
				</view>

				<!-- 就医 / 购药 -->
				<block v-if="activeTab === 'visit'">
					<view class="mi-chips">
						<view
							v-for="(f, i) in visitFilters"
							:key="i"
							class="mi-chip"
							:class="{ 'is-on': visitFilter === f.value }"
							@tap="visitFilter = f.value"
						>
							<text>{{ f.label }} {{ f.count }}</text>
						</view>
					</view>

					<view v-if="visits.length" class="mi-list">
						<view v-for="(v, i) in visits" :key="i" class="mi-item" @tap="showVisit(v)">
							<view class="mi-item-l">
								<view class="mi-item-top">
									<text class="mi-item-tag" :class="'is-' + v.type">{{ v.typeDesc }}</text>
									<text class="mi-item-org">{{ v.org }}</text>
								</view>
								<text class="mi-item-sub">{{ v.date }} · {{ v.dept }}</text>
							</view>
							<view class="mi-item-r">
								<text class="mi-item-amt">¥{{ fmtMoney(v.amount) }}</text>
								<text class="mi-item-fund">统筹 ¥{{ fmtMoney(v.fundPay) }}</text>
							</view>
						</view>
					</view>
					<view v-else class="mi-empty"><text>该分类下暂无记录</text></view>
				</block>

				<!-- 消费明细 -->
				<block v-else>
					<view class="mi-sum">
						<view class="mi-sum-item">
							<text class="mi-sum-k">明细合计 · 划入</text>
							<text class="mi-sum-v mi-in">+¥{{ fmtMoney(logSummary.income) }}</text>
						</view>
						<view class="mi-sum-item">
							<text class="mi-sum-k">明细合计 · 支出</text>
							<text class="mi-sum-v mi-out">-¥{{ fmtMoney(logSummary.expense) }}</text>
						</view>
					</view>

					<view class="mi-list">
						<view v-for="(l, i) in accountLog" :key="i" class="mi-item">
							<view class="mi-item-l">
								<text class="mi-item-org">{{ l.title }}</text>
								<text class="mi-item-sub">{{ l.date }}</text>
							</view>
							<view class="mi-item-r">
								<text class="mi-item-amt" :class="l.direction === 'in' ? 'mi-in' : 'mi-out'">
									{{ l.direction === 'in' ? '+' : '-' }}¥{{ fmtMoney(l.amount) }}
								</text>
							</view>
						</view>
					</view>
				</block>
			</view>

			<!-- 免责声明 -->
			<view class="mi-disclaimer">
				<text class="mi-disclaimer-t">演示声明</text>
				<text class="mi-disclaimer-b">
					本页为 StorApp 演示环境，参保信息、账户余额、就医与消费记录均为**虚构示例数据**，动态二维码由本地生成、不通任何医保系统。
					真实医保电子凭证由国家医保信息平台签发，需完成实名实人认证，请以「国家医保服务平台」APP 或当地医保官方渠道为准。
				</text>
			</view>
		</block>

		<view class="mi-bottom-space"></view>
	</view>
</template>

<script>
import {
	CODE_TTL_SECONDS,
	getInsuranceProfile,
	getInsuranceAccount,
	getVisitRecords,
	getVisitFilters,
	getAccountLog,
	getAccountLogSummary,
	getDynamicCode,
} from '@/libs/mockInsurance.js';
import { saQrDataUrl } from '@/libs/saqr.js';
import { toLogin } from '@/libs/login.js';
import { mapGetters } from 'vuex';

export default {
	data() {
		return {
			ttl: CODE_TTL_SECONDS,
			// 给一份零值骨架：首帧渲染早于 onLoad 时模板里的 {{ account.balance }}
			// 这类绑定不会是 undefined，避免出现 "NaN" / 空白闪烁
			profile: {
				maskedName: '',
				maskedCardId: '',
				insuranceStatus: '',
				insuranceStatusCode: 'normal',
				insuranceRegion: '',
				insuranceType: '',
				employer: '',
				insuredMonths: 0,
				firstInsuredMonth: '',
				socialSecurityNo: '',
				hasRealName: false,
			},
			account: {
				balance: 0,
				yearIncome: 0,
				yearExpense: 0,
				payBase: 0,
				payBaseMonth: '',
				personalPay: 0,
				companyPay: 0,
				lastPayMonth: '',
				visitCountYear: 0,
				visitTotalYear: 0,
				fundPayYear: 0,
				selfPayYear: 0,
			},
			visits: [],
			visitFilters: [],
			accountLog: [],
			logSummary: { income: 0, expense: 0 },
			activeTab: 'visit',
			visitFilter: '',
			tabs: [
				{ label: '就医/购药记录', value: 'visit' },
				{ label: '消费明细', value: 'log' },
			],
			qrSrc: '',
			secondsLeft: CODE_TTL_SECONDS,
			expiresAt: 0,
			seq: 0,
			timer: null,
			codeUid: '',
		};
	},
	computed: {
		// 用全局 getter，别自己从 state 里翻字段（store 里有缓存兜底逻辑）
		...mapGetters(['isLogin', 'uid', 'userInfo']),
		barPercent() {
			return Math.max(0, Math.min(100, (this.secondsLeft / this.ttl) * 100));
		},
		/** 二维码失效时刻（本地时间 HH:mm:ss）。比「第 N 次展码」有意义得多。 */
		expiresAtText() {
			const d = new Date(this.expiresAt || Date.now());
			const p = (n) => (n < 10 ? '0' + n : '' + n);
			return p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds());
		},
		today() {
			const d = new Date();
			const p = (n) => (n < 10 ? '0' + n : '' + n);
			return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
		},
	},
	onLoad() {
		this.profile = getInsuranceProfile(this.userInfo || {});
		this.account = getInsuranceAccount();
		this.visitFilters = getVisitFilters();
		this.visits = getVisitRecords(this.visitFilter);
		this.accountLog = getAccountLog();
		this.logSummary = getAccountLogSummary();
	},
	onShow() {
		// 从后台切回来时可能已经过了一个窗口，重新对时
		if (this.isLogin) this.startCode();
	},
	onHide() {
		this.stopCode();
	},
	onUnload() {
		this.stopCode();
	},
	watch: {
		visitFilter() {
			this.visits = getVisitRecords(this.visitFilter);
		},
		isLogin(val) {
			if (val) {
				this.profile = getInsuranceProfile(this.userInfo || {});
				this.startCode();
			} else {
				this.stopCode();
			}
		},
	},
	methods: {
		fmtMoney(v, digits) {
			const d = digits === undefined ? 2 : digits;
			const n = Number(v || 0);
			return n.toLocaleString('zh-CN', { minimumFractionDigits: d, maximumFractionDigits: d });
		},

		/* ---------- 动态码 ---------- */
		startCode() {
			// ⚠️ 不能用 this.uid 存——uid 是 mapGetters 映射来的只读计算属性，
			//    赋值会报 "Computed property was assigned to but it has no setter"。
			this.codeUid = this.uid || 'guest';
			this.tick();
			this.stopCode();
			this.timer = setInterval(() => this.tick(), 1000);
		},
		stopCode() {
			if (this.timer) {
				clearInterval(this.timer);
				this.timer = null;
			}
		},
		/** 每秒对一次表；跨过 60 秒窗口就换码 */
		tick() {
			const now = Date.now();
			const c = getDynamicCode(this.codeUid, now);
			if (c.seq !== this.seq || !this.qrSrc) {
				this.seq = c.seq;
				this.buildQr(c.token);
			}
			this.secondsLeft = c.secondsLeft;
			this.expiresAt = c.expiresAt;
		},
		buildQr(token) {
			try {
				// 二维码尺寸给大一点，手机端缩下来更清晰；纠错用 M
				this.qrSrc = saQrDataUrl(token, { level: 'M', size: 480, margin: 3 });
			} catch (e) {
				this.qrSrc = '';
			}
		},
		refreshCode() {
			this.seq = -1; // 强制换码
			this.tick();
			uni.showToast({ title: '二维码已刷新', icon: 'none' });
		},

		/* ---------- 交互 ---------- */
		goBack() {
			const pages = getCurrentPages();
			if (pages.length > 1) uni.navigateBack();
			else uni.switchTab({ url: '/pages/user/index' });
		},
		toLogin() {
			toLogin();
		},
		showVisit(v) {
			uni.showModal({
				title: v.typeDesc + '结算详情',
				content:
					'机构：' + v.org +
					'\n科室：' + v.dept +
					'\n日期：' + v.date +
					'\n医疗费总额：¥' + this.fmtMoney(v.amount) +
					'\n统筹基金支付：¥' + this.fmtMoney(v.fundPay) +
					'\n个人自付：¥' + this.fmtMoney(v.selfPay) +
					'\n结算状态：' + v.status,
				showCancel: false,
			});
		},
		showHelp() {
			uni.showModal({
				title: '关于医保电子凭证',
				content:
					'医保电子凭证（医保码）是全国医保线上业务唯一身份凭证，由国家医保信息平台签发，全国通用、跨渠道通用。\n\n' +
					'动态二维码有效期 1 分钟，截图即失效，请勿转发他人。\n\n' +
					'本页为演示环境，数据均为虚构，不代表真实参保信息。',
				showCancel: false,
			});
		},
	},
};
</script>

<style lang="scss" scoped>
.mi-page {
	min-height: 100vh;
	background: #eef2f5;
	padding-bottom: 40rpx;
}

/* ---------- 导航 ---------- */
.mi-nav {
	position: sticky;
	top: 0;
	z-index: 20;
	display: flex;
	align-items: center;
	height: 88rpx;
	padding: 0 24rpx;
	background: linear-gradient(135deg, #0d9488 0%, #14b8a6 100%);
}
.mi-nav-back {
	width: 64rpx;
	height: 88rpx;
	display: flex;
	align-items: center;
}
.mi-nav-back-ic {
	width: 20rpx;
	height: 20rpx;
	border-left: 4rpx solid #fff;
	border-bottom: 4rpx solid #fff;
	transform: rotate(45deg);
}
.mi-nav-title {
	flex: 1;
	text-align: center;
	color: #fff;
	font-size: 32rpx;
	font-weight: 600;
}
.mi-nav-right {
	width: 64rpx;
	text-align: right;
	color: rgba(255, 255, 255, 0.85);
	font-size: 26rpx;
}

/* ---------- 未登录 ---------- */
.mi-login {
	display: flex;
	flex-direction: column;
	align-items: center;
	padding: 180rpx 60rpx 0;
}
.mi-login-ic {
	width: 140rpx;
	height: 140rpx;
	line-height: 140rpx;
	text-align: center;
	border-radius: 36rpx;
	background: linear-gradient(135deg, #0d9488 0%, #14b8a6 100%);
	color: #fff;
	font-size: 68rpx;
	font-weight: 600;
	margin-bottom: 34rpx;
}
.mi-login-t {
	font-size: 30rpx;
	color: #334155;
	font-weight: 600;
}
.mi-login-s {
	font-size: 25rpx;
	color: #94a3b8;
	margin-top: 12rpx;
	text-align: center;
	line-height: 36rpx;
}
.mi-login-btn {
	margin-top: 44rpx;
	padding: 24rpx 90rpx;
	border-radius: 44rpx;
	background: #0d9488;
	color: #fff;
	font-size: 30rpx;
	font-weight: 600;
}

/* ---------- 凭证卡面 ---------- */
.mi-card {
	margin: 24rpx;
	padding: 30rpx;
	border-radius: 24rpx;
	background: linear-gradient(135deg, #0d9488 0%, #14b8a6 55%, #2dd4bf 100%);
	box-shadow: 0 12rpx 36rpx rgba(13, 148, 136, 0.28);
}
.mi-card-top {
	display: flex;
	align-items: flex-start;
	justify-content: space-between;
}
.mi-card-brand {
	display: flex;
	align-items: center;
}
.mi-card-logo {
	width: 72rpx;
	height: 72rpx;
	line-height: 72rpx;
	text-align: center;
	border-radius: 18rpx;
	background: rgba(255, 255, 255, 0.22);
	color: #fff;
	font-size: 38rpx;
	font-weight: 600;
	margin-right: 18rpx;
	flex-shrink: 0;
}
.mi-card-brand-tx {
	display: flex;
	flex-direction: column;
}
.mi-card-brand-t {
	color: #fff;
	font-size: 32rpx;
	font-weight: 600;
}
.mi-card-brand-s {
	color: rgba(255, 255, 255, 0.8);
	font-size: 21rpx;
	margin-top: 6rpx;
}
.mi-card-badge {
	padding: 8rpx 18rpx;
	border-radius: 22rpx;
	font-size: 22rpx;
	background: rgba(255, 255, 255, 0.92);
	color: #0d9488;
	font-weight: 600;
	flex-shrink: 0;
}
.mi-card-badge.is-normal {
	background: #fff;
	color: #0d9488;
}
.mi-card-info {
	margin-top: 30rpx;
	padding-top: 24rpx;
	border-top: 1rpx solid rgba(255, 255, 255, 0.28);
}
.mi-card-row {
	display: flex;
	align-items: center;
	margin-bottom: 16rpx;
}
.mi-card-k {
	width: 150rpx;
	color: rgba(255, 255, 255, 0.75);
	font-size: 24rpx;
	flex-shrink: 0;
}
.mi-card-v {
	color: #fff;
	font-size: 28rpx;
	font-weight: 600;
	letter-spacing: 0.5rpx;
}
.mi-card-v-sm {
	font-size: 25rpx;
	font-weight: 400;
}
.mi-card-tip {
	margin-top: 8rpx;
	padding: 14rpx 18rpx;
	border-radius: 12rpx;
	background: rgba(255, 255, 255, 0.18);
	color: rgba(255, 255, 255, 0.95);
	font-size: 22rpx;
}

/* ---------- 动态码 ---------- */
.mi-code {
	margin: 0 24rpx 24rpx;
	padding: 30rpx;
	background: #fff;
	border-radius: 24rpx;
	box-shadow: 0 4rpx 20rpx rgba(15, 23, 42, 0.05);
}
.mi-code-head {
	display: flex;
	align-items: baseline;
	justify-content: space-between;
	margin-bottom: 22rpx;
}
.mi-code-title {
	font-size: 30rpx;
	font-weight: 600;
	color: #0f172a;
}
.mi-code-hint {
	font-size: 23rpx;
	color: #94a3b8;
}
.mi-code-box {
	position: relative;
	display: flex;
	justify-content: center;
}
.mi-code-img {
	width: 440rpx;
	height: 440rpx;
	border-radius: 12rpx;
	background: #fff;
}
.mi-code-loading {
	width: 440rpx;
	height: 440rpx;
	display: flex;
	align-items: center;
	justify-content: center;
	color: #94a3b8;
	font-size: 26rpx;
}
/* 倒计时圆环压在二维码右下角，不遮住码心 */
.mi-code-timer {
	position: absolute;
	right: 6rpx;
	bottom: 6rpx;
	width: 92rpx;
	height: 92rpx;
	border-radius: 50%;
	background: #fff;
	box-shadow: 0 4rpx 16rpx rgba(15, 23, 42, 0.18);
	display: flex;
	align-items: baseline;
	justify-content: center;
	border: 3rpx solid #0d9488;
}
.mi-code-sec {
	font-size: 38rpx;
	font-weight: 700;
	color: #0d9488;
	line-height: 92rpx;
}
.mi-code-sec.is-urgent {
	color: #e11d48;
}
.mi-code-sec-u {
	font-size: 20rpx;
	color: #94a3b8;
	margin-left: 2rpx;
}
.mi-code-bar {
	height: 8rpx;
	border-radius: 8rpx;
	background: #e2e8f0;
	margin-top: 24rpx;
	overflow: hidden;
}
.mi-code-bar-in {
	height: 8rpx;
	border-radius: 8rpx;
	background: #0d9488;
	transition: width 1s linear;
}
.mi-code-bar-in.is-urgent {
	background: #e11d48;
}
.mi-code-foot {
	display: flex;
	align-items: center;
	justify-content: space-between;
	margin-top: 18rpx;
}
.mi-code-refresh {
	font-size: 25rpx;
	color: #0d9488;
	font-weight: 600;
}
.mi-code-tick {
	font-size: 22rpx;
	color: #94a3b8;
}
.mi-code-warn {
	display: flex;
	align-items: flex-start;
	margin-top: 20rpx;
	padding: 18rpx;
	border-radius: 14rpx;
	background: #fff7ed;
}
.mi-code-warn-ic {
	width: 32rpx;
	height: 32rpx;
	line-height: 32rpx;
	text-align: center;
	border-radius: 50%;
	background: #f59e0b;
	color: #fff;
	font-size: 22rpx;
	font-weight: 700;
	margin-right: 12rpx;
	flex-shrink: 0;
}
.mi-code-warn-tx {
	flex: 1;
	font-size: 22rpx;
	line-height: 34rpx;
	color: #b45309;
}

/* ---------- 面板 ---------- */
.mi-panel {
	margin: 0 24rpx 24rpx;
	padding: 30rpx;
	background: #fff;
	border-radius: 24rpx;
	box-shadow: 0 4rpx 20rpx rgba(15, 23, 42, 0.05);
}
.mi-panel-head {
	display: flex;
	align-items: baseline;
	justify-content: space-between;
	margin-bottom: 22rpx;
}
.mi-panel-title {
	position: relative;
	padding-left: 20rpx;
	font-size: 30rpx;
	font-weight: 600;
	color: #0f172a;
}
.mi-panel-title::before {
	content: '';
	position: absolute;
	left: 0;
	top: 50%;
	transform: translateY(-50%);
	width: 8rpx;
	height: 30rpx;
	border-radius: 4rpx;
	background: #0d9488;
}
.mi-panel-sub {
	font-size: 22rpx;
	color: #94a3b8;
}

/* 余额 */
.mi-balance {
	display: flex;
	align-items: center;
	padding: 26rpx 28rpx;
	border-radius: 20rpx;
	background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
}
.mi-balance-main {
	flex: 1;
}
.mi-balance-label {
	font-size: 23rpx;
	color: #0f766e;
}
.mi-balance-num {
	display: flex;
	align-items: baseline;
	margin-top: 8rpx;
}
.mi-balance-unit {
	font-size: 28rpx;
	color: #0d9488;
	font-weight: 600;
	margin-right: 4rpx;
}
.mi-balance-val {
	font-size: 56rpx;
	font-weight: 700;
	color: #0d9488;
	line-height: 1;
}
.mi-balance-side {
	display: flex;
	flex-direction: column;
	align-items: flex-end;
}
.mi-balance-item {
	display: flex;
	flex-direction: column;
	align-items: flex-end;
	margin-bottom: 10rpx;
}
.mi-balance-k {
	font-size: 21rpx;
	color: #64748b;
}
.mi-balance-v {
	font-size: 26rpx;
	font-weight: 600;
	margin-top: 2rpx;
}
.mi-in {
	color: #0d9488;
}
.mi-out {
	color: #e11d48;
}

/* 三宫格 */
.mi-grid {
	display: flex;
	margin-top: 24rpx;
}
.mi-grid-item {
	flex: 1;
	display: flex;
	flex-direction: column;
	align-items: center;
}
.mi-grid-v {
	font-size: 28rpx;
	font-weight: 600;
	color: #0f172a;
}
.mi-grid-k {
	font-size: 21rpx;
	color: #94a3b8;
	margin-top: 8rpx;
}

/* 明细行 */
.mi-rows {
	margin-top: 24rpx;
	padding-top: 20rpx;
	border-top: 1rpx solid #f1f5f9;
}
.mi-row {
	display: flex;
	margin-bottom: 16rpx;
}
.mi-row-k {
	width: 150rpx;
	font-size: 24rpx;
	color: #94a3b8;
	flex-shrink: 0;
}
.mi-row-v {
	flex: 1;
	font-size: 24rpx;
	color: #334155;
}

/* 四宫格统计 */
.mi-stats {
	display: flex;
	margin-top: 8rpx;
	padding-top: 22rpx;
	border-top: 1rpx solid #f1f5f9;
}
.mi-stat {
	flex: 1;
	display: flex;
	flex-direction: column;
	align-items: center;
}
.mi-stat-v {
	font-size: 26rpx;
	font-weight: 600;
	color: #0f172a;
}
.mi-stat-k {
	font-size: 20rpx;
	color: #94a3b8;
	margin-top: 8rpx;
}

/* ---------- tabs ---------- */
.mi-tabs {
	display: flex;
	background: #f1f5f9;
	border-radius: 16rpx;
	padding: 6rpx;
	margin-bottom: 22rpx;
}
.mi-tab {
	flex: 1;
	text-align: center;
	padding: 18rpx 0;
	font-size: 26rpx;
	color: #64748b;
	border-radius: 12rpx;
}
.mi-tab.is-on {
	background: #fff;
	color: #0d9488;
	font-weight: 600;
	box-shadow: 0 2rpx 8rpx rgba(15, 23, 42, 0.06);
}

/* chips */
.mi-chips {
	display: flex;
	flex-wrap: wrap;
	margin-bottom: 8rpx;
}
.mi-chip {
	padding: 10rpx 22rpx;
	margin: 0 12rpx 12rpx 0;
	border-radius: 26rpx;
	background: #f8fafc;
	color: #64748b;
	font-size: 23rpx;
}
.mi-chip.is-on {
	background: rgba(13, 148, 136, 0.1);
	color: #0d9488;
	font-weight: 600;
}

/* 记录项 */
.mi-list {
	margin-top: 6rpx;
}
.mi-item {
	display: flex;
	align-items: center;
	padding: 22rpx 0;
	border-bottom: 1rpx solid #f1f5f9;
}
.mi-item:last-child {
	border-bottom: none;
}
.mi-item-l {
	flex: 1;
	min-width: 0;
}
.mi-item-top {
	display: flex;
	align-items: center;
}
.mi-item-tag {
	font-size: 20rpx;
	padding: 4rpx 12rpx;
	border-radius: 8rpx;
	margin-right: 12rpx;
	flex-shrink: 0;
}
.mi-item-tag.is-outpatient {
	background: rgba(13, 148, 136, 0.1);
	color: #0d9488;
}
.mi-item-tag.is-pharmacy {
	background: rgba(59, 130, 246, 0.1);
	color: #3b82f6;
}
.mi-item-tag.is-inpatient {
	background: rgba(225, 29, 72, 0.1);
	color: #e11d48;
}
.mi-item-org {
	font-size: 27rpx;
	color: #0f172a;
	font-weight: 500;
	overflow: hidden;
	text-overflow: ellipsis;
	white-space: nowrap;
}
.mi-item-sub {
	display: block;
	font-size: 22rpx;
	color: #94a3b8;
	margin-top: 8rpx;
}
.mi-item-r {
	display: flex;
	flex-direction: column;
	align-items: flex-end;
	margin-left: 16rpx;
	flex-shrink: 0;
}
.mi-item-amt {
	font-size: 28rpx;
	font-weight: 600;
	color: #0f172a;
}
.mi-item-fund {
	font-size: 21rpx;
	color: #94a3b8;
	margin-top: 6rpx;
}

/* 合计 */
.mi-sum {
	display: flex;
	padding: 22rpx 24rpx;
	border-radius: 16rpx;
	background: #f8fafc;
	margin-bottom: 10rpx;
}
.mi-sum-item {
	flex: 1;
	display: flex;
	flex-direction: column;
}
.mi-sum-k {
	font-size: 21rpx;
	color: #94a3b8;
}
.mi-sum-v {
	font-size: 28rpx;
	font-weight: 700;
	margin-top: 6rpx;
}

.mi-empty {
	padding: 80rpx 0;
	text-align: center;
	color: #94a3b8;
	font-size: 26rpx;
}

/* ---------- 免责声明 ---------- */
.mi-disclaimer {
	margin: 0 24rpx;
	padding: 24rpx 26rpx;
	border-radius: 20rpx;
	background: #fff7ed;
	border: 1rpx solid #fed7aa;
}
.mi-disclaimer-t {
	display: block;
	font-size: 24rpx;
	font-weight: 600;
	color: #b45309;
	margin-bottom: 10rpx;
}
.mi-disclaimer-b {
	display: block;
	font-size: 22rpx;
	line-height: 36rpx;
	color: #92400e;
}

.mi-bottom-space {
	height: 40rpx;
}
</style>
