//
//  InstrumentPortal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

class InstrumentPortal: Portal {

    enum LocalError: Error {
        case timeout
        case cancelled
        case unexpectedType(type: UInt64, packet: Packet)
    }

    struct Packet {
        let type: UInt64
        let content: Data
    }

    let device: USBHIDDevice
    let identifier: UInt64
    var writeQueue = [Packet]()
    var readQueue = [Packet]()
    var timeout: TimeInterval = 10.0
    let readCondition = NSCondition()
    let readData = NSMutableData()

    init(device: USBHIDDevice, identifier: UInt64) {
        self.device = device
        self.identifier = identifier
    }

    func send(_ type: UInt64, content: Data) {
        writeQueue.append(Packet(type: type, content: content))
    }

    func write() throws {
        if writeQueue.isEmpty {
            return
        }
        
        let binary = Binary(byteOrder: .littleEndian)
        while !writeQueue.isEmpty {
            let packet = writeQueue.first!
            binary.writeVarUInt(identifier)
            binary.writeVarUInt(packet.type)
            binary.writeVarUInt(UInt64(packet.content.count))
            binary.write(packet.content)
            writeQueue.removeFirst()
        }
        let detourSource = DetourSource(size: 64, data: binary.data)
        while let subdata = detourSource.next() {
            if Thread.current.isCancelled {
                throw LocalError.cancelled
            }
            try device.setReport(subdata)
        }
    }

    func received(_ type: UInt64, content: Data) {
        readCondition.lock()
        defer {
            readCondition.broadcast()
            readCondition.unlock()
        }

        readQueue.append(Packet(type: type, content: content))
    }

    func read(type: UInt64) throws -> Data {
        try write()

        let deadline = Date(timeIntervalSinceNow: timeout)
        while true {
            readCondition.lock()
            defer {
                readCondition.broadcast()
                readCondition.unlock()
            }

            if let packet = readQueue.first {
                if packet.type != type {
                    throw LocalError.unexpectedType(type: type, packet: packet)
                }
                readQueue.removeFirst()
                return packet.content
            }

            if (!readCondition.wait(until: deadline)) {
                break
            }
        }
        throw LocalError.timeout
    }
    
    func movePacketContentFromReadQueueToData() {
        for packet in readQueue {
            readData.append(packet.content)
        }
        readQueue.removeAll()
    }

    func read(length: Int) throws -> Data {
        try write()

        assert(length >= 0)
        let deadline = Date(timeIntervalSinceNow: timeout)
        while true {
            readCondition.lock()
            defer {
                readCondition.broadcast()
                readCondition.unlock()
            }

            movePacketContentFromReadQueueToData()

            if readData.length >= length {
                let range = NSRange(location: 0, length: length)
                let data = readData.subdata(with: range)
                readData.replaceBytes(in: range, withBytes: nil, length: 0)
                return data
            }

            if (!readCondition.wait(until: deadline)) {
                break
            }
        }
        throw LocalError.timeout
    }

    func read() -> Data {
        readCondition.lock()
        defer {
            readCondition.broadcast()
            readCondition.unlock()
        }

        movePacketContentFromReadQueueToData()

        let data = NSData(data: readData as Data) as Data
        readData.length = 0
        return data
    }
    
}
