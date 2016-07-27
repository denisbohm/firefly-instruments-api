//
//  RelayInstrument.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class RelayInstrument: InternalInstrument {

    static let apiTypeSetState = UInt64(1)

    var portal: Portal

    public init(portal: Portal) {
        self.portal = portal
    }

    public func set(value: Bool) throws {
        portal.send(RelayInstrument.apiTypeSetState, content: value ? 1 : 0)
    }
    
}