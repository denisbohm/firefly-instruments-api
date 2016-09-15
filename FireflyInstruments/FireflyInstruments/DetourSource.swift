//
//  DetourSource.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/18/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import Foundation

open class DetourSource {

    var size: Int
    var data: Data
    var index: Int = 0
    var sequenceNumber: UInt64 = 0
    var startDate: Date?
    var endDate: Date?

    public init(size: Int, data: Data) {
        self.size = size
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(UInt64(data.count))
        binary.write(data);
        self.data = binary.data
    }

    open func next() -> Data? {
        if startDate == nil {
            startDate = Date()
        }

        if index >= data.count {
            if endDate == nil {
                endDate = Date()
                
                /*
                let duration = endDate!.timeIntervalSinceDate(startDate!)
                if duration > 0.0 {
                    let rate = Double(data.length) / duration
                    NSLog("detour source success: \(data.length) B (\(rate) B/s)")
                }
                 */
            }
            return nil
        }
        
        var n = data.count - index
        if n > (size - 1) {
            n = size - 1
        }
        let binary = Binary(byteOrder: .littleEndian)
        binary.writeVarUInt(sequenceNumber)
        var subdata = binary.data
        subdata.append(data.subdata(in: index ..< index + n))
        index += n
        sequenceNumber += 1
        return subdata
    }

}
