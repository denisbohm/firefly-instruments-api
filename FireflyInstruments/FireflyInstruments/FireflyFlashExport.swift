//
//  FireflyFlashExport.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/19/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

public class FireflyFlashExport {

    public enum Error: Swift.Error {
        case failure
    }
    
    public init() {
    }
    
    public func function(executable: FDExecutable, name: String) throws -> UInt32 {
        guard let function: FDExecutableFunction = executable.functions.object(forKey: name) as? FDExecutableFunction else {
            throw Error.failure
        }
        return function.address
    }
    
    public func transcode(resource: String, address: UInt32, length: UInt32) throws {
        guard let path = Bundle(for: FDExecutable.self).path(forResource: resource, ofType: "elf") else {
            throw Error.failure
        }
        let executable = FDExecutable()
        try executable.load(path)
        executable.sections = executable.combineAllSectionsType(.program, address: address, length: length, pageSize: 4)
        if executable.sections.count != 1 {
            throw Error.failure
        }
        let section = executable.sections[0]
        
        let haltAddress = try function(executable: executable, name: "halt")
        let writePagesAddress = try function(executable: executable, name: "write_pages")
        
        let header = """
        #ifndef FDI_FIREFLY_FLASH_APOLLO
        #define FDI_FIREFLY_FLASH_APOLLO

        #include "fdi_firefly_flash.h"

        extern fdi_firefly_flash_t fdi_firefly_flash_apollo;

        #endif
        """
        print(header)
        
        var source = """
        #include "fdi_firefly_flash_apollo.h"
        
        static uint8_t executable_data[];
        
        fdi_firefly_flash_t fdi_firefly_flash_apollo = {
        .executable_range = { .address = 0x\(String(format: "%08x", section.address)), .length = \(section.data.count) },
        .executable_data = executable_data,
        .page_length = 8192,
        .halt_address = 0x\(String(format: "%08x", haltAddress)),
        .write_pages_address = 0x\(String(format: "%08x", writePagesAddress)),
        };
        
        static uint8_t executable_data[] = {
        """
        for i in 0 ..< section.data.count {
            if (i % 16) == 0 {
                source += "\n"
            }
            let byte = section.data[i]
            source += String(format: "0x%02x, ", byte)
        }
        source += """
        
        };
        """
        print(source)
    }
    
    public func apollo() {
        do {
            try transcode(resource: "FireflyFlashAPOLLO", address: 0x10000000, length: 0x40000)
        } catch {
            print("error: \(error)")
        }
    }
    
}
