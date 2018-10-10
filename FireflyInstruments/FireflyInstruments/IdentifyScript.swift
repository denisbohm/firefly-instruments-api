//
//  IdentifyScript.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

open class IdentifyScript: SerialWireDebugScript, Script {
    
    open func main() throws {
        try setup()
        
        presenter.show(message: "reading CPU ID...")
        var cpuID: UInt32 = 0
        try serialWireDebug?.readCPUID(&cpuID)
        presenter.show(message: FDSerialWireDebug.cpuIDDescription(cpuID))
    }
    
}
