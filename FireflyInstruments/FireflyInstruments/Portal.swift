//
//  Portal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public protocol PortalDelegate : class {

    func portalReceived(_ portal: Portal, type: UInt64, content: Data) throws

}

public protocol Portal {

    var identifier: UInt64 { get }
    var timeout: TimeInterval { get set }

    func addDelegate(type: UInt64, delegate: PortalDelegate)
    func removeDelegate(type: UInt64)

    func send(_ type: UInt64, content: Data)
    func write() throws

    func received(_ type: UInt64, content: Data)

    func read(type: UInt64) throws -> Data

    // These functions are for reading the result content as a stream of bytes.
    func read(length: Int) throws -> Data
    func read() -> Data

}

extension Portal {

    func send(_ type: UInt64, content: [UInt8]) {
        send(type, content: Data(bytes: content))
    }

    func send(_ type: UInt64, content: UInt8...) {
        send(type, content: content)
    }

}
