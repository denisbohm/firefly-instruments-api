//
//  PortalTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

@testable import FireflyInstruments
import XCTest

class PortalTests: XCTestCase {

    func testWrite() throws {
        let device = MockUSBHIDDevice()
        let instrumentPortal = InstrumentPortal(device: device, identifier: 1)

        let bytes = [1, 2, 3] as [UInt8]
        let data = NSData(bytes: bytes, length: bytes.count)
        instrumentPortal.send(0x20, content: data)
        try instrumentPortal.write()
        device.assertDidSetReport(0, 6, 1, 0x20, 3, 1, 2, 3)
    }

    func testRead() throws {
        let device = MockUSBHIDDevice()
        let instrumentPortal = InstrumentPortal(device: device, identifier: 1)

        instrumentPortal.received(UInt64(1), content: NSData())
        let empty = try instrumentPortal.read(type: UInt64(1))
        XCTAssert(empty.length == 0)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            NSThread.sleepForTimeInterval(0.1)
            instrumentPortal.received(UInt64(1), content: NSMutableData(length: 1)!)
        }
        let one = try instrumentPortal.read(type: UInt64(1))
        XCTAssert(one.length == 1)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            NSThread.sleepForTimeInterval(0.1)
            instrumentPortal.received(UInt64(1), content: NSMutableData(length: 2)!)
        }
        let two = try instrumentPortal.read(length: 2)
        XCTAssert(two.length == 2)

        instrumentPortal.timeout = 0.001
        XCTAssertThrowsError(try instrumentPortal.read(type: UInt64(1)))

        instrumentPortal.received(UInt64(2), content: NSData())
        XCTAssertThrowsError(try instrumentPortal.read(type: UInt64(1)))
    }
    
}
