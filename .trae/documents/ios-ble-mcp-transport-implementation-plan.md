# iOS Swift BLE MCP Transport 实施计划

## 1. 目标与交付物
- 目标：为 `modelcontextprotocol/swift-sdk` 客户端实现一个可直接接入的 BLE `Transport`，用于通过 BLE GATT 与 MCP 设备进行双向 JSON-RPC 通信。
- 交付物：
  - 一个可复用的 Swift Package 模块（建议命名 `MCPBLETransport`）。
  - 与 Swift SDK `Client.connect(transport:)` 兼容的传输实现。
  - 面向 iOS 的最小可运行示例（扫描、连接、调用 `listTools`）。
  - 单元测试与关键协议测试（分片、重组、乱序与超时）。
  - 使用文档（初始化参数、UUID 配置、限制与故障排查）。

## 2. 规范与兼容基线
- Swift 版本：Swift 6.0+。
- 平台：iOS 16+（CoreBluetooth 并发 API 更友好；若项目要求更低版本，后续再补兼容层）。
- MCP SDK 对齐：
  - 以官方 Swift SDK 当前 `Transport` 接口契约为准。
  - 保证 `send/receive/close` 生命周期语义与 SDK 一致。
- BLE 协议对齐（参考 TS 实现）：
  - 默认 Service UUID：`00001999-0000-1000-8000-00805f9b34fb`
  - 默认 RX Characteristic UUID：`4963505f-5258-4000-8000-00805f9b34fb`（客户端写入）
  - 默认 TX Characteristic UUID：`4963505f-5458-4000-8000-00805f9b34fb`（客户端订阅通知）
  - 支持参数覆盖上述 UUID、设备名前缀过滤、扫描超时。

## 3. 模块设计
- `BLETransportOptions`
  - `serviceUUID` / `rxCharUUID` / `txCharUUID`
  - `namePrefix`
  - `scanTimeout`
  - `writeType`（默认 `.withResponse`，可按设备能力切换）
- `BLEPacketFramer`
  - 负责 MCP JSON 消息 `Data` 到 BLE 包的分片编码。
  - 首包携带总长度，后续包按序号递增（遵循 TS 参考实现语义）。
  - 根据有效 MTU 动态决定单包载荷大小。
- `BLEPacketAssembler`
  - 负责通知流的包重组与完整消息输出。
  - 维护当前消息上下文（总长度、已接收字节数、下一序号）。
  - 处理异常：序号错误、长度越界、超时未完成，重置并上报错误。
- `BLEMCPTransport`
  - 对外实现 Swift SDK `Transport` 协议。
  - 内部管理扫描、连接、发现服务/特征、订阅通知、发送队列与关闭。
- `CoreBluetoothAdapter`
  - 将 `CBCentralManager/CBPeripheral` 事件桥接为 async/await 流。
  - 隔离苹果框架细节，便于单测替身注入。

## 4. 目录与文件规划
- `Sources/MCPBLETransport/BLEMCPTransport.swift`
- `Sources/MCPBLETransport/BLETransportOptions.swift`
- `Sources/MCPBLETransport/BLEPacketFramer.swift`
- `Sources/MCPBLETransport/BLEPacketAssembler.swift`
- `Sources/MCPBLETransport/CoreBluetoothAdapter.swift`
- `Sources/MCPBLETransport/BLETransportError.swift`
- `Tests/MCPBLETransportTests/BLEPacketFramerTests.swift`
- `Tests/MCPBLETransportTests/BLEPacketAssemblerTests.swift`
- `Tests/MCPBLETransportTests/BLEMCPTransportLifecycleTests.swift`
- `Examples/iOSClientExample/`（或仓库既有示例目录下新增 BLE 示例）

## 5. 实施步骤（按顺序执行）
1. 读取并确认当前仓库中 `Transport` 协议签名与现有传输实现（如 Stdio/HTTP）的一致模式（初始化、连接、收发、关闭、错误传播）。
2. 新建 `MCPBLETransport` 模块骨架与公开 API（`BLEMCPTransport`、`BLETransportOptions`），先打通编译。
3. 实现 `BLEPacketFramer`：
   - 输入完整消息 `Data`，输出首包+后续包序列。
   - 覆盖边界：空消息、刚好单包、超大消息、多包分片。
4. 实现 `BLEPacketAssembler`：
   - 按通知包流重组消息并输出完整 `Data`。
   - 增加乱序、丢包、超长、重复包与超时恢复逻辑。
5. 实现 `CoreBluetoothAdapter`：
   - 扫描过滤（serviceUUID + 可选 namePrefix）。
   - 连接后发现 service/characteristics。
   - 启用 TX notify，暴露 AsyncStream<Data>。
   - 提供 RX 写入 API（含背压与串行写保障）。
6. 实现 `BLEMCPTransport` 与 MCP `Transport` 对接：
   - `connect`：完成扫描→连接→发现→订阅。
   - `send`：消息分片并按顺序写入 RX。
   - `receive`：从组包器输出完整 JSON-RPC 消息。
   - `close`：取消订阅、断连、释放资源。
7. 增加错误模型 `BLETransportError` 并统一映射：
   - 蓝牙不可用、权限不足、扫描超时、服务/特征缺失、连接丢失、协议错误、写入失败。
8. 编写测试：
   - 分片/组包纯逻辑单测（高覆盖）。
   - 传输生命周期测试（通过 adapter mock）。
9. 增加最小示例与文档：
   - 展示如何构造 `Client` + `BLEMCPTransport` 并调用 `listTools`。
   - 记录 Info.plist 权限、后台限制、常见失败原因。
10. 运行测试与静态检查，修复问题后形成最终交付。

## 6. 验收标准
- 与 MCP Swift SDK 客户端集成后可成功 `connect` 并完成至少一次 `listTools` 请求/响应。
- BLE 消息可正确分片与重组，测试覆盖核心边界场景。
- 异常可被识别并上抛，调用方可判定错误类型。
- 关闭流程无资源泄漏（通知停止、连接断开、任务取消）。
- 文档可指导 iOS 开发者在真实设备上完成首次连接验证。

## 7. 风险与应对
- MTU 差异导致分片边界不一致：通过运行时协商/保守载荷策略并在日志中暴露实际载荷。
- 设备实现差异（写响应、通知时序）：提供可配置 `writeType` 与重试策略开关。
- iOS 蓝牙权限与前后台行为限制：在示例和文档中明确权限配置与运行前提。
- 连接稳定性波动：加入连接状态机与指数退避重连（默认关闭，可配置启用）。

## 8. 实施约束
- 不修改 MCP Swift SDK 核心协议定义，优先以独立 package 方式扩展。
- 不引入额外第三方 BLE 库，直接使用 CoreBluetooth，降低依赖风险。
- 所有公开 API 命名与并发模型遵循仓库既有风格。
