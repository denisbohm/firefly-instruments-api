//
//  FireflyInstrumentsViewController.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 10/10/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

open class FireflyInstrumentsViewController: NSViewController, Presenter {

    @IBOutlet open var messageTextView: NSTextView!
    
    public let fixture = Fixture()
    open var runner: Runner? = nil
    
    override open func viewDidLoad() {
        super.viewDidLoad()
    }
    
    open func run(script: Script) {
        messageTextView.string = ""
        
        runner = Runner(fixture: fixture, presenter: self, script: script)
        runner?.start()
    }
    
    @IBAction open func cancel(_ sender: Any) {
        if let runner = runner {
            runner.cancel()
        }
    }
    
    open func showOnMain(message: String) {
        let string = NSAttributedString(string: message + "\n", attributes: [.foregroundColor : NSColor.textColor])
        messageTextView.textStorage?.append(string)
        messageTextView.scrollToEndOfDocument(nil)
    }
    
    open func show(message: String) {
        DispatchQueue.main.async() {
            self.showOnMain(message: message)
        }
    }
    
    open func completedOnMain() {
        runner = nil
    }
    
    open func completed() {
        DispatchQueue.main.async() {
            self.completedOnMain()
        }
    }
    

}
