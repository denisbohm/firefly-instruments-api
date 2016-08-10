//
//  InstrumentPortal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

class InstrumentPortal: Portal {

    enum Error: ErrorType {
        case Timeout
        case Cancelled
        case UnexpectedType(type: UInt64, packet: Packet)
    }

    struct Packet {
        let type: UInt64
        let content: NSData
    }

    let device: USBHIDDevice
    let identifier: UInt64
    var writeQueue = [Packet]()
    var readQueue = [Packet]()
    var timeout: NSTimeInterval = 10.0
    let readCondition = NSCondition()
    let readData = NSMutableData()

    init(device: USBHIDDevice, identifier: UInt64) {
        self.device = device
        self.identifier = identifier
    }

    func send(type: UInt64, content: NSData) {
        writeQueue.append(Packet(type: type, content: content))
    }

    func write() throws {
        if writeQueue.isEmpty {
            return
        }
        
        let binary = Binary(byteOrder: .LittleEndian)
        while !writeQueue.isEmpty {
            let packet = writeQueue.first!
            binary.writeVarUInt(identifier)
            binary.writeVarUInt(packet.type)
            binary.writeVarUInt(UInt64(packet.content.length))
            binary.write(packet.content)
            writeQueue.removeFirst()
        }
        let detourSource = DetourSource(size: 64, data: binary.data)
        while let subdata = detourSource.next() {
            if NSThread.currentThread().cancelled {
                throw Error.Cancelled
            }
            try device.setReport(subdata)
        }
    }

    func received(type: UInt64, content: NSData) {
        readCondition.lock()
        defer {
            readCondition.broadcast()
            readCondition.unlock()
        }

        readQueue.append(Packet(type: type, content: content))
    }

    func read(type type: UInt64) throws -> NSData {
        try write()

        let deadline = NSDate(timeIntervalSinceNow: timeout)
        while true {
            readCondition.lock()
            defer {
                readCondition.broadcast()
                readCondition.unlock()
            }

            if let packet = readQueue.first {
                if packet.type != type {
                    throw Error.UnexpectedType(type: type, packet: packet)
                }
                readQueue.removeFirst()
                return packet.content
            }

            if (!readCondition.waitUntilDate(deadline)) {
                break
            }
        }
        throw Error.Timeout
    }
    
    func movePacketContentFromReadQueueToData() {
        for packet in readQueue {
            readData.appendData(packet.content)
        }
        readQueue.removeAll()
    }

    func read(length length: Int) throws -> NSData {
        try write()

        assert(length >= 0)
        let deadline = NSDate(timeIntervalSinceNow: timeout)
        while true {
            readCondition.lock()
            defer {
                readCondition.broadcast()
                readCondition.unlock()
            }

            movePacketContentFromReadQueueToData()

            if readData.length >= length {
                let range = NSRange(location: 0, length: length)
                let data = readData.subdataWithRange(range)
                readData.replaceBytesInRange(range, withBytes: nil, length: 0)
                return data
            }

            if (!readCondition.waitUntilDate(deadline)) {
                break
            }
        }
        throw Error.Timeout
    }

    func read() -> NSData {
        readCondition.lock()
        defer {
            readCondition.broadcast()
            readCondition.unlock()
        }

        movePacketContentFromReadQueueToData()

        let data = NSMutableData(data: readData)
        readData.length = 0
        return data
    }
    
}