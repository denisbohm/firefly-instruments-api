//
//  Presenter.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

public enum PresenterType {
    case info
    case pass
    case fail
}

public protocol Presenter {
    
    func show(message: String, type: PresenterType)
    func completed()
    
    func hadFailures() -> Bool

}

extension Presenter {
    
    public func show(message: String) {
        show(message: message, type: .info)
    }
    
    public func show(message: String, pass: Bool) {
        show(message: message, type: pass ? .pass : .fail)
    }

}
