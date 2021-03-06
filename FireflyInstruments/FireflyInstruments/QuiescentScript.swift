//
//  QuiescentScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/29/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

open class QuiescentScript: FixtureScript, Script {

    enum LocalError: Error {
        case conversionError
    }
    
    let nrf5Firmware: IntelHex
    let apolloFirmware: IntelHex
    
    public init(fixture: Fixture, presenter: Presenter, nrf5Firmware: IntelHex, apolloFirmware: IntelHex) {
        self.nrf5Firmware = nrf5Firmware
        self.apolloFirmware = apolloFirmware
        super.init(fixture: fixture, presenter: presenter)
    }
    
    func programNRF5() throws {
        let serialWireDebugScript = SerialWireDebugScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire1")
        serialWireDebugScript.doSetupInstruments = false
        try serialWireDebugScript.setup()
        
        let programmer = Programmer()
        let flash = try programmer.setupFlash(serialWireDebugScript: serialWireDebugScript, processor: "NRF52")
        presenter.show(message: "erasing nRF5...")
        try flash.massErase()
        presenter.show(message: "nRF5 erased")
        
        try programmer.programFlash(presenter: presenter, fixture: fixture, flash: flash, name: "fd_quiescent_test_nrf5", firmware: nrf5Firmware)
        
        try serialWireDebugScript.serialWireInstrument?.setEnabled(false)
    }
    
    func programApollo() throws {
        let serialWireDebugScript = SerialWireDebugScript(fixture: fixture, presenter: presenter, serialWireInstrumentIdentifier: "SerialWire2")
        serialWireDebugScript.doSetupInstruments = false
        try serialWireDebugScript.setup()
        
        let programmer = Programmer()
        let flash = try programmer.setupFlash(serialWireDebugScript: serialWireDebugScript, processor: "APOLLO")
        presenter.show(message: "erasing apollo...")
        try flash.massErase()
        presenter.show(message: "apollo erased")
        
        programmer.doUseStorage = false // !!! storage method fails for Apollo - why? -denis
        try programmer.programFlash(presenter: presenter, fixture: fixture, flash: flash, name: "fd_quiescent_test_apollo", firmware: apolloFirmware)
        
        try serialWireDebugScript.serialWireInstrument?.setEnabled(false)
    }
    
    func powerCycle() throws {
        presenter.show(message: "cycling battery power...")
        try fixture.simulatorToBatteryRelayInstrument?.set(false)
        Thread.sleep(forTimeInterval: 1.0)
        try fixture.simulatorToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    func measure() throws {
        do {
            try fixture.voltageSenseRelayInstrument?.set(true)
            Thread.sleep(forTimeInterval: 1.0)
            let conversion = try fixture.voltageInstrument?.convert()
            try fixture.voltageSenseRelayInstrument?.set(false)
            let voltage = conversion?.voltage ?? 0
            presenter.show(message: "system voltage \(voltage)")
        }
        guard let conversion = try fixture.batteryInstrument?.convert() else {
            throw LocalError.conversionError
        }
        let limit: Float32 = 0.000100 // 100 uA
        let pass = conversion.current <= limit
        presenter.show(message: "quiescent current \(conversion.current) <= \(limit)", pass: pass)
    }
    
    override open func setup() throws {
        try super.setup()
    }
    
    open func main() throws {
        try setup()
        try programNRF5()
        try programApollo()
        try powerCycle()
        try measure()
    }
    
}
