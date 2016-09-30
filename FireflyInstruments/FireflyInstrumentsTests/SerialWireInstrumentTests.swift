//
//  SerialWireInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

@testable import FireflyInstruments
import XCTest

class SerialWireInstrumentTests: XCTestCase {

    func testSends() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(instrumentManager: instrumentManager, portal: portal)

        XCTAssertEqual(serialWireInstrument.identifier, 1)

        try serialWireInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        try serialWireInstrument.setEnabled(true)
        portal.assertDidSend(9, content: 0x01)
        portal.assertDidWrite()

        try serialWireInstrument.setEnabled(false)
        portal.assertDidSend(9, content: 0x00)
        portal.assertDidWrite()

        serialWireInstrument.setIndicator(true)
        portal.assertDidSend(0x01, content: 0b001, 0b001)
        serialWireInstrument.setIndicator(false)
        portal.assertDidSend(0x01, content: 0b001, 0b000)

        serialWireInstrument.setReset(true)
        portal.assertDidSend(0x01, content: 0b010, 0b010)
        serialWireInstrument.setReset(false)
        portal.assertDidSend(0x01, content: 0b010, 0b000)

        serialWireInstrument.turnToWrite()
        portal.assertDidSend(0x01, content: 0b100, 0b100)
        serialWireInstrument.turnToRead()
        portal.assertDidSend(0x01, content: 0b100, 0b000)

        serialWireInstrument.shiftOutBits(0b00000001, bitCount: 1)
        portal.assertDidSend(0x03, content: 0, 0b00000001)
        
        let bytes = [1, 2, 3] as [UInt8]
        serialWireInstrument.shiftOutData(Data(bytes))
        portal.assertDidSend(0x04, content: 2, 1, 2, 3)

        serialWireInstrument.shift(inBits: 2)
        portal.assertDidSend(0x05, content: 1)

        serialWireInstrument.shift(inData: 2)
        portal.assertDidSend(0x06, content: 1)

        portal.queueRead(2, content: 1)
        let value = try serialWireInstrument.getReset()
        portal.assertDidSend(2, content: 1)
        portal.assertDidReadType(type: 2)
        XCTAssert(value)

        portal.queueRead(10, content: 0)
        try serialWireInstrument.writeMemory(9, data: Data(bytes))
        portal.assertDidSend(10, content: 9, 3, 1, 2, 3)
        portal.assertDidReadType(type: 10)

        portal.queueRead(10, content: 1)
        XCTAssertThrowsError(try serialWireInstrument.writeMemory(9, data: Data(bytes)))
        portal.assertDidSend(10, content: 9, 3, 1, 2, 3)
        portal.assertDidReadType(type: 10)

        portal.queueRead(11, content: 0, 1, 2, 3)
        let memory = try serialWireInstrument.readMemory(9, length: UInt32(bytes.count))
        portal.assertDidSend(11, content: 9, 3)
        portal.assertDidReadType(type: 11)
        XCTAssertEqual(memory, Data(bytes))

        portal.queueRead(11, content: 1)
        XCTAssertThrowsError(try serialWireInstrument.readMemory(9, length: UInt32(bytes.count)))
        portal.assertDidSend(11, content: 9, 3)
        portal.assertDidReadType(type: 11)

        portal.queueRead(11, content: 0, 1)
        XCTAssertThrowsError(try serialWireInstrument.readMemory(9, length: UInt32(bytes.count)))
        portal.assertDidSend(11, content: 9, 3)
        portal.assertDidReadType(type: 11)

        portal.queueRead(12, content: 0)
        try serialWireInstrument.writeFromStorage(9, length: 8, storageIdentifier: 7, storageAddress: 6)
        portal.assertDidSend(12, content: 9, 8, 7, 6)
        portal.assertDidReadType(type: 12)

        portal.queueRead(12, content: 1)
        XCTAssertThrowsError(try serialWireInstrument.writeFromStorage(9, length: 8, storageIdentifier: 7, storageAddress: 6))
        portal.assertDidSend(12, content: 9, 8, 7, 6)
        portal.assertDidReadType(type: 12)

        portal.queueRead(13, content: 0)
        try serialWireInstrument.compareToStorage(9, length: 8, storageIdentifier: 7, storageAddress: 6)
        portal.assertDidSend(13, content: 9, 8, 7, 6)
        portal.assertDidReadType(type: 13)

        portal.queueRead(13, content: 1)
        XCTAssertThrowsError(try serialWireInstrument.compareToStorage(9, length: 8, storageIdentifier: 7, storageAddress: 6))
        portal.assertDidSend(13, content: 9, 8, 7, 6)
        portal.assertDidReadType(type: 13)
    }

    func testWrite() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(instrumentManager: instrumentManager, portal: portal)
        try serialWireInstrument.write()
        portal.assertDidWrite()
    }

    func testRead() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(instrumentManager: instrumentManager, portal: portal)

        let _ = try serialWireInstrument.read()
        portal.assertDidRead()

        let _ = try serialWireInstrument.read(withByteCount: 1)
        portal.assertDidSend(7)
        portal.assertDidWrite()
        portal.assertDidReadWithLength(1)
    }

    class TestThread: Foundation.Thread {

        let condition = NSCondition()
        let closure: () throws -> ()
        var error: Error? = nil
        var done = false

        init(closure: @escaping () throws -> ()) {
            self.closure = closure
        }

        override func main() {
            cancel()
            do {
                try closure()
            } catch (let error) {
                self.error = error
            }
            condition.lock()
            defer {
                condition.broadcast()
                condition.unlock()
            }
            done = true
        }

        func run() {
            start()
            let deadline = Date(timeIntervalSinceNow: 10)
            while (deadline as NSDate).isGreaterThan(Date()) {
                condition.lock()
                defer {
                    condition.unlock()
                }
                if done {
                    return
                }
            }
        }
        
    }
    
    func testReadCancel() {
        let portal = InstrumentPortal(device: USBHIDDevice(), identifier: 0)
        portal.send(0, content: Data())
        let thread = TestThread() {
            try portal.write()
        }
        thread.run()
        XCTAssert(thread.error != nil)
    }

    func testDetect() throws {
        let instrumentManager = MockInstrumentManager()
        let portal = MockPortal()
        let serialWireInstrument = SerialWireInstrument(instrumentManager: instrumentManager, portal: portal)

        var detect: ObjCBool = true
        try serialWireInstrument.getDetect(&detect)
        XCTAssertFalse(detect.boolValue)
    }

}
