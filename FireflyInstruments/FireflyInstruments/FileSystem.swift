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
 - a files metadata and content data are stored in contiguous locations
 - sectors are not shared across files
 - can set a minimum allocation size (wastes space, but minimizes fragmentation)
 - LRU policy to automatically remove old files if needed to reclaim space when new files are written
 */

public class FileSystem {

    public enum Error: ErrorType {
        case InvalidName(String)
        case DuplicateName(String)
        case NotEnoughSpace(name: String, length: UInt32)
    }

    public struct Hash {
        public let data: [UInt8] // 20 bytes
    }

    public struct Entry {
        public let name: String
        public let length: UInt32
        public let date: NSDate
        public let hash: NSData
        public let address: UInt32
    }

    enum Status {
        case Available
        case Metadata(entry: Entry, sectorCount: Int)
        case Content
    }
    
    struct Sector {
        let address: UInt32
        var status: Status
    }

    public let storageInstrument: StorageInstrument

    public var minimumSectorCount = 64

    public let size = 1<<22
    public let sectorSize = 1<<12

    let pageSize = 1<<8
    let hashSize = 20

    let magic: NSData

    var sectorCount: Int { get { return size / sectorSize } }

    var sectors = [Sector]()

    public init(storageInstrument: StorageInstrument) {
        self.storageInstrument = storageInstrument

        let magicBytes = [0xf0, 0x66, 0x69, 0x72, 0x65, 0x66, 0x6c, 0x79] as [UInt8]
        magic = NSData(bytes: magicBytes, length: magicBytes.count)
    }

