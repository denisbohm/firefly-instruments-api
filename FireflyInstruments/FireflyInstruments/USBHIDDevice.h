//
//  USBHIDDevice.h
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/20/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class USBHIDDevice;

@protocol USBHIDDeviceDelegate <NSObject>

- (void)usbHidDevice:(nonnull USBHIDDevice *)device inputReport:(nonnull NSData *)data;

@end

@interface USBHIDDevice : NSObject

@property (nullable) id<USBHIDDeviceDelegate> delegate;

@property (readonly, nullable) NSInteger *locationID;

- (BOOL)open:(NSError * _Nullable * _Nullable)error;
- (void)close;

- (BOOL)setReport:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;

@end