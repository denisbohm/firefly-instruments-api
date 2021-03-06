//
//  Programmer.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 5/16/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Foundation
import ARMSerialWireDebug

open class Programmer {
    
    public enum LocalError: Error {
        case preconditionFailure
        case firmwareMismatch
    }
    
    public var doUseStorage = true
    
    public init() {
    }
    
    open func loadIntoRAM(serialWireDebugScript: SerialWireDebugScript, resource: String, executable: FDExecutable, address: UInt32, length: UInt32) throws {
        let fixture = serialWireDebugScript.fixture
        guard
            let fileSystem = fixture.fileSystem,
            let storageInstrument = fixture.storageInstrument,
            let serialWireInstrument = serialWireDebugScript.serialWireInstrument,
            let serialWireDebug = serialWireDebugScript.serialWireDebug
        else {
            throw LocalError.preconditionFailure
        }
        
        guard let section = executable.combineAllSectionsType(.program, address: address, length: length, pageSize: 4).last else {
            throw LocalError.preconditionFailure
        }
        let entry = try fileSystem.ensure(resource, data: section.data)
        
        try serialWireDebug.reset()
        let length = UInt32(section.data.count)
        try serialWireInstrument.writeFromStorage(section.address, length: length, storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
        try serialWireInstrument.compareToStorage(section.address, length: length, storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
    }

    open func setupFlash(serialWireDebugScript: SerialWireDebugScript, processor: String) throws -> FDFireflyFlash {
        let fixture = serialWireDebugScript.fixture
        guard let serialWireDebug = serialWireDebugScript.serialWireDebug else {
            throw LocalError.preconditionFailure
        }
        let flash = try FDFireflyFlash(processor)
        flash.serialWireDebug = serialWireDebug
        flash.logger = serialWireDebug.logger
        try flash.setupProcessor()
        if fixture.fileSystem != nil {
            let resource = flash.resource()
            let executable = try flash.readFirmware()
            try serialWireDebug.halt()
            try loadIntoRAM(serialWireDebugScript: serialWireDebugScript, resource: resource, executable: executable, address: flash.ramAddress, length: flash.ramSize)
        } else {
            try flash.loadFirmwareIntoRAM()
        }
        try flash.setupCortexM()
        
        var erased: ObjCBool = false
        try flash.disableWatchdog(byErasingIfNeeded: &erased)
        
        return flash
    }
    
    open func programResult(presenter: Presenter, name: String, data: Data, verify: Data) {
        let pass = data == verify
        if !pass {
            var offset = 0
            let firmwareBytes = [UInt8](data)
            let verifyBytes = [UInt8](verify)
            for i in 0 ..< data.count {
                if firmwareBytes[i] != verifyBytes[i] {
                    offset = i
                    break
                }
            }
            let value = verifyBytes[offset]
            let expected = firmwareBytes[offset]
            presenter.show(message: "\(name) error: offset: \(offset), value: \(value), expected: \(expected)", pass: false)
        } else {
            presenter.show(message: "\(name) firmware", pass: true)
        }
    }
    
    open class WriteViaStorage : NSObject, FDFireflyFlashWriter {
        
        public let serialWireInstrument: SerialWireInstrument
        public let storageInstrument: StorageInstrument
        public let storageAddress: UInt32
        
        public init(serialWireInstrument: SerialWireInstrument, storageInstrument: StorageInstrument, storageAddress: UInt32) {
            self.serialWireInstrument = serialWireInstrument
            self.storageInstrument = storageInstrument
            self.storageAddress = storageAddress
        }
        
        open func write(_ heapAddress: UInt32, offset: UInt32, data: Data) throws {
            try serialWireInstrument.writeFromStorage(heapAddress, length: UInt32(data.count), storageIdentifier: storageInstrument.identifier, storageAddress: storageAddress + offset)
        }
        
    }
    
    open func programFlash(presenter: Presenter, fixture: Fixture, flash: FDFireflyFlash, name: String, firmware: IntelHex) throws {
        var (addressBounds, data) = try firmware.combineData()
        presenter.show(message: String(format: "\(name) firmware address: %08X - %08X", addressBounds.min, addressBounds.max))
        let address = addressBounds.min
        var length = data.count
        let pageSize = Int(flash.pageSize)
        length = ((length + pageSize - 1) / pageSize) * pageSize
        data.count = length
        
        if doUseStorage, let storageInstrument = fixture.storageInstrument, let fileSystem = fixture.fileSystem, let serialWireInstrument = fixture.serialWire1Instrument {
            let entry = try fileSystem.ensure(name, data: data)

            let writer = WriteViaStorage(serialWireInstrument: serialWireInstrument, storageInstrument: storageInstrument, storageAddress: entry.address)
            try flash.writePages(address, data: data, erase: true, writer: writer)
            var pass = false
            do {
                try serialWireInstrument.compareToStorage(address, length: UInt32(length), storageIdentifier: storageInstrument.identifier, storageAddress: entry.address)
                pass = true
            } catch let error as CustomStringConvertible {
                presenter.show(message: "verify error: \(error.description)")
            } catch {
                presenter.show(message: "verify error: \(error.localizedDescription)")
            }
            presenter.show(message: "\(name) firmware", pass: pass)
        } else {
            // !!! with 31 pagesPerWrite it fails at 224KB - need to investigate -denis
            flash.pagesPerWrite = 16
            try flash.writePages(address, data: data, erase: true)
            let verify = try flash.serialWireDebug!.readMemory(address, length: UInt32(data.count))
            programResult(presenter: presenter, name: name, data: data, verify: verify)
        }
    }
    
}
