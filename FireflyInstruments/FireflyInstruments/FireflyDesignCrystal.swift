//
//  FireflyDesignCrystal.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/11/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public protocol FireflyDesignCrystal: FireflyDesignSwdRpc {
    
    func fd_test_suite_crystal_test(source: UInt32) throws -> Bool
    
    func lowFrequencyCrystalTest(presenter: Presenter) throws
    
    func highFrequencyCrystalTest(presenter: Presenter) throws

}

extension FireflyDesignCrystal {

    public func fd_test_suite_crystal_test(source: UInt32) throws -> Bool {
        let r0 = try run(function: "fd_test_suite_crystal_test", r0: source, r1: 1000000)
        return r0 != 0
    }
    
    public func lowFrequencyCrystalTest(presenter: Presenter) throws {
        let pass = try fd_test_suite_crystal_test(source: 0)
        presenter.show(message: "32kHz crystal test", pass: pass)
    }
    
    public func highFrequencyCrystalTest(presenter: Presenter) throws {
        let pass = try fd_test_suite_crystal_test(source: 1)
        presenter.show(message: "32mHz crystal test", pass: pass)
    }
    
}
