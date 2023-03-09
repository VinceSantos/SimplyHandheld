//
//  HandheldService+Chainway.swift
//  SimplyHandheld
//
//  Created by Vince Carlo Santos on 3/8/23.
//

import Foundation
import SimplyChainway

//MARK: Chainway Custom Functions
extension HandheldService {
    func setChainwayDelegates() {
        ChainwayService.shared.delegate = self
    }
    
    func findR6Devices() {
        //TODO: figure out why this doesn't trigger when dispatchQueue.global() is used
        ChainwayService.shared.configureBLE()
    }
    
    func connectR6Reader(readerName: String) {
        DispatchQueue.global().async {
            ChainwayService.shared.stopScanningDevices()
            ChainwayService.shared.connectToDevice(withName: readerName)
        }
    }
    
    func chainwayStopScanDevice() {
        ChainwayService.shared.stopScanningDevices()
    }
    
    func chainwaySetReadMode(isBarcode: Bool) {
        ChainwayService.shared.setReadMode(isBarcode: isBarcode)
    }
    
    func chainwaySetReadPower(power: Int) {
        ChainwayService.shared.setReadPower(intPower: power / 10)
    }
    
    func chainwayGetBatteryLevel() {
        ChainwayService.shared.getBatteryLevel()
    }
    
    func chainwayDisconnectDevice() {
        ChainwayService.shared.disconnectDevice()
    }
}

//MARK: ChainwayService Delegate
extension HandheldService: ChainwayServiceDelegate {
    public func didConnectToDevice(deviceName: String) {
        if let device = handheldDevicesList.first(where: {$0.handheldName == deviceName}) {
            didConnectToDevice(handheld: device)
            setUpdateLocation(isStart: true)
        }
    }
    
    public func didDisconnectToDevice(deviceName: String) {
        if let hasConnectedDevice = connectedDevice {
            connectedDevice = nil
            isConnected = false
            delegate.invoke({$0.didDisconnectWithHandheld?(disconnectedHandheld: hasConnectedDevice)})
            setUpdateLocation(isStart: false)
        }
    }
    
    public func didFailWithDevice(deviceName: String) {
        if let hasConnectedDevice = connectedDevice {
            connectedDevice = nil
            isConnected = false
            delegate.invoke({$0.didFailWithHandheld?(failedHandheld: hasConnectedDevice)})
            setUpdateLocation(isStart: false)
        }
    }
    
    public func didReceiveDevice(device: CBPeripheral) {
        DispatchQueue.global().async { [self] in
            if !handheldDevicesList.contains(where: {$0.handheldName == device.name}) {
                handheldDevicesList.append(HandheldDevice(peripheral: device, handheldName: device.name ?? ""))
            }
            delegate.invoke({$0.didUpdateDeviceList?(deviceList: handheldDevicesList)})
        }
    }
    
    public func didReceiveBatteryLevel(batteryLevel: Int) {
        delegate.invoke({$0.didUpdateBatteryLevel?(batteryLevel: batteryLevel)})
    }
    
    public func didReceiveBarcode(barcode: String) {
        var barcodeLocalized = barcode
        if barcodeLocalized.hasPrefix("\u{02}") {
            barcodeLocalized.removeFirst(1)
        }
        let barcodeResponse = BarcodeResponse(value: barcodeLocalized)
        delegate.invoke({$0.didScanBarcode?(barcode: barcodeResponse)})
    }
    
    public func didReceiveRF(epc: String, rssi: Int) {
        var tagPass = false
        
        if tagPrefix.isEmpty {
            tagPass = true
        } else {
            if epc.lowercased().hasPrefix(tagPrefix.lowercased()) {
                tagPass = true
            } else {
                tagPass = false
            }
        }
        
        if tagPass {
            let rfidResponse = RFIDResponse(value: epc.uppercased(), rssi: rssi, location: currentLocation)
            delegate.invoke({$0.didScanRFID?(rfid: rfidResponse)})
        }
    }
}
