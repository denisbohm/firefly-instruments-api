//
//  FireflyDesignBq25120.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

public struct FireflyDesignBq25120Constants {
    public static let STATUS_SHIPMODE_REG: UInt8 =     0x00
    public static let FAULTS_FAULTMASKS_REG: UInt8 =   0x01
    public static let TSCONTROL_STATUS_REG: UInt8 =    0x02
    public static let FASTCHARGE_CTL_REG: UInt8 =      0x03
    public static let CHARGETERM_I2CADDR_REG: UInt8 =  0x04
    public static let BATT_VOLTAGE_CTL_REG: UInt8 =    0x05
    public static let SYSTEM_VOUT_CTL_REG: UInt8 =     0x06
    public static let LOADSW_LDO_CTL_REG: UInt8 =      0x07
    public static let PUSH_BTN_CTL_REG: UInt8 =        0x08
    public static let ILIMIT_UVLO_CTL_REG: UInt8 =     0x09
    public static let BATT_VOLT_MONITOR_REG: UInt8 =   0x0A
    public static let VIN_DPM_TIMER_REG: UInt8 =       0x0B
}

public protocol FireflyDesignBq25120: FireflyDesignSwdRpc {
    
    func fd_bq25120_write(heap: Heap, device: fd_i2cm_device_t, location: UInt8, value: UInt8) throws -> Bool
    
    func fd_bq25120_read(heap: Heap, device: fd_i2cm_device_t, location: UInt8) throws -> (result: Bool, value: UInt8)
    
    func fd_bq25120_set_system_voltage(device: fd_i2cm_device_t, voltage: Float) throws -> Bool
        
    func fd_bq25120_read_battery_voltage(device: fd_i2cm_device_t, heap: Heap) throws -> (result: Bool, voltage: Float)
    
}

extension FireflyDesignBq25120 {

    public func fd_bq25120_write(heap: Heap, device: fd_i2cm_device_t, location: UInt8, value: UInt8) throws -> Bool {
        let resultR0 = try run(function: "fd_bq25120_write", r0: device.heapAddress!, r1: UInt32(location), r2: UInt32(value))
        return resultR0 != 0
    }
    
    public func fd_bq25120_read(heap: Heap, device: fd_i2cm_device_t, location: UInt8) throws -> (result: Bool, value: UInt8) {
        try serialWireDebug?.writeMemory(heap.freeAddress, value: 0x5a5a5a5a)
        let resultR0 = try run(function: "fd_i2cm_device_sequence_tx1_rx1", r0: device.heapAddress!, r1: UInt32(location), r2: heap.freeAddress)
        let data = try serialWireDebug?.readMemory(heap.freeAddress, length: 1)
        return (result: resultR0 != 0, value: data![0])
    }
    
    public func fd_bq25120_set_system_voltage(device: fd_i2cm_device_t, voltage: Float) throws -> Bool {
        try serialWireDebug?.writeRegister(UInt16(CORTEX_M_REGISTER_S0), value:voltage.bitPattern)
        let resultR0 = try run(function: "fd_bq25120_set_system_voltage", r0: device.heapAddress!)
        return resultR0 != 0
    }
    
    public func fd_bq25120_read_battery_voltage(device: fd_i2cm_device_t, heap: Heap) throws -> (result: Bool, voltage: Float) {
        #if false
            let resultR0 = try run(function: "fd_bq25120_read_battery_voltage", r0: device.heapAddress!)
            let result = resultR0 != 0
            if !result {
                return (result: false, voltage: 0.0)
            }
            var voltageBitPattern: UInt32 = 0
            try serialWireDebug?.readRegister(UInt16(CORTEX_M_REGISTER_S0), value: &voltageBitPattern)
            let voltage = Float(bitPattern: voltageBitPattern)
        #endif
        
        let (result1, r1) = try fd_bq25120_read(heap: heap, device: device, location: FireflyDesignBq25120Constants.BATT_VOLTAGE_CTL_REG)
        if !result1 {
            return (result: false, voltage: 0.0)
        }
        var battery_regulation_voltage: Float = 3.6 + Float(r1 >> 1) * 0.01
        let result2 = try fd_bq25120_write(heap: heap, device: device, location: FireflyDesignBq25120Constants.BATT_VOLT_MONITOR_REG, value: 0b10000000)
        if !result2 {
            return (result: false, voltage: 0.0)
        }
        Thread.sleep(forTimeInterval: 0.002)
        let (result3, r3) = try fd_bq25120_read(heap: heap, device: device, location: FireflyDesignBq25120Constants.BATT_VOLT_MONITOR_REG)
        if !result3 {
            return (result: false, voltage: 0.0)
        }
        let range: Float = 0.6 + 0.1 * Float((r3 >> 5) & 0b11)
        let threshold: Float
        switch (r3 >> 2) & 0b111 {
        case 0b111:
            threshold = 0.08
        case 0b110:
            threshold = 0.06
        case 0b011:
            threshold = 0.04
        case 0b010:
            threshold = 0.02
        case 0b001:
            threshold = 0.00
        default:
            battery_regulation_voltage = 0.00
            threshold = 0.00
        }
        let voltage: Float = battery_regulation_voltage * (range + threshold)
        return (result: true, voltage: voltage)
    }
    
}
