//
//  VMDelegate.m
//  virtualization_test
//
//  Created by noone on 12/4/21.
//

#import "VMDelegate.h"
#import "VZPrivate.h"
#import "Debug.h"

/* sizes below 2 GiBs will panic iBootStage 1 */
#define MINIMUM_MEMORY_SIZE_FOR_IBOOT   2ULL * 1024 * 1024 * 1024


@implementation VMDelegate {
    VZVirtualMachine *vm;
    _VZVirtualMachineStartOptions *options;
    BOOL exitStatus;
}

/*
 * Generating plists needed for initial platform configuration
 */

+ (NSData *)generateHardwareModelWithDataRepresentationVerison:(NSInteger)dataRepresentationVersion
                                     platformVersion:(NSInteger)platformVersion
                                     minimumOSMajor:(NSInteger)minimumOSMajor
                                     minimumOSMinor:(NSInteger)minimumOSMinor
                                     minimumOSSubminor:(NSInteger)minimumOSSubminor
                                     needCustomBoardID:(BOOL)needCustomBoardID
                                     boardID:(NSUInteger)boardID {
    NSMutableDictionary *dict = [@{
        @"DataRepresentationVersion" : [NSNumber numberWithInteger:dataRepresentationVersion],
        @"PlatformVersion" : [NSNumber numberWithInteger:platformVersion],
        @"MinimumSupportedOS" : @[[NSNumber numberWithInteger:minimumOSMajor], [NSNumber numberWithInteger:minimumOSMinor], [NSNumber numberWithInteger:minimumOSSubminor]],
    } mutableCopy];
    
    if (needCustomBoardID) {
        dict[@"BoardID"] = [NSNumber numberWithInteger:boardID];
    }
    
    return [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
}

+ (NSData *)generateMachineIdentifierWithECID:(NSUInteger)ecid {
    NSDictionary *dict = @{
        @"ECID" : [NSNumber numberWithUnsignedInteger:ecid]
    };
    
    return [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
}

/*
 * Initialization and validation
 */

- (BOOL)configure {
    VZVirtualMachineConfiguration *vmConfig = [[VZVirtualMachineConfiguration alloc] init];
    
    /* intializing bootloader, optionally setting path to custom AVPBooter */
    VZMacOSBootLoader *bootloader = [[VZMacOSBootLoader alloc] init];
    if (self.romPath) {
        [bootloader _setROMURL:[NSURL fileURLWithPath:self.romPath]];
    }
    
    [vmConfig setBootLoader:bootloader];
    
    
    /* intializing platform configuration - BDID, production mode, platform version and etc. go here */
    VZMacPlatformConfiguration *platformConfig = [[VZMacPlatformConfiguration alloc] init];
    [platformConfig setHardwareModel:[[VZMacHardwareModel alloc] initWithDataRepresentation:[VMDelegate generateHardwareModelWithDataRepresentationVerison:self.dataRepresentationVersion platformVersion:self.platformVersion minimumOSMajor:self.minimumOSMajor minimumOSMinor:self.minimumOSMinor minimumOSSubminor:self.minimumOSSubminor needCustomBoardID:self.needCustomBDID boardID:self.BDID]]];
    [platformConfig setMachineIdentifier:[[VZMacMachineIdentifier alloc] initWithDataRepresentation:[VMDelegate generateMachineIdentifierWithECID:self.ECID]]];
    [platformConfig _setProductionModeEnabled:self.productionMode];
    
    
    /* initializing auxiliary storage - apparently a storage for non-FS things (NVRAM, firmware partitions and etc.). If doesn't exist, it will create it */
    NSError *error = nil;
    [platformConfig setAuxiliaryStorage:[[VZMacAuxiliaryStorage alloc] initCreatingStorageAtURL:[NSURL fileURLWithPath:self.auxPath] hardwareModel:[platformConfig hardwareModel] options:VZMacAuxiliaryStorageInitializationOptionAllowOverwrite error:&error]];
    if (error) {
        ERROR_PRINT("error creating auxiliary storage: %s", [[error debugDescription] UTF8String]);
        return NO;
    }
    
    [vmConfig setPlatform:platformConfig];
    
    
    /* intializing CPU count, memory and debug (if needed) */
    [vmConfig setCPUCount:self.cpuCount];
    
    /* warn user, that sizes below 2 GiBs will panic iBootStage 1 */
    if (self.memorySize < MINIMUM_MEMORY_SIZE_FOR_IBOOT) {
        WARNING_PRINT("requested memory size might be too small to run iBoot");
    }
    
    [vmConfig setMemorySize:self.memorySize];
    
    if (self.needDebug) {
        _VZGDBDebugStubConfiguration *debugConfig = [[_VZGDBDebugStubConfiguration alloc] init];
        [debugConfig setPort:self.debugPort];
        [vmConfig _setDebugStub:debugConfig];
    }
    
    /* intializing entropy, for whatever that means */
    VZVirtioEntropyDeviceConfiguration *entropy = [[VZVirtioEntropyDeviceConfiguration alloc] init];
    [vmConfig setEntropyDevices:@[entropy]];
    
    
    /* intializing debug UART for iBoot (PL011) and attaching it to stdout */
    /* TODO: optionally create a full-fledged character device instead */
    _VZPL011SerialPortConfiguration *serialPort = [[_VZPL011SerialPortConfiguration alloc] init];
    serialPort.attachment = [[VZFileHandleSerialPortAttachment alloc] initWithFileHandleForReading:nil fileHandleForWriting:[NSFileHandle fileHandleWithStandardOutput]];
    [vmConfig setSerialPorts:@[serialPort]];
    
    /* intializing storage, I used it for some tests, currently disabled */
    //[vmConfig setStorageDevices:@[[[VZVirtioBlockDeviceConfiguration alloc] initWithAttachment:[[VZDiskImageStorageDeviceAttachment alloc] initWithURL:[NSURL fileURLWithPath:@"/tmp/str.bin"] readOnly:NO error:nil]]]];
    
    /* intializing start options, not really needed for reasons stated many times already */
    options = [[_VZVirtualMachineStartOptions alloc] init];
    [options setForceDFU:self.forceDFU];
    
    /* validating our new configuration */
    [vmConfig validateWithError:&error];
    if (error) {
        ERROR_PRINT("VM configuration validation failed with error: %s", [[error debugDescription] UTF8String]);
        return NO;
    }
    
    /* intializing our new VM, events will be handled by this instance */
    vm = [[VZVirtualMachine alloc] initWithConfiguration:vmConfig];
    [vm setDelegate:self];
    
    return YES;
}

- (BOOL)start {
    /* starting (with options - not really needed currently) */
    [vm _startWithOptions:options completionHandler:^(NSError *error) {
        
        /* failure cause */
        if (error) {
            ERROR_PRINT("VM failed to start: %s", [[error debugDescription] UTF8String]);
            self->exitStatus = NO;
            CFRunLoopStop(CFRunLoopGetCurrent());
            
        /* non-failure cause */
        } else {
            SUCCESS_PRINT("VM is running!");
            
            if (self.needDebug) {
                SUCCESS_PRINT("GDB server is running on port %ld!", (long)self.debugPort);
            }
        }
    }];
    
    /* loop until shut down event - with error or not */
    CFRunLoopRun();
    
    return exitStatus;
}

/*
 * Graceful shutdown event handling
 */

- (void)guestDidStopVirtualMachine:(VZVirtualMachine *)virtualMachine {
    SUCCESS_PRINT("VM stopped on its' own!");
    exitStatus = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

/*
 * Shutdown with error event handling
 */

- (void)virtualMachine:(VZVirtualMachine *)virtualMachine didStopWithError:(NSError *)error {
    ERROR_PRINT("VM stopped with error: %s", [[error debugDescription] UTF8String]);
    exitStatus = NO;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

@end
