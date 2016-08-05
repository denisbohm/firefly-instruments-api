//
//  RelayInstrumentTests.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import XCTest

class RelayInstrumentTests: XCTestCase {

    func testSends() throws {
        let portal = MockPortal()
        let relayInstrument = RelayInstrument(portal: portal)

        try relayInstrument.reset()
        portal.assertDidSend(0)
        portal.assertDidWrite()

        try relayInstrument.set(false)
        portal.assertDidSend(0x01, content: 0)
        portal.assertDidWrite()

        try relayInstrument.set(true)
        portal.assertDidSend(0x01, content: 1)
        portal.assertDidWrite()
    }
    
}
