//
//  CurrentInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class CurrentInstrument: InternalInstrument {

    public struct Conversion {
        public let current: Float32
    }

    static let apiTypeReset = UInt64(0)
    static let apiTypeConvertCurrent = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public var identifier: UInt64 { get { return portal.identifier } }

    public func reset() throws {
        portal.send(CurrentInstrument.apiTypeReset)
        try portal.write()
    }

    public func convert() throws -> Conversion {
        portal.send(CurrentInstrument.apiTypeConvertCurrent)
        let data = try portal.read(type: CurrentInstrument.apiTypeConvertCurrent)
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let current: Float32 = try binary.read()
        return Conversion(current: current)
    }
    
}