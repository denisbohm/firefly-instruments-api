//
//  Portal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public protocol Portal {

    var identifier: UInt64 { get }
    var timeout: NSTimeInterval { get set }

    func send(type: UInt64, content: NSData)
    func write() throws

    func received(type: UInt64, content: NSData)

    func read(type type: UInt64) throws -> NSData

    // These functions are for reading the result content as a stream of bytes.
    func read(length length: Int) throws -> NSData
    func read() -> NSData

}

extension Portal {

    func send(type: UInt64, content: [UInt8]) {
        send(type, content: NSData(bytes: content, length: content.count))
    }

    func send(type: UInt64, content: UInt8...) {
        send(type, content: content)
    }

}