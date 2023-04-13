//
//  HandheldService+CS108.swift
//  SimplyHandheld
//
//  Created by Vince Carlo Santos on 3/8/23.
//

import Foundation
import CSL_CS108

//MARK: CS108 Custom Functions
extension HandheldService {
    func setCS108Delegates() {
        CSLRfidAppEngine.shared().reader.delegate = self
        CSLRfidAppEngine.shared().reader.readerDelegate = self
        CSLRfidAppEngine.shared().reader.scanDelegate = self
    }
    
    func findCS108Devices() {
        DispatchQueue.global().async {
            CSLRfidAppEngine.shared().reader.startScanDevice()
        }
    }
    
    func connectCS108Reader(readerName: String) {
        DispatchQueue.global().async { [self] in
            if let bleDeviceForReaderName = handheldDevicesList.first(where: {$0.handheldName == readerName}) {
                lastSelectedHandheld = bleDeviceForReaderName
                if let peripheral = lastSelectedHandheld?.peripheral {
                    //stop scanning for device
                    CSLRfidAppEngine.shared().reader.stopScanDevice()
                    //connect to device selected
                    CSLRfidAppEngine.shared().reader.connectDevice(peripheral)
                }
            }
        }
    }
    
    func cs108loadSpecialSauceWithImpinjExtension() {
        DispatchQueue.global().async { [self] in
            CSLRfidAppEngine.shared().settings.tagPopulation = Int32(tagPopulation)
            CSLRfidAppEngine.shared().settings.isQOverride = true
            CSLRfidAppEngine.shared().settings.qValue = 7
            CSLRfidAppEngine.shared().settings.session = .S1
            CSLRfidAppEngine.shared().settings.target = .A
            CSLRfidAppEngine.shared().settings.algorithm = .DYNAMICQ
            CSLRfidAppEngine.shared().settings.linkProfile = .RANGE_DRM
            CSLRfidAppEngine.shared().settings.tagFocus = 1
            CSLRfidAppEngine.shared().settings.rfLnaHighComp = 0
            CSLRfidAppEngine.shared().settings.rfLna = 3
            CSLRfidAppEngine.shared().settings.ifLna = 0
            CSLRfidAppEngine.shared().settings.ifAgc = 4
            
            CSLRfidAppEngine.shared().saveSettingsToUserDefaults()
        }
    }
    
    func cs108loadSpecialSauceWithoutImpinjExtension() {
        DispatchQueue.global().async { [self] in
            CSLRfidAppEngine.shared().settings.tagPopulation = Int32(tagPopulation)
            CSLRfidAppEngine.shared().settings.isQOverride = true
            CSLRfidAppEngine.shared().settings.qValue = 7
            CSLRfidAppEngine.shared().settings.session = .S0
            CSLRfidAppEngine.shared().settings.target = .ToggleAB
            CSLRfidAppEngine.shared().settings.algorithm = .DYNAMICQ
            CSLRfidAppEngine.shared().settings.linkProfile = .RANGE_DRM
            CSLRfidAppEngine.shared().settings.tagFocus = 0
            CSLRfidAppEngine.shared().settings.rfLnaHighComp = 0
            CSLRfidAppEngine.shared().settings.rfLna = 3
            CSLRfidAppEngine.shared().settings.ifLna = 0
            CSLRfidAppEngine.shared().settings.ifAgc = 4
            
            CSLRfidAppEngine.shared().saveSettingsToUserDefaults()
        }
    }
    
    func cs108StopScanDevice() {
        CSLRfidAppEngine.shared().reader.stopScanDevice()
    }
    
    func cs108SetBarcodeMode(isEnabled: Bool) {
        CSLRfidAppEngine.shared().isBarcodeMode = isEnabled
    }
    
    func cs108SetReadPower(power: Int) {
        CSLRfidAppEngine.shared().reader.setPower(Double(power / 10))
    }
    
    func cs108GetBatteryLevel() {
        if CSLRfidAppEngine.shared().reader.connectStatus == .CONNECTED && CSLRfidAppEngine.shared().reader.connectStatus != .SCANNING && CSLRfidAppEngine.shared().reader.connectStatus != .BUSY && CSLRfidAppEngine.shared().reader.connectStatus != .TAG_OPERATIONS {
            CSLRfidAppEngine.shared().reader.getSingleBatteryReport()
        }
    }
    
