//
//  ViewController.m
//  coreBluetoothRetrievePeripheral
//
//  Created by ZhangYi on 2018/11/28.
//  Copyright © 2018 ZhangYi. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "CDBLECentralSource.h"

NSString * const CDDeviceCodoonSportWatchCharacteristicUUID = @"2A19";
NSString * const CDDeviceCodoonSportWatchResponseCharacteristicUUID = @"2A19";

typedef struct {
    uint16_t frameLength;
    uint8_t frameCountEveryGroup;
    uint8_t timeoutInterval;
}fileTransferParameter;

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *peripheralTableView;
@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableDictionary <NSString *, CBPeripheral *> *scanPeripheralResult;
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) NSMutableArray *advertisementDataSource;
@property (nonatomic, strong) NSUUID *Identity;
@property (nonatomic, strong) CBPeripheral *selectedPeripheral;

@property (nonatomic, strong) NSData *OTASourceFile;
@property (nonatomic, assign) fileTransferParameter OTAParameters;
@property (nonatomic, assign) NSInteger index;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:NULL options:nil];
    _scanPeripheralResult = @{}.mutableCopy;
    _peripheralTableView.delegate = self;
    _peripheralTableView.dataSource = self;
}

#pragma mark - CBPeripheralDelegate

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (![[advertisementData objectForKey:CBAdvertisementDataLocalNameKey] isEqualToString:@"COD_WATCH_X3"]) {
        return;
    }
    [self.dataSource addObject:peripheral];
    NSData *macData = [advertisementData objectForKey:CBAdvertisementDataManufacturerDataKey];
    if (!macData) {
        [self.advertisementDataSource addObject:@""];
    } else {
        Byte *bytes = (Byte *)[macData bytes];
        NSString *productId = [NSString stringWithFormat:@" %d-%d-%d-%d-%d-%d-%d-%d", bytes[0], (bytes[1]<<8) + bytes[2], (bytes[3]<<8) + bytes[4], (bytes[5]<<8) + bytes[6], bytes[7], (bytes[8] << 8) + bytes[9], (bytes[10]<<8) + bytes[11], bytes[12]];
        [self.advertisementDataSource addObject:productId];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.peripheralTableView reloadData];
    });
  
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connect success!");
    _Identity = peripheral.identifier;
    _selectedPeripheral = peripheral;
    _selectedPeripheral.delegate = self;
    [_selectedPeripheral discoverServices:@[[CBUUID UUIDWithString:@"180F"]]];
    _outputTextView.text = [_outputTextView.text stringByAppendingString:@"Connect success!\n"];
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    _outputTextView.text = [_outputTextView.text stringByAppendingString:@"didDiscoverServices!\n"];
//    _selectedPeripheral = peripheral;
//    _selectedPeripheral.dele gate = self;
    [_selectedPeripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CDDeviceCodoonSportWatchCharacteristicUUID]] forService:peripheral.services.firstObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
    _outputTextView.text = [_outputTextView.text stringByAppendingString:@"didDiscoverCharacteristicsForService!\n"];
//    _selectedPeripheral = peripheral;
//    _selectedPeripheral.delegate = self;
    CBCharacteristic *writeCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchCharacteristicUUID];
    CBCharacteristic *responseCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchResponseCharacteristicUUID];
    
    if (!writeCharacteristic || !responseCharacteristic) {
        NSLog(@"Characteristic illegal");
        return;
    }
    
    [_selectedPeripheral setNotifyValue:YES forCharacteristic:responseCharacteristic];
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    if ([peripheral.identifier.UUIDString isEqualToString:_Identity.UUIDString]) {
        NSLog(@"*****RSSI: %@*****",RSSI.description);
        NSString *outputString = [_outputTextView.text stringByAppendingString:@"\n"];
        _outputTextView.text = [outputString stringByAppendingString:RSSI.description];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        return;
    }
    NSLog(@"%@", characteristic.value);
    _outputTextView.text = [_outputTextView.text stringByAppendingString:[NSString stringWithFormat:@"responseData:%@\n", characteristic.value]];
    
    [self preferredFilterUpdateValue:characteristic.value];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"centralManagerDidDisconnectPeripheral!");
}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral {
    NSLog(@"peripheralIsReadyToSendWriteWithoutResponse");
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *selectedPeripheral = _dataSource[indexPath.row];
    [_centralManager connectPeripheral:selectedPeripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @(YES)}];
    [_centralManager stopScan];
}

