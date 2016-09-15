//
//  Detour.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class Detour {

    public enum State {
        case clear
        case intermediate
        case success
    }

    public enum LocalError: Error {
        case unexpectedStart
        case outOfSequence(UInt64, UInt64)
    }

    open fileprivate(set) var state = State.clear
    fileprivate var buffer = Data()
    fileprivate var length: Int = 0
    fileprivate var sequenceNumber: UInt64 = 0
    fileprivate var startDate: Date? = nil
    fileprivate var endDate: Date? = nil

    open var data: Data {
        get {
            return buffer
        }
    }

    public init() {
    }

    open func clear() {
        state = .clear
        length = 0
        sequenceNumber = 0
        buffer.count = 0
    }

    open func event(_ data: Data) throws {
        let binary = Binary(data: data, byteOrder: .littleEndian)
        let eventSequenceNumber = try binary.readVarUInt()
        if eventSequenceNumber == 0 {
            if sequenceNumber != 0 {
                throw LocalError.unexpectedStart
            }
            try start(binary.remainingData)
        } else {
            if eventSequenceNumber != sequenceNumber {
                throw LocalError.outOfSequence(eventSequenceNumber, sequenceNumber)
            }
            append(binary.remainingData)
        }
    }
    
    fileprivate func start(_ data: Data) throws {
        startDate = Date()
        let binary = Binary(data: data, byteOrder: .littleEndian)
        state = .intermediate;
        length = Int(try binary.readVarUInt())
        sequenceNumber = 0;
        buffer.count = 0;
        append(binary.remainingData)
    }

    fileprivate func append(_ data: Data) {
        let total = buffer.count + data.count
        if total <= length {
            buffer.append(data)
        } else {
            // silently ignore any extra data at the end of the transfer (due to fixed size transport) -denis
            buffer.append(data.subdata(in: 0 ..< length - buffer.count))
        }
        if buffer.count >= length {
            endDate = Date()
            state = .success

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
