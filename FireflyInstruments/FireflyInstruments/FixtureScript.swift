//
//  FixtureScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

open class FixtureScript {

    enum ScriptError: Error {
        case setupFailure
    }
    
    let fixture: Fixture
    let presenter: Presenter
    var doSetupInstruments = true
    var batteryVoltage: Float = 4.1

    public init(fixture: Fixture, presenter: Presenter) {
        self.fixture = fixture
        self.presenter = presenter
    }
    
    func powerOnUSB() throws {
        presenter.show(message: "powering on USB...")
        Thread.sleep(forTimeInterval: 1.0)
        try fixture.voltageSenseRelayInstrument?.set(true)
        try fixture.usbPowerRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 1.0)
        let conversion = try fixture.voltageInstrument?.convert()
        if (conversion == nil) || (conversion!.voltage < 1.7) {
            throw ScriptError.setupFailure
        }
        try fixture.voltageSenseRelayInstrument?.set(false)
    }
    
    func powerOnBatterySimulator() throws {
        presenter.show(message: "powering on battery simulator at \(self.batteryVoltage) V...")
        Thread.sleep(forTimeInterval: 1.0)
        try fixture.voltageSenseRelayInstrument?.set(true)
        try fixture.batteryInstrument?.setEnabled(true)
        try fixture.batteryInstrument?.setVoltage(batteryVoltage)
        try fixture.simulatorToBatteryRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 1.0)
        let conversion = try fixture.voltageInstrument?.convert()
        if (conversion == nil) || (conversion!.voltage < 1.7) {
            throw ScriptError.setupFailure
        }
        try fixture.voltageSenseRelayInstrument?.set(false)
    }
    
    func powerOn() throws {
        try powerOnBatterySimulator()
    }
    
    func setupInstruments() throws {
        presenter.show(message: "connecting to instruments...")
        try fixture.collectInstruments()
        
        try powerOn()
    }
    
    func setup() throws {
        if doSetupInstruments {
            try setupInstruments()
        }
    }
    
}
