# 配置、参数与凭据

| 名称 | 使用者/范围 | 来源 | 更新方式/风险 |
| --- | --- | --- | --- |
| monitor.configuration.v1 | MonitorStore，本机用户 | 用户保存的UserDefaults JSON | 用户编辑；包含自选品种/指标/间隔/置顶，诊断导出不应公开 |
| monitor.instrument-column-width.v1 | MonitorStore，本机用户 | 品种列宽，默认266点 | 拖动结束保存；176–600点，窄窗仅暂时限制展示宽度；独立于行情配置，不重启轮询 |
| FuturesMonitor.Panel | AppKit，本机用户 | 窗口自动保存 | 本机位置尺寸，不公开 |
| 东方财富token | QuoteService，客户端 | 官方网页使用的公开固定协议参数 | 上游变更时人工更新；非私人账号密钥，无商业许可效力 |
| Referer/User-Agent | HTTPS客户端 | 源码协议参数 | 仅请求形状，不能替代访问授权 |
| FUTURES_ARCH | 构建脚本，本机/CI | 可选环境变量，默认uname -m | 仅arm64/x86_64；自检必须运行在对应架构 |
| FUTURES_OUTPUT_DIR | 构建脚本，本机/CI | 可选输出路径，默认dist/ | 写构建产物，勿指向需要保留的非构建目录 |
| 查询间隔 | MonitorStore | 用户配置5–86400秒 | 每次完成后等待；另受全局排队影响 |
| 资料刷新间隔 | BrokerReferenceService/MonitorStore | 源码常量 | 成功30分钟、失败60秒；缓存只在内存 |

目前已检查公开文件，没有账号密码、私人API密钥、签名证书或私钥嵌入客户端。公开网页token保留并明确记录来源；该检查不能为未来提交担保。无需.env或Secret配置。

公开前运行源码打包器并复核文件清单；本机档案、UserDefaults导出、原始响应与证书必须保持在排除范围。未来如添加签名CI，密钥通过受限Secrets传入，不提供给外部PR，不嵌入应用。
