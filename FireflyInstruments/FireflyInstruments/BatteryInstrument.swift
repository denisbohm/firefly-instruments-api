//
//  BatterySimulator.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public protocol BatteryInstrumentConvertDelegate {

    func batteryInstrumentConvertContinuousComplete(_ batteryInstrument: BatteryInstrument)

}

open class BatteryInstrument: InternalInstrument, PortalDelegate {

    public struct Conversion {
        public let current: Float32
    }

    public enum LocalError: Error {
        case invalidParameter
    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeConvertCurrent = UInt64(1)
    static let apiTypeSetVoltage = UInt64(2)
    static let apiTypeSetEnabled = UInt64(3)
    static let apiTypeConvertCurrentContinuous = UInt64(4)
    static let apiTypeConvertCurrentContinuousComplete = UInt64(5)

    unowned public private(set) var instrumentManager: InstrumentManager
    var portal: Portal
    public var convertDelegate: BatteryInstrumentConvertDelegate? = nil

    public init(instrumentManager: InstrumentManager, portal: Portal) {
        self.instrumentManager = instrumentManager
        self.portal = portal

        portal.addDelegate(type: BatteryInstrument.apiTypeConvertCurrentContinuousComplete, delegate: self)
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

    open func convertContinuous(rate: Float32, decimation: UInt64, samples: UInt64, address: UInt32) throws {
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(rate)
        binary.writeVarUInt(decimation)
        binary.writeVarUInt(samples)
        binary.write(address)
        portal.send(BatteryInstrument.apiTypeConvertCurrentContinuous, content: binary.data)
        let data = try portal.read(type: BatteryInstrument.apiTypeConvertCurrentContinuous)
        let response = Binary(data: data, byteOrder: .littleEndian)
        let result = try response.readVarUInt()
        if result != 0 {
            throw LocalError.invalidParameter
        }
    }

    func receivedConvertCurrentContinuous(data: Data) throws {
        let binary = Binary(data: data, byteOrder: .littleEndian)
        convertDelegate?.batteryInstrumentConvertContinuousComplete(self)
    }

    public func portalReceived(_ portal: Portal, type: UInt64, content: Data) throws {
        if type == BatteryInstrument.apiTypeConvertCurrentContinuous {
            try receivedConvertCurrentContinuous(data: content)
        }
    }
    
}
