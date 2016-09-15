//
//  InstrumentManager.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

open class InstrumentManager : NSObject, USBHIDDeviceDelegate {

    static let apiTypeResetInstruments = UInt64(0)
    static let apiTypeDiscoverInstruments = UInt64(1)
    static let apiTypeEcho = UInt64(2)

    public enum LocalError: Error {
        case invalidIdentifier(String)
        case invalidType(String)
        case portalNotFound(UInt64)
        indirect case invalidInputReport(Error)
    }

    public typealias ErrorHandler = (Error) -> (Void)

    typealias InstrumentConstructor = (Portal) -> (InternalInstrument)

    open let device: USBHIDDevice
    open var errorHandler: ErrorHandler?

    let constructorByCategory: [String: InstrumentConstructor]
    let detour = Detour()
    let portal: Portal
    var instruments = [String : InternalInstrument]()

    public init(device: USBHIDDevice) {
        self.device = device
        self.portal = InstrumentPortal(device: device, identifier: 0)

        var constructorByCategory = [String: InstrumentConstructor]()
        constructorByCategory["Battery"] = { portal in return BatteryInstrument(portal: portal) }
        constructorByCategory["Color"] = { portal in return ColorInstrument(portal: portal) }
        constructorByCategory["Current"] = { portal in return CurrentInstrument(portal: portal) }
        constructorByCategory["Indicator"] = { portal in return IndicatorInstrument(portal: portal) }
        constructorByCategory["Relay"] = { portal in return RelayInstrument(portal: portal) }
        constructorByCategory["SerialWire"] = { portal in return SerialWireInstrument(portal: portal) }
        constructorByCategory["Storage"] = { portal in return StorageInstrument(portal: portal) }
        constructorByCategory["Voltage"] = { portal in return VoltageInstrument(portal: portal) }
        self.constructorByCategory = constructorByCategory

        super.init()
        
        device.delegate = self
    }

    open func resetInstruments() throws {
        portal.send(InstrumentManager.apiTypeResetInstruments)
        try portal.write()
    }

    open func discoverInstruments() throws {
        var instruments = [String : InternalInstrument]()
        portal.send(InstrumentManager.apiTypeDiscoverInstruments)
        let data = try portal.read(type: InstrumentManager.apiTypeDiscoverInstruments)
        var countByCategory = [String : Int]()
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let count = try binary.readVarUInt()
        for _ in 1 ... count {
            let category: String = try binary.read()
            let identifier = try binary.readVarUInt()
            guard let constructor = constructorByCategory[category] else {
                continue
            }
            let portal = InstrumentPortal(device: device, identifier: identifier)
            let instrument = constructor(portal)
            let count = (countByCategory[category] ?? 0) + 1
            countByCategory[category] = count
            let name = "\(category)\(count)"
            instruments[name] = instrument
        }
        self.instruments = instruments
    }

    open func getInstrument<T>(_ identifier: String) throws -> T {
        guard let instrument = instruments[identifier] else {
            throw LocalError.invalidIdentifier(identifier)
        }
        guard let t = instrument as? T else {
            throw LocalError.invalidType(identifier)
        }
        return t
    }

    func getPortal(_ identifier: UInt64) -> Portal? {
        if identifier == 0 {
            return portal
        }
        for instrument in instruments.values {
            if instrument.portal.identifier == identifier {
                return instrument.portal
            }
        }
        return nil
    }

    func notifyErrorHandler(_ error: Error) {
        if let errorHandler = errorHandler {
            errorHandler(error)
        }
    }

    @objc open func usbHidDevice(_ device: USBHIDDevice, inputReport data: Data) {
        do {
            try detour.event(data)
            switch detour.state {
            case .success:
                let binary = Binary(data: detour.data, byteOrder: .littleEndian)
                let identifier = try binary.readVarUInt()
                let type = try binary.readVarUInt()
                let length = try binary.readVarUInt()
                let content = binary.remainingData
                if content.count != Int(length) {
                    NSLog("invalid content length")
                }
                detour.clear()
                guard let portal = getPortal(identifier) else {
                    notifyErrorHandler(LocalError.portalNotFound(identifier))
                    break
                }
                portal.received(type, content: content)
            default:
                break
            }
        } catch let error {
            notifyErrorHandler(LocalError.invalidInputReport(error))
            detour.clear()
        }
    }

}
