# 贡献指南

提交问题时请提供macOS版本、架构、应用版本、数据源、品种及最小复现步骤。截图和日志请去掉账号、个人信息及私密凭据。

改动前阅读 doc/architecture.md。使用 bash scripts/test.sh 运行独立的 Swift Testing 测试，使用 bash scripts/build.sh 构建，再执行应用 --self-test 作应用包冒烟检查。新增单元与集成测试使用 Swift Testing，按功能放入 Tests/Configuration、Tests/Quotes、Tests/Broker、Tests/Monitor。解析器测试在代码中人工构造最小 HTML/JSON 响应，不保存或重新内嵌抓取的真实样本；模型计算和状态测试直接构造 Swift 类型。异步测试应等待实际状态或任务完成并设置超时，避免固定延时猜测完成时间。界面改动请实际检查布局、按钮禁用状态及保存/取消行为，自检不替代UI验证；UI 自动化使用 XCTest。

--live-check 仅手动运行，避免在普通PR中自动访问第三方数据源。不要提交抓取的网页、真实账户资料、生成的.app、虚拟环境、签名证书或本机配置。构建CI采用只读权限；CodeQL分析任务仅额外获得上传安全扫描结果的权限，不自动发布版本。

`.gitignore` 不纳入本仓库提交或公开源码包。克隆仓库后，在本地 `.git/info/exclude` 或自行创建的本地 `.gitignore` 中排除构建目录、发布包和私密文件，并排除 `.gitignore` 本身；提交前复核暂存文件，避免提交 `.build/`、`dist/`、`*.app/`、`*.zip`、`.env*`、证书、用户配置和运行日志。

贡献者应有权提交相应代码，并同意其按本项目MIT许可证分发；第三方代码需附上来源和许可声明。提交说明写清行为变化、验证和已知限制。

## 版本发布

当前版本为 1.0，MIT 版权署名为 zhawlll。版本号在 `Resources/Info.plist` 中维护：`CFBundleShortVersionString` 为产品版本，`CFBundleVersion` 为构建号。

发布流程：

1. 更新应用版本、[版本说明](CHANGELOG.md)和[版本验证](APP_VERIFICATION.md)，记录当前功能及实际验证结果。
2. 运行 `bash scripts/test.sh`、`bash scripts/build.sh`，对构建后的应用运行 `--self-test`，校验签名及 Info.plist。检查真实窗口操作、键盘和无障碍；联网检查按需手动执行。
3. 运行 `python3 scripts/package-source.py`，复核源码包清单及 `SOURCE_MANIFEST.json` 中的 SHA-256。公开打包器使用文件白名单，包含 `AGENTS.md`，不包含本机配置、构建缓存、证书或抓取的原始响应。将源码包解压至独立目录，重新测试、构建和执行应用自检，确认包内文件完整。
4. 确认第三方目录标识和接口使用条件、仓库名称与所有者、许可证和版权署名，以及最终文件清单。
5. 应用包作为发布附件，不提交生成目录。对外分发前处理 Developer ID 签名与 Apple 公证，并明确下载包的签名状态。

远端仓库已配置私密漏洞报告、离线 CI 和 `main` 分支保护；漏洞报告入口在 [SECURITY.md](SECURITY.md) 中维护。通过 PR 提交修改，分支需保持最新，`build`、Python/Actions CodeQL 任务及安全结果检查必须通过并处理所有讨论；管理员同样受保护，禁止强推和删除，保持线性历史。单维护者阶段不要求第二人审批。构建工作流只读，CodeQL仅额外上传安全扫描结果，不自动发布。

默认 `dist/` 内的发布包在完成构建后可用以下命令生成；应用打包器检查签名、Info.plist 和实际架构，自动选择架构文件名，使用 UTF-8 中文路径并保留可执行权限。下方校验命令以 arm64 为例，其他架构需调整校验文件名并在对应平台验证。`SHA256SUMS` 必须在最终文档和源码包更新后重新生成。

```bash
python3 scripts/package-app.py
python3 scripts/package-source.py
(cd dist && shasum -a 256 "期货行情监控-macOS-arm64.zip" futures-monitor-source.zip > SHA256SUMS)
(cd dist && shasum -a 256 -c SHA256SUMS)
```
