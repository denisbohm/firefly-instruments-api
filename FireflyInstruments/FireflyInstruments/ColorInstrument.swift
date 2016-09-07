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

        public let c: Float32
        public let r: Float32
        public let g: Float32
        public let b: Float32

        public init(c: Float32, r: Float32, g: Float32, b: Float32) {
            self.c = c
            self.r = r
            self.g = g
            self.b = b
        }

        public var x: Float32 { get { return (-0.14282) * r + (+1.54924) * g + (-0.95641) * b } }
        public var y: Float32 { get { return (-0.32466) * r + (+1.57837) * g + (-0.73191) * b } }
        public var z: Float32 { get { return (-0.68202) * r + (+0.77073) * g + (+0.56332) * b } }

        public var illuminance: Float32 { get { return y } }

        public var hsv: (h: Float, s: Float, v: Float) {
            get {
                let min = Swift.min(r, g, b)
                let max = Swift.max(r, g, b)
                let v = max
                let s: Float
                var h: Float
                if  max != 0 {
                    let delta = max - min
                    s = delta / max
                    if r == max {
                        h = (g - b) / delta // between yellow & magenta
                    } else
                    if g == max {
                        h = 2 + (b - r) / delta // between cyan & yellow
                    } else {
                        h = 4 + (r - g) / delta // between magenta & cyan
                    }
                    h *= 60 // degrees
                    if h < 0 {
                        h += 360
                    }
                } else {
                    // r = g = b = 0		// s = 0, v is undefined
                    s = 0
                    h = 0
                }
                return (h: h, s: s, v: v)
            }
        }

        public var cct: Float32 {
            get {
                let d = (x + y + z)
                if d == 0 {
                    return 0
                }
                let cx = x / d
                let cy = y / d
                let n = (cx - 0.3320) / (0.1858 - cy)
                return 449 * pow(n, 3) + 3525 * pow(n, 2) + 6823.3 * n + 5520.33
            }
        }

    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeConvert = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public var identifier: UInt64 { get { return portal.identifier } }

    public func reset() throws {
        portal.send(ColorInstrument.apiTypeReset)
        try portal.write()
    }

    public func convert(integrationTime integrationTime: Float32 = 0.6144, gain: Float32 = 1) throws -> Conversion {
        let arguments = Binary(byteOrder: .LittleEndian)
        arguments.write(integrationTime)
        arguments.write(gain)
        portal.send(ColorInstrument.apiTypeConvert, content: arguments.data)
        let data = try portal.read(type: ColorInstrument.apiTypeConvert)
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let c: Float32 = try binary.read()
        let r: Float32 = try binary.read()
        let g: Float32 = try binary.read()
        let b: Float32 = try binary.read()
        return Conversion(c: c, r: r, g: g, b: b)
    }

}