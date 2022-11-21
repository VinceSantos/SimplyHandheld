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
    case handheldType = "com.simplyHandheld.selectedHandheldType"
    case handheldName = "com.simplyHandheld.selectedHandheldName"
}

@objc public enum HandheldMode: Int {
    case barcode
    case rfid
    case none
}

public class HandheldDevice: NSObject {
    public var peripheral: CBPeripheral? = nil
    public var handheldName: String
    
    init(peripheral: CBPeripheral? = nil, handheldName: String) {
        self.peripheral = peripheral
        self.handheldName = handheldName
    }
}

public class RFIDResponse: NSObject {
    public var value: String
    public var rssi: Int
    
    init(value: String, rssi: Int) {
        self.value = value
        self.rssi = rssi
    }
}

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

public class HandheldInfo: NSObject {
    public var btVersion: String = "N/A"
    public var icLabVersion: String = "N/A"
    public var rfidSerial: String = "N/A"
    public var boardVersion: String = "N/A"
    public var rfidVersion: String = "N/A"
}
