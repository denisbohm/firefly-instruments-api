//
//  DetourSourceTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/18/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class DetourSourceTests: XCTestCase {

    func testSingle() {
        let bytes = [0, 1] as [UInt8]
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let detourSource = DetourSource(size: 4, data: data)
        do {
            let next = detourSource.next()
            XCTAssert(next != nil)
            guard let subdata = next else {
                return
            }
            let detourBytes = [0, 2, 0, 1] as [UInt8]
            let detourData = Data(bytes: UnsafePointer<UInt8>(detourBytes), count: detourBytes.count)
            XCTAssertEqual(subdata, detourData)
        }
        XCTAssert(detourSource.next() == nil)
    }

    func testMultiple() {
        let bytes = [0, 1, 2] as [UInt8]
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let detourSource = DetourSource(size: 4, data: data)
        do {
            let next = detourSource.next()
            XCTAssert(next != nil)
            guard let subdata = next else {
                return
            }
            let detourBytes = [0, 3, 0, 1] as [UInt8]
            let detourData = Data(bytes: UnsafePointer<UInt8>(detourBytes), count: detourBytes.count)
            XCTAssertEqual(subdata, detourData)
        }
        do {
            let next = detourSource.next()
            XCTAssert(next != nil)
            guard let subdata = next else {
                return
            }
            let detourBytes = [1, 2] as [UInt8]
            let detourData = Data(bytes: UnsafePointer<UInt8>(detourBytes), count: detourBytes.count)
            XCTAssertEqual(subdata, detourData)
        }
        XCTAssert(detourSource.next() == nil)
    }

}
