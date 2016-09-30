//
//  SerialWireInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

open class SerialWireInstrument: NSObject, FDSerialWire, FDSerialWireDebugTransport, InternalInstrument {

    public enum LocalError : Error {
        case memoryTransferIssue(code: UInt64, data: Data)
        case unknownTransferType(type: FDSerialWireDebugTransferType)
        case transferIssue(code: UInt64)
        case transferMismatch
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
    static let apiTypeTransfer = UInt64(14)

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
        let value: UInt64 = try binary.readVarUInt()
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

    @objc open func transfer(_ transfers: [FDSerialWireDebugTransfer]) throws {
        var responseCount = 0
        let request = Binary(byteOrder: .littleEndian)
        request.writeVarUInt(UInt64(transfers.count))
        for transfer in transfers {
            request.writeVarUInt(UInt64(transfer.type.rawValue))
            switch transfer.type {
            case .readRegister:
                responseCount += 1
                request.writeVarUInt(UInt64(transfer.registerID))
            case .writeRegister:
                request.writeVarUInt(UInt64(transfer.registerID))
                request.write(transfer.value as UInt32)
            case .readMemory:
                responseCount += 1
                request.write(transfer.address as UInt32)
                request.writeVarUInt(UInt64(transfer.length))
            case .writeMemory:
                request.write(transfer.address as UInt32)
                if let data = transfer.data {
                    request.writeVarUInt(UInt64(data.count))
                    request.write(data)
                } else {
                    request.writeVarUInt(0)
                }
            }
        }
        portal.send(SerialWireInstrument.apiTypeTransfer, content: request.data)
        let data = try portal.read(type: SerialWireInstrument.apiTypeTransfer)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let code = try binary.readVarUInt()
        if code != 0 {
            throw LocalError.transferIssue(code: code)
        }
        let count = try binary.readVarUInt()
        if count != UInt64(responseCount) {
            throw LocalError.transferMismatch
        }
        for transfer in transfers {
            switch transfer.type {
            case .readRegister:
                let type = try binary.readVarUInt()
                if type != UInt64(transfer.type.rawValue) {
                    throw LocalError.transferMismatch
                }
                let registerID: UInt16 = try binary.read()
                if registerID != transfer.registerID {
                    throw LocalError.transferMismatch
                }
                transfer.value = try binary.read() as UInt32
            case .writeRegister:
                break
            case .readMemory:
                let type = try binary.readVarUInt()
                if type != UInt64(transfer.type.rawValue) {
                    throw LocalError.transferMismatch
                }
                let address: UInt32 = try binary.read()
                if address != transfer.address {
                    throw LocalError.transferMismatch
                }
                let length: UInt32 = try binary.read()
                if length != transfer.length {
                    throw LocalError.transferMismatch
                }
                transfer.data = try binary.read(length: Int(length))
            case .writeMemory:
                break
            }
        }
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