    func cs108DisconnectDevice() {
        CSLRfidAppEngine.shared().reader.disconnectDevice()
    }
    
    func cs108StartBarcodeRead() {
        CSLRfidAppEngine.shared().reader.startBarcodeReading()
    }
    
    func cs108StartRfidRead() {
        CSLRfidAppEngine.shared().reader.startInventory()
    }
    
    func cs108StopBarcodeRead() {
        CSLRfidAppEngine.shared().reader.stopBarcodeReading()
    }
    
    func cs108StopRfidRead() {
        CSLRfidAppEngine.shared().reader.stopInventory()
    }
    
    func cs108ClearBuffer() {
        CSLRfidAppEngine.shared().reader.filteredBuffer.removeAllObjects()
    }
    
    func cs108StartAccessRead(selectedEpc: String) {
        CSLRfidAppEngine.shared().reader.startTagMemoryRead(MEMORYBANK.TID, dataOffset: UInt16(0), dataCount: UInt16(6), accpwd: 00000000, maskBank: MEMORYBANK.EPC, maskPointer: 32, maskLength: (UInt32(selectedEpc.count) * 4), maskData: CSLBleReader.convertHexString(toData: selectedEpc))
    }
    
    func cs108StartAccessWrite(selectedEpc: String, newEpc: String) {
        CSLRfidAppEngine.shared().reader.startTagMemoryWrite(MEMORYBANK.EPC, dataOffset: 2, dataCount: (UInt16(UInt32(newEpc.count) / 4)), write: CSLBleReader.convertHexString(toData: newEpc), accpwd: 00000000, maskBank: MEMORYBANK.EPC, maskPointer: 32, maskLength: (UInt32(selectedEpc.count) * 4), maskData: CSLBleReader.convertHexString(toData: selectedEpc))
    }
    
    func cs108SetTagReadConfig() {
        CSLReaderConfigurations.setAntennaPortsAndPowerForTagAccess(false)
        CSLReaderConfigurations.setConfigurationsForTags()
    }
}

//MARK: CSL Reader Delegates
extension HandheldService: CSLBleReaderDelegate, CSLBleInterfaceDelegate, CSLBleScanDelegate {
    public func deviceListWasUpdated(_ deviceDiscovered: CBPeripheral!) {
        DispatchQueue.global().async { [self] in
            if !handheldDevicesList.contains(where: {$0.handheldName == deviceDiscovered.name}) {
                handheldDevicesList.append(HandheldDevice(peripheral: deviceDiscovered, handheldName: deviceDiscovered.name ?? ""))
            }
            delegate.invoke({$0.didUpdateDeviceList?(deviceList: handheldDevicesList)})
        }
    }
    
