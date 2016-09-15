//
//  Binary.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public enum ByteOrder: CFByteOrder {
    case littleEndian = 1
    case bigEndian = 2
}

public func isByteOrderNative(_ byteOrder: ByteOrder) -> Bool {
    return CFByteOrderGetCurrent() == byteOrder.rawValue
}

public func fromBinaryNative<T: ExpressibleByIntegerLiteral>(_ data: Data) -> T {
    var value: T = 0
    (data as NSData).getBytes(&value, length: MemoryLayout<T>.size)
    return value
}

public func toBinaryNative<T>(_ value: T) -> Data {
    guard let data = NSMutableData(capacity: MemoryLayout<T>.size) else {
        return Data()
    }
    var value = value
    data.append(&value, length: MemoryLayout<T>.size)
    return data as Data
}

public protocol BinaryConvertable {

    static func fromBinary(_ data: Data) -> Self
    static func toBinary(_ value: Self) -> Data
    
}

extension UInt8: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> UInt8 {
        return fromBinaryNative(data)
    }

    public static func toBinary(_ value: UInt8) -> Data {
        return toBinaryNative(value)
    }

}

extension UInt16: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> UInt16 {
        return fromBinaryNative(data)
    }

    public static func toBinary(_ value: UInt16) -> Data {
        return toBinaryNative(value)
    }

}

extension UInt32: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> UInt32 {
        return fromBinaryNative(data)
    }
    
    public static func toBinary(_ value: UInt32) -> Data {
        return toBinaryNative(value)
    }

}

extension UInt64: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> UInt64 {
        return fromBinaryNative(data)
    }

    public static func toBinary(_ value: UInt64) -> Data {
        return toBinaryNative(value)
    }

}

extension Float32: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> Float32 {
        return fromBinaryNative(data)
    }
    
    public static func toBinary(_ value: Float32) -> Data {
        return toBinaryNative(value)
    }

}

extension Float64: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> Float64 {
        return fromBinaryNative(data)
    }

    public static func toBinary(_ value: Float64) -> Data {
        return toBinaryNative(value)
    }

}

extension Float80: BinaryConvertable {

    public static func fromBinary(_ data: Data) -> Float80 {
        return fromBinaryNative(data)
    }

    public static func toBinary(_ value: Float80) -> Data {
        return toBinaryNative(value)
    }

}

open class Binary {

    public enum LocalError: Error {
        case invalidLength
        case outOfBounds
        case outOfMemory
        case invalidRepresentation
    }

    var buffer: Data
    open var swapBytes: Bool
    var readIndex: Int = 0

    open var length: Int {
        get {
            return buffer.count
        }
    }
    
    open var remainingReadLength: Int {
        get {
            return buffer.count - readIndex
        }
    }

    open var data: Data {
        get {
            return buffer
        }
    }

    open var remainingData: Data {
        get {
            return buffer.subdata(in: readIndex ..< buffer.count)
        }
    }

    public init(swapBytes: Bool) {
        self.buffer = Data()
        self.swapBytes = swapBytes
    }

    public convenience init(byteOrder: ByteOrder) {
        self.init(swapBytes: !isByteOrderNative(byteOrder))
    }

    public init(data: Data, swapBytes: Bool) {
        self.buffer = data
        self.swapBytes = swapBytes
    }

    public convenience init(data: Data, byteOrder: ByteOrder) {
        self.init(data: data, swapBytes: !isByteOrderNative(byteOrder))
    }

    open static func unpack<B: BinaryConvertable>(_ data: Data, index: Int, swapBytes: Bool) throws -> B {
        if data.count < (index + MemoryLayout<B>.size) {
            throw LocalError.outOfBounds
        }
        let subdata = data.subdata(in: index ..< index + MemoryLayout<B>.size)
        let ordered = swapBytes ? Data(subdata.reversed()) : subdata
        let value = B.fromBinary(ordered)
        return value
    }

    open static func unpackFloat16(_ data: Data, index: Int, swapBytes: Bool) throws -> Float {
        if data.count < (index + MemoryLayout<UInt16>.size) {
            throw LocalError.outOfBounds
        }
        let bitPattern: UInt16 = try unpack(data, index: index, swapBytes: swapBytes)
        let value = fd_ieee754_float_from_half(bitPattern)
        return value
    }

