# 安全说明

项目没有服务器、用户登录、交易下单、账号凭据存储或自带遥测。网络请求直接到数据提供方，提供方仍可看到网络连接信息；不将其行为等同于项目不收集数据的声明。

公开Issue只适合不包含敏感信息的问题。私密凭据、证书或账户资料请勿提交到Issue、PR或日志。如果发现泄漏，应先撤销或轮换相应凭据，再处理文件与历史。

本仓库已启用GitHub私密漏洞报告。请通过[私密漏洞报告入口](https://github.com/zhawlll/futures-market-monitor/security/advisories/new)提交安全问题，不要在公开Issue中披露漏洞细节或敏感资料。

当前代码仅使用网页公开token，新增任何私人服务密钥时不得嵌入客户端。签名密钥若用于CI，只通过受限Secrets传入。

## 仓库保护

- `main` 要求通过 PR 更新，合并前必须通过 `build`、三项 `CodeQL (swift/python/actions)` 任务及 `CodeQL` 安全结果检查、保持分支最新并处理所有讨论；检查限定为对应 GitHub App 提供，规则同样适用于管理员。禁止强推和删除，要求线性历史。
- 当前为单维护者仓库，审批人数为 0；可在增加维护者后提高审批人数。
- 已开启 Dependabot 漏洞告警与安全更新、密钥扫描及推送保护。GitHub Actions 依赖每周检查版本更新。
- CodeQL 工作流扫描 Swift 应用、Python 脚本和 GitHub Actions；Swift 使用现有构建脚本编译完整应用，避免只扫描核心测试目标。PR、主分支更新和每周定时运行触发扫描。
- 普通构建工作流只读仓库；CodeQL 分析任务额外获得 `security-events: write`，仅用于上传扫描结果，不注入私密凭据或自动发布版本。

安全扫描结果见[仓库安全页面](https://github.com/zhawlll/futures-market-monitor/security)，工作流执行结果见[GitHub Actions](https://github.com/zhawlll/futures-market-monitor/actions)。安全扫描不替代代码评审、测试或第三方数据使用条件核对。
