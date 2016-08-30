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

        try colorInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

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
        arguments.write(Float32(0.6144))
        arguments.write(Float32(1))
        let conversion = try colorInstrument.convert()
        portal.assertDidSend(0x01, content: arguments.data)
        portal.assertDidReadType(type: 0x01)
        XCTAssertEqualWithAccuracy(conversion.c, clear, accuracy: 0.001)
    }

    func testTransforms() {
        let conversion = ColorInstrument.Conversion(c: 0.1, r: 0.2, g: 0.3, b: 0.4)
        
        let x = conversion.x
        XCTAssertEqualWithAccuracy(x, 0.0536440015, accuracy: 0.001)
        let y = conversion.y
        XCTAssertEqualWithAccuracy(y, 0.115814984, accuracy: 0.001)
        let z = conversion.z
        XCTAssertEqualWithAccuracy(z, 0.320142984, accuracy: 0.001)

        let illuminance = conversion.illuminance
        XCTAssertEqualWithAccuracy(illuminance, y, accuracy: 0.001)

        let (h, s, v) = conversion.hsv
        XCTAssertEqualWithAccuracy(h, 210, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(s, 0.5, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(v, 0.4, accuracy: 0.001)

        let (hr, sr, vr) = ColorInstrument.Conversion(c: 0, r: 1.0, g: 0, b: 1.0).hsv
        XCTAssertEqualWithAccuracy(hr, 300, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(sr, 1, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(vr, 1, accuracy: 0.001)
        let (hg, sg, vg) = ColorInstrument.Conversion(c: 0, r: 0, g: 1.0, b: 0).hsv
        XCTAssertEqualWithAccuracy(hg, 120, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(sg, 1, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(vg, 1, accuracy: 0.001)
        let (h0, s0, v0) = ColorInstrument.Conversion(c: 0, r: 0, g: 0, b: 0).hsv
        XCTAssertEqualWithAccuracy(h0, 0, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(s0, 0, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(v0, 0, accuracy: 0.001)

        let cct = conversion.cct
        XCTAssertEqualWithAccuracy(cct, 140949, accuracy: 1.0)
        let cct0 = ColorInstrument.Conversion(c: 0, r: 0, g: 0, b: 0).cct
        XCTAssertEqualWithAccuracy(cct0, 0, accuracy: 0.001)
    }

}
