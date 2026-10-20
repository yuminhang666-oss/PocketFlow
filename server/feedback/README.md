# 私有反馈接收服务 · 已被邮箱方案替代的历史备选

2026-10-20用户明确改为发邮件到 yuminhang666@gmail.com，生产App按ADR0009打开手机邮件客户端。此目录仅保留之前已完成的本地工作，不由生产装配调用，不要求服务器/域名/云账号，不是0.3的部署门槛。以下说明记录原备选，未经新的明确授权不创建库/App或部署。

Node 24 标准库与持久 SQLite，无新增 npm 依赖。App 显式预览确认后 POST /v1/feedback → HTTPS 接收服务 → 仅获授权访问独立私有反馈库的 GitHub App → 私有 Issue。核心账本离线，不调用此服务。

目标库 yuminhang666-oss/PocketFlow-feedback 是建议名称，尚未创建或授权创建。必须在部署前确认实际所有者/私有库、托管服务/费用、GitHub App、HTTPS地址和部署范围。这里没有安装、配置账号、上传真实内容或部署。

## 本地验证与启动

`node --test server/feedback/server.test.mjs` 只用合成反馈与本地模拟 GitHub 端口，不联网、不创建真实 Issue。运行 Node 服务需本地安全配置 .env.example 的字段，进程环境注入，不把秘密放入 APK 或公共源码。使用 `node server/feedback/server.mjs`。HTTP 仅绑定 127.0.0.1，生产由受控 HTTPS 反向代理转发；只有确认代理隔离正确时才设 PF_TRUSTED_TLS_PROXY=1。不要把后端端口暴露公网。

## 最小权限与发布前配置

接口依据：[GitHub App安装身份](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation)、[创建Issue的接口与权限](https://docs.github.com/en/rest/issues/issues#create-an-issue)。本地模拟测试不能替代真实私有库权限联调。

GitHub App 安装范围只选独立私有反馈库，Repository permissions 为 Issues read/write 和 Metadata read。无 Contents、Actions、Administration、用户邮箱或业务仓库写权限。私钥使用只读 secret 文件；服务生成短时JWT并请求只限该反馈库的安装令牌。每次写入前核验目标仍为private，否则拒绝。目标应预建 type:bug/type:suggestion、status:open 和将启用版本的 version:* 标签。

App 构建时通过 POCKETFLOW_FEEDBACK_ENDPOINT 提供实际的 HTTPS /v1/feedback 地址。默认未配置，界面明确可保存草稿；没有真实私有 Issue 和回执前不称线上反馈已完成。Release联调前需在获授权私有库提交显著标记SYNTHETIC的测试内容。

## 幂等与故障

SQLite 的 feedback 主键和持久状态保存 feedbackId、规范正文摘要、操作状态、随机回执与 Issue 号。相同ID不同正文409；创建完成后才返回receipt。超时/进程中断状态先用正文标记对账，不盲目再次POST。无法确认时503并保持草稿，需维护者检查Issue和持久状态；不能为了重试直接删除幂等行。多实例必须使用同一可靠SQLite卷且受同一事务锁保护；本候选建议单实例，不把各副本独立磁盘当分布式幂等。

## 隐私、保留与删除

只接受白名单字段。无账目、预算、数据库、附件、日志、设备唯一ID或自动堆栈。服务代码不记录正文、联系方式、令牌；保留运行生命周期/错误码即可。IP只在内存取得并用服务端私有盐HMAC后用于小时限流，24小时后清理，不作为设备标识。

反馈正文/联系方式仅存于访问受限的服务SQLite和私有Issue，用于处理反馈。建议处理完成后90天删除正文和联系方式；可保留不含正文的幂等摘要与回执以防重复提交。删除需维护者在私有Issue和SQLite两处执行，记录脱敏操作结果；先核对状态与回执，勿自动删除未完成反馈。若用户请求删除，维护者根据回执核对并删除联系方式/正文，不要求其发送真实账单。备份同样加密、限制访问并执行保留周期。retentionCandidates只列出待审核ID，不自动删除远程数据。

## 成本与待授权

本地测试无需付费服务。生产需支持Node24、持久卷、HTTPS和备份的常驻托管；费用依最终服务商和配额确定，当前未选择付费方案，不承诺零成本。所需后续授权：精确私有库、GitHub App权限/安装目标、服务商与费用上限、域名/HTTPS和单实例持久卷部署范围。凭据由用户本地配置，不粘贴聊天。
