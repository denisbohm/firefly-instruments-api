//
//  SerialWireInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

open class SerialWireInstrument: NSObject, FDSerialWire, FDSerialWireDebugTransfer, InternalInstrument {

    public enum LocalError : Error {
        case memoryTransferIssue(code: UInt64, data: Data)
    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeSetOutputs = UInt64(1)
    static let apiTypeGetInputs = UInt64(2)
    static let apiTypeShiftOutBits = UInt64(3)
    static let apiTypeShiftOutData = UInt64(4)
    static let apiTypeShiftInBits = UInt64(5)
    static let apiTypeShiftInData = UInt64(6)
    static let apiTypeFlush = UInt64(7)
    static let apiTypeData = UInt64(8)
    static let apiTypeSetEnabled = UInt64(9)
    static let apiTypeWriteMemory = UInt64(10)
    static let apiTypeReadMemory = UInt64(11)
    static let apiTypeWriteFromStorage = UInt64(12)
    static let apiTypeCompareToStorage = UInt64(13)

    static let outputIndicator = 0
    static let outputReset = 1
    static let outputDirection = 2

    unowned public private(set) var instrumentManager: InstrumentManager
    var portal: Portal

    public init(instrumentManager: InstrumentManager, portal: Portal) {
        self.instrumentManager = instrumentManager
        self.portal = portal
    }

    open var identifier: UInt64 { get { return portal.identifier } }

    open func reset() throws {
        portal.send(SerialWireInstrument.apiTypeReset)
        try portal.write()
    }

    open func setEnabled(_ value: Bool) throws {
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(UInt8(value ? 1 : 0))
        portal.send(SerialWireInstrument.apiTypeSetEnabled, content: binary.data)
        try portal.write()
    }

    func set(_ output: Int, value: Bool) {
        let bits = UInt8(1 << output)
        let values = value ? bits : 0
        portal.send(SerialWireInstrument.apiTypeSetOutputs, content: bits, values)
    }

    func get(_ input: Int) throws -> Bool {
        let bits = UInt8(1 << input)
        portal.send(SerialWireInstrument.apiTypeGetInputs, content: bits)
        let data = try portal.read(type: SerialWireInstrument.apiTypeGetInputs)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let value: UInt8 = try binary.read()
        return value != 0
    }

    open func getReset() throws -> Bool {
        return try get(0)
    }

    @objc(initialize:) open func initialize() throws {
    }

    @objc open func getDetect(_ detect: UnsafeMutablePointer<ObjCBool>) throws {
        detect.pointee = false // not implemented -denis
    }

    @objc open func setIndicator(_ value: Bool) {
        set(SerialWireInstrument.outputIndicator, value: value)
    }

    @objc open func setReset(_ value: Bool) {
        set(SerialWireInstrument.outputReset, value: value)
    }

    @objc open func turnToRead() {
        set(SerialWireInstrument.outputDirection, value: false)
    }

    @objc open func turnToWrite() {
        set(SerialWireInstrument.outputDirection, value: true)
    }

    @objc open func shiftOutBits(_ byte: UInt8, bitCount: UInt) {
        assert(bitCount > 0)
        portal.send(SerialWireInstrument.apiTypeShiftOutBits, content: UInt8(bitCount - 1), byte)
    }

    @objc open func shiftOutData(_ data: Data) {
        assert(data.count > 0)
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(UInt64(data.count - 1))
        binary.write(data)
        portal.send(SerialWireInstrument.apiTypeShiftOutData, content: binary.data)
    }

    @objc open func shift(inBits bitCount: UInt) {
        portal.send(SerialWireInstrument.apiTypeShiftInBits, content: UInt8(bitCount - 1))
    }

    @objc open func shift(inData byteCount: UInt) {
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(UInt64(byteCount - 1))
        portal.send(SerialWireInstrument.apiTypeShiftInData, content: binary.data)
    }

    @objc(write:) open func write() throws {
        try portal.write()
    }

    @objc open func read(withByteCount byteCount: UInt) throws -> Data {
        portal.send(SerialWireInstrument.apiTypeFlush)
        try portal.write()
        return try portal.read(length: Int(byteCount)) as Data
    }

    @objc(read:) open func read() throws -> Data {
        return portal.read() as Data
    }

    @objc open func writeMemory(_ address: UInt32, data: Data) throws {
        let request = Binary(byteOrder: .littleEndian)
        request.writeVarUInt(UInt64(address))
        request.writeVarUInt(UInt64(data.count))
        request.write(data)
        portal.send(SerialWireInstrument.apiTypeWriteMemory, content: request.data)
        let data = try portal.read(type: SerialWireInstrument.apiTypeWriteMemory)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let code = try binary.readVarUInt()
        if code != 0 {
            throw LocalError.memoryTransferIssue(code: code, data: binary.remainingData)
        }
    }

    @objc open func readMemory(_ address: UInt32, length: UInt32) throws -> Data {
        let request = Binary(byteOrder: .littleEndian)
        request.writeVarUInt(UInt64(address))
        request.writeVarUInt(UInt64(length))
        portal.send(SerialWireInstrument.apiTypeReadMemory, content: request.data)
        let data = try portal.read(type: SerialWireInstrument.apiTypeReadMemory)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let code = try binary.readVarUInt()
        if code != 0 {
            throw LocalError.memoryTransferIssue(code: code, data: binary.remainingData)
        }
        let result = binary.remainingData
        if result.count != Int(length) {
            throw LocalError.memoryTransferIssue(code: code, data: result)
        }
        return result
    }

    open func writeFromStorage(_ address: UInt32, length: UInt32, storageIdentifier: UInt64, storageAddress: UInt32) throws {
        let request = Binary(byteOrder: .littleEndian)
        request.writeVarUInt(UInt64(address))
        request.writeVarUInt(UInt64(length))
        request.writeVarUInt(UInt64(storageIdentifier))
        request.writeVarUInt(UInt64(storageAddress))
        portal.send(SerialWireInstrument.apiTypeWriteFromStorage, content: request.data)
        let data = try portal.read(type: SerialWireInstrument.apiTypeWriteFromStorage)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let code = try binary.readVarUInt()
        if code != 0 {
            throw LocalError.memoryTransferIssue(code: code, data: binary.remainingData)
        }
    }

    open func compareToStorage(_ address: UInt32, length: UInt32, storageIdentifier: UInt64, storageAddress: UInt32) throws {
        let request = Binary(byteOrder: .littleEndian)
        request.writeVarUInt(UInt64(address))
        request.writeVarUInt(UInt64(length))
        request.writeVarUInt(UInt64(storageIdentifier))
        request.writeVarUInt(UInt64(storageAddress))
        portal.send(SerialWireInstrument.apiTypeCompareToStorage, content: request.data)
        let data = try portal.read(type: SerialWireInstrument.apiTypeCompareToStorage)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let code = try binary.readVarUInt()
        if code != 0 {
            throw LocalError.memoryTransferIssue(code: code, data: binary.remainingData)
        }
    }

}
