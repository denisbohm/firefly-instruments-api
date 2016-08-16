//
//  Detour.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class Detour {

    public enum State {
        case Clear
        case Intermediate
        case Success
    }

    public enum Error: ErrorType {
        case UnexpectedStart
        case OutOfSequence(UInt64, UInt64)
    }

    public private(set) var state = State.Clear
    private let buffer = NSMutableData()
    private var length: Int = 0
    private var sequenceNumber: UInt64 = 0
    private var startDate: NSDate? = nil
    private var endDate: NSDate? = nil

    public var data: NSData {
        get {
            return NSData(data: buffer)
        }
    }

    public init() {
    }

    public func clear() {
        state = .Clear
        length = 0
        sequenceNumber = 0
        buffer.length = 0
    }

    public func event(data: NSData) throws {
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        let eventSequenceNumber = try binary.readVarUInt()
        if eventSequenceNumber == 0 {
            if sequenceNumber != 0 {
                throw Error.UnexpectedStart
            }
            try start(binary.remainingData)
        } else {
            if eventSequenceNumber != sequenceNumber {
                throw Error.OutOfSequence(eventSequenceNumber, sequenceNumber)
            }
            append(binary.remainingData)
        }
    }
    
    private func start(data: NSData) throws {
        startDate = NSDate()
        let binary = Binary(data: data, byteOrder: .LittleEndian)
        state = .Intermediate;
        length = Int(try binary.readVarUInt())
        sequenceNumber = 0;
        buffer.length = 0;
        append(binary.remainingData)
    }

    private func append(data: NSData) {
        let total = buffer.length + data.length
        if total <= length {
            buffer.appendData(data)
        } else {
            // silently ignore any extra data at the end of the transfer (due to fixed size transport) -denis
            buffer.appendData(data.subdataWithRange(NSMakeRange(0, length - buffer.length)))
        }
        if buffer.length >= length {
            endDate = NSDate()
            state = .Success

            /*
            let duration = endDate!.timeIntervalSinceDate(startDate!)
            if (duration > 0.0) {
                let rate = Double(buffer.length) / duration;
                NSLog("detour success: \(buffer.length) B (\(rate) B/s)")
            }
             */
        } else {
            sequenceNumber += 1
        }
    }

}