//
//  FireflyDesignSwdRpc.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/11/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

public protocol FireflyDesignSwdRpc {
    
    var serialWireDebug: FDSerialWireDebug? { get }
    
    func run(function: String, r0: UInt32, r1: UInt32, r2: UInt32, r3: UInt32, timeout: TimeInterval) throws -> UInt32
    
}

extension FireflyDesignSwdRpc {
    
    public func run(function: String, r0: UInt32 = 0, r1: UInt32 = 0, r2: UInt32 = 0, r3: UInt32 = 0, timeout: TimeInterval = 1.0) throws -> UInt32 {
        return try run(function: function, r0: r0, r1: r1, r2: r2, r3: r3, timeout: timeout)
    }
    
}
