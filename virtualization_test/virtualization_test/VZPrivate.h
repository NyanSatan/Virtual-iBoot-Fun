//
//  VZPrivate.h
//  virtualization_test
//
//  Created by noone on 12/4/21.
//

/*
 * This file defines interfaces/extensions
 * needed to access private parts of
 * Virtualization framework's API
 */

#ifndef VZPrivate_h
#define VZPrivate_h

#import <Foundation/Foundation.h>

/*
 * Start options. Not really needed in our
 * case, as we don't define any storage,
 * and thus will always end up in DFU mode.
 * Most of the require the private entitlement
 * (com.apple.private.virtualization)
 */

@interface _VZVirtualMachineStartOptions : NSObject

@property BOOL restartAction;
@property BOOL panicAction;
@property BOOL stopInIBootStage1;
@property BOOL stopInIBootStage2;
@property BOOL bootMacOSRecovery;
@property BOOL forceDFU;

@end


/*
 * Extension for VZVirtualMachine, needed for
 * _startWithOptions:completionHandler:.
 * Well, not actually really needed
 */

@interface VZVirtualMachine()
- (void)_startWithOptions:(_VZVirtualMachineStartOptions *_Nonnull)options completionHandler:(void (^_Nonnull)(NSError * _Nullable errorOrNil))completionHandler;
@end


/*
 * Extension for VZMacPlatformConfiguration,
 * needed for _setProductionModeEnabled:.
 * Makes it run with CPFM:01 (no production fuse)
 */

@interface VZMacPlatformConfiguration()
- (void)_setProductionModeEnabled:(BOOL)enabled;
@end


/*
 * Interface for _VZGDBDebugStubConfiguration,
 * needed for debug server. Just need port
 * property here
 */

@interface _VZGDBDebugStubConfiguration : NSObject <NSCopying>
@property NSInteger port;
@end


/*
 * Extension for VZVirtualMachineConfiguration,
 * needed for _setDebugStub:, which enables
 * GDB server on the requested port
 */

@interface VZVirtualMachineConfiguration()
- (void)_setDebugStub:(_VZGDBDebugStubConfiguration *_Nonnull)config;
@end


/*
 * Extension for VZMacOSBootLoader,
 * needed for _setROMURL:, which
 * allows to pass custom ROM (AVPBooter)
 */

@interface VZMacOSBootLoader()
- (void)_setROMURL:(NSURL *_Nonnull)url;
- (NSURL *_Nullable)_romURL;
@end


/*
 * Interface for _VZPL011SerialPortConfiguration,
 * needed for getting serial output from iBoot,
 * since PL011 is the one used as debug UART port
 */

@interface _VZPL011SerialPortConfiguration : VZSerialPortConfiguration
- (instancetype _Nonnull)init;
@end


#endif /* VZPrivate_h */
