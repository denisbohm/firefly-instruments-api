//
//  Binary.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public enum ByteOrder: CFByteOrder {
    case LittleEndian = 1
    case BigEndian = 2
}

extension NSData {

    public func reversed() -> NSData {
        let data = NSMutableData(data: self)
        let sourcePointer = UnsafePointer<UInt8>(self.bytes)
        let sourceBytes = UnsafeBufferPointer<UInt8>(start: sourcePointer, count: self.length)
        let pointer = UnsafeMutablePointer<UInt8>(data.mutableBytes)
        let bytes = UnsafeMutableBufferPointer<UInt8>(start: pointer, count: data.length)
        var sourceIndex = self.length - 1
        for i in 0 ..< self.length {
            bytes[i] = sourceBytes[sourceIndex]
            sourceIndex -= 1
        }
        return data
    }
    
}

extension NSMutableData {

    public func reverse() {
        let pointer = UnsafeMutablePointer<UInt8>(mutableBytes)
        let bytes = UnsafeMutableBufferPointer<UInt8>(start: pointer, count: length)
        var sourceIndex = self.length - 1
        for i in 0 ..< self.length / 2 {
            let temporary = bytes[i]
            bytes[i] = bytes[sourceIndex]
            bytes[sourceIndex] = temporary
            sourceIndex -= 1
        }
    }
    
}

public func isByteOrderNative(byteOrder: ByteOrder) -> Bool {
    return CFByteOrderGetCurrent() == byteOrder.rawValue
}

public func fromBinaryNative<T: IntegerLiteralConvertible>(data: NSData) -> T {
    var value: T = 0
    data.getBytes(&value, length: sizeof(T))
    return value
}

public func toBinaryNative<T>(value: T) -> NSData {
    guard let data = NSMutableData(capacity: sizeof(T)) else {
        return NSData()
    }
    var value = value
    data.appendBytes(&value, length: sizeof(T))
    return data
}

public protocol BinaryConvertable {

    static func fromBinary(data: NSData) -> Self
    static func toBinary(value: Self) -> NSData
    
}

extension UInt8: BinaryConvertable {

    public static func fromBinary(data: NSData) -> UInt8 {
        return fromBinaryNative(data)
    }

    public static func toBinary(value: UInt8) -> NSData {
        return toBinaryNative(value)
    }

}

extension UInt16: BinaryConvertable {

    public static func fromBinary(data: NSData) -> UInt16 {
        return fromBinaryNative(data)
    }

    public static func toBinary(value: UInt16) -> NSData {
        return toBinaryNative(value)
    }

}

extension UInt32: BinaryConvertable {

    public static func fromBinary(data: NSData) -> UInt32 {
        return fromBinaryNative(data)
    }
    
    public static func toBinary(value: UInt32) -> NSData {
        return toBinaryNative(value)
    }

}

extension UInt64: BinaryConvertable {

    public static func fromBinary(data: NSData) -> UInt64 {
        return fromBinaryNative(data)
    }

    public static func toBinary(value: UInt64) -> NSData {
        return toBinaryNative(value)
    }

}

extension Float32: BinaryConvertable {

    public static func fromBinary(data: NSData) -> Float32 {
        return fromBinaryNative(data)
    }
    
    public static func toBinary(value: Float32) -> NSData {
        return toBinaryNative(value)
    }

}

extension Float64: BinaryConvertable {

    public static func fromBinary(data: NSData) -> Float64 {
        return fromBinaryNative(data)
    }

    public static func toBinary(value: Float64) -> NSData {
        return toBinaryNative(value)
    }

}

extension Float80: BinaryConvertable {

    public static func fromBinary(data: NSData) -> Float80 {
        return fromBinaryNative(data)
    }

    public static func toBinary(value: Float80) -> NSData {
        return toBinaryNative(value)
    }

}

public class Binary {

    public enum Error: ErrorType {
        case InvalidLength
        case OutOfBounds
        case OutOfMemory
        case InvalidRepresentation
    }

    let buffer: NSMutableData
    public var swapBytes: Bool
    var readIndex: Int = 0

    public var length: Int {
        get {
            return buffer.length
        }
    }
    
    public var remainingLength: Int {
        get {
            return buffer.length - readIndex
        }
    }

    public var data: NSData {
        get {
            return NSData(data: buffer)
        }
    }

    public var remainingData: NSData {
        get {
            return buffer.subdataWithRange(NSRange(location: readIndex, length: buffer.length - readIndex))
        }
    }

    public init(swapBytes: Bool) {
        self.buffer = NSMutableData()
        self.swapBytes = swapBytes
    }

    public convenience init(byteOrder: ByteOrder) {
        self.init(swapBytes: !isByteOrderNative(byteOrder))
    }

    public init(data: NSData, swapBytes: Bool) {
        self.buffer = NSMutableData(data: data)
        self.swapBytes = swapBytes
    }

