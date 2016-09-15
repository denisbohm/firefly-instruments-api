//
//  DetourTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/15/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class DetourTests: XCTestCase {

    func testSingle() throws {
        let detour = Detour()
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0)
        binary.writeVarUInt(2)
        let content = Data(bytes: UnsafePointer<UInt8>([3, 4] as [UInt8]), count: 2)
        binary.write(content)
        try detour.event(binary.data)
        let result = detour.data
        XCTAssertEqual(result, content)
    }

    func testMultiple() throws {
        let detour = Detour()
        let binary1 = Binary(byteOrder: .littleEndian)
        binary1.writeVarUInt(0)
        binary1.writeVarUInt(2)
        try detour.event(binary1.data)
        let binary2 = Data(bytes: UnsafePointer<UInt8>([1, 3, 4, 0] as [UInt8]), count: 4)
        try detour.event(binary2)
        XCTAssert(detour.state == .success)
        let result = detour.data
        let content = Data(bytes: UnsafePointer<UInt8>([3, 4] as [UInt8]), count: 2)
        XCTAssertEqual(result, content)
    }

    func testOutOfSequence() throws {
        let detour = Detour()
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(1)
        binary.writeVarUInt(2)
        let content = Data(bytes: UnsafePointer<UInt8>([3, 4] as [UInt8]), count: 2)
        binary.write(content)
        XCTAssertThrowsError(try detour.event(binary.data))
    }

    func testUnexpectedStart() throws {
        let detour = Detour()
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0)
        binary.writeVarUInt(2)
        try detour.event(binary.data)
        XCTAssertThrowsError(try detour.event(binary.data))
    }

    func testClear() throws {
        let detour = Detour()
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0)
        binary.writeVarUInt(2)
        try detour.event(binary.data)
        detour.clear()
        try detour.event(binary.data)
    }

}