-(NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath{
    void(^OTAActionDeleteHandler)(UITableViewRowAction *, NSIndexPath *) = ^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        
    };
    
    UITableViewRowAction *actionOTA = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"OTA" handler:OTAActionDeleteHandler];
    actionOTA.backgroundColor = [UIColor colorWithRed:204.f/255.f green:204.f/255.f blue:204.f/255.f alpha:1.0];

    return @[actionOTA];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 45.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    CBPeripheral *selectedPeripheral = _dataSource[indexPath.row];
    
    cell.textLabel.text = [selectedPeripheral.name stringByAppendingString:_advertisementDataSource[indexPath.row]];
    return cell;
}

#pragma mark - handle event

- (IBAction)scan:(id)sender {
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"180F"], [CBUUID UUIDWithString:@"0AF0"]] options:nil];
}

- (IBAction)retrieve:(id)sender {
    CBPeripheral *peripheral = [_centralManager retrievePeripheralsWithIdentifiers:@[_Identity]].firstObject;
    if (peripheral) {
        NSLog(@"YES");
    } else {
        NSLog(@"NO");
    }
}

- (IBAction)getRSSI:(id)sender {
    if (_selectedPeripheral) {
        [_selectedPeripheral readRSSI];
    }
}

- (IBAction)startHeartRate:(id)sender {
    if (!_selectedPeripheral) {
        return;
    }
    [self codoonSportWatchSyncHeartRateData];
}

- (IBAction)stopHeartRate:(id)sender {
    if (!_selectedPeripheral) {
        return;
    }
    [self codoonSportWatchStopSyncHeartRateData];
}

- (IBAction)OTAButtonDidClick:(UIButton *)sender {
    if (!_selectedPeripheral) {
        return;
    }
    _index = 0;
    NSString *fileName = @"GD01";
    NSData *bootData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:fileName withExtension:@"bin"]];
    _OTASourceFile = bootData;
    [self codoonSportWatchStartOTA];
}

#pragma mark - private method

- (void)codoonSportWatchSyncHeartRateData {
    UInt8 switchFlag = 0x00;
    UInt8 dataCategory = 0x03;
    
    NSMutableData *parameters = [NSMutableData data];
    [parameters appendBytes:&switchFlag length:1];
    [parameters appendBytes:&dataCategory length:1];
    
    NSData *data = [self commandDataWithMainCode:0x04 subCode:0x07 parameters:parameters];
    
    [self writeValue:data];
}

- (void)codoonSportWatchStopSyncHeartRateData {
    UInt8 switchFlag = 0x01;
    UInt8 dataCategory = 0x03;
    
    NSMutableData *parameters = [NSMutableData data];
    [parameters appendBytes:&switchFlag length:1];
    [parameters appendBytes:&dataCategory length:1];
    
    NSData *data = [self commandDataWithMainCode:0x04 subCode:0x07 parameters:parameters];
    
    [self writeValue:data];
}

#pragma mark - OTA

- (void)codoonSportWatchStartOTA {
    uint16_t singleFrameByteCount = 155;
    uint32_t binDataLength = (uint32_t)_OTASourceFile.length;
    uint8_t dataCategory = 0;
    
    NSMutableData *parameters = [NSMutableData data];
    [parameters appendBytes:[CDBLECentralSource convertNSIntegerDataToBytes:singleFrameByteCount bytesLength:2] length:2];
    [parameters appendBytes:[CDBLECentralSource convertNSIntegerDataToBytes:binDataLength bytesLength:4] length:4];
    [parameters appendBytes:&dataCategory length:1];
    NSData *data = [self commandDataWithMainCode:0x0a subCode:0x01 parameters:parameters];
    [self writeValue:data];
}


