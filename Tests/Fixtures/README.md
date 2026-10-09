# 目录编码测试

仅保留 catalog-sina.js：使用内置最小标识目录构造的GB18030编码文本，用于目录解码检查，不执行JavaScript。

HTML和JSON测试样本文件已删除。Tests/Broker、Tests/Quotes 的解析回归在 Swift 代码内人工构造最小响应，不重新内嵌已删除的真实样本。金额与状态测试使用 Tests/Support/Fixtures.swift 中的人工 Swift 模型。运行需要的品种目录仍在Resources/，不是行情或费率样本。
