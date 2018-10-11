//
//  FireflyDesignLsm6dsl.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public struct FireflyDesignLsm6dslConstants {
    
    public static let ODR_POWER_DOWN = UInt8(0b0000)
    public static let ODR_13_HZ      = UInt8(0b0001)
    public static let ODR_26_HZ      = UInt8(0b0010)
    public static let ODR_52_HZ      = UInt8(0b0011)
    public static let ODR_104_HZ     = UInt8(0b0100)
    public static let ODR_208_HZ     = UInt8(0b0101)
    public static let ODR_416_HZ     = UInt8(0b0110)
    public static let ODR_833_HZ     = UInt8(0b0111)
    public static let ODR_1660_HZ    = UInt8(0b1000)
    public static let ODR_3330_HZ    = UInt8(0b1001)
    public static let ODR_6660_HZ    = UInt8(0b1010)
    
    public static let XFS_2_G  = UInt8(0b00)
    public static let XFS_4_G  = UInt8(0b10)
    public static let XFS_8_G  = UInt8(0b11)
    public static let XFS_16_G = UInt8(0b01)
    
    public static let XBWF_50_HZ  = UInt8(0b11)
    public static let XBWF_100_HZ = UInt8(0b10)
    public static let XBWF_200_HZ = UInt8(0b01)
    public static let XBWF_400_HZ = UInt8(0b00)
    
    public static let GFS_125_DPS  = UInt8(0b001)
    public static let GFS_245_DPS  = UInt8(0b000)
    public static let GFS_500_DPS  = UInt8(0b010)
    public static let GFS_1000_DPS = UInt8(0b100)
    public static let GFS_2000_DPS = UInt8(0b110)
    
    public static let GHPF_DISABLED_HZ = UInt8(0b000)
    public static let GHPF_P0081_HZ    = UInt8(0b100)
    public static let GHPF_P0324_HZ    = UInt8(0b101)
    public static let GHPF_2P07_HZ     = UInt8(0b110)
    public static let GHPF_16P32_HZ    = UInt8(0b111)
    
}

public class fd_lsm6dsl_configuration_t: Heap.Struct {
    
    public let fifo_threshold: Heap.Primitive<UInt16>
    public let fifo_output_data_rate: Heap.Primitive<UInt8>
    public let accelerometer_output_data_rate: Heap.Primitive<UInt8>
    public let accelerometer_low_power: Heap.Primitive<Bool>
    public let accelerometer_full_scale_range: Heap.Primitive<UInt8>
    public let accelerometer_bandwidth_filter: Heap.Primitive<UInt8>
    public let accelerometer_enable: Heap.Primitive<Bool>
    public let gyro_output_data_rate: Heap.Primitive<UInt8>
    public let gyro_low_power: Heap.Primitive<Bool>
    public let gyro_full_scale_range: Heap.Primitive<UInt8>
    public let gyro_high_pass_filter: Heap.Primitive<UInt8>
    public let gyro_enable: Heap.Primitive<Bool>
    
