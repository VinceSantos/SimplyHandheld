//
//  HandheldService.swift
//  Wave 3
//
//  Created by Vince Carlo Santos on 11/8/22.
//

import Foundation
import CSL_CS108
import SimplyChainway

final class HandheldService: NSObject {
    static let shared = HandheldService()
    private var isConfiguringHandheld = false
    private var tagPopulation = 50
    var handheldSupported: HandheldSupported?
    var handheldDevicesList = [HandheldDevice]()
    var connectedDevice: HandheldDevice?
    var handheldMode = HandheldMode.none
    var isConnected = false
    weak var delegate: HandheldServiceDelegate?

    override init() {
        super.init()
        CSLRfidAppEngine.shared().reader.delegate = self
        CSLRfidAppEngine.shared().reader.readerDelegate = self
        ChainwayService.shared.delegate = self
//        if let storedHandheldSupport = UserDefaultsUtility.getData(type: String.self, forKey: .storedHandheldType) {
//            handheldSupported = HandheldSupported(rawValue: storedHandheldSupport)
//        }
    }
    
    func selectHandheldSupport(selectedHandheldSupport: HandheldSupported) {
        handheldSupported = selectedHandheldSupport
//        setData(value: selectedHandheldSupport.rawValue, key: .handheldType)
    }
    
    func checkHandheldSupport(completion: @escaping (Result<HandheldSupported, HandheldError>) -> Void) {
        if let hasHandheldSupport = handheldSupported {
            completion(.success(hasHandheldSupport))
        } else {
            completion(.failure(.init(message: "No Handheld Support Found.")))
        }
    }
    
