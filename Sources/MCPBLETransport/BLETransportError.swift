import Foundation

public enum BLETransportError: Error, Sendable, Equatable {
    case bluetoothUnavailable
    case permissionDenied
    case scanTimeout
    case connectTimeout
    case peripheralNotFound
    case requiredServiceNotFound
    case requiredCharacteristicNotFound
    case disconnected
    case notConnected
    case writeFailed(String)
    case invalidPacket
    case packetSequenceMismatch
    case packetLengthMismatch
    case mtuTooSmall
}
