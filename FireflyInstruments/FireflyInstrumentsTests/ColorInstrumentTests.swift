//
//  ColorInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class ColorInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let colorInstrument = ColorInstrument(portal: portal)

        let clear = Float32(0.1)
        let red = Float32(0.2)
        let green = Float32(0.3)
        let blue = Float32(0.4)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(clear)
        binary.write(red)
        binary.write(green)
        binary.write(blue)
        portal.queueRead(UInt64(1), content: binary.data)
        let arguments = Binary(byteOrder: .LittleEndian)
        arguments.write(Float32(0.0024))
        arguments.write(Float32(1))
        let conversion = try colorInstrument.convert()
        portal.assertDidSend(0x01, content: arguments.data)
        XCTAssertEqualWithAccuracy(conversion.c, clear, accuracy: 0.001)
    }

}
