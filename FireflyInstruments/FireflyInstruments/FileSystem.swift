//
//  FileSystem.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 8/27/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

/*
 instrument storage file system
 - keep it simple
 - embrace the nature of the flash chip
 - intended to store a small number of files (~10)
 - each files metadata and content data are stored in contiguous locations
 - sectors are not shared across files
 - can set a minimum allocation size (wastes space, but minimizes fragmentation)
 - LRU policy to automatically remove old files if needed to reclaim space when new files are written
 */

open class FileSystem {

    public enum LocalError: Error {
        case invalidName(String)
        case duplicateName(String)
        case notFound(String)
        case notEnoughSpace(name: String, length: UInt32)
    }

    public struct Hash {
        public let data: [UInt8] // 20 bytes
    }

    public struct Entry {
        public let name: String
        public let length: UInt32
        public let date: Date
        public let hash: Data
        public let address: UInt32
    }

    enum Status {
        case available
        case metadata(entry: Entry, sectorCount: Int)
        case content
    }
    
    struct Sector {
        let address: UInt32
        var status: Status
    }

    open let storageInstrument: StorageInstrument

    open var minimumSectorCount = 1 // !!! should be 64 normally

    open let size = 1<<22
    open let sectorSize = 1<<12

    let pageSize = 1<<8
    let hashSize = 20

    let magic = Data(bytes: [0xf0, 0x66, 0x69, 0x72, 0x65, 0x66, 0x6c, 0x79])

    var sectorCount: Int { get { return size / sectorSize } }

    var sectors = [Sector]()

    public init(storageInstrument: StorageInstrument) {
        self.storageInstrument = storageInstrument
    }