    public init(
        fifo_threshold: UInt16,
        fifo_output_data_rate: UInt8,
        accelerometer_output_data_rate: UInt8,
        accelerometer_low_power: Bool,
        accelerometer_full_scale_range: UInt8,
        accelerometer_bandwidth_filter: UInt8,
        accelerometer_enable: Bool,
        gyro_output_data_rate: UInt8,
        gyro_low_power: Bool,
        gyro_full_scale_range: UInt8,
        gyro_high_pass_filter: UInt8,
        gyro_enable: Bool
        ) {
        self.fifo_threshold = Heap.Primitive(value: fifo_threshold)
        self.fifo_output_data_rate = Heap.Primitive(value: fifo_output_data_rate)
        self.accelerometer_output_data_rate = Heap.Primitive(value: accelerometer_output_data_rate)
        self.accelerometer_low_power = Heap.Primitive(value: accelerometer_low_power)
        self.accelerometer_full_scale_range = Heap.Primitive(value: accelerometer_full_scale_range)
        self.accelerometer_bandwidth_filter = Heap.Primitive(value: accelerometer_bandwidth_filter)
        self.accelerometer_enable = Heap.Primitive(value: accelerometer_enable)
        self.gyro_output_data_rate = Heap.Primitive(value: gyro_output_data_rate)
        self.gyro_low_power = Heap.Primitive(value: gyro_low_power)
        self.gyro_full_scale_range = Heap.Primitive(value: gyro_full_scale_range)
        self.gyro_high_pass_filter = Heap.Primitive(value: gyro_high_pass_filter)
        self.gyro_enable = Heap.Primitive(value: gyro_enable)
        super.init(fields: [
            self.fifo_threshold,
            self.fifo_output_data_rate,
            self.accelerometer_output_data_rate,
            self.accelerometer_low_power,
            self.accelerometer_full_scale_range,
            self.accelerometer_bandwidth_filter,
            self.accelerometer_enable,
            self.gyro_output_data_rate,
            self.gyro_low_power,
            self.gyro_full_scale_range,
            self.gyro_high_pass_filter,
            self.gyro_enable
            ])
    }
    
}

public class fd_lsm6dsl_accelerometer_sample_t: Heap.Struct {
    
    public let x: Heap.Primitive<Int16>
    public let y: Heap.Primitive<Int16>
    public let z: Heap.Primitive<Int16>
    
    public init(x: Int16, y: Int16, z: Int16) {
        self.x = Heap.Primitive(value: x)
        self.y = Heap.Primitive(value: y)
        self.z = Heap.Primitive(value: z)
        super.init(fields: [self.x, self.y, self.z])
    }
    
}

public class fd_lsm6dsl_gyro_sample_t: Heap.Struct {
    
    public let x: Heap.Primitive<Int16>
    public let y: Heap.Primitive<Int16>
    public let z: Heap.Primitive<Int16>
    
    public init(x: Int16, y: Int16, z: Int16) {
        self.x = Heap.Primitive(value: x)
        self.y = Heap.Primitive(value: y)
        self.z = Heap.Primitive(value: z)
        super.init(fields: [self.x, self.y, self.z])
    }
    
}

public class fd_lsm6dsl_sample_t: Heap.Struct {
    
    public let accelerometer: fd_lsm6dsl_accelerometer_sample_t
    public let gyro: fd_lsm6dsl_gyro_sample_t
    
    public init(accelerometer: fd_lsm6dsl_accelerometer_sample_t, gyro: fd_lsm6dsl_gyro_sample_t) {
        self.accelerometer = accelerometer
        self.gyro = gyro
        super.init(fields: [self.accelerometer, self.gyro])
    }
    
}

public protocol FireflyDesignLsm6dsl: FireflyDesignSpim {
    
    func fd_lsm6dsl_read(device: fd_spim_device_t, location: UInt8) throws -> UInt8
    
    func fd_lsm6ds3_configure(device: fd_spim_device_t, configuration: fd_lsm6dsl_configuration_t) throws
    
    func fd_lsm6dsl_read_fifo_samples(device: fd_spim_device_t, samples: fd_lsm6dsl_sample_t, sample_count: UInt32) throws -> Int
    
}

extension FireflyDesignLsm6dsl {
    
    public func fd_lsm6dsl_read(device: fd_spim_device_t, location: UInt8) throws -> UInt8 {
        let resultR0 = try run(function: "fd_lsm6dsl_read", r0: device.heapAddress!, r1: UInt32(location))
        return UInt8(truncatingIfNeeded: resultR0)
    }

    public func fd_lsm6ds3_configure(device: fd_spim_device_t, configuration: fd_lsm6dsl_configuration_t) throws {
        let _ = try run(function: "fd_lsm6ds3_configure", r0: device.heapAddress!, r1: configuration.heapAddress!)
    }

