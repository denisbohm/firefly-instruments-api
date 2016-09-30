//
//  MockInstrumentManager.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 9/30/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

import FireflyInstruments

class MockInstrumentManager: InstrumentManager {

    init() {
        super.init(device: MockUSBHIDDevice())
    }

    override func echo(data: Data) throws {
    }

    override func resetInstruments() throws {
    }

    override func discoverInstruments() throws {
    }

    override func getInstrument<T>(_ identifier: String) throws -> T {
        throw LocalError.invalidIdentifier(identifier)
    }

}
