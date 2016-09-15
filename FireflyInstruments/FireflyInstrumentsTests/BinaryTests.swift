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

    func checkPackUnpack<B>(_ value: B, swapBytes: Bool) throws where B:BinaryConvertable, B:Equatable {
        let data = Binary.pack(value, swapBytes: swapBytes)
        let result: B = try Binary.unpack(data, index: 0, swapBytes: swapBytes)
        XCTAssert(result == value)
    }

    func checkPackUnpackFloat16(_ value: Float, swapBytes: Bool) throws {
        let data = Binary.packFloat16(value, swapBytes: swapBytes)
        let result: Float = try Binary.unpackFloat16(data, index: 0, swapBytes: swapBytes)
        XCTAssert(result == value)
    }

    func checkPackUnpack(_ swapBytes: Bool) throws {
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

    func checkWriteRead<B>(_ value: B, swapBytes: Bool) throws where B:BinaryConvertable, B:Equatable {
        let binary = Binary(swapBytes: swapBytes)
        binary.write(value)
        let result: B = try binary.read()
        XCTAssert(result == value)
        let binary2 = Binary(data: binary.data, swapBytes: swapBytes)
        let result2: B = try binary2.read()
        XCTAssert(result2 == value)
    }

    func checkWriteReadFloat16(_ value: Float, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeFloat16(value)
        let result: Float = try binary.readFloat16()
        XCTAssert(result == value)
        let binary2 = Binary(data: binary.data, swapBytes: swapBytes)
        let result2: Float = try binary2.readFloat16()
        XCTAssert(result2 == value)
    }

    func checkWriteReadData(_ data: Data, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.write(data)
        let result = try binary.read(length: data.count)
        XCTAssertEqual(result, data)
    }

    func checkWriteReadVarUInt(_ value: UInt64, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeVarUInt(value)
        let result = try binary.readVarUInt()
        XCTAssert(result == value)
    }

    func checkWriteReadVarInt(_ value: Int64, swapBytes: Bool) throws {
        let binary = Binary(swapBytes: swapBytes)
        binary.writeVarInt(value)
        let result = try binary.readVarInt()
        XCTAssert(result == value)
    }

    func checkWriteRead(_ swapBytes: Bool) throws {
        try checkWriteRead(3 as UInt8, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt16, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt32, swapBytes: swapBytes)
        try checkWriteRead(3 as UInt64, swapBytes: swapBytes)
        try checkWriteReadFloat16(3.5 as Float, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float32, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float64, swapBytes: swapBytes)
        try checkWriteRead(3.5 as Float80, swapBytes: swapBytes)
        let data = Data(bytes: UnsafePointer<UInt8>([1, 2] as [UInt8]), count: 2)
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
        let data = Data(bytes: UnsafePointer<UInt8>([1, 2] as [UInt8]), count: 2)
        let remainingHalf = Data(bytes: UnsafePointer<UInt8>([2] as [UInt8]), count: 1)
        let binary = Binary(data: data, swapBytes: false)
        let _: UInt8 = try binary.read()
        XCTAssertEqual(binary.length, 2)
        XCTAssertEqual(binary.remainingReadLength, 1)
        let allData = binary.data
        XCTAssertEqual(allData, data)
        let remainingData = binary.remainingData
        XCTAssertEqual(remainingData, remainingHalf)
    }

    func testByteOrder() {
        let binaryLittleEndian = Binary(byteOrder: .littleEndian)
        XCTAssert(!binaryLittleEndian.swapBytes)

        let binaryBigEndian = Binary(byteOrder: .bigEndian)
        XCTAssert(binaryBigEndian.swapBytes)

        let data = Data(bytes: UnsafePointer<UInt8>([1] as [UInt8]), count: 1)

        let binaryDataLittleEndian = Binary(data: data, byteOrder: .littleEndian)
        XCTAssert(!binaryDataLittleEndian.swapBytes)

        let binaryDataBigEndian = Binary(data: data, byteOrder: .bigEndian)
        XCTAssert(binaryDataBigEndian.swapBytes)
    }

    func testInvalidLength() {
        let binary = Binary(swapBytes: false)
        XCTAssertThrowsError(try binary.read(length: -1))
    }

    func testOutOfBounds() {
        let data = Data()
        XCTAssertThrowsError(try Binary.unpack(data, index: 0, swapBytes: false) as UInt8)
        XCTAssertThrowsError(try Binary.unpackFloat16(data, index: 0, swapBytes: false))

        let binary = Binary(swapBytes: false)
        XCTAssertThrowsError(try binary.read(length: 1))
        XCTAssertThrowsError(try binary.readVarUInt())
    }

    func testInvalidRepresentation() {
        let bytes = [UInt8](repeating: 0xff, count: 10)
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let binary = Binary(data: data, swapBytes: false)
        XCTAssertThrowsError(try binary.readVarUInt())
    }

    // how can we test NSData out of memory errors? -denis

}
