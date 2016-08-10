//
//  SerialWireInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class SerialWireInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(portal: portal)

        try serialWireInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        try serialWireInstrument.setEnabled(true)
        portal.assertDidSend(9, content: 0x01)
        portal.assertDidWrite()

        serialWireInstrument.setIndicator(true)
        portal.assertDidSend(0x01, content: 0b001, 0b001)
        serialWireInstrument.setIndicator(false)
        portal.assertDidSend(0x01, content: 0b001, 0b000)

        serialWireInstrument.setReset(true)
        portal.assertDidSend(0x01, content: 0b010, 0b010)
        serialWireInstrument.setReset(false)
        portal.assertDidSend(0x01, content: 0b010, 0b000)

        serialWireInstrument.turnToWrite()
        portal.assertDidSend(0x01, content: 0b100, 0b100)
        serialWireInstrument.turnToRead()
        portal.assertDidSend(0x01, content: 0b100, 0b000)

        serialWireInstrument.shiftOutBits(0b00000001, bitCount: 1)
        portal.assertDidSend(0x03, content: 0, 0b00000001)
        
        let bytes = [1, 2, 3] as [UInt8]
        serialWireInstrument.shiftOutData(NSData(bytes: bytes, length: bytes.count))
        portal.assertDidSend(0x04, content: 2, 1, 2, 3)

        serialWireInstrument.shiftInBits(2)
        portal.assertDidSend(0x05, content: 1)

        serialWireInstrument.shiftInData(2)
        portal.assertDidSend(0x06, content: 1)
    }

    func testWrite() throws {
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(portal: portal)
        try serialWireInstrument.write()
        portal.assertDidWrite()
    }

    func testRead() throws {
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(portal: portal)

        try serialWireInstrument.read()
        portal.assertDidRead()

        try serialWireInstrument.readWithByteCount(1)
        portal.assertDidReadWithLength(1)
    }

    func testDetect() throws {
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(portal: portal)

        var detect: ObjCBool = true
        try serialWireInstrument.getDetect(&detect)
        XCTAssertFalse(detect)
    }

}
