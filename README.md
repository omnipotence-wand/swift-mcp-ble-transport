# SwiftMCPBLETransport

`SwiftMCPBLETransport` 是一个面向 iOS 的 BLE 传输库，用于把 `modelcontextprotocol/swift-sdk` 的 `Client` 连接到 BLE MCP 设备。

## 安装

在你的 `Package.swift` 中添加依赖：

```swift
.package(url: "https://github.com/omnipotence-wand/swift_mcp_ble_transport.git", from: "0.1.0")
```

并在目标中加入：

```swift
.product(name: "SwiftMCPBLETransport", package: "swift-mcp-ble-transport")
```

## 快速使用

```swift
import MCP
import SwiftMCPBLETransport

let client = Client(name: "BLEClient", version: "1.0.0")
let transport = BLEMCPTransport(
    options: BLETransportOptions(
        namePrefix: "MCP",
        scanTimeout: .seconds(10)
    )
)
let result = try await client.connect(transport: transport)
let (tools, _) = try await client.listTools()
print(result.capabilities)
print(tools.map(\.name))
```

## 默认 UUID

- Service: `00001999-0000-1000-8000-00805f9b34fb`
- RX: `4963505f-5258-4000-8000-00805f9b34fb`
- TX: `4963505f-5458-4000-8000-00805f9b34fb`

## 协议分片

- 单包：`TYPE_SINGLE`
- 多包首包：`TYPE_START + totalLength(4 bytes, big-endian)`
- 中间包：`TYPE_CONT`
- 结束包：`TYPE_END`
- 序号使用 6-bit 循环计数。

## iOS 权限

需要在应用 `Info.plist` 中添加：

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
