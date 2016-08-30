//
//  InstrumentManager.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/13/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

public class InstrumentManager : NSObject, USBHIDDeviceDelegate {

    static let apiTypeResetInstruments = UInt64(0)
    static let apiTypeDiscoverInstruments = UInt64(1)
    static let apiTypeEcho = UInt64(2)

    public enum Error: ErrorType {
        case InvalidIdentifier(String)
        case InvalidType(String)
        case PortalNotFound(UInt64)
        case InvalidInputReport(ErrorType)
    }

    public typealias ErrorHandler = (Error) -> (Void)

    typealias InstrumentConstructor = (Portal) -> (InternalInstrument)

    public let device: USBHIDDevice
    public var errorHandler: ErrorHandler?

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

    public func resetInstruments() throws {
        portal.send(InstrumentManager.apiTypeResetInstruments)
        try portal.write()
    }

    public func discoverInstruments() throws {
        var instruments = [String : InternalInstrument]()
        portal.send(InstrumentManager.apiTypeDiscoverInstruments)
        let data = try portal.read(type: InstrumentManager.apiTypeDiscoverInstruments)
        var countByCategory = [String : Int]()
        let binary = Binary(data: data, byteOrder: .LittleEndian)
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

    public func getInstrument<T>(identifier: String) throws -> T {
        guard let instrument = instruments[identifier] else {
            throw Error.InvalidIdentifier(identifier)
        }
        guard let t = instrument as? T else {
            throw Error.InvalidType(identifier)
        }
        return t
    }

    func getPortal(identifier: UInt64) -> Portal? {
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

    func notifyErrorHandler(error: Error) {
        if let errorHandler = errorHandler {
            errorHandler(error)
        }
    }

    @objc public func usbHidDevice(device: USBHIDDevice, inputReport data: NSData) {
        do {
            try detour.event(data)
            switch detour.state {
            case .Success:
                let binary = Binary(data: detour.data, byteOrder: .LittleEndian)
                let identifier = try binary.readVarUInt()
                let type = try binary.readVarUInt()
                let length = try binary.readVarUInt()
                let content = binary.remainingData
                if content.length != Int(length) {
                    NSLog("invalid content length")
                }
                detour.clear()
                guard let portal = getPortal(identifier) else {
                    notifyErrorHandler(Error.PortalNotFound(identifier))
                    break
                }
                portal.received(type, content: content)
            default:
                break
            }
        } catch let error {
            notifyErrorHandler(Error.InvalidInputReport(error))
            detour.clear()
        }
    }

}