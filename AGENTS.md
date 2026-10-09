# 项目协作说明

本文件适用于本仓库内的开发、修复、评审与文档维护。默认使用中文沟通，代码中的类型、函数和文件名沿用现有英文命名。用户明确指令优先于本文件。

## 项目与环境

- 项目名：FuturesMonitor；应用名：期货行情监控。
- 原生 macOS 应用，最低 macOS 14，使用 SwiftUI、AppKit、Observation 和 Foundation。
- `Package.swift` 要求 Swift tools 6.0，当前 Swift 语言模式为 5；不要仅因使用 Swift 6 工具链而擅自切换语言模式。
- 构建需要 Xcode 或 Command Line Tools 及 macOS SDK；Python 3 仅用于辅助脚本，不是应用运行依赖。
- 应用直接访问东方财富和新浪公开 HTTPS 接口，无服务器、数据库、登录或交易功能。

## 开始工作

先阅读 `README.md`、`CONTRIBUTING.md` 和 `doc/architecture.md`。按任务补充阅读：

- 产品操作与显示口径：`APP_README.md`。
- 配置、参数与持久化：`doc/variables.md`。
- 测试范围与验收：`doc/tests.md`。
- 实际版本验证结果：`APP_VERIFICATION.md`。
- 第三方来源与许可边界：`THIRD_PARTY_NOTICES.md`、`SECURITY.md`。

先检查相关代码和现有改动，保留用户未完成的工作。只修改任务需要的文件，避免顺带重构、升级依赖或改版本号。

## 代码地图

| 路径 | 职责 |
| --- | --- |
| `Sources/FuturesMonitor/Application/` | 应用入口、菜单、状态栏、窗口及睡眠唤醒生命周期 |
| `Sources/FuturesMonitor/Configuration/` | 配置模型、草稿、品种与指标选择、查询间隔 |
| `Sources/FuturesMonitor/Quotes/` | 行情模型、目录和响应解析、HTTPS 服务、节流与 K 线链接 |
| `Sources/FuturesMonitor/Monitor/` | MonitorStore、独立轮询、行情表格及窗口展示 |
| `Sources/FuturesMonitor/Broker/` | 合约单位、保证金和手续费资料、部分缓存及参考金额 |
| `Sources/FuturesMonitor/Testing/` | 应用包冒烟检查、模拟服务和手动联网检查 |
| `Tests/` | Swift Testing 单元与集成测试，按 Configuration、Quotes、Broker、Monitor 分类 |
| `Resources/` | Info.plist 和内置品种标识目录 |
| `scripts/` | 测试、构建、工具链兼容、预览与公开源码打包 |
| `doc/` | 架构、配置、验证地图及演示图片 |

## 实现约束

- 每个顶层类型独立存放，沿用现有模块划分；新增 UI 文件时检查 `Package.swift` 的排除列表，核心测试目标不编译 UI、应用入口和应用包自检工具。
- `MonitorStore` 使用 `@MainActor` 和属性级 `@Observable`；保留按行更新，避免把单行行情变更扩大为整个对象的发布。
- 配置仅在保存草稿时提交，取消不写入。保持来源、非空品种和指标、来源一致性及 5–86400 秒间隔校验。
- 真实配置存于当前 macOS 用户的 UserDefaults。保持已有键和兼容迁移，测试使用独立域并清理，不修改用户真实配置。
- 每个品种独立轮询；查询完成后至少等待 5 秒，全局请求启动至少间隔 0.5 秒。不要把查询间隔解释为所有品种同步刷新周期。
- 保留任务取消与 generation 检查，旧请求晚返回不能写入新配置或暂停后的状态。
- 行情失败保留该行上次成功值，首次失败显示占位；拒绝较旧行情。切换来源不混用旧缓存。
- 公司资料按部分合并成功值，失败部分保留本次运行缓存；没有有效乘数或比例时不估算金额。
- 保留数据源差异：东方财富涨跌幅按昨收、涨跌额按昨结算；新浪两者按昨结算。主力连续不是可下单月份合约。
- K 线链接使用固定官网地址和已验证的连续代码；未知新浪节点不能推测月份合约链接。
- 保留固定品种首列、固定表头、共享纵向滚动及横向表头同步；列宽展示受窗口限制时，不覆盖已保存偏好。
- 数字显示沿用 FormatStyle 及现有分组、精度、正负号约定。
- 远端响应属于不可信输入，校验状态码、字段、代码和时间；不执行下载的 JavaScript。
- 工具链兼容通过 `scripts/toolchain-overlay.py` 的构建目录 VFS overlay 实现，不直接修改系统工具链。

