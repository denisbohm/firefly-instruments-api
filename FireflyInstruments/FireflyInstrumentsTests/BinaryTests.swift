//
//  BinaryTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/15/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class BinaryTests: XCTestCase {

    func testReversing() {
        let ascendingBytes = [1, 2, 3, 4] as [UInt8]
        let ascending = NSData(bytes: ascendingBytes, length: ascendingBytes.count)
        let descendingBytes = [4, 3, 2, 1] as [UInt8]
        let descending = NSData(bytes: descendingBytes, length: descendingBytes.count)

        let reversed = ascending.reversed()
        XCTAssert(reversed.isEqualToData(descending))

        let reverse = NSMutableData(data: ascending)
        reverse.reverse()
        XCTAssert(reverse.isEqualToData(descending))
    }

    func checkPackUnpack<B where B:BinaryConvertable, B:Equatable>(value: B, swapBytes: Bool) throws {
        let data = Binary.pack(value, swapBytes: swapBytes)
        let result: B = try Binary.unpack(data, index: 0, swapBytes: swapBytes)
        XCTAssert(result == value)
    }

    func checkPackUnpackFloat16(value: Float, swapBytes: Bool) throws {
        let data = Binary.packFloat16(value, swapBytes: swapBytes)
        let result: Float = try Binary.unpackFloat16(data, index: 0, swapBytes: swapBytes)
        XCTAssert(result == value)
    }

    func checkPackUnpack(swapBytes: Bool) throws {
        try checkPackUnpack(3 as UInt8, swapBytes: swapBytes)
        try checkPackUnpack(3 as UInt16, swapBytes: swapBytes)
        try checkPackUnpack(3 as UInt32, swapBytes: swapBytes)
        try checkPackUnpack(3 as UInt64, swapBytes: swapBytes)
        try checkPackUnpackFloat16(3.5 as Float, swapBytes: swapBytes)
        try checkPackUnpack(3.5 as Float32, swapBytes: swapBytes)
        try checkPackUnpack(3.5 as Float64, swapBytes: swapBytes)
        try checkPackUnpack(3.5 as Float80, swapBytes: swapBytes)
    }

    func testPackUnpack() throws {
        try checkPackUnpack(true)
        try checkPackUnpack(false)
    }

    func checkWriteRead<B where B:BinaryConvertable, B:Equatable>(value: B, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.write(value)
        let result: B = try binary.read()
        XCTAssert(result == value)
        let binary2 = Binary(data: binary.data, swapBytes: swapBytes)
        let result2: B = try binary2.read()
        XCTAssert(result2 == value)
    }

    func checkWriteReadFloat16(value: Float, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeFloat16(value)
        let result: Float = try binary.readFloat16()
        XCTAssert(result == value)
        let binary2 = Binary(data: binary.data, swapBytes: swapBytes)
        let result2: Float = try binary2.readFloat16()
        XCTAssert(result2 == value)
    }

    func checkWriteReadData(data: NSData, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.write(data)
        let result = try binary.read(length: data.length)
        XCTAssert(result.isEqualToData(data))
    }

    func checkWriteReadVarUInt(value: UInt64, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeVarUInt(value)
        let result = try binary.readVarUInt()
        XCTAssert(result == value)
    }

    func checkWriteReadVarInt(value: Int64, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeVarInt(value)
        let result = try binary.readVarInt()
        XCTAssert(result == value)
    }

    func checkWriteRead(swapBytes: Bool) throws {
        try checkWriteRead(3 as UInt8, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt16, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt32, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt64, swapBytes: swapBytes)
        try checkWriteReadFloat16(3.5 as Float, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float32, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float64, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float80, swapBytes: swapBytes)
        let data = NSData(bytes: [1, 2] as [UInt8], length: 2)
        try checkWriteReadData(data, swapBytes: swapBytes)
        try checkWriteReadVarUInt(128, swapBytes: swapBytes)
        try checkWriteReadVarInt(128, swapBytes: swapBytes)
        try checkWriteReadVarInt(-128, swapBytes: swapBytes)
    }

    func testWriteRead() throws {
        try checkWriteRead(false)
        try checkWriteRead(true)
    }

    func testComputedVars() throws {
        let data = NSData(bytes: [1, 2] as [UInt8], length: 2)
        let remainingHalf = NSData(bytes: [2] as [UInt8], length: 1)
        let binary = Binary(data: data, swapBytes: false)
        let _: UInt8 = try binary.read()
        XCTAssert(binary.length == 2)
        XCTAssert(binary.remainingLength == 1)
        let allData = binary.data
        XCTAssert(allData.isEqualToData(data))
        let remainingData = binary.remainingData
        XCTAssert(remainingData.isEqualToData(remainingHalf))
    }

    func testByteOrder() {
        let binaryLittleEndian = Binary(byteOrder: .LittleEndian)
        XCTAssert(!binaryLittleEndian.swapBytes)

        let binaryBigEndian = Binary(byteOrder: .BigEndian)
        XCTAssert(binaryBigEndian.swapBytes)

        let data = NSData(bytes: [1] as [UInt8], length: 1)

        let binaryDataLittleEndian = Binary(data: data, byteOrder: .LittleEndian)
        XCTAssert(!binaryDataLittleEndian.swapBytes)

        let binaryDataBigEndian = Binary(data: data, byteOrder: .BigEndian)
        XCTAssert(binaryDataBigEndian.swapBytes)
    }

    func testInvalidLength() {
        let binary = Binary(swapBytes: false)
        XCTAssertThrowsError(try binary.read(length: -1))
    }

    func testOutOfBounds() {
        let data = NSData()
        XCTAssertThrowsError(try Binary.unpack(data, index: 0, swapBytes: false) as UInt8)
        XCTAssertThrowsError(try Binary.unpackFloat16(data, index: 0, swapBytes: false))

        let binary = Binary(swapBytes: false)
        XCTAssertThrowsError(try binary.read(length: 1))
        XCTAssertThrowsError(try binary.readVarUInt())
    }

    func testInvalidRepresentation() {
        let bytes = [UInt8](count: 10, repeatedValue: 0xff)
        let data = NSData(bytes: bytes, length: bytes.count)
        let binary = Binary(data: data, swapBytes: false)
        XCTAssertThrowsError(try binary.readVarUInt())
    }

    // how can we test NSData out of memory errors? -denis

}
