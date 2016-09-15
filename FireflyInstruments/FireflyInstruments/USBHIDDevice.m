//
//  USBHIDDevice.m
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import "USBHIDDevice.h"
#import "USBHIDDevice_Private.h"

#import "FDError.h"

#import <IOKit/hid/IOHIDManager.h>

@implementation USBHIDDevice

+ (USBHIDDevice *)usbHidDevice:(USBHIDMonitor *)monitor hidDeviceRef:(IOHIDDeviceRef) hidDeviceRef
{
    USBHIDDevice * usbHidDevice = [[USBHIDDevice alloc] init];
    usbHidDevice.monitor = monitor;
    usbHidDevice.hidDeviceRef = hidDeviceRef;
    return usbHidDevice;
}

- (id)init
{
    if (self = [super init]) {
        _inputData = [NSMutableData data];
        [_inputData setLength:64];
        _outputData = [NSMutableData data];
        [_outputData setLength:64];
    }
    return self;
}

- (BOOL)open:(NSError **)error
{
    if (_isOpen) {
        return YES;
    }

    // !!! It appears that the HID manager does the open and scheduling. -denis
    /*
     IOReturn ioReturn = IOHIDDeviceOpen(_hidDeviceRef, kIOHIDOptionsTypeSeizeDevice);
     if (ioReturn != kIOReturnSuccess) {

     }
     IOHIDDeviceScheduleWithRunLoop(_hidDeviceRef, _monitor.runLoopRef, kCFRunLoopDefaultMode);
     */
    IOHIDDeviceRegisterInputReportCallback(_hidDeviceRef, (uint8_t *)_inputData.bytes, _inputData.length, FDUSBHIDDeviceInputReportCallback, (__bridge void *)self);

    _isOpen = true;
    return YES;
}

- (void)close
{
    if (!_isOpen) {
        return;
    }

    // !!! It appears that the HID manager does the open and scheduling. -denis
    // !!! If we close and unregister we (sometimes) won't get removal callbacks, etc... -denis
    //    IOHIDDeviceClose(_hidDeviceRef, kIOHIDOptionsTypeNone);
    IOHIDDeviceRegisterInputReportCallback(_hidDeviceRef, (uint8_t *)_inputData.bytes, _inputData.length, NULL, (__bridge void *)self);
    //    IOHIDDeviceUnscheduleFromRunLoop(_hidDeviceRef, _monitor.runLoopRef, kCFRunLoopDefaultMode);

    _isOpen = false;
}

- (BOOL)setReport:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error
{
//    NSLog(@"USB HID Set Report: %@", data);

    if (!_isOpen) {
        return FDErrorReturn(error, nil);
    }
    [_outputData resetBytesInRange:NSMakeRange(0, _outputData.length)];
    [data getBytes:(void *)_outputData.bytes length:_outputData.length];
    IOReturn ioReturn = IOHIDDeviceSetReport(_hidDeviceRef, kIOHIDReportTypeOutput, 0x81, _outputData.bytes, _outputData.length);
    if (ioReturn != kIOReturnSuccess) {

    }
    return YES;
}

- (void)inputReport:(NSData *)data
{
//    NSLog(@"USB HID Input Report: %@", data);

    [_delegate usbHidDevice:self inputReport:data];
}

static
void FDUSBHIDDeviceInputReportCallback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex reportLength)
{
    USBHIDDevice *device = (__bridge USBHIDDevice *)context;
    [device inputReport:[NSData dataWithBytes:report length:reportLength]];
}

- (NSInteger *)locationID
{
    if (_locationIDPointer == nil) {
        CFTypeRef typeRef = IOHIDDeviceGetProperty(_hidDeviceRef, CFSTR(kIOHIDLocationIDKey));
        if (typeRef && (CFGetTypeID(typeRef) == CFNumberGetTypeID())) {
            CFNumberRef locationRef = (CFNumberRef)typeRef;
            long location = 0;
            if (CFNumberGetValue(locationRef, kCFNumberLongType, &location)) {
                _locationIDStorage = location;
                _locationIDPointer = &_locationIDStorage;
            }
        }
    }
    return _locationIDPointer;
}

@end