    public func fd_lsm6dsl_read_fifo_samples(device: fd_spim_device_t, samples: fd_lsm6dsl_sample_t, sample_count: UInt32) throws -> Int {
        let resultR0 = try run(function: "fd_lsm6dsl_read_fifo_samples", r0: device.heapAddress!, r1: samples.heapAddress!, r2: sample_count)
        return Int(resultR0)
    }

    public func dumpLSM6DSL(device: fd_spim_device_t) throws {
        NSLog("LSM6DSL Registers")
        for i in 0 ... 0x7f {
            let value = try fd_spim_device_sequence_tx1_rx1(device: device, tx_byte: UInt8(0x80 | i))
            NSLog("  %02x = %02x", i, value)
        }
    }
    
    public func isInRange(_ value: Int16, _ min: Int16, _ max: Int16) -> Bool {
        return (min <= value) && (value <= max)
    }
    
    public func lsm6dslTest(presenter: Presenter, heap: Heap, device: fd_spim_device_t) throws {
        presenter.show(message: "testing LSM6DSL...")

        try fd_spim_bus_enable(bus: device.bus.object)
        
        let whoAmI = try fd_lsm6dsl_read(device: device, location: 0x0f)
        presenter.show(message: String(format: "lsm6dsl whoAmI %02x", whoAmI), pass: whoAmI == 0x6a)
        
        let subheap = Heap()
        subheap.setBase(address: heap.freeAddress)
        let configuration = fd_lsm6dsl_configuration_t(
            fifo_threshold: 32,
            fifo_output_data_rate: FireflyDesignLsm6dslConstants.ODR_13_HZ,
            accelerometer_output_data_rate: FireflyDesignLsm6dslConstants.ODR_13_HZ,
            accelerometer_low_power: true,
            accelerometer_full_scale_range: FireflyDesignLsm6dslConstants.XFS_2_G,
            accelerometer_bandwidth_filter: FireflyDesignLsm6dslConstants.XBWF_50_HZ,
            accelerometer_enable: true,
            gyro_output_data_rate: FireflyDesignLsm6dslConstants.ODR_13_HZ,
            gyro_low_power: true,
            gyro_full_scale_range: FireflyDesignLsm6dslConstants.GFS_125_DPS,
            gyro_high_pass_filter: FireflyDesignLsm6dslConstants.GHPF_DISABLED_HZ,
            gyro_enable: true
        )
        subheap.addRoot(object: configuration)
        let sample = fd_lsm6dsl_sample_t(
            accelerometer: fd_lsm6dsl_accelerometer_sample_t(x: 0, y: 0, z: 0),
            gyro: fd_lsm6dsl_gyro_sample_t(x: 0, y: 0, z: 0)
        )
        subheap.addRoot(object: sample)
        subheap.locate()
        subheap.encode()
        try serialWireDebug?.writeMemory(subheap.baseAddress, data: subheap.data)
        try fd_lsm6ds3_configure(device: device, configuration: configuration)
        Thread.sleep(forTimeInterval: 1.0)
        
        let count = try fd_lsm6dsl_read_fifo_samples(device: device, samples: sample, sample_count: 1)
        subheap.data = try serialWireDebug!.readMemory(subheap.baseAddress, length: UInt32(subheap.data.count))
        try subheap.decode()
        let pass =
            (count > 0) && (count < 100) &&
            isInRange(sample.accelerometer.x.value, -400, 400) &&
            isInRange(sample.accelerometer.y.value, -400, 400) &&
            isInRange(sample.accelerometer.z.value, -9000, -8000) &&
            isInRange(sample.gyro.x.value, -400, 400) &&
            isInRange(sample.gyro.y.value, -400, 400) &&
            isInRange(sample.gyro.z.value, -400, 400)
        presenter.show(message: String(format: "n=\(count) ax=%d, ay=%d, az=%d, gx=%d, gy=%d, gz=%d",
            sample.accelerometer.x.value,
            sample.accelerometer.y.value,
            sample.accelerometer.z.value,
            sample.gyro.x.value,
            sample.gyro.y.value,
            sample.gyro.z.value
        ), pass: pass)
    }

}
