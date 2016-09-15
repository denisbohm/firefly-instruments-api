//
//  VoltageInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class VoltageInstrument: InternalInstrument {

    public struct Conversion {
        public let voltage: Float32
    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeConvertVoltage = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    open var identifier: UInt64 { get { return portal.identifier } }

    open func reset() throws {
        portal.send(VoltageInstrument.apiTypeReset)
        try portal.write()
    }

    open func convert() throws -> Conversion {
        portal.send(VoltageInstrument.apiTypeConvertVoltage)
        let data = try portal.read(type: VoltageInstrument.apiTypeConvertVoltage)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let voltage: Float32 = try binary.read()
        return Conversion(voltage: voltage)
    }
    
}
