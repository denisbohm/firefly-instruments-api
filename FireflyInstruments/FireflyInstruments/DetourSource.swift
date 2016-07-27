//
//  DetourSource.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/18/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

public class DetourSource {

    var size: Int
    var data: NSData
    var index: Int = 0
    var sequenceNumber: UInt64 = 0
    var startDate: NSDate?
    var endDate: NSDate?

    public init(size: Int, data: NSData) {
        self.size = size
        let binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(UInt64(data.length))
        binary.write(data);
        self.data = binary.data
    }

    public func next() -> NSData? {
        if startDate == nil {
            startDate = NSDate()
        }

        if index >= data.length {
            if endDate == nil {
                endDate = NSDate()
                let duration = endDate!.timeIntervalSinceDate(startDate!)
                if duration > 0.0 {
                    let rate = Double(data.length) / duration
                    NSLog("detour source success: \(data.length) B (\(rate) B/s)")
                }
            }
            return nil
        }
        
        var n = data.length - index
        if n > (size - 1) {
            n = size - 1
        }
        let binary = Binary(byteOrder: .LittleEndian)
        binary.writeVarUInt(sequenceNumber)
        let subdata = NSMutableData(data: binary.data)
        subdata.appendData(data.subdataWithRange(NSRange(location: index, length: n)))
        index += n
        sequenceNumber += 1
        return subdata
    }

}