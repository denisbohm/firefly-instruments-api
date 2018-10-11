//
//  FixtureScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

open class FixtureScript {

    public enum ScriptError: Error {
        case setupFailure
    }
    
    public let fixture: Fixture
    public let presenter: Presenter
    public var doSetupInstruments = true
    public var batteryVoltage: Float = 4.1

    public init(fixture: Fixture, presenter: Presenter) {
        self.fixture = fixture
        self.presenter = presenter
    }
    
    open func powerOnUSB() throws {
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
    
    open func powerOnBatterySimulator() throws {
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
    
    open func powerOn() throws {
        try powerOnBatterySimulator()
    }
    
    open func setupInstruments() throws {
        presenter.show(message: "connecting to instruments...")
        try fixture.collectInstruments()
        
        try powerOn()
    }
    
    open func setup() throws {
        if doSetupInstruments {
            try setupInstruments()
        }
    }
    
}
