# 第三方来源与许可边界

MIT许可证仅覆盖本项目有权许可的自有代码、人工样本和文档，不覆盖远端服务、行情、第三方网页或数据使用权。没有将网站可访问性视为商业使用或再分发授权。

| 内容 | 来源 | 项目中的使用 | 许可与处理 |
| --- | --- | --- | --- |
| SwiftUI、AppKit、Foundation | Apple SDK | 链接系统框架 | 不在源码包中复制Apple SDK；使用者遵守Apple SDK条款 |
| 新浪期货网页接口 | https://vip.stock.finance.sina.com.cn/ | 在线目录、主连快照与接口形状参考 | 服务条款与数据使用条件需向提供方确认；不附带下载的JS原件 |
| 东方财富期货网页接口 | https://qhweb.eastmoney.com/quote | 在线目录和主连快照 | 无商业授权证明或稳定性承诺；使用前核对提供方条件 |
| 公司合约单位、保证金、手续费 | https://portal.eastmoneyfutures.com/pages/service/jyts.html 和 https://portal.eastmoneyfutures.com/pages/service/sxf.html | 运行时在线查询、内存缓存 | 不附带抓取原页或HTML/JSON测试样本 |
| Resources/catalog*.json | 提供方目录的最小标识映射 | 名称、交易所、节点/代码与路由，供初次配置和目录失败时使用 | 仅保留功能必需字段，无报价、费率或网页；此标识目录不作第三方数据使用权授权声明，正式公开前仍需核对来源条件 |
| 应用图标 | scripts/make-icon.swift | 自绘几何图形 | 项目自有，MIT |

东方财富请求中的token是网页使用的公开协议参数，不是用户账号凭据，也不是商业API密钥或授权证明。其变更可能导致查询失败。

许可选择与数据来源说明不能保证通过商店审核或取得数据商业许可。
