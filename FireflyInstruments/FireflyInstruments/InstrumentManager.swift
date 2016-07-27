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

    static let apiIdentifierSerialWire1 = UInt64(1)
    static let apiIdentifierSerialWire2 = UInt64(2)
    static let apiIdentifierColor1 = UInt64(3)
    static let apiIdentifierIndicator1 = UInt64(4)
    static let apiIdentifierRelay1 = UInt64(5)
    static let apiIdentifierRelay2 = UInt64(6)
    static let apiIdentifierRelay3 = UInt64(7)
    static let apiIdentifierRelay4 = UInt64(8)
    static let apiIdentifierRelay5 = UInt64(9)
    static let apiIdentifierVoltage1 = UInt64(10)
    static let apiIdentifierVoltage2 = UInt64(11)
    static let apiIdentifierCurrent1 = UInt64(12)
    static let apiIdentifierBattery1 = UInt64(13)

    static let apiTypeEcho = UInt64(1)
    static let apiTypeDiscoverInstruments = UInt64(2)

    public enum Error: ErrorType {
        case InvalidIdentifier(String)
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
        constructorByCategory["Indicator"] = { portal in return IndicatorInstrument(portal: portal) }
        constructorByCategory["SerialWire"] = { portal in return SerialWireInstrument(portal: portal) }
        constructorByCategory["Relay"] = { portal in return RelayInstrument(portal: portal) }
        constructorByCategory["Voltage"] = { portal in return RelayInstrument(portal: portal) }
        constructorByCategory["Current"] = { portal in return RelayInstrument(portal: portal) }
        constructorByCategory["Battery"] = { portal in return RelayInstrument(portal: portal) }
        constructorByCategory["Color"] = { portal in return ColorInstrument(portal: portal) }
        self.constructorByCategory = constructorByCategory

        super.init()
        
        device.delegate = self
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

    public func getInstrument(identifier: String) throws -> Instrument {
        guard let instrument = instruments[identifier] else {
            throw Error.InvalidIdentifier(identifier)
        }
        return instrument
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
                let content = binary.remainingData
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