    public func didConnect(toDevice deviceConnected: CBPeripheral!) {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2, execute: DispatchWorkItem(block: { [self] in
            if CSLRfidAppEngine.shared().reader.connectStatus != STATUS.CONNECTED {
                print("Failed to connect to reader.")
            } else {
                //set device name to singleton object
                CSLRfidAppEngine.shared().reader.deviceName = lastSelectedHandheld?.handheldName
                var btFwVersion: NSString?
                var slVersion: NSString?
                var rfidBoardSn: NSString?
                var pcbBoardVersion: NSString?
                var rfidFwVersion: NSString?
                var appVersion: String?
                
                let btFwVersionPtr = AutoreleasingUnsafeMutablePointer<NSString?>?.init(&btFwVersion)
                let slVersionPtr = AutoreleasingUnsafeMutablePointer<NSString?>?.init(&slVersion)
                let rfidBoardSnPtr = AutoreleasingUnsafeMutablePointer<NSString?>?.init(&rfidBoardSn)
                let pcbBoardVersionPtr = AutoreleasingUnsafeMutablePointer<NSString?>?.init(&pcbBoardVersion)
                let rfidFwVersionPtr = AutoreleasingUnsafeMutablePointer<NSString?>?.init(&rfidFwVersion)
                
                //Configure reader
                CSLRfidAppEngine.shared().reader.barcodeReader(true)
                CSLRfidAppEngine.shared().reader.power(onRfid: false)
                CSLRfidAppEngine.shared().reader.power(onRfid: true)
                if CSLRfidAppEngine.shared().reader.getBtFirmwareVersion(btFwVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.btFirmwareVersion = btFwVersionPtr?.pointee as String?
                    connectedDeviceInfo.btVersion = btFwVersionPtr?.pointee as String? ?? "N/A"
                }
                if CSLRfidAppEngine.shared().reader.getSilLabIcVersion(slVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.siLabICFirmwareVersion = slVersionPtr?.pointee as String?
                    connectedDeviceInfo.icLabVersion = slVersionPtr?.pointee as String? ?? "N/A"

                }
                if CSLRfidAppEngine.shared().reader.getRfidBrdSerialNumber(rfidBoardSnPtr) {
                    CSLRfidAppEngine.shared().readerInfo.deviceSerialNumber = rfidBoardSnPtr?.pointee as String?
                    connectedDeviceInfo.rfidSerial = rfidBoardSnPtr?.pointee as String? ?? "N/A"
                }
                if CSLRfidAppEngine.shared().reader.getPcBBoardVersion(pcbBoardVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.pcbBoardVersion = pcbBoardVersionPtr?.pointee as String?
                    connectedDeviceInfo.boardVersion = pcbBoardVersionPtr?.pointee as String? ?? "N/A"
                }
                
                CSLRfidAppEngine.shared().reader.batteryInfo.setPcbVersion(pcbBoardVersionPtr?.pointee?.doubleValue ?? 0.0)
                
                CSLRfidAppEngine.shared().reader.sendAbortCommand()
                
                if CSLRfidAppEngine.shared().reader.getRfidFwVersionNumber(rfidFwVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.rfidFirmwareVersion = rfidFwVersionPtr?.pointee as String?
                    connectedDeviceInfo.rfidVersion = rfidFwVersionPtr?.pointee as String? ?? "N/A"
                }
                
                
                if let object = Bundle.main.infoDictionary?["CFBundleShortVersionString"], let object1 = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] {
                    appVersion = "v\(object) Build \(object1)"
                }
                CSLRfidAppEngine.shared().readerInfo.appVersion = appVersion
                
                
                var OEMData: UInt32 = 0
                
                //device country code
                CSLRfidAppEngine.shared().reader.readOEMData(CSLRfidAppEngine.shared().reader, atAddr: 0x00000002, forData: &OEMData)
                CSLRfidAppEngine.shared().readerInfo.countryCode = OEMData
                print(String(format: "OEM data address 0x%08X: 0x%08X", 0x02, OEMData))
                //special country version
                CSLRfidAppEngine.shared().reader.readOEMData(CSLRfidAppEngine.shared().reader, atAddr: 0x0000008e, forData: &OEMData)
                CSLRfidAppEngine.shared().readerInfo.specialCountryVerison = OEMData
                print(String(format: "OEM data address 0x%08X: 0x%08X", 0x8e, OEMData))
                //freqency modification flag
                CSLRfidAppEngine.shared().reader.readOEMData(CSLRfidAppEngine.shared().reader, atAddr: 0x0000008f, forData: &OEMData)
                CSLRfidAppEngine.shared().readerInfo.freqModFlag = OEMData
                print(String(format: "OEM data address 0x%08X: 0x%08X", 0x8f, OEMData))
                //model code
                CSLRfidAppEngine.shared().reader.readOEMData(CSLRfidAppEngine.shared().reader, atAddr: 0x000000a4, forData: &OEMData)
                CSLRfidAppEngine.shared().readerInfo.modelCode = OEMData
                print(String(format: "OEM data address 0x%08X: 0x%08X", 0xa4, OEMData))
                //hopping/fixed frequency
                CSLRfidAppEngine.shared().reader.readOEMData(CSLRfidAppEngine.shared().reader, atAddr: 0x0000009d, forData: &OEMData)
                CSLRfidAppEngine.shared().readerInfo.isFxied = OEMData
                print(String(format: "OEM data address 0x%08X: 0x%08X", 0x9d, OEMData))
                
                CSLRfidAppEngine.shared().readerRegionFrequency = CSLReaderFrequency(
                    oemData: CSLRfidAppEngine.shared().readerInfo.countryCode,
                    specialCountryVerison: CSLRfidAppEngine.shared().readerInfo.specialCountryVerison,
                    freqModFlag: CSLRfidAppEngine.shared().readerInfo.freqModFlag,
                    modelCode: CSLRfidAppEngine.shared().readerInfo.modelCode,
                    isFixed: CSLRfidAppEngine.shared().readerInfo.isFxied)
                
                if let savedRegion = CSLRfidAppEngine.shared().settings.region,
                   CSLRfidAppEngine.shared().readerRegionFrequency.tableOfFrequencies[savedRegion] == nil {
                    //the region being stored is not valid, reset to default region and frequency channel
                    if let region = CSLRfidAppEngine.shared().readerRegionFrequency.regionList.firstObject as? String {
                        CSLRfidAppEngine.shared().settings.region = region
                    }
                    CSLRfidAppEngine.shared().settings.channel = "0"
                    CSLRfidAppEngine.shared().saveSettingsToUserDefaults()
                }
                
                let fw = CSLRfidAppEngine.shared().readerInfo.btFirmwareVersion as String
                if fw.count >= 5 {
                    if (fw.prefix(1) == "3") {
                        //if BT firmware version is greater than v3, it is connecting to CS463
                        CSLRfidAppEngine.shared().reader.readerModelNumber = READERTYPE.CS463
                    } else {
                        CSLRfidAppEngine.shared().reader.readerModelNumber = READERTYPE.CS108
                    }
                }
                                
                CSLReaderConfigurations.setReaderRegionAndFrequencies()
                CSLReaderConfigurations.setAntennaPortsAndPowerForTags(true)
                CSLReaderConfigurations.setConfigurationsForTags()
                if let handheldConfigured = lastSelectedHandheld {
                    didConnectToDevice(handheld: handheldConfigured)
                    setUpdateLocation(isStart: true)
                }
            }
        }))
    }
    
    public func didDisconnectDevice(_ deviceDisconnected: CBPeripheral!) {
        if let hasConnectedDevice = connectedDevice {
            connectedDevice = nil
            isConnected = false
            delegate.invoke({$0.didDisconnectWithHandheld?(disconnectedHandheld: hasConnectedDevice)})
            setUpdateLocation(isStart: false)
        }
    }
    
    public func didFailed(toConnect deviceFailedToConnect: CBPeripheral!) {
        if let hasConnectedDevice = connectedDevice {
            connectedDevice = nil
            isConnected = false
            delegate.invoke({$0.didFailWithHandheld?(failedHandheld: hasConnectedDevice)})
            setUpdateLocation(isStart: false)
        }
    }
    
    public func didInterfaceChangeConnectStatus(_ sender: CSLBleInterface!) {
        
    }
    
    public func didReceiveTagResponsePacket(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        var tagPass = false
        
        if tagPrefix.isEmpty {
            tagPass = true
        } else {
            if tag.epc.lowercased().hasPrefix(tagPrefix.lowercased()) {
                tagPass = true
            } else {
                tagPass = false
            }
        }
        
        if tagPass {
            let rfidResponse = RFIDResponse(value: tag.epc, rssi: Int(tag.rssi), location: currentLocation)
            delegate.invoke({$0.didScanRFID?(rfid: rfidResponse)})
        }
    }
    
    public func didTriggerKeyChangedState(_ sender: CSLBleReader!, keyState state: Bool) {
        DispatchQueue.global().async { [self] in
            if !isTriggerDisabled {
                if state == true {
                    startReading(force: false)
                } else {
                    stopReading(force: false)
                }
            }
        }
    }
    
    public func didReceiveBatteryLevelIndicator(_ sender: CSLBleReader!, batteryPercentage battPct: Int32) {
        delegate.invoke({$0.didUpdateBatteryLevel?(batteryLevel: Int(battPct))})
    }
    
    public func didReceiveBarcodeData(_ sender: CSLBleReader!, scannedBarcode barcode: CSLReaderBarcode!) {
        let barcodeResponse = BarcodeResponse(value: barcode.barcodeValue)
        delegate.invoke({$0.didScanBarcode?(barcode: barcodeResponse)})

    }
    
    public func didReceiveTagAccessData(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        delegate.invoke({$0.didReceiveTagAccess?(rfid: RFIDAccessResponse(isRead: tag.accessCommand == .READ ? true : false, epc: tag.epc, pc: String(format: "%04X", tag.pc), tid: tag.data ?? ""))})
    }
    
    public func didReceiveCommandEndResponse(_ sender: CSLBleReader!) {
        delegate.invoke({$0.didReceiveCommandEnd?()})
    }
}
