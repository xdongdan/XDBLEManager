//
//  XDBLEManager.h
//  XDBLEManagerExample
//
//  Created by xiaodongdan on 2017/12/4.
//  Copyright © 2017年 xiaodongdan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


@protocol XDBLEManagerDelegate <NSObject>

@optional

// BLE状态
- (void)BLECentralState:(NSInteger)state;

// 发现外设
// 全部外设
- (void)findPeripherals:(NSArray *)peripherals;
// 指定外设
- (void)findPeripheral:(CBPeripheral *)peripheral;

// 外设连接成功
- (void)connectPeripheral:(CBPeripheral *)peripheral;

// 外设连接失败
- (void)failToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

// 断开外设连接
- (void)disconnectPeripheral:(CBPeripheral *)peripheral;

// 外设返回的特征数据
- (void)updateValueForCharacteristic:(CBCharacteristic *)characteristic;

@end

@interface XDBLEManager : NSObject

@property (nonatomic, weak) id <XDBLEManagerDelegate>delegate;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;   // 连接的外设
@property (nonatomic, strong) NSMutableArray *peripheralArray;   // 外设数组

// 需要扫描的设备的UUIDString列表，可不传
@property (nonatomic, strong) NSArray<NSString *> *serviceUUIDStrs;

// 需要连接的外设的外设名，需要根据这个字段判断连接扫描出来的哪个外设
@property (nonatomic, strong) NSString *peripheralName;

+ (instancetype)sharedManager;

// 扫描外设
- (void)scanPeripherals;

//连接外设
- (void)connectPeripheral:(CBPeripheral *)peripheral;

// 断开外设连接
- (void)cancelPeripheralConnect;

// 重置数据
- (void)resetData;

@end