    func setupHandheld() {
        checkHandheldSupport { [self] handheldSupportResult in
            switch handheldSupportResult {
            case .success(let handheldSupport):
                switch handheldSupport {
                case .cs108:
                    findCS108Devices()
                case .r6:
                    findR6Devices()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func connectToHandheld(with name: String) {
        checkHandheldSupport { [self] handheldSupportResult in
            switch handheldSupportResult {
            case .success(let handheldSupport):
                switch handheldSupport {
                case .cs108:
                    connectCS108Reader(readerName: name)
                case .r6:
                    connectR6Reader(readerName: name)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func didConnectToDevice(handheld: HandheldDevice) {
        connectedDevice = handheld
        isConnected = true
        delegate?.didConnectToHandheld(handheld: handheld)
    }
    
    func setReaderMode(readerMode: HandheldMode) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        switch readerMode {
                        case .barcode:
                            CSLRfidAppEngine.shared().isBarcodeMode = true
                            CSLRfidAppEngine.shared().reader.barcodeReader(true)
                            CSLRfidAppEngine.shared().reader.power(onRfid: false)
                            handheldMode = .barcode
                        case .rfid:
                            CSLRfidAppEngine.shared().isBarcodeMode = false
                            CSLRfidAppEngine.shared().reader.barcodeReader(false)
                            CSLRfidAppEngine.shared().reader.power(onRfid: true)
                            handheldMode = .rfid
                        case .none:
                            handheldMode = .none
                        }
                    case .r6:
                        switch readerMode {
                        case .barcode:
                            ChainwayService.shared.setReadMode(isBarcode: true)
                            handheldMode = .barcode
                        case .rfid:
                            ChainwayService.shared.setReadMode(isBarcode: false)
                            handheldMode = .rfid
                        case .none:
                            handheldMode = .none
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}

//MARK: Service User Defaults
extension HandheldService {
    private func setData<T>(value: T, key: HandheldUserDefault) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key.rawValue)
    }
    
    private func getData<T>(type: T.Type, forKey: HandheldUserDefault) -> T? {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: forKey.rawValue) as? T
        return value
    }
    
    private func removeData(key: HandheldUserDefault) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key.rawValue)
    }
}

//MARK: CS108 Custom Functions
extension HandheldService {
    func findCS108Devices() {
        CSLRfidAppEngine.shared().reader.startScanDevice()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: DispatchWorkItem(block: { [self] in
            if let cslLibraryDeviceList = CSLRfidAppEngine.shared().reader.bleDeviceList {
                for item in cslLibraryDeviceList {
                    if let bleItem = item as? CBPeripheral {
                        handheldDevicesList.append(HandheldDevice(peripheral: bleItem, handheldName: bleItem.name ?? "", handheldMacAddress: ""))
                    }
                }
                if !handheldDevicesList.isEmpty {
                    delegate?.didUpdateDeviceList(deviceList: handheldDevicesList)
                }
            }
        }))
    }
    
    func connectCS108Reader(readerName: String) {
        if let hasBleDeviceList = CSLRfidAppEngine.shared().reader.bleDeviceList as? [CBPeripheral] {
            if let deviceIndexInLibrary = hasBleDeviceList.firstIndex(where: {$0.name == readerName}) {
                if !isConfiguringHandheld {
                    isConfiguringHandheld = true
                    configureCS108Reader(deviceIndex: deviceIndexInLibrary)
                }
            }
        }
    }
    
    func configureCS108Reader(deviceIndex: Int) {
        //stop scanning for device
        CSLRfidAppEngine.shared().reader.stopScanDevice()
        //connect to device selected
        CSLRfidAppEngine.shared().reader.connectDevice(CSLRfidAppEngine.shared()?.reader.bleDeviceList[deviceIndex] as! CBPeripheral?)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: DispatchWorkItem(block: { [self] in
            if CSLRfidAppEngine.shared().reader.connectStatus != STATUS.CONNECTED {
                print("Failed to connect to reader.")
            } else {
                //set device name to singleton object
                CSLRfidAppEngine.shared().reader.deviceName = CSLRfidAppEngine.shared().reader.deviceListName[deviceIndex] as? String
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
                }
                if CSLRfidAppEngine.shared().reader.getSilLabIcVersion(slVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.siLabICFirmwareVersion = slVersionPtr?.pointee as String?
                }
                if CSLRfidAppEngine.shared().reader.getRfidBrdSerialNumber(rfidBoardSnPtr) {
                    CSLRfidAppEngine.shared().readerInfo.deviceSerialNumber = rfidBoardSnPtr?.pointee as String?
                }
                if CSLRfidAppEngine.shared().reader.getPcBBoardVersion(pcbBoardVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.pcbBoardVersion = pcbBoardVersionPtr?.pointee as String?
                }
                
                CSLRfidAppEngine.shared().reader.batteryInfo.setPcbVersion(pcbBoardVersionPtr?.pointee?.doubleValue ?? 0.0)
                
                CSLRfidAppEngine.shared().reader.sendAbortCommand()
                
                if CSLRfidAppEngine.shared().reader.getRfidFwVersionNumber(rfidFwVersionPtr) {
                    CSLRfidAppEngine.shared().readerInfo.rfidFirmwareVersion = rfidFwVersionPtr?.pointee as String?
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
                
                if CSLRfidAppEngine.shared().readerRegionFrequency.tableOfFrequencies[CSLRfidAppEngine.shared().settings.region!] == nil {
                    //the region being stored is not valid, reset to default region and frequency channel
                    CSLRfidAppEngine.shared().settings.region = CSLRfidAppEngine.shared().readerRegionFrequency.regionList[0] as? String
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
                        CSLRfidAppEngine.shared().reader.startBatteryAutoReporting()
                    }
                }
                
                //set low power mode
                CSLRfidAppEngine.shared().reader.setPowerMode(true)
                
                CSLReaderConfigurations.setReaderRegionAndFrequencies()
                CSLReaderConfigurations.setAntennaPortsAndPowerForTags(true)
                CSLReaderConfigurations.setConfigurationsForTags()
                if let hasConnectedToDevice = CSLRfidAppEngine.shared().reader.bleDevice {
                    let hasConnectedDevice = HandheldDevice(peripheral: hasConnectedToDevice, handheldName: hasConnectedToDevice.name ?? "", handheldMacAddress: "")
                    didConnectToDevice(handheld: hasConnectedDevice)
                }
            }
        }))
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
    
    func cs108setPreFilter(prefix: String) {
        CSLRfidAppEngine.shared().settings.prefilterMask = prefix
        CSLRfidAppEngine.shared().settings.prefilterOffset = 0
        CSLRfidAppEngine.shared().settings.prefilterBank = .EPC
        CSLRfidAppEngine.shared().settings.prefilterIsEnabled = true
        
        CSLRfidAppEngine.shared().saveSettingsToUserDefaults()
    }
}

//MARK: CSL Reader Delegates
extension HandheldService: CSLBleReaderDelegate, CSLBleInterfaceDelegate {
    func didInterfaceChangeConnectStatus(_ sender: CSLBleInterface!) {
        
    }
    
    func didReceiveTagResponsePacket(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        let rfidResponse = RFIDResponse(value: tag.epc, rssi: Int(tag.rssi))
        delegate?.didScanRFID(value: rfidResponse)
    }
    
    func didTriggerKeyChangedState(_ sender: CSLBleReader!, keyState state: Bool) {
        DispatchQueue.global().async { [self] in
            if state == true {
                if handheldMode == .barcode {
                    CSLRfidAppEngine.shared().isBarcodeMode = true
                    CSLRfidAppEngine.shared().reader.startBarcodeReading()
                } else if handheldMode == .rfid {
                    CSLRfidAppEngine.shared().reader.startInventory()
                }
            } else {
                if handheldMode == .barcode {
                    CSLRfidAppEngine.shared().isBarcodeMode = false
                    CSLRfidAppEngine.shared().reader.stopBarcodeReading()
                } else if handheldMode == .rfid {
                    CSLRfidAppEngine.shared().reader.stopInventory()
                }
                CSLRfidAppEngine.shared().reader.filteredBuffer.removeAllObjects()
            }
        }
    }
    
    func didReceiveBatteryLevelIndicator(_ sender: CSLBleReader!, batteryPercentage battPct: Int32) {
        
    }
    
    func didReceiveBarcodeData(_ sender: CSLBleReader!, scannedBarcode barcode: CSLReaderBarcode!) {
        let barcodeResponse = BarcodeResponse(value: barcode.barcodeValue)
        delegate?.didScanBarcode(value: barcodeResponse)
    }
    
    func didReceiveTagAccessData(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        
    }
}

//MARK: Chainway Custom Functions
extension HandheldService {
    func findR6Devices() {
        ChainwayService.shared.configureBLE()
    }
    
    func connectR6Reader(readerName: String) {
        ChainwayService.shared.connectToDevice(withName: readerName)
    }
    
    func configureR6Reader(deviceIndex: Int) {
        //
    }
}

//MARK: ChainwayService Delegate
extension HandheldService: ChainwayServiceDelegate {
    func didReceiveDevices(devices: [String]) {
        let d5Devices = devices.filter({$0.hasPrefix("D5")})
        if d5Devices.count > 0 {
            for item in d5Devices {
                if !handheldDevicesList.contains(where: {$0.handheldName == item}) {
                    handheldDevicesList.append(HandheldDevice(handheldName: item, handheldMacAddress: ""))
                }
            }
            delegate?.didUpdateDeviceList(deviceList: handheldDevicesList)
        }
    }
    
    func didConnectToDevice(deviceName: String) {
        if let device = handheldDevicesList.first(where: {$0.handheldName == deviceName}) {
            didConnectToDevice(handheld: device)
        }
    }
    
    func didReceiveRFTags(tags: [String]) {
        print(tags)
    }
    
    func didReceiveBarcode(barcode: String) {
        print(barcode)
    }
}

//MARK: HandheldService Delegate
protocol HandheldServiceDelegate: AnyObject {
    func didUpdateDeviceList(deviceList: [HandheldDevice])
    func didConnectToHandheld(handheld: HandheldDevice)
    func didScanRFID(value: RFIDResponse)
    func didScanBarcode(value: BarcodeResponse)
}

extension HandheldServiceDelegate {
    func didUpdateDeviceList(deviceList: [HandheldDevice]) {}
    func didConnectToHandheld(handheld: HandheldDevice) {}
    func didScanRFID(value: RFIDResponse) {}
    func didScanBarcode(value: BarcodeResponse) {}
}
