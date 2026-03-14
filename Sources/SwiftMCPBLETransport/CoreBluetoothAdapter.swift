import Foundation
import Logging

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth

protocol BLEAdapter: AnyObject, Sendable {
    func connect(options: BLETransportOptions) async throws
    func disconnect() async
    func write(_ data: Data, withResponse: Bool) async throws
    func incomingMessages() -> AsyncThrowingStream<Data, Error>
    func currentMTU() -> Int
}

final class CoreBluetoothAdapter: NSObject, BLEAdapter, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private let logger: Logger
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var options: BLETransportOptions?
    private var incomingStream: AsyncThrowingStream<Data, Error>
    private var incomingContinuation: AsyncThrowingStream<Data, Error>.Continuation
    private var stateContinuation: CheckedContinuation<Void, Error>?
    private var scanContinuation: CheckedContinuation<CBPeripheral, Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var serviceContinuation: CheckedContinuation<Void, Error>?
    private var characteristicContinuation: CheckedContinuation<Void, Error>?
    private var notifyContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var disconnectContinuation: CheckedContinuation<Void, Never>?
    private var mtu: Int = 23

    init(logger: Logger) {
        self.logger = logger
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.incomingStream = AsyncThrowingStream<Data, Error> { continuation = $0 }
        self.incomingContinuation = continuation
        super.init()
        self.central = CBCentralManager(delegate: self, queue: .main)
    }

    func connect(options: BLETransportOptions) async throws {
        self.options = options
        try await waitUntilBluetoothReady()
        let peripheral = try await discoverPeripheral(options: options)
        self.peripheral = peripheral
        peripheral.delegate = self
        try await connectPeripheral(peripheral)
        let service = try await discoverService(peripheral: peripheral, serviceUUID: CBUUID(string: options.serviceUUID))
        let characteristics = try await discoverCharacteristics(
            peripheral: peripheral,
            service: service
        )

        guard let rx = characteristics.first(where: { $0.uuid == CBUUID(string: options.rxCharacteristicUUID) }),
              let tx = characteristics.first(where: { $0.uuid == CBUUID(string: options.txCharacteristicUUID) })
        else {
            throw BLETransportError.requiredCharacteristicNotFound
        }

        self.rxCharacteristic = rx
        self.txCharacteristic = tx

        try await enableNotify(peripheral: peripheral, characteristic: tx)
        let writeType: CBCharacteristicWriteType = options.writeWithResponse ? .withResponse : .withoutResponse
        let writeLen = peripheral.maximumWriteValueLength(for: writeType)
        if writeLen > 0 {
            self.mtu = writeLen + BLEFramingConstants.attOverhead
        } else {
            self.mtu = options.mtu
        }
    }

    func disconnect() async {
        guard let peripheral else { return }
        if peripheral.state == .disconnected {
            cleanupAfterDisconnect()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.disconnectContinuation = continuation
            self.central.cancelPeripheralConnection(peripheral)
        }
        cleanupAfterDisconnect()
    }

    func write(_ data: Data, withResponse: Bool) async throws {
        guard let peripheral, let characteristic = rxCharacteristic else {
            throw BLETransportError.notConnected
        }

        if !withResponse {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.writeContinuation = continuation
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    func incomingMessages() -> AsyncThrowingStream<Data, Error> {
        incomingStream
    }

    func currentMTU() -> Int {
        mtu
    }

    private func waitUntilBluetoothReady() async throws {
        if central.state == .poweredOn {
            return
        }
        if central.state == .unauthorized {
            throw BLETransportError.permissionDenied
        }
        if central.state == .unsupported || central.state == .poweredOff {
            throw BLETransportError.bluetoothUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.stateContinuation = continuation
        }
    }

    private func discoverPeripheral(options: BLETransportOptions) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBPeripheral, Error>) in
            self.scanContinuation = continuation
            self.central.scanForPeripherals(
                withServices: [CBUUID(string: options.serviceUUID)],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    private func connectPeripheral(_ peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation
            self.central.connect(peripheral, options: nil)
        }
    }

    private func discoverService(peripheral: CBPeripheral, serviceUUID: CBUUID) async throws -> CBService {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.serviceContinuation = continuation
            peripheral.discoverServices([serviceUUID])
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            throw BLETransportError.requiredServiceNotFound
        }
        return service
    }

    private func discoverCharacteristics(peripheral: CBPeripheral, service: CBService) async throws -> [CBCharacteristic] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.characteristicContinuation = continuation
            peripheral.discoverCharacteristics(nil, for: service)
        }
        return service.characteristics ?? []
    }

    private func enableNotify(peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.notifyContinuation = continuation
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    private func cleanupAfterDisconnect() {
        peripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if let continuation = self.stateContinuation {
            if central.state == .poweredOn {
                self.stateContinuation = nil
                continuation.resume()
            } else if central.state == .unauthorized {
                self.stateContinuation = nil
                continuation.resume(throwing: BLETransportError.permissionDenied)
            } else if central.state == .unsupported || central.state == .poweredOff {
                self.stateContinuation = nil
                continuation.resume(throwing: BLETransportError.bluetoothUnavailable)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let continuation = self.scanContinuation else { return }
        if let prefix = self.options?.namePrefix {
            let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            guard localName?.hasPrefix(prefix) == true else { return }
        }
        self.scanContinuation = nil
        central.stopScan()
        continuation.resume(returning: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let continuation = self.connectContinuation else { return }
        self.connectContinuation = nil
        continuation.resume()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let continuation = self.connectContinuation else { return }
        self.connectContinuation = nil
        continuation.resume(throwing: error ?? BLETransportError.connectTimeout)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let continuation = self.disconnectContinuation {
            self.disconnectContinuation = nil
            continuation.resume()
        }
        self.incomingContinuation.finish(throwing: BLETransportError.disconnected)
        self.cleanupAfterDisconnect()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let continuation = self.serviceContinuation else { return }
        self.serviceContinuation = nil
        if let error {
            continuation.resume(throwing: error)
            return
        }
        continuation.resume()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let continuation = self.characteristicContinuation else { return }
        self.characteristicContinuation = nil
        if let error {
            continuation.resume(throwing: error)
            return
        }
        continuation.resume()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let continuation = self.notifyContinuation else { return }
        self.notifyContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let continuation = self.writeContinuation else { return }
        self.writeContinuation = nil
        if let error {
            continuation.resume(throwing: BLETransportError.writeFailed(error.localizedDescription))
        } else {
            continuation.resume()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            self.incomingContinuation.finish(throwing: error)
            return
        }
        guard let data = characteristic.value else { return }
        self.incomingContinuation.yield(data)
    }
}

#else

protocol BLEAdapter: AnyObject {
    func connect(options: BLETransportOptions) async throws
    func disconnect() async
    func write(_ data: Data, withResponse: Bool) async throws
    func incomingMessages() -> AsyncThrowingStream<Data, Error>
    func currentMTU() -> Int
}

#endif
