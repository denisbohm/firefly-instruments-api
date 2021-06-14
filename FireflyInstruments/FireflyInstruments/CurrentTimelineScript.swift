//
//  CurrentTimelineScript.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 11/16/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation

open class CurrentTimelineScript: FixtureScript, Script, BatteryInstrumentConvertDelegate {
    
    public let currentChart: CurrentChart
    public let semaphore = Semaphore()
    
    public init(fixture: Fixture, presenter: Presenter, currentChart: CurrentChart) {
        self.currentChart = currentChart
        super.init(fixture: fixture, presenter: presenter)
    }
    
    // !!! on separate thread, need to signal testPower thread -denis
    public func batteryInstrumentConvertContinuousComplete(_ batteryInstrument: BatteryInstrument) {
        presenter.show(message: "convert continuous complete")
        semaphore.complete()
    }
    
    func testCurrent() throws {
        guard
            let batteryInstrument = fixture.batteryInstrument,
            let storageInstrument = fixture.storageInstrument,
            let batteryAdjustableRelayInstrument = fixture.simulatorToBatteryRelayInstrument
        else {
            return
        }
        
        try batteryInstrument.setVoltage(3.8)
        try batteryInstrument.setEnabled(true)
        try batteryAdjustableRelayInstrument.set(true)
        batteryInstrument.convertDelegate = self

        try fixture.usbPowerRelayInstrument?.set(false)

        let sampleCount = 1000
        let fileSystem = FileSystem(storageInstrument: storageInstrument)
        try fileSystem.inspect()
        presenter.show(message: "instrument storage file system entries:")
        for entry in fileSystem.list() {
            presenter.show(message: String(format: "\t\(entry.name)\t\(entry.date)\t\(entry.length)\t@0x%08x", entry.address))
        }
        let sizeOfSample = 4 // mean is a 4 byte float
        let bytes = sampleCount * sizeOfSample
        // reserve the file content (don't really need to write to it)... -denis
        let entry = try fileSystem.write("battery.log", data: Data([UInt8](repeating: 0xff, count: bytes)))
        
        let passes = 10000
        for pass in 1 ... passes {
            presenter.show(message: "monitoring power: pass \(pass) of \(passes)...")
            try storageInstrument.erase(entry.address, length: entry.length)
            try storageInstrument.flush()
            
            var date = Date()
            try batteryInstrument.convertContinuous(rate: 1.0e6, decimation: 1000, samples: UInt64(sampleCount), address: entry.address)
            // wait for conversions to complete -denis
            try semaphore.runWithTimeout()
            
            var values: [Double] = []
            var samples: [CurrentChart.Sample] = []
            let data = try storageInstrument.read(entry.address, length: entry.length)
            let binary = Binary(data: data, byteOrder: .littleEndian)
            while binary.remainingReadLength > 0 {
                let mean: Float32 = try binary.read()
                values.append(Double(mean))
                samples.append(CurrentChart.Sample(date: date, current: Double(mean)))
                date = date.addingTimeInterval(1.0e-3)
            }
            values.sort()
            let median = values[values.count / 2]
            let mean = values.reduce(0, +) / Double(values.count)
            let summary = String(format: "%3.0f uA mean, %3.0f uA median", mean * 1.0e6, median * 1.0e6)
            presenter.show(message: "pass \(pass) 1 summary: \(summary)")
            DispatchQueue.main.async {
                self.currentChart.setSummary(summary: summary)
                self.currentChart.setSamples(samples: samples)
            }
        }
        
        try fileSystem.erase("battery.log")
    }
    
    open func main() throws {
        try setup()
        
        presenter.show(message: "waiting 30 seconds for device to startup...")
        Thread.sleep(forTimeInterval: 30.0)
        
        presenter.show(message: "testing current...")
        try testCurrent()
    }
    
}
