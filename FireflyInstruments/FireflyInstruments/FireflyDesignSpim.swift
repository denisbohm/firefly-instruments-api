//
//  FireflyDesignSpim.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public class fd_spim_bus_t: Heap.Struct {
    
    public let instance: Heap.Primitive<UInt32>
    public let sclk: fd_gpio_t
    public let mosi: fd_gpio_t
    public let miso: fd_gpio_t
    public let frequency: Heap.Primitive<UInt32>
    public let mode: Heap.Primitive<UInt32>
    
    public init(instance: UInt32, sclk: fd_gpio_t, mosi: fd_gpio_t, miso: fd_gpio_t, frequency: UInt32, mode: UInt32) {
        self.instance = Heap.Primitive<UInt32>(value: instance)
        self.sclk = sclk
        self.mosi = mosi
        self.miso = miso
        self.frequency = Heap.Primitive<UInt32>(value: frequency)
        self.mode = Heap.Primitive<UInt32>(value: mode)
        super.init(fields: [self.instance, self.sclk, self.mosi, self.miso, self.frequency, self.mode])
    }
    
}

public class fd_spim_device_t: Heap.Struct {
    
    public let bus: Heap.Reference<fd_spim_bus_t>
    public let csn: fd_gpio_t
    
    public init(bus: fd_spim_bus_t, csn: fd_gpio_t) {
        self.bus = Heap.Reference(object: bus)
        self.csn = csn
        super.init(fields: [self.bus, self.csn])
    }
    
}

public protocol FireflyDesignSpim: FireflyDesignSwdRpc {

    func fd_spim_bus_enable(bus: fd_spim_bus_t) throws
    
    func fd_spim_device_sequence_tx1_rx1(device: fd_spim_device_t, tx_byte: UInt8) throws -> UInt8

}

extension FireflyDesignSpim {
    
    public func fd_spim_bus_enable(bus: fd_spim_bus_t) throws {
        let _ = try run(function: "fd_spim_bus_enable", r0: bus.heapAddress!)
    }

    public func fd_spim_device_sequence_tx1_rx1(device: fd_spim_device_t, tx_byte: UInt8) throws -> UInt8 {
        let resultR0 = try run(function: "fd_spim_device_sequence_tx1_rx1", r0: device.heapAddress!, r1: UInt32(tx_byte))
        return UInt8(truncatingIfNeeded: resultR0)
    }
    
}
