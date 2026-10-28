<template>
	<view class="up-page">
		<!-- 合规说明：实名是监管要求，不是产品选择，所以要讲清楚为什么 -->
		<view class="up-notice">
			<text class="up-notice-title">处方药需实名购买</text>
			<text class="up-notice-sub">依据《药品管理法》，处方药必须凭执业医师处方销售，购买人须实名。我们仅将信息用于处方审核与留存，不会用于其他用途。</text>
		</view>

		<view class="up-form">
			<view class="up-field">
				<text class="up-label">患者姓名<text class="up-req">*</text></text>
				<input class="up-input" v-model="form.patientName" placeholder="请填写与处方一致的姓名"
					placeholder-class="up-ph" maxlength="20" />
			</view>

			<view class="up-field">
				<text class="up-label">身份证号<text class="up-req">*</text></text>
				<input class="up-input" v-model="form.idcard" placeholder="请输入 18 位身份证号"
					placeholder-class="up-ph" maxlength="18" />
			</view>

			<view class="up-field up-field-col">
				<text class="up-label">处方照片<text class="up-req">*</text></text>
				<view class="up-imgs">
					<view v-for="(img, i) in form.images" :key="i" class="up-img-box">
						<image class="up-img" :src="img" mode="aspectFill" />
						<view class="up-img-del" @tap.stop="removeImg(i)">×</view>
					</view>
					<view v-if="form.images.length < 3" class="up-img-add" @tap="chooseImg">
						<text class="up-img-add-plus">+</text>
						<text class="up-img-add-txt">上传处方</text>
					</view>
				</view>
				<text class="up-hint">请确保姓名、医师签名、公章、日期清晰可见；最多 3 张</text>
			</view>

			<view class="up-field up-field-col">
				<text class="up-label">临床诊断</text>
				<textarea class="up-textarea" v-model="form.diagnosis" placeholder="选填，例如：上呼吸道感染"
					placeholder-class="up-ph" maxlength="120" />
			</view>
		</view>

		<view class="up-tips">
			<text class="up-tips-item">· 提交后由执业药师审核，通常 30 分钟内完成</text>
			<text class="up-tips-item">· 处方有效期为 3 天，请在有效期内下单</text>
			<text class="up-tips-item">· 处方及审核记录会按规定留存，不做删除</text>
		</view>

		<view class="up-footer">
			<view class="up-submit" :class="{ 'up-submit-disabled': submitting }" @tap="submit">
				<text>{{ submitting ? '提交中...' : '提交审核' }}</text>
			</view>
		</view>
	</view>
</template>

<script>
	import {
		uploadPrescription
	} from '@/api/prescription.js';

	export default {
		data() {
			return {
				form: {
					patientName: '',
					idcard: '',
					images: [],
					diagnosis: ''
				},
				submitting: false
			};
		},
		methods: {
			chooseImg() {
				const that = this;
				that.$util.uploadImageOne({
					url: 'upload/image',
					name: 'multipart',
					// model 只是服务端的存储目录名，不参与校验；用 prescription 便于运维区分
					model: 'prescription',
					pid: 1
				}, function(res) {
					that.form.images.push(res.data.url);
				}, function() {
					// 失败提示由 $util 内部统一弹，这里不用重复提示
				});
			},
			removeImg(i) {
				this.form.images.splice(i, 1);
			},
			/** 提交前本地校验：能在这里拦住就别浪费一次网络往返 */
			validate() {
				const f = this.form;
				if (!f.patientName.trim()) {
					return '请填写患者姓名';
				}
				if (!/^\d{17}[\dXx]$/.test(f.idcard.trim())) {
					return '请输入正确的 18 位身份证号';
				}
				if (f.images.length === 0) {
					return '请上传处方照片';
				}
				return '';
			},
			submit() {
				if (this.submitting) return;
				const err = this.validate();
				if (err) {
					uni.showToast({ title: err, icon: 'none' });
					return;
				}
				this.submitting = true;
				uploadPrescription({
					patientName: this.form.patientName.trim(),
					idcard: this.form.idcard.trim(),
					images: JSON.stringify(this.form.images),
					diagnosis: this.form.diagnosis.trim()
				}).then(() => {
					uni.showToast({ title: '提交成功，等待药师审核', icon: 'none' });
					setTimeout(() => {
						// 返回列表页，列表的 onShow 会自动刷新
						uni.navigateBack();
					}, 1200);
				}).catch((e) => {
					uni.showToast({
						title: (e && e.msg) || '提交失败，请重试',
						icon: 'none'
					});
				}).finally(() => {
					this.submitting = false;
				});
			}
		}
	};
