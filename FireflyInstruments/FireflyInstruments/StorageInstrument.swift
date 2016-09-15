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

    var portal: Portal

    public init(portal: Portal) {
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
        let arguments = Binary(byteOrder: .littleEndian)
        arguments.writeVarUInt(UInt64(address))
        arguments.writeVarUInt(UInt64(data.count))
        arguments.write(data)
        portal.send(StorageInstrument.apiTypeWrite, content: arguments.data)
    }

    open func read(_ address: UInt32, length: UInt32, sublength: UInt32 = 0, substride: UInt32 = 0) throws -> Data {
        let arguments = Binary(byteOrder: .littleEndian)
        arguments.writeVarUInt(UInt64(address))
        arguments.writeVarUInt(UInt64(length))
        arguments.writeVarUInt(UInt64(sublength))
        arguments.writeVarUInt(UInt64(substride))
        portal.send(StorageInstrument.apiTypeRead, content: arguments.data)
        let data = try portal.read(type: StorageInstrument.apiTypeRead)
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let result: Data = try binary.read(length: Int(length))
        return result
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
