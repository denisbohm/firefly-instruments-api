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
        case setReport(NSData)
    }

    var calls = [Call]()
    var inputReports = [NSData]()

    func assertDidSetReport(content: UInt8...) {
        XCTAssert(calls.count > 0)
        guard let call = calls.last else {
            return
        }
        guard case let Call.setReport(callData) = call else {
            XCTFail("unexpected func called")
            return
        }
        let data = NSData(bytes: content, length: content.count)
        XCTAssert(callData.isEqualToData(data))
    }

    @objc override func setReport(data: NSData) throws {
        calls.append(.setReport(data))

        for inputReport in inputReports {
            delegate?.usbHidDevice(self, inputReport: inputReport)
        }
    }

    func queue(inputReport: NSData) {
        inputReports.append(inputReport)
    }

}