- (void)sendNext {
    uint32_t groupDataLength = self.OTAParameters.frameLength * self.OTAParameters.frameCountEveryGroup;
    NSInteger totalTurm = _OTASourceFile.length / groupDataLength;
    if (_index < totalTurm) {
        [self sendFile:[_OTASourceFile subdataWithRange:NSMakeRange(_index * groupDataLength, groupDataLength)]];
    } else if (_index == totalTurm) {
        [self sendFile:[_OTASourceFile subdataWithRange:NSMakeRange(_index * groupDataLength, _OTASourceFile.length - _index * groupDataLength)]];
    } else {
        [self sendTotalFileCRC];
    }
}

- (void)sendFile:(NSData *)groupFile {
    _index++;
    if (groupFile.length <= 0) {
        return;
    }
    uint8_t groupIndex = 0;
    while (groupIndex < self.OTAParameters.frameCountEveryGroup) {
        if (!self.selectedPeripheral.canSendWriteWithoutResponse) {
//            NSLog(@"==================等待");
//            [NSThread sleepForTimeInterval:0.5];
//            continue;
        }
        NSInteger subLength = MIN(self.OTAParameters.frameLength, (groupFile.length - groupIndex * self.OTAParameters.frameLength));
        NSData *sendData = [groupFile subdataWithRange:NSMakeRange(self.OTAParameters.frameLength * groupIndex, subLength)];
        NSMutableData *commandData = [NSMutableData data];
        UInt8 head = 0xAB;
        [commandData appendBytes:&head length:1];
        [commandData appendBytes:&groupIndex length:1];
        [commandData appendData:sendData];
        [self writeValue:commandData];
        if (subLength < self.OTAParameters.frameLength) {
            break;
        }
        groupIndex++;
    }
    uint32_t groupCrc = [CDBLECentralSource CRC32ValueByXCYDecoding:groupFile];
    uint8_t dataCategory = 0x00;
    
    NSMutableData *parameters = [NSMutableData data];
    [parameters appendBytes:[CDBLECentralSource convertNSIntegerDataToBytes:groupCrc bytesLength:4] length:4];
    [parameters appendBytes:&dataCategory length:1];
    NSData *data = [self commandDataWithMainCode:0x0a subCode:0x02 parameters:parameters];
    [self writeValue:data];
}

- (void)sendTotalFileCRC {
    uint32_t fileCRC = [CDBLECentralSource CRC32ValueByXCYDecoding:_OTASourceFile];
    uint8_t dataCategory = 0x00;
    
    NSMutableData *parameters = [NSMutableData data];
    [parameters appendBytes:[CDBLECentralSource convertNSIntegerDataToBytes:fileCRC bytesLength:4] length:4];
    [parameters appendBytes:&dataCategory length:1];
    NSData *data = [self commandDataWithMainCode:0x0a subCode:0x03 parameters:parameters];
    [self writeValue:data];
}

#pragma mark -

- (void)writeValue:(NSData *)value {
    NSLog(@"%@", value);
    CBCharacteristic *writeCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchCharacteristicUUID];
    CBCharacteristic *responseCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchResponseCharacteristicUUID];
    
    if (!writeCharacteristic || !responseCharacteristic) {
        NSLog(@"Characteristic illegal");
        return;
    }
    
    CBCharacteristicWriteType type = CBCharacteristicWriteWithoutResponse;
    if (writeCharacteristic.properties & CBCharacteristicPropertyWrite) {
        type = CBCharacteristicWriteWithResponse;
    }
    [_selectedPeripheral writeValue:value forCharacteristic:writeCharacteristic type:type];
}

