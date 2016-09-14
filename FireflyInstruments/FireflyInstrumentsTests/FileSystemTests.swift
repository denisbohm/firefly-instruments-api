//
//  FileSystemTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 9/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments
import Foundation
import XCTest

class FireflySystemTests: XCTestCase {

    func testScanEmpty() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        let entries = fileSystem.list()
        XCTAssertEqual(entries.count, 0)
    }

    func testGetNotFound() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        let entry = fileSystem.get("Bogus")
        XCTAssertNil(entry)
    }

    func checkList(fileSystem: FileSystem, names: [String]) {
        let entries = fileSystem.list()
        XCTAssertEqual(entries.count, names.count)
        if entries.count < names.count {
            return
        }
        for index in 0 ..< entries.count {
            let entry = entries[index]
            let name = names[index]
            XCTAssertEqual(entry.name, name)
        }
    }

    func testWrite() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        let name = "File"
        let bytes = [1, 2, 3, 4] as [UInt8]
        let date = NSDate()
        let data = NSData(bytes: bytes, length: bytes.count)
        let hash = FDCryptography.sha1(data)
        let entry = try fileSystem.write(name, data: data)
        XCTAssertEqual(entry.name, name)
        XCTAssertEqual(entry.length, UInt32(bytes.count))
        XCTAssert(entry.date.isGreaterThanOrEqualTo(date))
        XCTAssertEqual(entry.hash, hash)
        XCTAssertEqual(entry.address, 4096)
        checkList(fileSystem, names: [name])

        do {
            let entry = fileSystem.get(name)
            XCTAssertNotNil(entry)
            if let entry = entry {
                XCTAssertEqual(entry.name, name)
            }
        }

        try fileSystem.inspect()
        checkList(fileSystem, names: [name])

        try fileSystem.erase(name)
        checkList(fileSystem, names: [])
    }

    func testReplacement() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()

        let count = fileSystem.size / (fileSystem.minimumSectorCount * fileSystem.sectorSize)

        var names = [String]()
        let bytes = [1, 2, 3, 4] as [UInt8]
        let data = NSData(bytes: bytes, length: bytes.count)
        for index in 0 ..< count {
            let name = "\(index)"
            names.append(name)
            let _ = try fileSystem.write(name, data: data)
        }
        checkList(fileSystem, names: names)

        let name = "\(count)"
        names.removeFirst()
        names.append(name)
        let entry = try fileSystem.write(name, data: data)
        checkList(fileSystem, names: names)
        XCTAssertEqual(entry.address, 4096)
    }

    func testCorrupt() throws {

    }

    func testRepair() throws {
        
    }
    
}