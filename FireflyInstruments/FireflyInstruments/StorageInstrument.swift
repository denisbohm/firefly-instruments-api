//
//  StorageInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 8/26/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class StorageInstrument: InternalInstrument {

    static let apiTypeReset = UInt64(0)
    static let apiTypeErase = UInt64(1)
    static let apiTypeWrite = UInt64(2)
    static let apiTypeRead = UInt64(3)
    static let apiTypeHash = UInt64(4)

    unowned public private(set) var instrumentManager: InstrumentManager
    var portal: Portal

    public var maxTransferLength = 1024

    public init(instrumentManager: InstrumentManager, portal: Portal) {
        self.instrumentManager = instrumentManager
        self.portal = portal
    }

    open var identifier: UInt64 { get { return portal.identifier } }

    open func reset() throws {
        portal.send(StorageInstrument.apiTypeReset)
        try portal.write()
    }

    open func erase(_ address: UInt32, length: UInt32) throws {
        let arguments = Binary(byteOrder: .littleEndian)
        arguments.writeVarUInt(UInt64(address))
        arguments.writeVarUInt(UInt64(length))
        portal.send(StorageInstrument.apiTypeErase, content: arguments.data)
    }

    open func write(_ address: UInt32, data: Data) throws {
        var offset = 0
        while offset < data.count {
            let length = min(data.count - offset, maxTransferLength)
            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address + UInt32(offset)))
            arguments.writeVarUInt(UInt64(length))
            arguments.write(data.subdata(in: offset ..< offset + length))
            portal.send(StorageInstrument.apiTypeWrite, content: arguments.data)
//            try portal.write() // !!! extra write here causes loss of next write for echo? -denis
            try instrumentManager.echo(data: Data(bytes: [0xbe, 0xef]))
            offset += length
        }
    }

    open func read(_ address: UInt32, length: UInt32, sublength: UInt32 = 0, substride: UInt32 = 0) throws -> Data {
        var sublength = sublength
        if sublength == 0 {
            sublength = length
        }
        let length = Int(length)

        // !!! this won't work for sublengths larger than the maxTransferLength -denis
        var data = Data(count: length)
        var offset = 0
        while offset < length {
            let transferLength = min(data.count - offset, maxTransferLength)
            let transferSublength = min(Int(sublength), transferLength)
            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address + UInt32(offset)))
            arguments.writeVarUInt(UInt64(transferLength))
            arguments.writeVarUInt(UInt64(transferSublength))
            arguments.writeVarUInt(UInt64(substride))
            NSLog("Storage Instrument: read \(transferLength) \(transferSublength) \(substride)")
            portal.send(StorageInstrument.apiTypeRead, content: arguments.data)
            let result = try portal.read(type: StorageInstrument.apiTypeRead)
            let binary = Binary(data: result, byteOrder: .littleEndian)
            let subdata = try binary.read(length: transferLength)
            data.replaceSubrange(offset ..< offset + transferLength, with: subdata)
            offset += transferLength
        }
        return data
    }

    open func hash(_ address: UInt32, length: UInt32) throws -> Data {
        let arguments = Binary(byteOrder: .littleEndian)
        arguments.writeVarUInt(UInt64(address))
        arguments.writeVarUInt(UInt64(length))
        portal.send(StorageInstrument.apiTypeHash, content: arguments.data)
        let data = try portal.read(type: StorageInstrument.apiTypeHash)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let result: Data = try binary.read(length: 20)
        return result
    }

}