- (NSData *)commandDataWithMainCode:(UInt8)mainCode subCode:(UInt8)subCode parameters:(NSData *)parameters {
    UInt8 head = 0xAA;
    
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:&head length:1];
    [data appendBytes:&mainCode length:1];
    [data appendBytes:&subCode length:1];
    
    // 帧数据长度
    if(parameters == nil) {
        UInt8 leading = 0x00;
        UInt8 tailing = 0x02;
        [data appendBytes:&leading length:1];
        [data appendBytes:&tailing length:1];
    } else {
        NSInteger length = parameters.length + 2;
        Byte *lengthBytes = [self convertNSIntegerDataToBytes:length bytesLength:2];
        [data appendBytes:lengthBytes length:2];
    }
    
    // 标识
    NSData *identiData = [NSMutableData dataWithLength:0x02];
    [data appendBytes:identiData.bytes length:2];
    
    // 帧数据
    if (parameters) {
        [data appendData:parameters];
    }
    
    UInt8 crc = [self crc:data];
    [data appendBytes:&crc length:1];
    
    return data;
}

- (void)preferredFilterUpdateValue:(NSData *)data {
    
    uint16_t responseCode = 0;
    [data getBytes:&responseCode range:NSMakeRange(1, 2)];
    uint16_t commandCode = CFSwapInt16HostToBig((CFSwapInt16BigToHost(responseCode) - 0x80));
    if (commandCode == CFSwapInt16BigToHost(0x0a01)) {
        NSData *parameterData = [self codSmartSportWatch_getResponseParameter:data];
        UInt16 singleFrameLength = 0;
        UInt8 frameCountEveryGroup = 0;
        UInt8 timeoutInterval = 0;
        [parameterData getBytes:&singleFrameLength range:NSMakeRange(2, 2)];
        [parameterData getBytes:&frameCountEveryGroup range:NSMakeRange(4, 1)];
        [parameterData getBytes:&timeoutInterval range:NSMakeRange(5, 1)];
        
        self.OTAParameters = (fileTransferParameter){CFSwapInt16BigToHost(singleFrameLength) - 2, frameCountEveryGroup, timeoutInterval};
        [self sendNext];
    } else if (commandCode == CFSwapInt16BigToHost(0x0a02)) {
        [self sendNext];
    } else if (commandCode == CFSwapInt16BigToHost(0x0a03)) {
        NSLog(@"文件传输完成!");
    }
}

#pragma mark - Util

- (Byte *)convertNSIntegerDataToBytes:(NSInteger)original bytesLength:(NSInteger)length {
    Byte *resultBytes= malloc(sizeof(Byte)*(length));
    for (int i = 0; i < length; i++) {
        resultBytes[i] = (Byte)(original >> (length - i - 1) * 8);
    }
    return resultBytes;
}

- (UInt8)crc:(NSData *)data
{
    const uint8_t *bytes = [data bytes];
    unsigned long sum = bytes[0];
    for (int i=1; i<data.length; i++) {
        sum += bytes[i];
    }
    return sum;
}

- (CBCharacteristic *)characteristicForUUIDString:(NSString *)UUIDString {
    if(UUIDString.length == 0) {
        return nil;
    }
    __block CBCharacteristic *characteristic;
    [_selectedPeripheral.services enumerateObjectsUsingBlock:^(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop1) {
        [obj.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop2) {
            if([obj.UUID.UUIDString isEqualToString:UUIDString]) {
                characteristic = obj;
                *stop1 = YES;
                *stop2 = YES;
            }
        }];
    }];
    
    
    return characteristic;
}

- (NSData *)codSmartSportWatch_getResponseParameter:(NSData *)responseData {
    UInt16 length_temp = 0;
    [responseData getBytes:&length_temp range:NSMakeRange(3, 2)];
    
    UInt16 length = CFSwapInt16BigToHost(length_temp);
    return [responseData subdataWithRange:NSMakeRange(5, length)];
}

- (NSMutableArray *)dataSource {
    if (!_dataSource) {
        _dataSource = @[].mutableCopy;
    }
    return _dataSource;
}

- (NSMutableArray *)advertisementDataSource {
    if (!_advertisementDataSource) {
        _advertisementDataSource = @[].mutableCopy;
    }
    return _advertisementDataSource;
}

@end
