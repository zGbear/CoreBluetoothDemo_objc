//
//  ViewController.m
//  coreBluetoothRetrievePeripheral
//
//  Created by ZhangYi on 2018/11/28.
//  Copyright © 2018 ZhangYi. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSString * const CDDeviceCodoonSportWatchCharacteristicUUID = @"2A19";
NSString * const CDDeviceCodoonSportWatchResponseCharacteristicUUID = @"2A19";

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *peripheralTableView;
@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableDictionary <NSString *, CBPeripheral *> *scanPeripheralResult;
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) NSUUID *Identity;
@property (nonatomic, strong) CBPeripheral *selectedPeripheral;

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
    
    [self.dataSource addObject:peripheral];
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
//    _selectedPeripheral.delegate = self;
    [_selectedPeripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CDDeviceCodoonSportWatchCharacteristicUUID]] forService:peripheral.services.firstObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
    _outputTextView.text = [_outputTextView.text stringByAppendingString:@"didDiscoverCharacteristicsForService!\n"];
//    _selectedPeripheral = peripheral;
//    _selectedPeripheral.delegate = self;
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
    
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *selectedPeripheral = _dataSource[indexPath.row];
    [_centralManager connectPeripheral:selectedPeripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @(YES)}];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 30.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    CBPeripheral *selectedPeripheral = _dataSource[indexPath.row];
    
    cell.textLabel.text = selectedPeripheral.name;
    
    return cell;
}

#pragma mark - handle event

- (IBAction)scan:(id)sender {
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"180F"], [CBUUID UUIDWithString:@"FE95"]] options:nil];
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

- (void)writeValue:(NSData *)value {
    
    CBCharacteristic *writeCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchCharacteristicUUID];
    CBCharacteristic *responseCharacteristic = [self characteristicForUUIDString:CDDeviceCodoonSportWatchResponseCharacteristicUUID];
    
    if (!writeCharacteristic || !responseCharacteristic) {
        NSLog(@"Characteristic illegal");
        return;
    }
    
    [_selectedPeripheral setNotifyValue:YES forCharacteristic:responseCharacteristic];
    
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

- (NSMutableArray *)dataSource {
    if (!_dataSource) {
        _dataSource = @[].mutableCopy;
    }
    return _dataSource;
}

@end
