//
//  USBHIDDiscover.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/28/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class USBHIDFinder : NSObject, USBHIDMonitorDelegate {

    enum Error: ErrorType {
        case Timeout
    }

    let matcher: USBHIDMonitorMatcher
    var monitor: USBHIDMonitor? = nil
    let condition = NSCondition()
    var usbDevices = [USBHIDDevice]()
    public var timeout: NSTimeInterval = 10.0

    public init(name: String, vid: UInt16, pid: UInt16) {
        matcher = USBHIDMonitorMatcher("Firefly Instrument", vid: 0x0483, pid: 0x5710)
    }

    deinit {
        stop()
    }

    public func usbHidMonitor(usbMonitor: USBHIDMonitor, deviceAdded usbDevice: USBHIDDevice) {
        condition.lock()
        defer {
            condition.broadcast()
            condition.unlock()
        }
        if usbDevices.indexOf(usbDevice) == nil {
            usbDevices.append(usbDevice)
        }
    }

    public func usbHidMonitor(usbMonitor: USBHIDMonitor, deviceRemoved usbDevice: USBHIDDevice) {
        condition.lock()
        defer {
            condition.broadcast()
            condition.unlock()
        }
        if let index = usbDevices.indexOf(usbDevice) {
            usbDevices.removeAtIndex(index)
        }
    }

    public func find() throws -> USBHIDDevice {
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
            condition.waitUntilDate(NSDate(timeIntervalSinceNow: timeout))
            usbDevice = usbDevices.first
        }
        if usbDevice == nil {
            throw Error.Timeout
        }
        return usbDevice!
    }

    public func stop() {
        if let monitor = monitor {
            monitor.stop()
            self.monitor = nil
        }
        usbDevices.removeAll()
    }
    
}