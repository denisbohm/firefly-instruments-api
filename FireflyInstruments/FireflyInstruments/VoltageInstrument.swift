//
//  VoltageInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class VoltageInstrument: InternalInstrument {

    public struct Conversion {
        public let voltage: Float32
    }

    static let apiTypeConvertVoltage = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func convert() throws -> Conversion {
        portal.send(VoltageInstrument.apiTypeConvertVoltage)
        let data = try portal.read(type: VoltageInstrument.apiTypeConvertVoltage)
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let voltage: Float32 = try binary.read()
        return Conversion(voltage: voltage)
    }
    
}