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
        let portal = MockPortal()
        let currentInstrument = CurrentInstrument(portal: portal)

        let current = Float32(0.1)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(current)
        portal.queueRead(UInt64(1), content: binary.data)
        let conversion = try currentInstrument.convert()
        portal.assertDidSend(0x01)
        XCTAssertEqualWithAccuracy(conversion.current, current, accuracy: 0.001)
    }
    
}
