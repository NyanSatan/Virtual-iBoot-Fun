//
//  Debug.h
//  virtualization_test
//
//  Created by noone on 12/4/21.
//

/*
 * Just colorful printf macroses
 */

#ifndef Debug_h
#define Debug_h

#define SUCCESS_PRINT(format, ...) printf("\033[1;32m" format "\033[0m\n", ##__VA_ARGS__)
#define WARNING_PRINT(format, ...) printf("\033[1;33m" format "\033[0m\n", ##__VA_ARGS__)
#define ERROR_PRINT(format, ...) printf("\033[1;31m" format "\033[0m\n", ##__VA_ARGS__)

#endif /* Debug_h */
