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

    func queueDiscovery(device: MockUSBHIDDevice, category: String) {
        let binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(0) // ordinal
        let categoryLength = category.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        binary.writeVarUInt(UInt64(6 + categoryLength)) // length
        binary.writeVarUInt(0) // instrument identifier
        binary.writeVarUInt(1) // type
        binary.writeVarUInt(UInt64(3 + categoryLength)) // data length
        binary.writeVarUInt(1) // instrument count
        binary.write(category) // instrument category
        binary.writeVarUInt(1) // instrument identifier
        device.queue(binary.data)
    }

    func getInstrument<T>(category: String, _: T.Type) throws -> T {
        let device = MockUSBHIDDevice()
        let instrumentManager = InstrumentManager(device: device)
        queueDiscovery(device, category: category)
        try instrumentManager.discoverInstruments()
        return try instrumentManager.getInstrument("\(category)1")
    }

    func testGetInstruments() throws {
        try getInstrument("Battery", BatteryInstrument.self)
        try getInstrument("Color", ColorInstrument.self)
        try getInstrument("Current", CurrentInstrument.self)
        try getInstrument("Indicator", IndicatorInstrument.self)
        try getInstrument("Relay", RelayInstrument.self)
        try getInstrument("SerialWire", SerialWireInstrument.self)
        try getInstrument("Voltage", VoltageInstrument.self)
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
        XCTAssertThrowsError(try serialWire.readWithByteCount(1))

        let empty = try serialWire.read()
        XCTAssert(empty.length == 0)

        var binary = Binary(byteOrder: .LittleEndian)
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
        XCTAssert(two.length == 2)
        var remaining = try serialWire.read().length
        XCTAssert(remaining == 0)

        instrumentManager.usbHidDevice(device, inputReport: data)
        let one = try serialWire.readWithByteCount(1)
        XCTAssert(one.length == 1)
        remaining = try serialWire.read().length
        XCTAssert(remaining == 1)

        var sequenceNumber: UInt8 = 1
        let outOfSequenceData = NSData(bytes: &sequenceNumber, length: 1)
        var lastError: InstrumentManager.Error? = nil
        instrumentManager.errorHandler = { error in
            lastError = error
        }
        instrumentManager.usbHidDevice(device, inputReport: outOfSequenceData)
        XCTAssert(lastError != nil)
        let bytes = [0, 2, 80, 1] as [UInt8]
        let invalidInstrumentIdentiferData = NSData(bytes: bytes, length: bytes.count)
        lastError = nil
        instrumentManager.usbHidDevice(device, inputReport: invalidInstrumentIdentiferData)
        XCTAssert(lastError != nil)
        remaining = try serialWire.read().length
        XCTAssert(remaining == 0)

        binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(0) // detour sequence number
        binary.writeVarUInt(4) // detour data length
        binary.writeVarUInt(serialWire.portal.identifier)
        binary.writeVarUInt(1) // type
        binary.writeVarUInt(1) // length
        instrumentManager.usbHidDevice(device, inputReport: binary.data)
        binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(1) // detour sequence number
        binary.write(UInt8(7)) // content
        instrumentManager.usbHidDevice(device, inputReport: binary.data)
        let combined = try serialWire.read()
        XCTAssert(combined.length == 1)
    }

}
