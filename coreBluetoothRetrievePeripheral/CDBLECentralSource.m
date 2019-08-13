//
//  CDBLECentralSource.m
//  coreBluetoothRetrievePeripheral
//
//  Created by ZhangYi on 2019/8/12.
//  Copyright © 2019 ZhangYi. All rights reserved.
//

#import "CDBLECentralSource.h"
#include <zlib.h>

@implementation CDBLECentralSource

+ (uint32_t)CRC32ValueByXCYDecoding:(NSData *)data {
    
    uLong crc = crc32(0L, Z_NULL, 0);
    crc = crc32(crc, [data bytes], (uInt)[data length]);
    return (uint32_t)crc;
}

+ (Byte *)convertNSIntegerDataToBytes:(NSInteger)original bytesLength:(NSInteger)length {
    Byte *resultBytes= malloc(sizeof(Byte)*(length));
    for (int i = 0; i < length; i++) {
        resultBytes[i] = (Byte)(original >> (length - i - 1) * 8);
    }
    return resultBytes;
}

@end
