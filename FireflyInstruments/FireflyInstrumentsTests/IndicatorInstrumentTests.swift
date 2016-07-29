//
//  IndicatorInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class IndicatorInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let indicatorInstrument = IndicatorInstrument(portal: portal)

        let red = Float32(0.1)
        let green = Float32(0.2)
        let blue = Float32(0.3)
        try indicatorInstrument.set(red: red, green: green, blue: blue)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(red)
        binary.write(green)
        binary.write(blue)
        portal.assertDidSend(0x01, content: binary.data)
        portal.assertDidWrite()
    }
    
}
