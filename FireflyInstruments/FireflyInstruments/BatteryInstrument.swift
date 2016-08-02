//
//  BatterySimulator.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class BatteryInstrument: InternalInstrument {

    public struct Conversion {
        public let current: Float32
    }

    static let apiTypeConvertCurrent = UInt64(1)
    static let apiTypeSetVoltage = UInt64(2)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func setVoltage(value: Float32) throws {
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(value)
        portal.send(BatteryInstrument.apiTypeSetVoltage, content: binary.data)
        try portal.write()
    }

    public func convert() throws -> Conversion {
        portal.send(BatteryInstrument.apiTypeConvertCurrent)
        let data = try portal.read(type: BatteryInstrument.apiTypeConvertCurrent)
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let current: Float32 = try binary.read()
        return Conversion(current: current)
    }
    
}