    func erase(_ sector: Sector) throws {
        NSLog("File System: erase: \(sector.address)")
        var sectorCount = 1
        if case let Status.metadata(_, metadataSectorCount) = sector.status {
            sectorCount = metadataSectorCount
        }
        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))
        let firstSectorIndex = Int(sector.address) / sectorSize
        for sectorIndex in firstSectorIndex ..< sectorCount {
            sectors[sectorIndex].status = Status.available
        }
    }

    open func erase(_ name: String) throws {
        for sector in sectors {
            if case let Status.metadata(entry, _) = sector.status {
                if entry.name == name {
                    try erase(sector)
                }
            }
        }
    }
    
    func repair() throws {
        for sector in sectors {
            if case let Status.metadata(entry, _) = sector.status {
                let hash = try storageInstrument.hash(sector.address + UInt32(sectorSize), length: entry.length)
                if hash != entry.hash {
                    try erase(sector)
                }
            }
        }
    }

    func scan() throws {
        sectors.removeAll()
        // read the first byte of each sector so we can quickly probe the status of each
        let markers = try storageInstrument.read(0, length: UInt32(sectorCount), sublength: 1, substride: UInt32(sectorSize))
        var sectorIndex = 0
        while sectorIndex < sectorCount {
            let address = UInt32(sectorIndex * sectorSize)
            let marker = markers[sectorIndex]
            if marker == 0xf0 {
                // should be metadata
                let data = try storageInstrument.read(0, length: UInt32(pageSize))
                if magic == data.subdata(in: 0 ..< magic.count) {
                    let binary = Binary(data: data, byteOrder: ByteOrder.littleEndian)
                    let _ = try binary.read(length: magic.count) // skip header
                    let length: UInt32 = try binary.read()
                    let unixTime: UInt32 = try binary.read()
                    let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
                    let hash = try binary.read(length: hashSize)
                    let name: String = try binary.read()
                    let entry = Entry(name: name, length: length, date: date, hash: hash, address: address + UInt32(sectorSize))
                    let status = Status.metadata(entry: entry, sectorCount: Int(sectorCount))
                    let sector = Sector(address: address, status: status)
                    sectors.append(sector)
                    sectorIndex += 1

                    for _ in 1 ..< Int(sectorCount) {
                        let address = UInt32(sectorIndex * sectorSize)
                        sectors.append(Sector(address: address, status: Status.content))
                        sectorIndex += 1
                    }
                    continue
                }
                // something corrupt found, consider this sector available... -denis
            }

            // available
            sectors.append(Sector(address: address, status: Status.available))
            sectorIndex += 1
        }
    }

    open func inspect() throws {
        try scan()
        try repair()
    }

    open func list() -> [Entry] {
        var entries = [Entry]()
        for sector in sectors {
            if case let Status.metadata(entry, _) = sector.status {
                entries.append(entry)
            }
        }
        return entries
    }

    open func get(_ name: String) -> Entry? {
        for sector in sectors {
            if case let Status.metadata(entry, _) = sector.status {
                if entry.name == name {
                    return entry
                }
            }
        }
        return nil
    }

    open func read(_ name: String) throws -> Data {
        guard let entry = get(name) else {
            throw LocalError.notFound(name)
        }
        NSLog("File System: read: reading \(name) \(entry.length)")
        return try storageInstrument.read(entry.address, length: entry.length)
    }

    func write(_ name: String, data: Data, date: Date, sector: Sector, sectorCount: Int) throws -> Entry {
        let length = UInt32(data.count)
        let hash = FDCryptography.sha1(data)!
        let entry = Entry(name: name, length: length, date: date, hash: hash, address: sector.address + UInt32(sectorSize))
        var sectorIndex = Int(sector.address) / sectorSize
        sectors[sectorIndex].status = Status.metadata(entry: entry, sectorCount: sectorCount)
        for _ in 1 ..< sectorCount {
            sectorIndex += 1
            sectors[sectorIndex].status = Status.content
        }

        NSLog("File System: write: erasing")
        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))

        let binary = Binary(byteOrder: ByteOrder.littleEndian)
        binary.write(magic)
        binary.write(length)
        binary.write(UInt32(date.timeIntervalSince1970))
        binary.write(hash)
        binary.write(name)
        var address = sector.address
        NSLog("File System: write: writing metadata")
        try storageInstrument.write(address, data: binary.data)

        address += UInt32(sectorSize)
        NSLog("File System: write: writing content")
        try storageInstrument.write(address, data: data)

        return entry
    }

    func checkCandidate(_ name: String, data: Data, date: Date, availableSector: Sector?, availableSectorCount: Int, entrySectorCount: Int) throws -> Entry? {
        if let sector = availableSector {
            if availableSectorCount >= entrySectorCount {
                NSLog("File System: found candidate")
                return try write(name, data: data, date: date, sector: sector, sectorCount: entrySectorCount)
            }
        }
        return nil
    }

    func sectorCountForContentLength(_ length: UInt32) -> Int {
        return (Int(length) + (sectorSize - 1)) / sectorSize
    }

    func checkWrite(_ name: String, data: Data, date: Date) throws -> Entry? {
        let entrySectorCount = max(1 + sectorCountForContentLength(UInt32(data.count)), minimumSectorCount)
        var availableSector: Sector? = nil
        var availableSectorCount = 0
        for sector in sectors {
            if case Status.available = sector.status {
                if availableSector == nil {
                    availableSector = sector
                    availableSectorCount = 1
                } else {
                    availableSectorCount += 1
                }
            } else {
                if let entry = try checkCandidate(name, data: data, date: date, availableSector: availableSector, availableSectorCount: availableSectorCount, entrySectorCount: entrySectorCount) {
                    return entry
                }
                availableSector = nil
                availableSectorCount = 0
            }
        }
        if let entry = try checkCandidate(name, data: data, date: date, availableSector: availableSector, availableSectorCount: availableSectorCount, entrySectorCount: entrySectorCount) {
            return entry
        }
        return nil
    }

    func getLeastRecentlyUsed() throws -> Sector? {
        var leastRecentlyUsedSector: Sector? = nil
        var leastRecentlyUsedDate: Date? = nil
        for sector in sectors {
            if case let Status.metadata(entry, _) = sector.status {
                if leastRecentlyUsedSector == nil {
                    leastRecentlyUsedSector = sector
                    leastRecentlyUsedDate = entry.date
                    continue
                }
                if (entry.date as NSDate).isLessThan(leastRecentlyUsedDate) {
                    leastRecentlyUsedSector = sector
                    leastRecentlyUsedDate = entry.date
                }
            }
        }
        return leastRecentlyUsedSector
    }

    func eraseLeastRecentlyUsed() throws -> Bool {
        if let sector = try getLeastRecentlyUsed() {
            try erase(sector)
            return true
        }
        return false
    }

    // Allocate a file system entry.
    // The entry is stored in flash before this returns.
    // This will free other (least recently used) entries to make space if needed.
    open func write(_ name: String, data: Data, date: Date = Date()) throws -> Entry {
        repeat {
            if let entry = try checkWrite(name, data: data, date: date) {
                return entry
            }
            NSLog("File System: write: not enough room - erasing least recently used entry")
        } while try eraseLeastRecentlyUsed()
        throw LocalError.notEnoughSpace(name: name, length: UInt32(data.count))
    }

}
