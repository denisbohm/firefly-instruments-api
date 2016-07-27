//
//  ColorInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/15/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class ColorInstrument: InternalInstrument {

    public struct Conversion {
        public let clear: Float32
        public let red: Float32
        public let green: Float32
        public let blue: Float32
    }

    static let apiTypeConvert = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func convert() throws -> Conversion {
        portal.send(ColorInstrument.apiTypeConvert)
        let data = try portal.read(type: ColorInstrument.apiTypeConvert)
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let clear: Float32 = try binary.read()
        let red: Float32 = try binary.read()
        let green: Float32 = try binary.read()
        let blue: Float32 = try binary.read()
        return Conversion(clear: clear, red: red, green: green, blue: blue)
    }

}