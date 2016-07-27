//
//  USBHIDDevice_Private.h
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import "USBHIDDevice.h"

#import <IOKit/hid/IOHIDManager.h>

@class USBHIDMonitor;

@interface USBHIDDevice ()

+ (USBHIDDevice *)usbHidDevice:(USBHIDMonitor *)monitor hidDeviceRef:(IOHIDDeviceRef) hidDeviceRef;

@property (weak) USBHIDMonitor *monitor;
@property IOHIDDeviceRef hidDeviceRef;
@property NSMutableData *inputData;
@property NSMutableData *outputData;
@property bool isOpen;
@property NSInteger *locationIDPointer;
@property NSInteger locationIDStorage;

@end