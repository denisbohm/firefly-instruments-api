//
//  BatterySimulator.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class BatteryInstrument: InternalInstrument {

    public struct Conversion {
        public let current: Float32
    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeConvertCurrent = UInt64(1)
    static let apiTypeSetVoltage = UInt64(2)
    static let apiTypeSetEnabled = UInt64(3)

    unowned public private(set) var instrumentManager: InstrumentManager
    var portal: Portal

    public init(instrumentManager: InstrumentManager, portal: Portal) {
        self.instrumentManager = instrumentManager
        self.portal = portal
    }

    open var identifier: UInt64 { get { return portal.identifier } }

    open func reset() throws {
        portal.send(BatteryInstrument.apiTypeReset)
        try portal.write()
    }

    open func setEnabled(_ value: Bool) throws {
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(UInt8(value ? 1 : 0))
        portal.send(BatteryInstrument.apiTypeSetEnabled, content: binary.data)
        try portal.write()
    }

    open func setVoltage(_ value: Float32) throws {
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(value)
        portal.send(BatteryInstrument.apiTypeSetVoltage, content: binary.data)
        try portal.write()
    }

    open func convert() throws -> Conversion {
        portal.send(BatteryInstrument.apiTypeConvertCurrent)
        let data = try portal.read(type: BatteryInstrument.apiTypeConvertCurrent)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let current: Float32 = try binary.read()
        return Conversion(current: current)
    }
    
}