    public convenience init(data: NSData, byteOrder: ByteOrder) {
        self.init(data: data, swapBytes: !isByteOrderNative(byteOrder))
    }

    public static func unpack<B: BinaryConvertable>(data: NSData, index: Int, swapBytes: Bool) throws -> B {
        if data.length < (index + sizeof(B)) {
            throw Error.OutOfBounds
        }
        let subdata = data.subdataWithRange(NSRange(location: index, length: sizeof(B)))
        let ordered = swapBytes ? subdata.reversed() : subdata
        let value = B.fromBinary(ordered)
        return value
    }

    public static func unpackFloat16(data: NSData, index: Int, swapBytes: Bool) throws -> Float {
        if data.length < (index + sizeof(UInt16)) {
            throw Error.OutOfBounds
        }
        let bitPattern: UInt16 = try unpack(data, index: index, swapBytes: swapBytes)
        let value = fd_ieee754_float_from_half(bitPattern)
        return value
    }

    public static func pack<B: BinaryConvertable>(value: B, swapBytes: Bool) -> NSData {
        let data = B.toBinary(value)
        let ordered = swapBytes ? data.reversed() : data
        return ordered
    }

    public static func packFloat16(value: Float, swapBytes: Bool) -> NSData {
        let bitPattern = fd_ieee754_half_from_float(value)
        let data = pack(bitPattern, swapBytes: swapBytes)
        return data
    }

    func checkRemaining(length: Int) throws {
        if length < 0 {
            throw Error.InvalidLength
        }
        if remainingLength < length {
            throw Error.OutOfBounds
        }
    }

    public func read<B: BinaryConvertable>() throws -> B {
        try checkRemaining(sizeof(B))
        let value: B = try Binary.unpack(buffer, index: readIndex, swapBytes: swapBytes)
        readIndex += sizeof(B)
        return value
    }

    public func read(length length: Int) throws -> NSData {
        try checkRemaining(length)
        let data = buffer.subdataWithRange(NSRange(location: readIndex, length: length))
        readIndex += length
        return data
    }

    public func readFloat16() throws -> Float {
        try checkRemaining(sizeof(UInt16))
        let value = try Binary.unpackFloat16(buffer, index: readIndex, swapBytes: swapBytes)
        readIndex += sizeof(UInt16)
        return value
    }

    public func readVarUInt() throws -> UInt64 {
        var value: UInt64 = 0
        for index in 0 ..< remainingLength {
            let byte: UInt8 = try read()
            value |= UInt64(byte & 0x7f) << UInt64(index * 7)
            if (byte & 0x80) == 0 {
                return value
            }
            if (value & 0xe000000000000000) != 0 {
                throw Error.InvalidRepresentation
            }
        }
        throw Error.OutOfBounds
    }

    public func readVarInt() throws -> Int64 {
        let zigZag = try readVarUInt()
        let bitPattern: UInt64
        if (zigZag & 0x0000000000000001) != 0 {
            bitPattern = ((zigZag & 0xfffffffffffffffe) >> 1) ^ 0xffffffffffffffff
        } else {
            bitPattern = (zigZag & 0xfffffffffffffffe) >> 1
        }
        return Int64(bitPattern: bitPattern)
    }

    public func read() throws -> String {
        let length = try readVarUInt()
        let data = try read(length: Int(length))
        guard let string = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
            throw Error.InvalidRepresentation
        }
        return string
    }

    public func write<B: BinaryConvertable>(value: B) {
        let data = Binary.pack(value, swapBytes: swapBytes)
        buffer.appendData(data)
    }

    public func write(data: NSData) {
        buffer.appendData(data)
    }

    public func writeFloat16(value: Float) {
        let data = Binary.packFloat16(value, swapBytes: swapBytes)
        buffer.appendData(data)
    }

    public func writeVarUInt(value: UInt64) {
        var remainder = value
        while remainder != 0 {
            if remainder <= 0x7f {
                break
            }
            var byte = UInt8(truncatingBitPattern: remainder) | 0x80
            buffer.appendBytes(&byte, length: 1)
            remainder = (remainder & 0xffffffffffffff80) >> 7
        }
        var byte = UInt8(truncatingBitPattern: remainder)
        buffer.appendBytes(&byte, length: 1)
    }

    public func writeVarInt(value: Int64) {
        let bitPattern = UInt64(bitPattern: value)
        let zigZag: UInt64
        if value < 0 {
            zigZag = ((bitPattern & 0x7fffffffffffffff) << 1) ^ 0xffffffffffffffff
        } else {
            zigZag = (bitPattern & 0x7fffffffffffffff) << 1
        }
        writeVarUInt(zigZag)
    }

    public func write(value: String) {
        let bytes = Array(value.utf8) as [UInt8]
        let data = NSData(bytes: bytes, length: bytes.count)
        writeVarUInt(UInt64(bytes.count))
        write(data)
    }

}