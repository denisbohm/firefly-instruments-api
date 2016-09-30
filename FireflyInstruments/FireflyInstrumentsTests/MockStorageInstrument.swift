//
//  MockStorageInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 9/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
import FireflyInstruments

class MockStorageInstrument: StorageInstrument {

    var memory: [UInt8]

    init() {
        memory = [UInt8](repeating: 0xff as UInt8, count: 1 << 22)

        super.init(instrumentManager: MockInstrumentManager(), portal: MockPortal())
    }

    override func reset() throws {
    }

    override func erase(_ address: UInt32, length: UInt32) throws {
        for index in Int(address) ..< Int(address + length) {
            memory[index] = 0xff
        }
    }

    override func write(_ address: UInt32, data: Data) throws {
        var array = [UInt8](repeating: 0, count: data.count)
        (data as NSData).getBytes(&array, length: data.count)
        memory.replaceSubrange(Int(address) ..< Int(address) + data.count, with: array)
    }

    override func read(_ address: UInt32, length: UInt32, sublength: UInt32 = 0, substride: UInt32 = 0) throws -> Data {
        let address: Int = Int(address)
        let length: Int = Int(length)
        var sublength: Int = Int(sublength)
        let substride: Int = Int(substride)
        if sublength == 0 {
            sublength = length
        }

        var index = address
        var amount = 0
        let data = NSMutableData()
        while amount < length {
            let subdata = Array(memory[index ..< index + sublength])
            data.append(subdata, length: subdata.count)
            amount += sublength
            index += substride
        }
        return data as Data
    }

    override func hash(_ address: UInt32, length: UInt32) throws -> Data {
        let subarray = Array(memory[Int(address) ..< Int(address + length)])
        let subdata = Data(bytes: UnsafePointer<UInt8>(subarray), count: subarray.count)
        return FDCryptography.sha1(subdata)
    }

}
