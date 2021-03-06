//
//  IndicatorInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/21/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class IndicatorInstrument: InternalInstrument {

    static let apiTypeReset = UInt64(0)
    static let apiTypeSetRGB = UInt64(1)

    unowned public private(set) var instrumentManager: InstrumentManager
    var portal: Portal

    public init(instrumentManager: InstrumentManager, portal: Portal) {
        self.instrumentManager = instrumentManager
        self.portal = portal
    }

    open var identifier: UInt64 { get { return portal.identifier } }

    open func flush() throws {
        try portal.write()
    }

    open func reset() throws {
        portal.send(IndicatorInstrument.apiTypeReset)
        try portal.write()
    }

    open func set(red: Float, green: Float, blue: Float) throws {
        let binary = Binary(byteOrder: .littleEndian)
        binary.write(red)
        binary.write(green)
        binary.write(blue)
        portal.send(IndicatorInstrument.apiTypeSetRGB, content: binary.data)
        try portal.write()
    }
    
}
