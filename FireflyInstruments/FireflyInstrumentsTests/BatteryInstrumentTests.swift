//
//  BatteryInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class BatteryInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let batteryInstrument = BatteryInstrument(portal: portal)

        XCTAssertEqual(batteryInstrument.identifier, 1)

        try batteryInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        try batteryInstrument.setEnabled(true)
        portal.assertDidSend(3, content: 0x01)
        portal.assertDidWrite()

        let voltage = Float32(3.8)
        try batteryInstrument.setVoltage(voltage)
        let binaryVoltage = Binary(byteOrder: .LittleEndian)
        binaryVoltage.write(voltage)
        portal.assertDidSend(2, content: binaryVoltage.data)
        portal.assertDidWrite()

        let current = Float32(0.1)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(current)
        portal.queueRead(UInt64(1), content: binary.data)
        let conversion = try batteryInstrument.convert()
        portal.assertDidSend(1)
        XCTAssertEqualWithAccuracy(conversion.current, current, accuracy: 0.001)
    }
    
}
