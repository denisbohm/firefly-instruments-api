//
//  FileSystem.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 8/27/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

/*
 instrument storage file system

 - intended to store a small number of files (~10)
 - each files data is stored in contiguous locations
 - separate files are stored in their own sectors
 - can set a minimum allocation size (wastes space, but minimizes fragmentation)
 - LRU policy

 */

public class FileSystem {

    public enum Error: ErrorType {
        case InvalidName(String)
        case DuplicateName(String)
    }

    public struct Hash {
        let data: [UInt8] // 20 bytes
    }

    static let OpenMarker: UInt8 = 0xff
    static let UsedMarker: UInt8 = 0x0f
    static let FreeMarker: UInt8 = 0x00

    public struct Entry {
        let location: UInt32
        let marker: UInt8
        let name: String
        let length: UInt32
        let hash: NSData
        let date: NSDate
        let address: UInt32
        let allocation: UInt32
    }

    public let storageInstrument: StorageInstrument

    public var size = 2^21
    public var pageSize = 2^8
    public var sectorSize = 2^12
    public var minimumAllocationSize = 2^18

    let entrySize = 2^8

    var entries = [Entry]()

    public init(storageInstrument: StorageInstrument) {
        self.storageInstrument = storageInstrument
    }

    public func readIndex() throws {
        let data = try storageInstrument.read(0, length: UInt32(sectorSize))
        var location = 0
        while location < sectorSize {
            let entry: Entry
            let binary = Binary(data: data.subdataWithRange(NSRange(location: location, length: entrySize)), byteOrder: ByteOrder.LittleEndian)
            let marker: UInt8 = try binary.read()
            /*
            if marker != FileSystem.UsedMarker {
                entry = Entry(location: location, marker: marker, name: "", length: 0, hash: NSData(), date: NSDate(), address: 0, allocation: 0)
            } else {
                let length: UInt32 = try binary.read()
                let hash: NSData = try binary.read(length: 20)
                let name: String = try binary.read()
            }
 */

            location += entrySize
        }
    }

    public func get(name: String) -> Entry? {
        return nil
    }

    // Allocate a file system entry.
    // The entry is stored in flash before this returns.
    // This will free other (least recently used) entries to make space if needed.
    public func allocate(name: String, length: UInt32, hash: Hash, date: NSDate = NSDate()) throws -> Entry {
        throw Error.InvalidName(name)
    }

    public func free(entry: Entry) {

    }

}