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
        case corruptWrite
    }

    public struct Hash {
        public let data: [UInt8] // 20 bytes
    }

    public struct Entry {
        public let name: String
        public let sectorCount: UInt32
        public let length: UInt32
        public let date: Date
        public let hash: Data
        public let address: UInt32
    }

    enum Status {
        case available
        case metadata(entry: Entry)
        case content
    }
    
    struct Sector {
        let address: UInt32
        var status: Status
    }

    public let storageInstrument: StorageInstrument

    open var minimumSectorCount = 2 // increase to reduce fragmentation

    public let size = 1<<21
    public let sectorSize = 1<<12

    let pageSize = 1<<8
    let hashSize = 20

    let magic = Data([0xf0, 0x66, 0x69, 0x72, 0x65, 0x66, 0x6c, 0x79])

    var sectorCount: Int { get { return size / sectorSize } }

    var sectors = [Sector]()

    public init(storageInstrument: StorageInstrument) {
        self.storageInstrument = storageInstrument
    }

    open func format() throws {
        try storageInstrument.erase(0, length: UInt32(sectorCount * sectorSize))
        for sectorIndex in 0 ..< sectors.count {
            sectors[sectorIndex].status = Status.available
        }
    }

    func erase(_ sector: Sector) throws {
        var sectorCount = 1
        if case let Status.metadata(entry) = sector.status {
            sectorCount = Int(entry.sectorCount)
        }
        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))
        let firstSectorIndex = Int(sector.address) / sectorSize
        for sectorIndex in firstSectorIndex ..< firstSectorIndex + sectorCount {
            sectors[sectorIndex].status = Status.available
        }
    }

    open func erase(_ name: String) throws {
        for sector in sectors {
            if case let Status.metadata(entry) = sector.status {
                if entry.name == name {
                    try erase(sector)
                }
            }
        }
    }
    
    func repair() throws -> Bool {
        var repaired = false
        var entryByName = [String : Entry]()
        for sector in sectors {
            if case let Status.metadata(entry) = sector.status {
                let hash = try storageInstrument.hash(sector.address + UInt32(sectorSize), length: entry.length)
                if hash != entry.hash {
                    NSLog("FileSystem.repair: erasing entry with incorrect content hash: \(entry.name)")
                    try erase(sector)
                    repaired = true
                } else
                if let existing = entryByName[entry.name] {
                    NSLog("FileSystem.repair: erasing duplicate entry: \(entry.name) @0x%08x vs @0x%08x", entry.address, existing.address)
                    try erase(sector)
                    repaired = true
                } else {
                    entryByName[entry.name] = entry
                }
            }
        }
        return repaired
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
                let data = try storageInstrument.read(address, length: UInt32(pageSize))
                if magic == data.subdata(in: 0 ..< magic.count) {
                    do {
                        let binary = Binary(data: data, byteOrder: ByteOrder.littleEndian)
                        let _ = try binary.read(length: magic.count) // skip header
                        let usedSectorCount: UInt32 = try binary.read()
                        let length: UInt32 = try binary.read()
                        let unixTime: UInt32 = try binary.read()
                        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
                        let hash = try binary.read(length: hashSize)
                        let name: String = try binary.read()
                        let entry = Entry(name: name, sectorCount: usedSectorCount, length: length, date: date, hash: hash, address: address + UInt32(sectorSize))
                        let status = Status.metadata(entry: entry)
                        let sector = Sector(address: address, status: status)
                        sectors.append(sector)
                        sectorIndex += 1

                        for _ in 1 ..< Int(usedSectorCount) {
                            let address = UInt32(sectorIndex * sectorSize)
                            sectors.append(Sector(address: address, status: Status.content))
                            sectorIndex += 1
                        }
                        continue
                    } catch {
                        // entry appears to be corrupt, consider this sector available... -denis
                        NSLog("File System: corruption in sector \(sectorIndex) entry?")
                    }
                }
                // something corrupt found, consider this sector available... -denis
                NSLog("File System: corruption in sector \(sectorIndex)?")
            }

            // available
            sectors.append(Sector(address: address, status: Status.available))
            sectorIndex += 1
        }
    }

    open func inspect() throws {
        try scan()
        let _ = try repair()
    }

    open func list() -> [Entry] {
        var entries = [Entry]()
        for sector in sectors {
            if case let Status.metadata(entry) = sector.status {
                entries.append(entry)
            }
        }
        return entries
    }

    open func get(_ name: String) -> Entry? {
        for sector in sectors {
            if case let Status.metadata(entry) = sector.status {
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
        return try storageInstrument.read(entry.address, length: entry.length)
    }

    func write(_ name: String, data: Data, date: Date, sector: Sector, sectorCount: Int) throws -> Entry {
        let length = UInt32(data.count)
        let hash = FDCryptography.sha1(data)!
        let entry = Entry(name: name, sectorCount: UInt32(sectorCount), length: length, date: date, hash: hash, address: sector.address + UInt32(sectorSize))
        var sectorIndex = Int(sector.address) / sectorSize
        sectors[sectorIndex].status = Status.metadata(entry: entry)
        for _ in 1 ..< sectorCount {
            sectorIndex += 1
            sectors[sectorIndex].status = Status.content
        }

        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))

        let binary = Binary(byteOrder: ByteOrder.littleEndian)
        binary.write(magic)
        binary.write(UInt32(sectorCount))
        binary.write(length)
        binary.write(UInt32(date.timeIntervalSince1970))
        binary.write(hash)
        binary.write(name)
        var address = sector.address
        try storageInstrument.write(address, data: binary.data)

        address += UInt32(sectorSize)
        try storageInstrument.write(address, data: data)

        return entry
    }

    func checkCandidate(_ name: String, data: Data, date: Date, availableSector: Sector?, availableSectorCount: Int, entrySectorCount: Int) throws -> Entry? {
        if let sector = availableSector {
            if availableSectorCount >= entrySectorCount {
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
            if case let Status.metadata(entry) = sector.status {
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
        } while try eraseLeastRecentlyUsed()
        throw LocalError.notEnoughSpace(name: name, length: UInt32(data.count))
    }

    // This function returns the preexisting entry if the file already exists and the hashes match.
    // Otherwise, the preexisting entry will be removed and a new entry written (possibly removing other least recently used files to make room).
    open func ensure(_ name: String, data: Data, date: Date = Date()) throws -> Entry {
        var entry: Entry? = get(name)
        if let preexisting = entry {
            let hash = FDCryptography.sha1(data)
            if hash != preexisting.hash {
                try erase(name)
                entry = nil
            }
        }
        if entry == nil {
            entry = try write(name, data: data, date: date)
            let verify = try storageInstrument.hash(entry!.address, length: entry!.length)
            if verify != entry!.hash {
                throw LocalError.corruptWrite
            }
        }
        return entry!
    }

}
