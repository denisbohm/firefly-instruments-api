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
    @IBOutlet open var startButton: NSButton?
    @IBOutlet open var cancelButton: NSButton?

    public let fixture = Fixture()
    open var runner: Runner? = nil
    open var failCount = 0
    
    override open func viewDidLoad() {
        super.viewDidLoad()
    }
    
    open func run(script: Script) {
        failCount = 0
        messageTextView.string = ""
        startButton?.isEnabled = false
        cancelButton?.isEnabled = true
        
        runner = Runner(fixture: fixture, presenter: self, script: script)
        runner?.start()
    }
    
    @IBAction open func cancel(_ sender: Any) {
        if let runner = runner {
            runner.cancel()
        }
    }
    
    open func showOnMain(message: String, type: PresenterType) {
        var attributes: [NSAttributedString.Key: Any] = [:]
        switch type {
        case .info:
            attributes[.foregroundColor] = NSColor.textColor
        case .pass:
            attributes[.foregroundColor] = NSColor.black
            attributes[.backgroundColor] = NSColor.green
        case .fail:
            attributes[.foregroundColor] = NSColor.white
            attributes[.backgroundColor] = NSColor.red
            
            failCount += 1
        }
        let string = NSAttributedString(string: message + "\n", attributes: attributes)
        messageTextView.textStorage?.append(string)
        messageTextView.scrollToEndOfDocument(nil)
    }
    
    open func show(message: String, type: PresenterType) {
        DispatchQueue.main.async() {
            self.showOnMain(message: message, type: type)
        }
    }
    
    open func completedOnMain() {
        runner = nil
        
        startButton?.isEnabled = true
        cancelButton?.isEnabled = false
        showOnMain(message: String(format: "completed with %d failures", failCount), type: failCount == 0 ? .pass : .fail)
        NSSound(named: "Ping")?.play()
    }
    
    open func completed() {
        DispatchQueue.main.async() {
            self.completedOnMain()
        }
    }
    

}
