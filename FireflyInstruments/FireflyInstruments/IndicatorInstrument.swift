//
//  IndicatorInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/21/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class IndicatorInstrument: InternalInstrument {

    static let apiTypeSetRGB = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func set(red red: Float, green: Float, blue: Float) throws {
        let binary = Binary(byteOrder: .LittleEndian)
        binary.write(red)
        binary.write(green)
        binary.write(blue)
        portal.send(IndicatorInstrument.apiTypeSetRGB, content: binary.data)
        try portal.write()
    }
    
}