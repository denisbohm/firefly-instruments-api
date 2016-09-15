//
//  InstrumentManagerTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug
@testable import FireflyInstruments
import XCTest

class InstrumentManagerTests: XCTestCase {

    func queueDiscovery(_ device: MockUSBHIDDevice, category: String) {
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0) // ordinal
        let categoryLength = category.lengthOfBytes(using: String.Encoding.utf8)
        binary.writeVarUInt(UInt64(6 + categoryLength)) // length
        binary.writeVarUInt(0) // instrument identifier
        binary.writeVarUInt(1) // type
        binary.writeVarUInt(UInt64(3 + categoryLength)) // data length
        binary.writeVarUInt(1) // instrument count
        binary.write(category) // instrument category
        binary.writeVarUInt(1) // instrument identifier
        device.queue(binary.data)
    }

    func getInstrument<T>(_ category: String, _: T.Type) throws -> T {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: category)
        try instrumentManager.discoverInstruments()
        return try instrumentManager.getInstrument("\(category)1")
    }

    func testGetInstruments() throws {
        let _ = try getInstrument("Battery", BatteryInstrument.self)
        let _ = try getInstrument("Color", ColorInstrument.self)
        let _ = try getInstrument("Current", CurrentInstrument.self)
        let _ = try getInstrument("Indicator", IndicatorInstrument.self)
        let _ = try getInstrument("Relay", RelayInstrument.self)
        let _ = try getInstrument("SerialWire", SerialWireInstrument.self)
        let _ = try getInstrument("Storage", StorageInstrument.self)
        let _ = try getInstrument("Voltage", VoltageInstrument.self)
    }

    func testGetUnknownPortal() throws {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: "Battery")
        try instrumentManager.discoverInstruments()
        XCTAssertNil(instrumentManager.getPortal(99))
    }

    func testResetInstruments() throws {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        try instrumentManager.resetInstruments()
    }

    func testUnknownInstrument() throws {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: "Anonymous")
        try instrumentManager.discoverInstruments()
    }

    func testGetUnknown() throws {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: "Battery")
        try instrumentManager.discoverInstruments()
        XCTAssertThrowsError(try instrumentManager.getInstrument("Anonymous") as IndicatorInstrument)
        XCTAssertThrowsError(try instrumentManager.getInstrument("Battery1") as IndicatorInstrument)
    }

    func testInstrumentPortal() throws {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: "SerialWire")
        try instrumentManager.discoverInstruments()

        let serialWire: SerialWireInstrument = try instrumentManager.getInstrument("SerialWire1")
        serialWire.setIndicator(true)
        try serialWire.write()
        device.assertDidSetReport(0, 5, 1, 1, 2, 0b001, 0b001)

        serialWire.portal.timeout = 0.001
        XCTAssertThrowsError(try serialWire.read(withByteCount: 1))

        let empty = try serialWire.read()
        XCTAssert(empty.count == 0)

        var binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0) // detour sequence number
        binary.writeVarUInt(5) // detour data length
        binary.writeVarUInt(serialWire.portal.identifier)
        binary.writeVarUInt(2) // type
        binary.writeVarUInt(2) // length
        binary.write(UInt8(3))
        binary.write(UInt8(4))
        let data = binary.data
        instrumentManager.usbHidDevice(device, inputReport: data)
        let two = try serialWire.read()
        XCTAssert(two.count == 2)
        var remaining = try serialWire.read().count
        XCTAssert(remaining == 0)

        instrumentManager.usbHidDevice(device, inputReport: data)
        let one = try serialWire.read(withByteCount: 1)
        XCTAssert(one.count == 1)
        remaining = try serialWire.read().count
        XCTAssert(remaining == 1)

        let sequenceNumber: UInt8 = 1
        let outOfSequenceData = Data([sequenceNumber])
        var lastError: Error? = nil
        instrumentManager.errorHandler = { error in
            lastError = error
        }
        instrumentManager.usbHidDevice(device, inputReport: outOfSequenceData)
        XCTAssert(lastError != nil)
        let bytes = [0, 2, 80, 1] as [UInt8]
        let invalidInstrumentIdentiferData = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        lastError = nil
        instrumentManager.usbHidDevice(device, inputReport: invalidInstrumentIdentiferData)
        XCTAssert(lastError != nil)
        remaining = try serialWire.read().count
        XCTAssert(remaining == 0)

        binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(0) // detour sequence number
        binary.writeVarUInt(4) // detour data length
        binary.writeVarUInt(serialWire.portal.identifier)
        binary.writeVarUInt(1) // type
        binary.writeVarUInt(1) // length
        instrumentManager.usbHidDevice(device, inputReport: binary.data)
        binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(1) // detour sequence number
        binary.write(UInt8(7)) // content
        instrumentManager.usbHidDevice(device, inputReport: binary.data)
        let combined = try serialWire.read()
        XCTAssert(combined.count == 1)
    }

}
