//
//  Instrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public protocol Instrument {

    var instrumentManager: InstrumentManager { get }
    
    var identifier: UInt64 { get }

}
