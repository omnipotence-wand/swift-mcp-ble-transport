import Foundation

enum BLEFramingConstants {
    static let typeSingle: UInt8 = 0x00
    static let typeStart: UInt8 = 0x40
    static let typeCont: UInt8 = 0x80
    static let typeEnd: UInt8 = 0xC0
    static let headerTypeMask: UInt8 = 0xC0
    static let headerSeqMask: UInt8 = 0x3F
    static let maxGattValueLength = 512
    static let attOverhead = 3
    static let minPayload = 20
}
