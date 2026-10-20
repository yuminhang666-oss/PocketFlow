# 邮件交接合成测试夹具

仅安装在本任务隔离的 emulator-5586。它是ACTION_SENDTO/mailto的显著SYNTHETIC接收器，**没有INTERNET权限，也没有邮件发送功能**。用来检查真实Release的原生桥实际传递固定收件人、受控主题、Unicode正文与无附件，而不是冒充邮件投递成功。

使用现有JDK/API36/build-tools和原测试证书在.local/qa/mail-sink构建，不安装新依赖。实际邮件投递仍须用户在自己的邮件客户端确认，不在本任务发送真实测试邮件。设备验证先在无邮件客户端时检查草稿/复制，再安装此夹具验证交接；证据明确标注模拟收件器。

夹具构建脚本从本机进程环境 POCKETFLOW_TEST_KEYSTORE_PASSWORD 读取已有测试签名密码；不在源码或命令参数明文存储密码，也不生成新密钥。此脚本不用于正式App构建。