</script>

<style lang="scss" scoped>
	.up-page {
		min-height: 100vh;
		background: #F5F7FA;
		padding-bottom: 180rpx;
	}

	.up-notice {
		display: flex;
		flex-direction: column;
		margin: 24rpx;
		padding: 26rpx 30rpx;
		background: rgba(13, 148, 136, 0.08);
		border-left: 8rpx solid #0D9488;
		border-radius: 12rpx;
	}

	.up-notice-title {
		font-size: 28rpx;
		color: #0D9488;
		font-weight: 600;
		margin-bottom: 10rpx;
	}

	.up-notice-sub {
		font-size: 24rpx;
		color: #64748B;
		line-height: 38rpx;
	}

	.up-form {
		margin: 0 24rpx;
		background: #fff;
		border-radius: 20rpx;
		padding: 8rpx 30rpx;
	}

	.up-field {
		display: flex;
		align-items: center;
		padding: 28rpx 0;
		border-bottom: 1rpx solid #F1F5F9;
	}

	.up-field:last-child {
		border-bottom: none;
	}

	.up-field-col {
		flex-direction: column;
		align-items: flex-start;
	}

	.up-label {
		width: 190rpx;
		font-size: 28rpx;
		color: #334155;
		flex-shrink: 0;
	}

	.up-field-col .up-label {
		width: auto;
		margin-bottom: 20rpx;
	}

	.up-req {
		color: #DC2626;
		margin-left: 6rpx;
	}

	.up-input {
		flex: 1;
		font-size: 28rpx;
		color: #0F172A;
	}

	.up-textarea {
		width: 100%;
		height: 140rpx;
		font-size: 28rpx;
		color: #0F172A;
	}

	.up-ph {
		color: #CBD5E1;
		font-size: 27rpx;
	}

	/* 图片上传 */
	.up-imgs {
		display: flex;
		flex-wrap: wrap;
	}

	.up-img-box {
		position: relative;
		width: 180rpx;
		height: 180rpx;
		margin: 0 20rpx 20rpx 0;
	}

	.up-img {
		width: 180rpx;
		height: 180rpx;
		border-radius: 12rpx;
		background: #F1F5F9;
	}

	.up-img-del {
		position: absolute;
		top: -14rpx;
		right: -14rpx;
		width: 40rpx;
		height: 40rpx;
		line-height: 36rpx;
		text-align: center;
		border-radius: 50%;
		background: rgba(15, 23, 42, 0.7);
		color: #fff;
		font-size: 30rpx;
	}

	.up-img-add {
		width: 180rpx;
		height: 180rpx;
		border: 2rpx dashed #CBD5E1;
		border-radius: 12rpx;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.up-img-add-plus {
		font-size: 52rpx;
		color: #94A3B8;
		line-height: 56rpx;
	}

	.up-img-add-txt {
		font-size: 22rpx;
		color: #94A3B8;
	}

	.up-hint {
		font-size: 23rpx;
		color: #94A3B8;
		margin-top: 6rpx;
		line-height: 34rpx;
	}

	/* 说明 */
	.up-tips {
		display: flex;
		flex-direction: column;
		margin: 28rpx 24rpx 0;
	}

	.up-tips-item {
		font-size: 24rpx;
		color: #94A3B8;
		line-height: 42rpx;
	}

	/* 底部 */
	.up-footer {
		position: fixed;
		left: 0;
		right: 0;
		bottom: 0;
		padding: 20rpx 24rpx calc(20rpx + env(safe-area-inset-bottom));
		background: #fff;
		box-shadow: 0 -4rpx 20rpx rgba(15, 23, 42, 0.06);
	}

	.up-submit {
		text-align: center;
		padding: 28rpx 0;
		border-radius: 44rpx;
		background: #0D9488;
		color: #fff;
		font-size: 30rpx;
		font-weight: 600;
	}

	.up-submit-disabled {
		background: #94A3B8;
	}
</style>
