//
//  BatteryPowerScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/11/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

open class BatteryPowerScript: FixtureScript, Script {
    
    enum LocalError: Error {
        case conversionError
    }
    
    open func main() throws {
//        self.batteryVoltage = 3.6
        
        try setup()
        
        try fixture.voltageSenseRelayInstrument?.set(true)
        Thread.sleep(forTimeInterval: 2.0)
        let conversion = try fixture.voltageInstrument?.convert()
        presenter.show(message: String(format: "target voltage %0.2f", conversion?.voltage ?? 0.0))
        try fixture.voltageSenseRelayInstrument?.set(false)
        
        for _ in 0 ..< 60 {
            Thread.sleep(forTimeInterval: 1.0)
            try measure()
        }
    }
    
    open func measure() throws {
        guard let conversion = try fixture.batteryInstrument?.convert() else {
            throw LocalError.conversionError
        }
        let limit: Float32 = 0.000100 // 100 uA
        let pass = conversion.current <= limit
        presenter.show(message: "quiescent current \(conversion.current) <= \(limit)", pass: pass)

    }

}
