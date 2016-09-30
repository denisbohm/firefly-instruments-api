//
//  CurrentInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class CurrentInstrumentTests: XCTestCase {

    func testSends() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let currentInstrument = CurrentInstrument(instrumentManager: instrumentManager, portal: portal)

        XCTAssertEqual(currentInstrument.identifier, 1)

        try currentInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        let current = Float32(0.1)
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(current)
        portal.queueRead(UInt64(1), content: binary.data)
        let conversion = try currentInstrument.convert()
        portal.assertDidSend(0x01)
        XCTAssertEqualWithAccuracy(conversion.current, current, accuracy: 0.001)
    }
    
}
