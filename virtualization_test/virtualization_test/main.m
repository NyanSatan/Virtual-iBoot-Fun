//
//  main.m
//  virtualization_test
//
//  Created by noone on 12/3/21.
//

#import <Foundation/Foundation.h>
#import "VMDelegate.h"

#define DATA_REPRESENTATION_VERSION 1
#define PLATFORM_VERSION            2
#define MINIMUM_VERSION_MAJOR       12
#define MINIMUM_VERSION_MINOR       0
#define MINIMUM_VERSION_SUBMINOR    0

#define CPU_COUNT   1
#define MAX_CPU_COUNT   4

#define MEMORY_SIZE_GIBS 2
#define GIBS(count) ((uint64_t)count * 1024 * 1024 * 1024)

#define AUX_PATH    "/tmp/aux.bin"


VMDelegate *delegate;

void sig_handler(int signal);

void usage(const char *program_name) {
    printf("usage: %s [OPTIONS]\n", program_name);
    printf("\t-r\tpath to custom ROM\n");
    printf("\t-a\tpath to auxiliary storage, default - %s\n", AUX_PATH);
    printf("\t-s\tpath to storage, must already exist, defualt - disabled\n");
    printf("\t-d\tdebug port, default - disabled\n");
    printf("\t-v\tplatform version, default - 2\n");
    printf("\t-c\tcount of CPUs, default - 1\n");
    printf("\t-m\tmemory size in GiBs, default - 2\n");
    printf("\t-b\tboard ID, default - defined by platform version\n");
    printf("\t-e\tECID, default - random\n");
    printf("\t-p\tdemote production mode\n");
    printf("\t-f\tforce DFU\n");
}

const char *args = "r:a:s:d:v:c:m:b:e:pf";

int parse_numeric_arg(const char *arg, int base, uint64_t *val, uint64_t max_val) {
    char *stop;
    uint64_t result = strtoull(arg, &stop, base);
    if (*stop || result > max_val) {
        return -1;
    }
    
    *val = result;
    
    return 0;
}

int main(int argc, const char *argv[]) {
    /*
     * Parsing args, nothing interesting
     */
    
    const char *rom_path = NULL;
    const char *aux_path = AUX_PATH;
    const char *storage_path = NULL;
    bool need_debug = false;
    uint16_t debug_port = 0;
    uint8_t platform_version = PLATFORM_VERSION;
    uint8_t cpu_count = CPU_COUNT;
    uint8_t memory_size_gibs = MEMORY_SIZE_GIBS;
    bool need_custom_boardid = false;
    uint8_t boardid = 0;
    uint64_t ecid = (uint64_t)arc4random_uniform(UINT32_MAX) << 32 | arc4random_uniform(UINT32_MAX);
    bool need_demote = false;
    bool force_dfu = false;
    
    
    char c;
    while ((c = getopt(argc, (char *const *)argv, args)) != -1) {
        switch (c) {
            case 'r':
                rom_path = optarg;
                break;
                
            case 'a':
                aux_path = optarg;
                break;
                
            case 's':
                storage_path = optarg;
                break;
                
            case 'd': {
                uint64_t _debug_port;
                if (parse_numeric_arg(optarg, 10, &_debug_port, UINT16_MAX) != 0) {
                    printf("invalid debug port\n");
                    return -1;
                }
                
                need_debug = true;
                debug_port = (uint16_t)_debug_port;
                
                break;
            }
                
            case 'v': {
                uint64_t _platform_version;
                if (parse_numeric_arg(optarg, 0, &_platform_version, UINT8_MAX) != 0) {
                    printf("invalid platform version\n");
                    return -1;
                }

                platform_version = (uint8_t)_platform_version;
                
                break;
            }
                
            case 'c': {
                uint64_t _cpu_count;
                if (parse_numeric_arg(optarg, 0, &_cpu_count, MAX_CPU_COUNT) != 0) {
                    printf("invalid CPU count\n");
                    return -1;
                }

                cpu_count = (uint8_t)_cpu_count;
                
                break;
            }
                
            case 'm': {
                uint64_t _memory_size_gibs;
                if (parse_numeric_arg(optarg, 0, &_memory_size_gibs, UINT8_MAX) != 0) {
                    printf("invalid memory size\n");
                    return -1;
                }

                memory_size_gibs = (uint8_t)_memory_size_gibs;
                
                break;
            }
                
            case 'b': {
                uint64_t _boardid;
                if (parse_numeric_arg(optarg, 0, &_boardid, UINT8_MAX) != 0) {
                    printf("invalid board ID\n");
                    return -1;
                }
                
                need_custom_boardid = true;
                boardid = (uint8_t)_boardid;
                
                break;
            }
            case 'e':{
                if (parse_numeric_arg(optarg, 0, &ecid, UINT64_MAX) != 0) {
                    printf("invalid ECID\n");
                    return -1;
                }
                
                break;
            }
                
            case 'p':
                need_demote = true;
                break;
                
            case 'f':
                force_dfu = true;
                break;
                
            case '?':
                printf("invalid args\n");
                usage(argv[0]);
                return -1;
                
            default:
                abort();
                break;
        }
    }
    
    @autoreleasepool {
        /*
         * Configuring
         */
        
        delegate = [[VMDelegate alloc] init];
        
        /* if no ROM path set, it will just use default AVPBooter */
        if (rom_path) {
            [delegate setRomPath:[NSString stringWithUTF8String:rom_path]];
        }
        
        if (storage_path) {
            [delegate setStoragePath:[NSString stringWithUTF8String:storage_path]];
        }
        
        [delegate setAuxPath:[NSString stringWithUTF8String:aux_path]];

        [delegate setDataRepresentationVersion:DATA_REPRESENTATION_VERSION];
        [delegate setPlatformVersion:platform_version];
        
        [delegate setMinimumOSMajor:MINIMUM_VERSION_MAJOR];
        [delegate setMinimumOSMinor:MINIMUM_VERSION_MINOR];
        [delegate setMinimumOSSubminor:MINIMUM_VERSION_SUBMINOR];
        
        [delegate setECID:ecid];
        [delegate setCpuCount:cpu_count];
        [delegate setMemorySize:GIBS(memory_size_gibs)];
        [delegate setProductionMode:!need_demote];
        
        /* if no custom BDID set, it will just use default for requested platform version */
        if (need_custom_boardid) {
            [delegate setNeedCustomBDID:YES];
            [delegate setBDID:boardid];
        }
        
        if (need_debug) {
            [delegate setNeedDebug:YES];
            [delegate setDebugPort:debug_port];
        }
        
        /* not really needed to force DFU, will go there by default */
        /* UPD: now with storage support this might make sense */
        [delegate setForceDFU:force_dfu];
        
        
        /* if there's something wrong, it will print about it */
        if (![delegate configure]) {
            return -1;
        }
        
        /*
         * Setting up Ctrl+C handler
         */
        
        signal(SIGINT, sig_handler);
        
        /*
         * Starting
         * Blocks until VM is shut down for whatever reason
         */
        
        return [delegate start] ? 0 : -1;
    }
}

void sig_handler(int signal) {
    [delegate stopByUserRequest];
}