## 构建与验证

从仓库根目录执行：

```bash
# 核心单元与集成测试（离线）
bash scripts/test.sh
# 聚焦相关测试；完整回归仍按改动范围执行
bash scripts/test.sh --filter MonitorStoreTests

# 构建完整应用，包括 UI、资源和本地签名
bash scripts/build.sh
# 应用包离线冒烟检查
"dist/期货行情监控.app/Contents/MacOS/FuturesMonitor" --self-test

# 应用包签名与元信息检查
codesign --verify --deep --strict "dist/期货行情监控.app"
plutil -lint "dist/期货行情监控.app/Contents/Info.plist"
```

- 业务代码改动运行相关测试及必要回归，并构建应用、执行 `--self-test`。仅文档改动检查内容、路径和命令，无需重复编译。
- `FuturesMonitorCore` 仅验证核心业务，应用使用 `scripts/build.sh` 构建；核心测试通过不能代表 UI 编译或交互通过。
- 新增单元与集成测试使用 Swift Testing；UI 自动化使用 XCTest。为行为变化和缺陷补充有意义的测试，避免只复制实现。
- 解析器测试人工构造最小 HTML/JSON 响应；模型和状态测试直接构造 Swift 类型。不要保存抓取的真实响应。
- 异步测试等待实际状态或任务完成并设置超时，避免固定延时猜测完成时间；取消场景可等待返回的任务句柄。
- UI 改动实际检查布局、按钮禁用、保存/取消及相关交互。`bash scripts/render-previews.sh` 生成演示图到 `doc/images/`，离屏渲染和自检不能代替交互验收。
- `--live-check` 会访问真实第三方接口，仅手动按需执行，不纳入普通 PR 自动测试或离线 CI。
- 默认构建本机架构；可用 `FUTURES_ARCH=arm64` 或 `FUTURES_ARCH=x86_64` 指定架构，`FUTURES_OUTPUT_DIR` 指定输出目录。目标架构运行情况需实测后再声明。

## 文档与交付

- 行为、参数或验证入口变化时同步相关文档；版本变化维护 `Resources/Info.plist`、`CHANGELOG.md` 和 `APP_VERIFICATION.md`。
- 验证记录区分本次实际执行、已有覆盖和未完成验收。不要将历史通过结果写成当前执行结果，也不要将本地验证写成远端 CI 通过。
- 交付说明写清行为变化、验证结果及尚未验证的范围；遇到环境阻碍记录实际错误和影响。
- 公开源码打包使用 `python3 scripts/package-source.py` 的白名单，包含本文件；修改公开导出范围前复核文件清单。
- 不提交 `.build/`、`dist/`、生成的 `.app`、本机配置、虚拟环境、抓取网页、账户资料、证书或私密凭据。
- `.gitignore` 仅保留在本地，不提交或纳入公开源码包；本仓库通过 `.git/info/exclude` 维护本地排除规则，提交前复核 `git status` 和暂存清单。
- 当前构建使用 ad-hoc 签名；不能声称已完成 Developer ID 签名、Apple 公证或 App Sandbox。对外发行按 `CONTRIBUTING.md` 的发布流程处理。
- 自有代码采用 MIT；公开接口及目录标识不等于获得第三方数据商业展示或再分发许可。保留来源说明，不擅自引入来源或许可不明的样本和代码。
