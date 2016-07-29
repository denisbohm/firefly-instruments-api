//
//  MockPortal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import Foundation
import XCTest

class MockPortal: Portal {

    enum Call {
        case send(UInt64, NSData)
        case write()
        case readWithLength(Int)
        case read()
    }

    struct Read {
        let type: UInt64
        let content: NSData
    }

    let identifier: UInt64 = 1
    var timeout: NSTimeInterval = 10.0

    var calls = [Call]()

    var reads = [Read]()

    var assertIndex = 0

    func nextAssertCall() -> Call? {
        XCTAssert(calls.count > assertIndex)
        if calls.count <= assertIndex {
            return nil
        }
        let call = calls[assertIndex]
        assertIndex += 1
        return call
    }

    func assertDidSend(type: UInt64, content: [UInt8]) {
        guard let call = nextAssertCall() else {
            return
        }
        guard case let Call.send(callType, callContent) = call else {
            XCTFail("unexpected func called")
            return
        }
        XCTAssert(callType == type)
        let data = NSData(bytes: content, length: content.count)
        XCTAssert(callContent.isEqualToData(data))
    }

    func assertDidSend(type: UInt64, content: UInt8...) {
        assertDidSend(type, content: content)
    }

    func assertDidSend(type: UInt64, content: NSData) {
        let bytes = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(content.bytes), count: content.length)) as [UInt8]
        assertDidSend(type, content: bytes)
    }

    func send(type: UInt64, content: NSData) {
        calls.append(.send(type, content))
    }

    func assertDidWrite() {
        guard let call = nextAssertCall() else {
            return
        }
        guard case Call.write = call else {
            XCTFail("unexpected func called")
            return
        }
    }

    func write() throws {
        calls.append(.write())
    }

    func queueRead(type: UInt64, content: NSData) {
        reads.append(Read(type: type, content: content))
    }

    func received(type: UInt64, content: NSData) {
    }

    func read(type type: UInt64) throws -> NSData {
        guard let read = reads.first else {
            return NSData()
        }
        reads.removeFirst()
        return read.content
    }

    func assertDidReadWithLength(length: Int) {
        guard let call = nextAssertCall() else {
            return
        }
        guard case let Call.readWithLength(callLength) = call else {
            XCTFail("unexpected func called")
            return
        }
        XCTAssert(callLength == length)
    }

    func read(length length: Int) throws -> NSData {
        calls.append(.readWithLength(length))
        return NSData()
    }

    func assertDidRead() {
        guard let call = nextAssertCall() else {
            return
        }
        guard case Call.read = call else {
            XCTFail("unexpected func called")
            return
        }
    }

    func read() -> NSData {
        calls.append(.read())
        return NSData()
    }

}