import Foundation
import Testing
@testable import MCPBLETransport

@Test
func framer_singlePacket() throws {
    let framer = BLEPacketFramer()
    let message = Data("hello".utf8)
    let packets = try framer.packetize(message: message, maxPayload: 20)
    #expect(packets.count == 1)
    #expect(packets[0].first == BLEFramingConstants.typeSingle)
    #expect(Data(packets[0].dropFirst()) == message)
}

@Test
func framer_multiPacket() throws {
    let framer = BLEPacketFramer()
    let message = Data(repeating: 0x41, count: 128)
    let packets = try framer.packetize(message: message, maxPayload: 23)
    #expect(packets.count > 1)
    #expect((packets.first?.first ?? 0) & BLEFramingConstants.headerTypeMask == BLEFramingConstants.typeStart)
    #expect((packets.last?.first ?? 0) & BLEFramingConstants.headerTypeMask == BLEFramingConstants.typeEnd)
}

@Test
func framer_computeMaxPayload() {
    let framer = BLEPacketFramer()
    #expect(framer.computeMaxPayload(mtu: 23) == 20)
    #expect(framer.computeMaxPayload(mtu: 517) == 512)
}
