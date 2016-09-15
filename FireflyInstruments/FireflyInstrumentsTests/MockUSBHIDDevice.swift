//
//  MockUSBHIDDevice.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/22/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

import FireflyInstruments
import Foundation
import XCTest

class MockUSBHIDDevice: USBHIDDevice {

    enum Call {
        case setReport(Data)
    }

    var calls = [Call]()
    var inputReports = [Data]()

    func assertDidSetReport(_ content: UInt8...) {
        XCTAssert(calls.count > 0)
        guard let call = calls.last else {
            return
        }
        guard case let Call.setReport(callData) = call else {
            XCTFail("unexpected func called")
            return
        }
        let data = Data(bytes: UnsafePointer<UInt8>(content), count: content.count)
        XCTAssert(callData == data)
    }

    @objc override func setReport(_ data: Data) throws {
        calls.append(.setReport(data))

        for inputReport in inputReports {
            delegate?.usbHidDevice(self, inputReport: inputReport)
        }
    }

    func queue(_ inputReport: Data) {
        inputReports.append(inputReport)
    }

}
