import Foundation

public struct BLETransportOptions: Sendable {
    public var serviceUUID: String
    public var rxCharacteristicUUID: String
    public var txCharacteristicUUID: String
    public var namePrefix: String?
    public var scanTimeout: Duration
    public var connectTimeout: Duration
    public var writeWithResponse: Bool
    public var mtu: Int

    public init(
        serviceUUID: String = "00001999-0000-1000-8000-00805F9B34FB",
        rxCharacteristicUUID: String = "4963505F-5258-4000-8000-00805F9B34FB",
        txCharacteristicUUID: String = "4963505F-5458-4000-8000-00805F9B34FB",
        namePrefix: String? = nil,
        scanTimeout: Duration = .seconds(10),
        connectTimeout: Duration = .seconds(10),
        writeWithResponse: Bool = true,
        mtu: Int = 23
    ) {
        self.serviceUUID = serviceUUID
        self.rxCharacteristicUUID = rxCharacteristicUUID
        self.txCharacteristicUUID = txCharacteristicUUID
        self.namePrefix = namePrefix
        self.scanTimeout = scanTimeout
        self.connectTimeout = connectTimeout
        self.writeWithResponse = writeWithResponse
        self.mtu = max(23, mtu)
    }
}
