//
//  Runner.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

open class Runner: Thread {
    
    let fixture: Fixture
    let presenter: Presenter
    let script: Script
    
    public init(fixture: Fixture, presenter: Presenter, script: Script) {
        self.fixture = fixture
        self.presenter = presenter
        self.script = script
    }
    
    override open func main() {
        do {
            try script.main()
        } catch {
            presenter.show(message: "Unexpected Error: \(error.localizedDescription)", pass: false)
        }
        presenter.completed()
    }

}
