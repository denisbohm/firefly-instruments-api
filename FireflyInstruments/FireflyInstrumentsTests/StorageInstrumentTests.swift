//
//  StorageInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 8/26/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class StorageInstrumentTests: XCTestCase {

    func testSends() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let storageInstrument = StorageInstrument(instrumentManager: instrumentManager, portal: portal)

        XCTAssertEqual(storageInstrument.identifier, 1)

        // reset
        try storageInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()
        portal.assertEndOfCalls()

        let address = UInt32(9)
        let length = UInt32(1)
        let bytes = [1] as [UInt8]
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let hashBytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 ] as [UInt8]
        let hash = Data(bytes: UnsafePointer<UInt8>(hashBytes), count: hashBytes.count)

        // erase
        do {
            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address))
            arguments.writeVarUInt(UInt64(length))
            try storageInstrument.erase(address, length: length)
            portal.assertDidSend(1, content: arguments.data)
            portal.assertEndOfCalls()
        }

        // write
        do {
            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address))
            arguments.writeVarUInt(UInt64(length))
            arguments.write(data)
            try storageInstrument.write(address, data: data)
            portal.assertDidSend(2, content: arguments.data)
            portal.assertDidWrite()
            portal.assertEndOfCalls()
        }

        // read with sublength and substride
        do {
            portal.queueRead(UInt64(3), content: data)

            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address))
            arguments.writeVarUInt(UInt64(length))
            let sublength: UInt32 = 1
            arguments.writeVarUInt(UInt64(sublength))
            let substride: UInt32 = 4096
            arguments.writeVarUInt(UInt64(substride))
            let result = try storageInstrument.read(address, length: UInt32(data.count), sublength: sublength, substride: substride)
            portal.assertDidSend(3, content: arguments.data)
            portal.assertDidReadType(type: 3)
            XCTAssertEqual(data, result)
            portal.assertEndOfCalls()
        }

        // read
        do {
            portal.queueRead(UInt64(3), content: data)

            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address))
            arguments.writeVarUInt(UInt64(length))
            let sublength: UInt32 = 1
            arguments.writeVarUInt(UInt64(sublength))
            let substride: UInt32 = 0
            arguments.writeVarUInt(UInt64(substride))
            let result = try storageInstrument.read(address, length: UInt32(data.count))
            portal.assertDidSend(3, content: arguments.data)
            portal.assertDidReadType(type: 3)
            XCTAssertEqual(data, result)
            portal.assertEndOfCalls()
        }

        // hash
        do {
            portal.queueRead(UInt64(4), content: hash)

            let arguments = Binary(byteOrder: .littleEndian)
            arguments.writeVarUInt(UInt64(address))
            arguments.writeVarUInt(UInt64(length))
            let result = try storageInstrument.hash(address, length: UInt32(data.count))
            portal.assertDidSend(4, content: arguments.data)
            portal.assertDidReadType(type: 4)
            XCTAssertEqual(hash, result)
            portal.assertEndOfCalls()
        }
    }

}
