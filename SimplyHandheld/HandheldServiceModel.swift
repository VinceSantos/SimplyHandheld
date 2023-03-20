//
//  HandheldServiceModel.swift
//  Wave 3
//
//  Created by Vince Carlo Santos on 11/8/22.
//

import Foundation
import CoreBluetooth

@objc public enum HandheldSupported: Int {
    case cs108
    case r6
    case none
}

enum HandheldUserDefault: String {
    case handheldSupport = "com.simplyHandheld.selectedHandhelSupport"
    case handheldName = "com.simplyHandheld.selectedHandheldName"
}

@objc public enum HandheldMode: Int {
    case barcode
    case rfid
    case none
}

@objcMembers
public class HandheldDevice: NSObject {
    public var peripheral: CBPeripheral? = nil
    public var handheldName: String
    
    init(peripheral: CBPeripheral? = nil, handheldName: String) {
        self.peripheral = peripheral
        self.handheldName = handheldName
    }
}

@objcMembers
public class RFIDResponse: NSObject {
    public var value: String
    public var rssi: Int
    public var location: (Double, Double) //lat, lon
    
    init(value: String, rssi: Int, location: (Double, Double)) {
        self.value = value
        self.rssi = rssi
        self.location = location
    }
}

@objcMembers
public class RFIDAccessResponse: NSObject {
    public var isRead: Bool
    public var epc: String
    public var pc: String
    public var tid: String
    
    init(isRead: Bool, epc: String, pc: String, tid: String) {
        self.isRead = isRead
        self.epc = epc
        self.pc = pc
        self.tid = tid
    }
}

@objcMembers
public class BarcodeResponse: NSObject {
    public var value: String
    
    init(value: String) {
        self.value = value
    }
}

public class HandheldError: NSObject, Error {
    var message: String
    
    init(message: String) {
        self.message = message
    }
}

@objcMembers
public class HandheldInfo: NSObject {
    public var btVersion: String = "N/A"
    public var icLabVersion: String = "N/A"
    public var rfidSerial: String = "N/A"
    public var boardVersion: String = "N/A"
    public var rfidVersion: String = "N/A"
}
