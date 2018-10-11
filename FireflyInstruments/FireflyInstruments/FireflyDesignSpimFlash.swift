//
//  FireflyDesignSpimFlash.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public class fd_spi_flash_information_t: Heap.Struct {
    
    public let manufacturer_id: Heap.Primitive<UInt8>
    public let device_id: Heap.Primitive<UInt8>
    public let memory_type: Heap.Primitive<UInt8>
    public let memory_capacity: Heap.Primitive<UInt8>
    
    public init(manufacturer_id: UInt8, device_id: UInt8, memory_type: UInt8, memory_capacity: UInt8) {
        self.manufacturer_id = Heap.Primitive(value: manufacturer_id)
        self.device_id = Heap.Primitive(value: device_id)
        self.memory_type = Heap.Primitive(value: memory_type)
        self.memory_capacity = Heap.Primitive(value: memory_capacity)
        super.init(fields: [self.manufacturer_id, self.device_id, self.memory_type, self.memory_capacity])
    }
    
}

public protocol FireflyDesignSpimFlash: FireflyDesignSwdRpc {
    
    func fd_spi_flash_get_information(heap: Heap, device: fd_spim_device_t) throws -> fd_spi_flash_information_t
    
}

extension FireflyDesignSpimFlash {
    
    public func fd_spi_flash_get_information(heap: Heap, device: fd_spim_device_t) throws -> fd_spi_flash_information_t {
        let subheap = Heap()
        subheap.setBase(address: heap.freeAddress)
        let information = fd_spi_flash_information_t(manufacturer_id: 0, device_id: 0, memory_type: 0, memory_capacity: 0)
        subheap.addRoot(object: information)
        subheap.locate()
        subheap.encode()
        let _ = try run(function: "fd_spi_flash_get_information", r0: device.heapAddress!, r1: information.heapAddress!)
        subheap.data = try serialWireDebug!.readMemory(subheap.baseAddress, length: UInt32(subheap.data.count))
        try subheap.decode()
        return information
    }

}
