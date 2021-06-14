//
//  Semaphore.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 11/16/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

open class Semaphore: NSObject {
    
    public enum LocalError: Error {
        case timeout
        case cancelled
    }
    
    let condition = NSCondition()
    var done = false
    open var timeout: TimeInterval = 30.0
    open var error: Error?
    
    public override init() {
    }
    
    open func complete(_ error: Error? = nil) {
        condition.lock()
        self.done = true
        condition.broadcast()
        condition.unlock()
    }
    
    open func runWithTimeout(_ before: () throws -> Void = {}, after: () throws -> Void = {}) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        condition.lock()
        
        do {
            try before()
        } catch let error {
            condition.unlock()
            throw error
        }
        
        var signaled: Bool
        loop:
            while true {
                signaled = condition.wait(until: Date(timeIntervalSinceNow: 0.25))
                condition.unlock()
                if signaled {
                    break loop
                }
                if (deadline as NSDate).isLessThan(Date()) {
                    error = LocalError.timeout
                    break loop
                }
                if Thread.current.isCancelled {
                    error = LocalError.cancelled
                    break loop
                }
                condition.lock()
        }
        
        try after()
        
        if error != nil {
            throw error!
        }
    }
    
}
