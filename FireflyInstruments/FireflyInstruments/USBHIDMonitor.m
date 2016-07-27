//
//  USBHIDMonitor.m
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import "USBHIDMonitor.h"

#import "USBHIDDevice_Private.h"

#import <IOKit/hid/IOHIDManager.h>

@interface USBHIDMonitorMatcher ()

@property NSString *name;
@property uint16_t vid;
@property uint16_t pid;

@end

@implementation USBHIDMonitorMatcher

+ (USBHIDMonitorMatcher *)USBHIDMonitorMatcher:(NSString *)name vid:(uint16_t)vid pid:(uint16_t)pid
{
    USBHIDMonitorMatcher *matcher = [[USBHIDMonitorMatcher alloc] init];
    matcher.name = name;
    matcher.vid = vid;
    matcher.pid = pid;
    return matcher;
}

static long get_long_property(IOHIDDeviceRef device, CFStringRef key)
{
    CFTypeRef ref = IOHIDDeviceGetProperty(device, key);
    if (ref) {
        if (CFGetTypeID(ref) == CFNumberGetTypeID()) {
            long value;
            CFNumberGetValue((CFNumberRef) ref, kCFNumberSInt32Type, &value);
            return value;
        }
    }
    return 0;
}

static unsigned short get_vendor_id(IOHIDDeviceRef device)
{
    return get_long_property(device, CFSTR(kIOHIDVendorIDKey));
}

static unsigned short get_product_id(IOHIDDeviceRef device)
{
    return get_long_property(device, CFSTR(kIOHIDProductIDKey));
}

- (BOOL)matches:(IOHIDDeviceRef)deviceRef
{
    return (get_vendor_id(deviceRef) == self.vid) && (get_product_id(deviceRef) == self.pid);
}

@end

@interface USBHIDMonitor ()

@property NSArray<USBHIDMonitorMatcher *> *matchers;
@property IOHIDManagerRef hidManagerRef;
@property NSThread *hidRunLoopThread;
@property CFRunLoopRef runLoopRef;
@property NSMutableArray *hidDevices;

@end

@implementation USBHIDMonitor

+ (nonnull USBHIDMonitor *)USBHIDMonitor:(nonnull NSArray<USBHIDMonitorMatcher *> *)matchers
{
    USBHIDMonitor *monitor = [[USBHIDMonitor alloc] init];
    monitor.matchers = matchers;
    return monitor;
}

- (id)init
{
    if (self = [super init]) {
        _hidDevices = [NSMutableArray array];
    }
    return self;
}

- (NSArray *)devices
{
    return [NSArray arrayWithArray:_hidDevices];
}

- (void)removal:(USBHIDDevice *)device
{
    [device close];
    IOHIDDeviceRegisterRemovalCallback(device.hidDeviceRef, NULL, (__bridge void *)device);

    [_hidDevices removeObject:device];
    [_delegate usbHidMonitor:self deviceRemoved:device];
    CFRelease(device.hidDeviceRef);
    device.hidDeviceRef = 0;
}

static
void USBHIDMonitorRemovalCallback(void *context, IOReturn result, void *sender)
{
    USBHIDDevice *device = (__bridge USBHIDDevice *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [device.monitor removal:device];
    });
}

- (BOOL)matches:(IOHIDDeviceRef)deviceRef
{
    for (USBHIDMonitorMatcher *matcher in self.matchers) {
        if ([matcher matches:deviceRef]) {
            return YES;
        }
    }
    return NO;
}

- (void)deviceMatching:(IOHIDDeviceRef)hidDeviceRef
{
    if ((self.matchers != nil) && ![self matches:hidDeviceRef]) {
        return;
    }

    USBHIDDevice *device = [USBHIDDevice usbHidDevice:self hidDeviceRef:hidDeviceRef];
    CFRetain(hidDeviceRef);
    [_hidDevices addObject:device];

    IOHIDDeviceRegisterRemovalCallback(hidDeviceRef, USBHIDMonitorRemovalCallback, (__bridge void*)device);

    [_delegate usbHidMonitor:self deviceAdded:device];
}

static
void FDUSBHIDMonitorDeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef hidDeviceRef)
{
    USBHIDMonitor *monitor = (__bridge USBHIDMonitor *)context;
    [monitor deviceMatching:hidDeviceRef];
}

- (void)start
{
    _hidRunLoopThread = [[NSThread alloc] initWithTarget:self selector:@selector(hidRunLoop) object:nil];
    [_hidRunLoopThread start];
}

- (void)stop
{
    [_hidRunLoopThread cancel];
    BOOL done = NO;
    for (NSUInteger i = 0; i < 25; ++i) {
        [NSThread sleepForTimeInterval:0.1];
        if (!_hidRunLoopThread.isExecuting) {
            done = YES;
            break;
        }
    }
    if (!done) {
        NSLog(@"usb test thread failed to stop");
    }
    _hidRunLoopThread = nil;
    _hidDevices = [NSMutableArray array];
}

- (USBHIDDevice *)deviceWithLocationID:(NSInteger)locationID
{
    for (USBHIDDevice *device in _hidDevices) {
        NSInteger *deviceLocationID = device.locationID;
        if ((deviceLocationID != nil) && (*deviceLocationID == locationID)) {
            return device;
        }
    }
    return nil;
}

- (void)hidRunLoop
{
    @autoreleasepool {
        _hidManagerRef = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        _runLoopRef = CFRunLoopGetCurrent();
        IOHIDManagerScheduleWithRunLoop(_hidManagerRef, _runLoopRef, kCFRunLoopDefaultMode);
        IOReturn ioReturn = IOHIDManagerOpen(_hidManagerRef, 0);
        if (ioReturn != kIOReturnSuccess) {

        }
        if (self.matchers.count == 1) {
            NSString *vendorKey = [NSString stringWithCString:kIOHIDVendorIDKey encoding:NSUTF8StringEncoding];
            NSString *productKey = [NSString stringWithCString:kIOHIDProductIDKey encoding:NSUTF8StringEncoding];
            USBHIDMonitorMatcher *matcher = _matchers.firstObject;
            NSNumber *vendor = [NSNumber numberWithInt:matcher.vid];
            NSNumber *product = [NSNumber numberWithInt:matcher.pid];
            IOHIDManagerSetDeviceMatchingMultiple(_hidManagerRef, (__bridge CFArrayRef)@[@{vendorKey: vendor, productKey: product}]);
        } else {
            IOHIDManagerSetDeviceMatchingMultiple(_hidManagerRef, NULL);
        }
        IOHIDManagerRegisterDeviceMatchingCallback(_hidManagerRef, FDUSBHIDMonitorDeviceMatchingCallback, (__bridge void *)self);
    }

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (![_hidRunLoopThread isCancelled]) {
        @autoreleasepool {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }

    IOHIDManagerUnscheduleFromRunLoop(_hidManagerRef, _runLoopRef, kCFRunLoopDefaultMode);
    _runLoopRef = nil;
    IOHIDManagerClose(_hidManagerRef, 0);
    _hidManagerRef = nil;
}

@end