//
//  USBHIDMonitor.h
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "USBHIDDevice.h"

@class USBHIDMonitor;

@protocol USBHIDMonitorDelegate <NSObject>

- (void)usbHidMonitor:(nonnull USBHIDMonitor *)monitor deviceAdded:(nonnull USBHIDDevice *)device;
- (void)usbHidMonitor:(nonnull USBHIDMonitor *)monitor deviceRemoved:(nonnull USBHIDDevice *)device;

@end

@interface USBHIDMonitorMatcher : NSObject

+ (nonnull USBHIDMonitorMatcher *)USBHIDMonitorMatcher:(nonnull NSString *)name vid:(uint16_t)vid pid:(uint16_t)pid;

@property (nonnull, readonly) NSString *name;
@property (readonly) uint16_t vid;
@property (readonly) uint16_t pid;

@end

@interface USBHIDMonitor : NSObject

+ (nonnull USBHIDMonitor *)USBHIDMonitor:(nonnull NSArray<USBHIDMonitorMatcher *> *)matchers;

@property (nonnull, readonly) NSArray<USBHIDMonitorMatcher *> *matchers;

@property (nonnull) id<USBHIDMonitorDelegate> delegate;

@property (nonnull, readonly) NSArray<USBHIDDevice *> *devices;

- (void)start;
- (void)stop;

- (nullable USBHIDDevice *)deviceWithLocationID:(NSInteger)locationID;

@end