//
//  SerialWireInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

public class SerialWireInstrument: NSObject, FDSerialWire, InternalInstrument {

    static let apiTypeReset = UInt64(0)
    static let apiTypeSetOutputs = UInt64(1)
    static let apiTypeGetInputs = UInt64(2)
    static let apiTypeShiftOutBits = UInt64(3)
    static let apiTypeShiftOutData = UInt64(4)
    static let apiTypeShiftInBits = UInt64(5)
    static let apiTypeShiftInData = UInt64(6)
    static let apiTypeSetEnabled = UInt64(7)

    static let outputIndicator = 0
    static let outputReset = 1
    static let outputDirection = 2

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func reset() throws {
        portal.send(SerialWireInstrument.apiTypeReset)
        try portal.write()
    }

    public func setEnabled(value: Bool) throws {
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(UInt8(value ? 1 : 0))
        portal.send(SerialWireInstrument.apiTypeSetEnabled, content: binary.data)
        try portal.write()
    }

    func set(output: Int, value: Bool) {
        let bits = UInt8(1 << output)
        let values = value ? bits : 0
        portal.send(SerialWireInstrument.apiTypeSetOutputs, content: bits, values)
    }

    @objc public func getDetect(detect: UnsafeMutablePointer<ObjCBool>) throws {
        detect.memory = false // not implemented -denis
    }

    @objc public func setIndicator(value: Bool) {
        set(SerialWireInstrument.outputIndicator, value: value)
    }

    @objc public func setReset(value: Bool) {
        set(SerialWireInstrument.outputReset, value: value)
    }

    @objc public func turnToRead() {
        set(SerialWireInstrument.outputDirection, value: false)
    }

    @objc public func turnToWrite() {
        set(SerialWireInstrument.outputDirection, value: true)
    }

    @objc public func shiftOutBits(byte: UInt8, bitCount: UInt) {
        assert(bitCount > 0)
        portal.send(SerialWireInstrument.apiTypeShiftOutBits, content: UInt8(bitCount - 1), byte)
    }

    @objc public func shiftOutData(data: NSData) {
        assert(data.length > 0)
        let binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(UInt64(data.length - 1))
        binary.write(data)
        portal.send(SerialWireInstrument.apiTypeShiftOutData, content: binary.data)
    }

    @objc public func shiftInBits(bitCount: UInt) {
        portal.send(SerialWireInstrument.apiTypeShiftInBits, content: UInt8(bitCount - 1))
    }

    @objc public func shiftInData(byteCount: UInt) {
        let binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(UInt64(byteCount - 1))
        portal.send(SerialWireInstrument.apiTypeShiftInData, content: binary.data)
    }

    @objc(write:) public func write() throws {
        try portal.write()
    }

    @objc public func readWithByteCount(byteCount: UInt) throws -> NSData {
        return try portal.read(length: Int(byteCount))
    }

    @objc(read:) public func read() throws -> NSData {
        return portal.read()
    }

}