//
//  FireflyDesignI2cm.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public class fd_i2cm_bus_t: Heap.Struct {
    
    public let instance: Heap.Primitive<UInt32>
    public let scl: fd_gpio_t
    public let sda: fd_gpio_t
    public let frequency: Heap.Primitive<UInt32>
    
    public init(instance: UInt32, scl: fd_gpio_t, sda: fd_gpio_t, frequency: UInt32) {
        self.instance = Heap.Primitive(value: instance)
        self.scl = scl
        self.sda = sda
        self.frequency = Heap.Primitive(value: frequency)
        super.init(fields: [self.instance, self.scl, self.sda, self.frequency])
    }
    
}

public class fd_i2cm_device_t: Heap.Struct {
    
    public let bus: Heap.Reference<fd_i2cm_bus_t>
    public let address: Heap.Primitive<UInt32>
    
    public init(bus: fd_i2cm_bus_t, address: UInt32) {
        self.bus = Heap.Reference(object: bus)
        self.address = Heap.Primitive(value: address)
        super.init(fields: [self.bus, self.address])
    }
    
}

public enum fd_i2cm_direction_t: UInt8 {
    case rx = 0
    case tx = 1
}

public class fd_i2cm_transfer_t: Heap.Struct {
    
    public let direction: Heap.Primitive<UInt8>
    public let bytes: Heap.Reference<Heap.ByteArray>
    public let byte_count: Heap.Primitive<UInt32>
    
    public init(direction: fd_i2cm_direction_t, bytes: Heap.ByteArray) {
        self.direction = Heap.Primitive(value: direction.rawValue)
        self.bytes = Heap.Reference(object: bytes)
        self.byte_count = Heap.Primitive(value: UInt32(bytes.value.count))
        super.init(fields: [self.direction, self.bytes, self.byte_count])
    }
    
}

public class fd_i2cm_io_t: Heap.Struct {
    
    public let transfers: Heap.Reference<fd_i2cm_transfer_t>
    public let transfer_count: Heap.Primitive<UInt32>
    public let completion_callback: Heap.Primitive<UInt32>
    
    public init(transfers: [fd_i2cm_transfer_t]) {
        self.transfers = Heap.Reference(object: transfers[0])
        self.transfer_count = Heap.Primitive(value: UInt32(transfers.count))
        self.completion_callback = Heap.Primitive(value: 0)
        super.init(fields: [self.transfers, self.transfer_count, self.completion_callback])
    }
    
}

public protocol FireflyDesignI2cm: FireflyDesignSwdRpc {
    
    func fd_i2cm_bus_enable(bus: fd_i2cm_bus_t) throws
    
    func fd_i2cm_bus_disable(bus: fd_i2cm_bus_t) throws
    
    func fd_i2cm_device_io(heap: Heap, device: fd_i2cm_device_t, io: fd_i2cm_io_t) throws -> Bool

}

extension FireflyDesignI2cm {

    public func fd_i2cm_bus_enable(bus: fd_i2cm_bus_t) throws {
        let _ = try run(function: "fd_i2cm_bus_enable", r0: bus.heapAddress!)
    }
    
    public func fd_i2cm_bus_disable(bus: fd_i2cm_bus_t) throws {
        let _ = try run(function: "fd_i2cm_bus_disable", r0: bus.heapAddress!)
    }
    
    public func fd_i2cm_device_io(heap: Heap, device: fd_i2cm_device_t, io: fd_i2cm_io_t) throws -> Bool {
        let resultR0 = try run(function: "fd_i2cm_device_io", r0: device.heapAddress!, r1: io.heapAddress!)
        return resultR0 != 0
    }

}
