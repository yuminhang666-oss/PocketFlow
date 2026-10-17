# ADR 0003：公开仓库与个人测试版下载

日期：2026-10-17。用户明确要求“改成公共可见”，目标为既有 yuminhang666-oss/PocketFlow 仓库及其已交付测试 APK。

主控已将仓库由 private 改为 public，更新测试发布页的登录说明。提交历史、源码、PR、工作流与测试发布附件随仓库公开；没有改变应用代码、主分支、APK内容或测试标签，也没有选择新的开源许可证。

公开前刷新远程分支，对14个可达提交、430条对象记录进行密钥格式及敏感文件路径检查；未发现所检查的令牌/私钥格式、数据库、环境凭据或签名私钥文件。该扫描是有限范围检查，不宣称覆盖所有可能的敏感信息。

公开后已通过连接器与GitHub API确认 visibility=public、private=false；以不含Authorization或登录Cookie的普通请求核验仓库页面、测试版页面和APK均HTTP200，APK响应大小为163,682,534字节。匿名API受共享出口限流，因此匿名可达性以网页与APK请求验证。

- 仓库：https://github.com/yuminhang666-oss/PocketFlow
- 测试版：https://github.com/yuminhang666-oss/PocketFlow/releases/tag/mvp-v0.1.0-debug
- APK：https://github.com/yuminhang666-oss/PocketFlow/releases/download/mvp-v0.1.0-debug/PocketFlow-debug.apk

测试标签仍指向d8a37aea1ed71f2704539c45aa937836ec499b7d，服务器附件SHA256与已核验安装包相同。Debug、未配置正式Release签名及尚未真机验收的限制继续有效。真实账单和签名私钥不随本次授权上传。