    func erase(sector: Sector) throws {
        var sectorCount = 1
        if case let Status.Metadata(_, metadataSectorCount) = sector.status {
            sectorCount = metadataSectorCount
        }
        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))
        let firstSectorIndex = Int(sector.address) / sectorSize
        for sectorIndex in firstSectorIndex ..< sectorCount {
            sectors[sectorIndex].status = Status.Available
        }
    }

    public func erase(name: String) throws {
        for sector in sectors {
            if case let Status.Metadata(entry, _) = sector.status {
                if entry.name == name {
                    try erase(sector)
                }
            }
        }
    }
    
    func repair() throws {
        for sector in sectors {
            if case let Status.Metadata(entry, _) = sector.status {
                let hash = try storageInstrument.hash(sector.address + UInt32(sectorSize), length: entry.length)
                if !hash.isEqualToData(entry.hash) {
                    try erase(sector)
                }
            }
        }
    }

    func scan() throws {
        sectors.removeAll()
        // read the first byte of each sector so we can quickly probe the status of each
        let markersData = try storageInstrument.read(0, length: UInt32(sectorCount), sublength: 1, substride: UInt32(sectorSize))
        let markers = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(markersData.bytes), count: markersData.length))
        var sectorIndex = 0
        while sectorIndex < sectorCount {
            let address = UInt32(sectorIndex * sectorSize)
            let marker = markers[sectorIndex]
            if marker == 0xf0 {
                // should be metadata
                let data = try storageInstrument.read(0, length: UInt32(pageSize))
                if magic.isEqualToData(data.subdataWithRange(NSRange(location: 0, length: magic.length))) {
                    let binary = Binary(data: data, byteOrder: ByteOrder.LittleEndian)
                    try binary.read(length: magic.length) // skip header
                    let length: UInt32 = try binary.read()
                    let unixTime: UInt32 = try binary.read()
                    let date = NSDate(timeIntervalSince1970: NSTimeInterval(unixTime))
                    let hash = try binary.read(length: hashSize)
                    let dataAddress: UInt32 = try binary.read()
                    let sectorCount: UInt32 = try binary.read()
                    let name: String = try binary.read()
                    let entry = Entry(name: name, length: length, date: date, hash: hash, address: dataAddress)
                    let status = Status.Metadata(entry: entry, sectorCount: Int(sectorCount))
                    let sector = Sector(address: address, status: status)
                    sectors.append(sector)
                    sectorIndex += 1

                    for _ in 1 ..< Int(sectorCount) {
                        let address = UInt32(sectorIndex * sectorSize)
                        sectors.append(Sector(address: address, status: Status.Content))
                        sectorIndex += 1
                    }
                    continue
                }
                // something corrupt found, consider this sector available... -denis
            }

            // available
            sectors.append(Sector(address: address, status: Status.Available))
            sectorIndex += 1
        }
    }

    public func inspect() throws {
        try scan()
        try repair()
    }

    public func list() -> [Entry] {
        var entries = [Entry]()
        for sector in sectors {
            if case let Status.Metadata(entry, _) = sector.status {
                entries.append(entry)
            }
        }
        return entries
    }

    public func get(name: String) -> Entry? {
        for sector in sectors {
            if case let Status.Metadata(entry, _) = sector.status {
                if entry.name == name {
                    return entry
                }
            }
        }
        return nil
    }

    func write(name: String, data: NSData, date: NSDate, sector: Sector, sectorCount: Int) throws -> Entry {
        let length = UInt32(data.length)
        let hash = FDCryptography.sha1(data)
        let entry = Entry(name: name, length: length, date: date, hash: hash, address: sector.address + UInt32(sectorSize))
        var sectorIndex = Int(sector.address) / sectorSize
        sectors[sectorIndex].status = Status.Metadata(entry: entry, sectorCount: sectorCount)
        for _ in 1 ..< sectorCount {
            sectorIndex += 1
            sectors[sectorIndex].status = Status.Content
        }

        try storageInstrument.erase(sector.address, length: UInt32(sectorCount * sectorSize))

        let binary = Binary(byteOrder: ByteOrder.LittleEndian)
        binary.write(magic)
        binary.write(length)
        binary.write(UInt32(date.timeIntervalSince1970))
        binary.write(hash)
        binary.write(name)
        var address = sector.address
        try storageInstrument.write(address, data: binary.data)

        address += UInt32(sectorSize)
        var sublocation = 0
        var sublength = pageSize
        let pageCount = (data.length + pageSize - 1) / pageSize
        for _ in 0 ..< pageCount {
            if (sublocation + sublength) > data.length {
                sublength = data.length - sublocation
            }
            let subdata = data.subdataWithRange(NSRange(location: sublocation, length: sublength))
            try storageInstrument.write(address, data: subdata)
            address += UInt32(pageSize)
            sublocation += pageSize
        }

        return entry
    }

    func checkCandidate(name: String, data: NSData, date: NSDate, availableSector: Sector?, availableSectorCount: Int, entrySectorCount: Int) throws -> Entry? {
        if let sector = availableSector {
            if availableSectorCount >= entrySectorCount {
                return try write(name, data: data, date: date, sector: sector, sectorCount: entrySectorCount)
            }
        }
        return nil
    }

    func sectorCountForContentLength(length: UInt32) -> Int {
        return (Int(length) + (sectorSize - 1)) / sectorSize
    }

    func checkWrite(name: String, data: NSData, date: NSDate) throws -> Entry? {
        let entrySectorCount = max(1 + sectorCountForContentLength(UInt32(data.length)), minimumSectorCount)
        var availableSector: Sector? = nil
        var availableSectorCount = 0
        for sector in sectors {
            if case Status.Available = sector.status {
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
        var leastRecentlyUsedDate: NSDate? = nil
        for sector in sectors {
            if case let Status.Metadata(entry, _) = sector.status {
                if leastRecentlyUsedSector == nil {
                    leastRecentlyUsedSector = sector
                    leastRecentlyUsedDate = entry.date
                    continue
                }
                if entry.date.isLessThan(leastRecentlyUsedDate) {
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
    public func write(name: String, data: NSData, date: NSDate = NSDate()) throws -> Entry {
        repeat {
            if let entry = try checkWrite(name, data: data, date: date) {
                return entry
            }
        } while try eraseLeastRecentlyUsed()
        throw Error.NotEnoughSpace(name: name, length: UInt32(data.length))
    }

}