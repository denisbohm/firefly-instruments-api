//
//  RelayInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class RelayInstrument: InternalInstrument {

    static let apiTypeReset = UInt64(0)
    static let apiTypeSetState = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public var identifier: UInt64 { get { return portal.identifier } }

    public func reset() throws {
        portal.send(RelayInstrument.apiTypeReset)
        try portal.write()
    }

    public func set(value: Bool) throws {
        portal.send(RelayInstrument.apiTypeSetState, content: value ? 1 : 0)
        try portal.write()
    }
    
}