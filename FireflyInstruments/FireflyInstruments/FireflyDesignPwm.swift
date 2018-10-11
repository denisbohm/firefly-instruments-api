//
//  FireflyDesignPwm.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

public class fd_pwm_module_t: Heap.Struct {
    
    public let instance: Heap.Primitive<UInt32>
    public let frequency: Heap.Primitive<Float32>
    
    public init(instance: UInt32, frequency: Float32) {
        self.instance = Heap.Primitive(value: instance)
        self.frequency = Heap.Primitive(value: frequency)
        super.init(fields: [self.instance, self.frequency])
    }
    
}

public class fd_pwm_channel_t: Heap.Struct {
    
    public let module: Heap.Reference<fd_pwm_module_t>
    public let instance: Heap.Primitive<UInt32>
    public let gpio: fd_gpio_t
    
    public init(module: fd_pwm_module_t, instance: UInt32, gpio: fd_gpio_t) {
        self.module = Heap.Reference(object: module)
        self.instance = Heap.Primitive(value: instance)
        self.gpio = gpio
        super.init(fields: [self.module, self.instance, self.gpio])
    }
    
}

public protocol FireflyDesignPwm: FireflyDesignSwdRpc {
  
    func fd_pwm_initialize(heap: Heap) throws -> (module: fd_pwm_module_t, channel: fd_pwm_channel_t)
    
    func fd_pwm_module_enable(module: fd_pwm_module_t) throws
    
    func fd_pwm_channel_start(channel: fd_pwm_channel_t, intensity: Float32) throws

}

extension FireflyDesignPwm {
    
    public func fd_pwm_initialize(heap: Heap) throws -> (module: fd_pwm_module_t, channel: fd_pwm_channel_t) {
        let PWM0: UInt32 = 0x4001C000
        let module = fd_pwm_module_t(instance: PWM0, frequency: 32000.0)
        heap.addRoot(object: module)
        let moduleCount: UInt32 = 1
        
        let channel = fd_pwm_channel_t(module: module, instance: 0, gpio: fd_gpio_t(port: 0, pin: 20))
        heap.addRoot(object: channel)
        
        heap.locate()
        heap.encode()
        try serialWireDebug?.writeMemory(heap.baseAddress, data: heap.data)
        let _ = try run(function: "fd_pwm_initialize", r0: module.heapAddress!, r1: moduleCount)
        return (module: module, channel: channel)
    }
    
    public func fd_pwm_module_enable(module: fd_pwm_module_t) throws {
        let _ = try run(function: "fd_pwm_module_enable", r0: module.heapAddress!)
    }

    public func fd_pwm_channel_start(channel: fd_pwm_channel_t, intensity: Float32) throws {
        try serialWireDebug?.writeRegister(UInt16(CORTEX_M_REGISTER_S0), value:intensity.bitPattern)
        let _ = try run(function: "fd_pwm_channel_start", r0: channel.heapAddress!)
    }

}
