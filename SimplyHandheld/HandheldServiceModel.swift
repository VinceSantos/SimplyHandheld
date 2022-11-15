//
//  HandheldServiceModel.swift
//  Wave 3
//
//  Created by Vince Carlo Santos on 11/8/22.
//

import Foundation
import CoreBluetooth

enum HandheldSupported: String, CaseIterable {
    case cs108 = "CSL CS-108"
    case r6 = "Chainway R6 Pro"
}

enum HandheldUserDefault: String {
    case handheldType = "com.simplyHandheld.selectedHandheldType"
    case handheldName = "com.simplyHandheld.selectedHandheldName"
}

enum HandheldMode {
    case barcode
    case rfid
    case none
}

struct HandheldDevice {
    var peripheral: CBPeripheral? = nil
    var handheldName: String
    var handheldMacAddress: String
}

struct RFIDResponse {
    var value: String
    var rssi: Int
}

struct BarcodeResponse {
    var value: String
}

struct HandheldError: Error {
    var message: String
}
