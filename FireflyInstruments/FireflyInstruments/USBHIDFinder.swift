//
//  USBHIDDiscover.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/28/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class USBHIDFinder : NSObject, USBHIDMonitorDelegate {

    enum LocalError: Error {
        case timeout
    }

    let matcher: USBHIDMonitorMatcher
    var monitor: USBHIDMonitor? = nil
    let condition = NSCondition()
    var usbDevices = [USBHIDDevice]()
    open var timeout: TimeInterval = 10.0

    public init(name: String, vid: UInt16, pid: UInt16) {
        matcher = USBHIDMonitorMatcher("Firefly Instrument", vid: 0x0483, pid: 0x5710)
    }

    deinit {
        stop()
    }

    open func usbHidMonitor(_ usbMonitor: USBHIDMonitor, deviceAdded usbDevice: USBHIDDevice) {
        condition.lock()
        defer {
            condition.broadcast()
            condition.unlock()
        }
        if usbDevices.index(of: usbDevice) == nil {
            usbDevices.append(usbDevice)
        }
    }

    open func usbHidMonitor(_ usbMonitor: USBHIDMonitor, deviceRemoved usbDevice: USBHIDDevice) {
        condition.lock()
        defer {
            condition.broadcast()
            condition.unlock()
        }
        if let index = usbDevices.index(of: usbDevice) {
            usbDevices.remove(at: index)
        }
    }

    open func find() throws -> USBHIDDevice {
        if monitor == nil {
            let monitor = USBHIDMonitor([matcher])
            monitor.delegate = self
            self.monitor = monitor
            monitor.start()
        }
        condition.lock()
        defer {
            condition.unlock()
        }
        var usbDevice = usbDevices.first
        if usbDevice == nil {
            condition.wait(until: Date(timeIntervalSinceNow: timeout))
            usbDevice = usbDevices.first
        }
        if usbDevice == nil {
            throw LocalError.timeout
        }
        return usbDevice!
    }

    open func stop() {
        if let monitor = monitor {
            monitor.stop()
            self.monitor = nil
        }
        usbDevices.removeAll()
    }
    
}