    open static func pack<B: BinaryConvertable>(_ value: B, swapBytes: Bool) -> Data {
        let data = B.toBinary(value)
        let ordered = swapBytes ? Data(data.reversed()) : data
        return ordered
    }

    open static func packFloat16(_ value: Float, swapBytes: Bool) -> Data {
        let bitPattern = fd_ieee754_half_from_float(value)
        let data = pack(bitPattern, swapBytes: swapBytes)
        return data
    }

    func checkReadRemaining(_ length: Int) throws {
        if length < 0 {
            throw LocalError.invalidLength
        }
        if remainingReadLength < length {
            throw LocalError.outOfBounds
        }
    }

    open func read<B: BinaryConvertable>() throws -> B {
        try checkReadRemaining(MemoryLayout<B>.size)
        let value: B = try Binary.unpack(buffer as Data, index: readIndex, swapBytes: swapBytes)
        readIndex += MemoryLayout<B>.size
        return value
    }

    open func read(length: Int) throws -> Data {
        try checkReadRemaining(length)
        let data = buffer.subdata(in: readIndex ..< readIndex + length)
        readIndex += length
        return data
    }

    open func readFloat16() throws -> Float {
        try checkReadRemaining(MemoryLayout<UInt16>.size)
        let value = try Binary.unpackFloat16(buffer as Data, index: readIndex, swapBytes: swapBytes)
        readIndex += MemoryLayout<UInt16>.size
        return value
    }

    open func readVarUInt() throws -> UInt64 {
        var value: UInt64 = 0
        for index in 0 ..< remainingReadLength {
            let byte: UInt8 = try read()
            value |= UInt64(byte & 0x7f) << UInt64(index * 7)
            if (byte & 0x80) == 0 {
                return value
            }
            if (value & 0xe000000000000000) != 0 {
                throw LocalError.invalidRepresentation
            }
        }
        throw LocalError.outOfBounds
    }

    open func readVarInt() throws -> Int64 {
        let zigZag = try readVarUInt()
        let bitPattern: UInt64
        if (zigZag & 0x0000000000000001) != 0 {
            bitPattern = ((zigZag & 0xfffffffffffffffe) >> 1) ^ 0xffffffffffffffff
        } else {
            bitPattern = (zigZag & 0xfffffffffffffffe) >> 1
        }
        return Int64(bitPattern: bitPattern)
    }

    open func read() throws -> String {
        let length = try readVarUInt()
        let data = try read(length: Int(length))
        guard let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String else {
            throw LocalError.invalidRepresentation
        }
        return string
    }

    open func write<B: BinaryConvertable>(_ value: B) {
        let data = Binary.pack(value, swapBytes: swapBytes)
        buffer.append(data)
    }

    open func write(_ data: Data) {
        buffer.append(data)
    }

    open func writeFloat16(_ value: Float) {
        let data = Binary.packFloat16(value, swapBytes: swapBytes)
        buffer.append(data)
    }

    open func writeVarUInt(_ value: UInt64) {
        var remainder = value
        while remainder != 0 {
            if remainder <= 0x7f {
                break
            }
            var byte = UInt8(truncatingBitPattern: remainder) | 0x80
            buffer.append(&byte, count: 1)
            remainder = (remainder & 0xffffffffffffff80) >> 7
        }
        var byte = UInt8(truncatingBitPattern: remainder)
        buffer.append(&byte, count: 1)
    }

    open func writeVarInt(_ value: Int64) {
        let bitPattern = UInt64(bitPattern: value)
        let zigZag: UInt64
        if value < 0 {
            zigZag = ((bitPattern & 0x7fffffffffffffff) << 1) ^ 0xffffffffffffffff
        } else {
            zigZag = (bitPattern & 0x7fffffffffffffff) << 1
        }
        writeVarUInt(zigZag)
    }

    open func write(_ value: String) {
        let bytes = Array(value.utf8) as [UInt8]
        let data = Data(bytes: bytes)
        writeVarUInt(UInt64(bytes.count))
        write(data)
    }

}
