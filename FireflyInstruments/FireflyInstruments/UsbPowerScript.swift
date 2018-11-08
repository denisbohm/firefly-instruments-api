//
//  UsbPowerScript.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/31/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

open class UsbPowerScript: FixtureScript, Script {
    
    open override func powerOn() throws {
        try powerOnUSB()
    }

    open func main() throws {
        try setup()
        
        try fixture.voltageSenseRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 2.0)
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: String(format: "target voltage %0.2f", conversion?.voltage ?? 0.0))
        try fixture.voltageSenseRelayInstrument?.set(false)
    }
    
}
