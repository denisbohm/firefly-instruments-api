//
//  FileSystemTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 9/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
@testable import FireflyInstruments
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

    func checkList(_ fileSystem: FileSystem, names: [String]) {
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

    func getUsedSectorCount(_ fileSystem: FileSystem) -> Int {
        var count = 0
        for sector in fileSystem.sectors {
            if case FileSystem.Status.available = sector.status {
            } else {
                count += 1
            }
        }
        return count
    }

    func testWrite() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        let name = "File"
        let bytes = [1, 2, 3, 4] as [UInt8]
        let date = Date()
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let hash = FDCryptography.sha1(data)
        let entry = try fileSystem.write(name, data: data)
        XCTAssertEqual(entry.name, name)
        XCTAssertEqual(entry.length, UInt32(bytes.count))
        XCTAssert(entry.date >= date)
        XCTAssertEqual(entry.hash, hash)
        XCTAssertEqual(entry.address, 4096)
        checkList(fileSystem, names: [name])
        XCTAssertEqual(getUsedSectorCount(fileSystem), fileSystem.minimumSectorCount)
        try fileSystem.inspect()
        XCTAssertEqual(getUsedSectorCount(fileSystem), fileSystem.minimumSectorCount)

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
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        for index in 0 ..< count {
            let name = "\(index)"
            names.append(name)
            let _ = try fileSystem.write(name, data: data)
            try fileSystem.inspect()
        }
        checkList(fileSystem, names: names)

        let name = "\(count)"
        names[0] = name
        let entry = try fileSystem.write(name, data: data)
        checkList(fileSystem, names: names)
        XCTAssertEqual(entry.address, 4096)
        try fileSystem.inspect()
        checkList(fileSystem, names: names)
    }

    func testCorrupt() throws {
        let storageInstrument = MockStorageInstrument()
        storageInstrument.randomize()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        checkList(fileSystem, names: [])
    }

    func testRepair() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()

        let _ = try fileSystem.ensure("a", data: Data())
        let _ = try fileSystem.ensure("b", data: Data())
        let _ = try fileSystem.ensure("c", data: Data())
        checkList(fileSystem, names: ["a", "b", "c"])

        // mess up hash for "a"
        storageInstrument.memory[21] = 0x5a
        // make two "c" entries
        storageInstrument.memory[2 * 4096 + 41] = 0x63 // "c"
        try fileSystem.inspect()
        checkList(fileSystem, names: ["c"])
    }

    func testOverwrite() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()

        let name = "a"
        let _ = try fileSystem.ensure(name, data: Data())
        let _ = try fileSystem.ensure(name, data: Data(bytes: [1]))
        checkList(fileSystem, names: [name])
    }

    func testFormat() throws {
        let storageInstrument = MockStorageInstrument()
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        let _ = try fileSystem.ensure("a", data: Data())
        try fileSystem.format()
        checkList(fileSystem, names: [])
    }

}
