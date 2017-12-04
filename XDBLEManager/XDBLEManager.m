//
//  XDBLEManager.m
//  XDBLEManagerExample
//
//  Created by xiaodongdan on 2017/12/4.
//  Copyright © 2017年 xiaodongdan. All rights reserved.
//

#import "XDBLEManager.h"

// 蓝牙进程被杀掉后恢复连接时用
static NSString *XDBLERestoreIdentifierKey = @"XDBLERestoreIdentifierKey";

@interface XDBLEManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@end

@implementation XDBLEManager

+ (instancetype)sharedManager {
    static XDBLEManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[XDBLEManager alloc] init];
        manager.peripheralArray = [NSMutableArray array];
    });
    return manager;
}

- (void)setDelegate:(id<XDBLEManagerDelegate>)delegate {
    _delegate = delegate;
    if (self.centralManager) {
        return;
    }
    dispatch_queue_t centeralQueue = dispatch_queue_create("CenteralQueue", DISPATCH_QUEUE_SERIAL);
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey: [NSNumber numberWithBool:YES], CBCentralManagerOptionRestoreIdentifierKey: XDBLERestoreIdentifierKey};
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centeralQueue options:options];
}

- (void)scanPeripherals {
    [self.peripheralArray removeAllObjects];
    // 不重复扫描已发现设备
    NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO], CBCentralManagerOptionShowPowerAlertKey: [NSNumber numberWithBool:YES]};
    NSMutableArray *serviceUUIDs = nil;
    if (self.serviceUUIDStrs) {
        serviceUUIDs = [NSMutableArray array];
        for (NSString *str in self.serviceUUIDStrs) {
            CBUUID *uuid = [CBUUID UUIDWithString:str];
            [serviceUUIDs addObject:uuid];
        }
    }
    [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral {
    [self.centralManager connectPeripheral:peripheral options:nil];
    self.peripheral = peripheral;
    self.peripheral.delegate = self;
    if (self.delegate && [self.delegate respondsToSelector:@selector(findPeripheral:)]) {
        [self.delegate findPeripheral:peripheral];
    }
}

- (void)cancelPeripheralConnect {
    [self.centralManager cancelPeripheralConnection:self.peripheral];
    self.peripheral = nil;
}

- (void)resetData {
    [self cancelPeripheralConnect];
    self.centralManager = nil;
}

#pragma mark - CBCentralManagerDelegate
// 中心设备状态改变的回调
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (self.delegate && [self.delegate respondsToSelector:@selector(BLECentralState:)]) {
        [self.delegate BLECentralState:central.state];
    }
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            //打开状态
            //开始扫描
            [self scanPeripherals];
            break;
        case CBCentralManagerStatePoweredOff:
            //关闭状态
            // 提示打开蓝牙
            break;
        case CBCentralManagerStateResetting:
            //复位
            break;
        case CBCentralManagerStateUnsupported:
            //表明设备不支持蓝牙低功耗
            break;
        case CBCentralManagerStateUnauthorized:
            //该应用程序是无权使用蓝牙低功耗
            break;
        case CBCentralManagerStateUnknown:
            //未知
            break;
        default:
            break;
    }
}

// 蓝牙在后台被杀掉时，重连会调用。可以获取蓝牙恢复时的各种状态
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict {
    
}

// 发现外设的回调
// peripheral：外设类
// advertisementData：广播的值，一般携带设备名，serviceUUIDs等信息
// RSSI：外设的RSSI值，绝对值越大，表示信号越差，设备离得越远。如果想转换成百分比强度，(RSSI+100)/100
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    // 将扫描到的外设添加到peripheralArray里
    if (![self.peripheralArray containsObject:peripheral]) {
        [self.peripheralArray addObject:peripheral];
        if (self.delegate && [self.delegate respondsToSelector:@selector(findPeripherals:)]) {
            [self.delegate findPeripherals:self.peripheralArray];
        }
        
        // 判断外设并连接
        if ([peripheral.name isEqualToString:self.peripheralName] && !self.peripheral) {
            [self connectPeripheral:peripheral];
        }
    }
}

// 外设连接成功的回调
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // 当需要的外设连接成功后停止扫描
    [self.centralManager stopScan];
    // 连接成功后寻找服务，传nil会寻找所有服务
    [peripheral discoverServices:nil];
    if (self.delegate && [self.delegate respondsToSelector:@selector(connectPeripheral:)]) {
        [self.delegate connectPeripheral:peripheral];
    }
}

// 外设连接失败的回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.peripheral = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(failToConnectPeripheral:error:)]) {
        [self.delegate failToConnectPeripheral:peripheral error:error];
    }
}

// 断开外设连接的回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (!self.peripheral) {
        return;
    }
    
    self.peripheral = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(disconnectPeripheral:)]) {
        [self.delegate disconnectPeripheral:peripheral];
    }
}

#pragma mark - CBPeripheralDelegate
// 发现服务的回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (!error) {
        for (CBService *service in peripheral.services) {
            if (service) {
                [peripheral discoverCharacteristics:nil forService:service];
            }
        }
    }
}

// 发现服务的特征
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        // 监听外设特征值
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
}

// 已经更新的特征的值
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(updateValueForCharacteristic:)]) {
            [self.delegate updateValueForCharacteristic:characteristic];
        }
    }
}

@end
