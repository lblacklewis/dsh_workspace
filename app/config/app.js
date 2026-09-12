// +----------------------------------------------------------------------
// | StorApp 品牌定制版 - 移动端配置
// +----------------------------------------------------------------------
//移动端商城API
// 服务器API（走80端口Nginx转发）
let domain = 'http://82.156.226.192/front-api'
// 本地API
// let domain = 'http://localhost:20610'
// let domain = 'https://apif.java.crmeb.net'
// 深度演示站
// let domain = 'https://apif.crmeb.xbdzz.cn'

module.exports = {
	// 请求域名 格式： https://您的域名
	// #ifdef MP || APP-PLUS
		// HTTP_REQUEST_URL:'',
		HTTP_REQUEST_URL: domain,
		// H5商城地址
		HTTP_H5_URL: 'http://localhost:20610',
	// #endif
	// #ifdef H5
		HTTP_REQUEST_URL:domain,
	// #endif
	HEADER:{
		'content-type': 'application/json',
		'X-Source' : 'df07addc462f7f8f'
	},
	HEADERPARAMS:{
		'content-type': 'application/x-www-form-urlencoded'
	},
	// 回话密钥名称 请勿修改此配置
	TOKENNAME: 'Authori-zation',
	// 缓存时间 0 永久
	EXPIRE:0,
	//分页最多显示条数
	LIMIT: 10
};
