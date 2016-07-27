//
//  VoltageInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class VoltageInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let voltageInstrument = VoltageInstrument(portal: portal)

        let voltage = Float32(0.1)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(voltage)
        portal.queueRead(UInt64(1), content: binary.data)
        let conversion = try voltageInstrument.convert()
        portal.assertDidSend(0x01)
        XCTAssertEqualWithAccuracy(conversion.voltage, voltage, accuracy: 0.001)
    }
    
}
