//
//  FireflyDesignGpio.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

public class fd_gpio_t: Heap.Struct {
    
    public var port: Heap.Primitive<UInt32>
    public var pin: Heap.Primitive<UInt32>
    
    public init(port: UInt32, pin: UInt32) {
        self.port = Heap.Primitive<UInt32>(value: port)
        self.pin = Heap.Primitive<UInt32>(value: pin)
        super.init(fields: [self.port, self.pin])
    }
    
}

public protocol FireflyDesignGpio: FireflyDesignSwdRpc {

    func fd_gpio_configure_input(gpio: fd_gpio_t) throws
    
    func fd_gpio_configure_input_pull_up(gpio: fd_gpio_t) throws
    
    func fd_gpio_configure_output(gpio: fd_gpio_t) throws
    
    func fd_gpio_configure_output_open_drain(gpio: fd_gpio_t) throws
    
    func fd_gpio_set(gpio: fd_gpio_t, value: Bool) throws
    
    func fd_gpio_get(gpio: fd_gpio_t) throws -> Bool

}

extension FireflyDesignGpio {
    
    public func fd_gpio_configure_input(gpio: fd_gpio_t) throws {
        let _ = try run(function: "fd_gpio_configure_input", r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    public func fd_gpio_configure_input_pull_up(gpio: fd_gpio_t) throws {
        let _ = try run(function: "fd_gpio_configure_input_pull_up", r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    public func fd_gpio_configure_output(gpio: fd_gpio_t) throws {
        let _ = try run(function: "fd_gpio_configure_output", r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    public func fd_gpio_configure_output_open_drain(gpio: fd_gpio_t) throws {
        let _ = try run(function: "fd_gpio_configure_output_open_drain", r0: gpio.port.value, r1: gpio.pin.value)
    }
    
    public func fd_gpio_set(gpio: fd_gpio_t, value: Bool) throws {
        let _ = try run(function: "fd_gpio_set", r0: gpio.port.value, r1: gpio.pin.value, r2: value ? 1 : 0)
    }
    
    public func fd_gpio_get(gpio: fd_gpio_t) throws -> Bool {
        let r0 = try run(function: "fd_gpio_get", r0: gpio.port.value, r1: gpio.pin.value)
        return r0 != 0
    }

}
