//
//  VMDelegate.h
//  virtualization_test
//
//  Created by noone on 12/4/21.
//

#import <Foundation/Foundation.h>
#import <Virtualization/Virtualization.h>

NS_ASSUME_NONNULL_BEGIN

@interface VMDelegate : NSObject <VZVirtualMachineDelegate>

/*
 * Paths
 */

@property NSString *romPath;
@property NSString *auxPath;    // apparently a storage for non-FS things
@property NSString *storagePath;

/*
 * Hardware model
 */

@property NSInteger dataRepresentationVersion;  // currently unknown, we set 1 here and it works
@property NSInteger platformVersion;    // 1 - BDID:F8, 2 - BDID:20, the rest - error
@property NSInteger minimumOSMajor;
@property NSInteger minimumOSMinor;
@property NSInteger minimumOSSubminor;

/*
 * Machine identifier
 */

@property BOOL needCustomBDID;
@property NSUInteger BDID;
@property NSUInteger ECID;

/*
 * Hardware configuration
 */

@property NSUInteger cpuCount;
@property NSUInteger memorySize;    // sizes below 2 GiBs will panic iBootStage 1

/*
 * Runtime configuration
 */

@property BOOL forceDFU;
@property BOOL productionMode;  // CPFM:01 if no, no idea (yet) what this changes on a VM,
                                // debugging is allowed regardless

@property BOOL needDebug;
@property NSInteger debugPort;

/*
 * Methods
 */

- (BOOL)configure;  // initialization and validation
- (BOOL)start;  // actually start, this blocks
- (void)stopByUserRequest;  // stop by user request, this doesn't block

@end

NS_ASSUME_NONNULL_END
