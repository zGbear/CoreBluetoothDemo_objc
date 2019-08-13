//
//  CDBLECentralSource.h
//  coreBluetoothRetrievePeripheral
//
//  Created by ZhangYi on 2019/8/12.
//  Copyright © 2019 ZhangYi. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CDBLECentralSource : NSObject

+ (uint32_t)CRC32ValueByXCYDecoding:(NSData *)data;

+ (Byte *)convertNSIntegerDataToBytes:(NSInteger)original bytesLength:(NSInteger)length;

@end

NS_ASSUME_NONNULL_END
