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
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let voltageInstrument = VoltageInstrument(instrumentManager: instrumentManager, portal: portal)

        XCTAssertEqual(voltageInstrument.identifier, 1)

        try voltageInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        let voltage = Float32(0.1)
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(voltage)
        portal.queueRead(UInt64(1), content: binary.data)
        let conversion = try voltageInstrument.convert()
        portal.assertDidSend(0x01)
        XCTAssertEqualWithAccuracy(conversion.voltage, voltage, accuracy: 0.001)
    }
    
}
