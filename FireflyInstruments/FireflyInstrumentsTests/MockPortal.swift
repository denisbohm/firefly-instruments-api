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
        case send(UInt64, Data)
        case write()
        case readWithLength(Int)
        case readType(UInt64)
        case read()
    }

    struct Read {
        let type: UInt64
        let content: Data
    }

    let identifier: UInt64 = 1
    var timeout: TimeInterval = 10.0

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

    func assertDidSend(_ type: UInt64, content: [UInt8]) {
        guard let call = nextAssertCall() else {
            return
        }
        guard case let Call.send(callType, callContent) = call else {
            XCTFail("unexpected func called")
            return
        }
        XCTAssert(callType == type)
        let data = Data(bytes: UnsafePointer<UInt8>(content), count: content.count)
        XCTAssert(callContent == data)
    }

    func assertDidSend(_ type: UInt64, content: UInt8...) {
        assertDidSend(type, content: content)
    }

    func assertDidSend(_ type: UInt64, content: Data) {
        let bytes = Array(UnsafeBufferPointer(start: (content as NSData).bytes.bindMemory(to: UInt8.self, capacity: content.count), count: content.count)) as [UInt8]
        assertDidSend(type, content: bytes)
    }

    func send(_ type: UInt64, content: Data) {
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

    func queueRead(_ type: UInt64, content: Data) {
        reads.append(Read(type: type, content: content))
    }

    func queueRead(_ type: UInt64, content: [UInt8]) {
        queueRead(type, content: Data(bytes: UnsafePointer<UInt8>(content), count: content.count))
    }

    func queueRead(_ type: UInt64, content: UInt8...) {
        queueRead(type, content: content)
    }

    func received(_ type: UInt64, content: Data) {
    }

    func assertDidReadType(type: UInt64) {
        guard let call = nextAssertCall() else {
            return
        }
        guard case let Call.readType(callType) = call else {
            XCTFail("unexpected func called")
            return
        }
        XCTAssert(callType == type)
    }

    func read(type: UInt64) throws -> Data {
        calls.append(.readType(type))
        guard let read = reads.first else {
            return Data()
        }
        reads.removeFirst()
        return read.content
    }

    func assertDidReadWithLength(_ length: Int) {
        guard let call = nextAssertCall() else {
            return
        }
        guard case let Call.readWithLength(callLength) = call else {
            XCTFail("unexpected func called")
            return
        }
        XCTAssert(callLength == length)
    }

    func read(length: Int) throws -> Data {
        calls.append(.readWithLength(length))
        return Data()
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

    func read() -> Data {
        calls.append(.read())
        return Data()
    }

}
