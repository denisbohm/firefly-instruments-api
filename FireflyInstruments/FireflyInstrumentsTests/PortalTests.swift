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

        let data = Data(bytes: [1, 2, 3])
        instrumentPortal.send(0x20, content: data)
        try instrumentPortal.write()
        device.assertDidSetReport(0, 6, 1, 0x20, 3, 1, 2, 3)
    }

    func testRead() throws {
        let device = MockUSBHIDDevice()
        let instrumentPortal = InstrumentPortal(device: device, identifier: 1)

        instrumentPortal.received(UInt64(1), content: Data())
        let empty = try instrumentPortal.read(type: UInt64(1))
        XCTAssert(empty.count == 0)

        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            Thread.sleep(forTimeInterval: 0.1)
            instrumentPortal.received(UInt64(1), content: NSMutableData(length: 1)! as Data)
        }
        let one = try instrumentPortal.read(type: UInt64(1))
        XCTAssert(one.count == 1)

        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            Thread.sleep(forTimeInterval: 0.1)
            instrumentPortal.received(UInt64(1), content: NSMutableData(length: 2)! as Data)
        }
        let two = try instrumentPortal.read(length: 2)
        XCTAssert(two.count == 2)

        instrumentPortal.timeout = 0.001
        XCTAssertThrowsError(try instrumentPortal.read(type: UInt64(1)))

        instrumentPortal.received(UInt64(2), content: Data())
        XCTAssertThrowsError(try instrumentPortal.read(type: UInt64(1)))
    }
    
}
