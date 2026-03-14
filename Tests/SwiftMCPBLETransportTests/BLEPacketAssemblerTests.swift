import Foundation
import Testing
@testable import SwiftMCPBLETransport

@Test
func assembler_roundTrip() throws {
    let framer = BLEPacketFramer()
    var assembler = BLEPacketAssembler()
    let message = Data("abcdefghijklmnopqrstuvwxyz".utf8)
    let packets = try framer.packetize(message: message, maxPayload: 12)

    var output: Data?
    for packet in packets {
        output = try assembler.feed(packet: packet) ?? output
    }

    #expect(output == message)
}

@Test
func assembler_sequenceMismatchThrows() throws {
    var assembler = BLEPacketAssembler()
    let start = Data([BLEFramingConstants.typeStart, 0, 0, 0, 10, 1, 2, 3])
    _ = try assembler.feed(packet: start)
    let badSeq = Data([BLEFramingConstants.typeCont | 0x03, 4, 5])
    do {
        _ = try assembler.feed(packet: badSeq)
        Issue.record("expected sequence mismatch")
    } catch {
        #expect(error as? BLETransportError == .packetSequenceMismatch)
    }
}

@Test
func assembler_lengthMismatchThrows() throws {
    var assembler = BLEPacketAssembler()
    let start = Data([BLEFramingConstants.typeStart, 0, 0, 0, 6, 1, 2, 3, 4])
    _ = try assembler.feed(packet: start)
    let end = Data([BLEFramingConstants.typeEnd | 0x01, 5])
    do {
        _ = try assembler.feed(packet: end)
        Issue.record("expected length mismatch")
    } catch {
        #expect(error as? BLETransportError == .packetLengthMismatch)
    }
}
