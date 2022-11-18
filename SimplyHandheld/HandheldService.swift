//
//  HandheldService.swift
//  Wave 3
//
//  Created by Vince Carlo Santos on 11/8/22.
//

import Foundation
import CSL_CS108
import SimplyChainway

@objcMembers
public class HandheldService: NSObject {
    public static let shared = HandheldService()
    private var tagPopulation = 50
    public var handheldSupported = HandheldSupported.none
    public var handheldDevicesList = [HandheldDevice]()
    public var lastSelectedHandheld: HandheldDevice?
    public var connectedDevice: HandheldDevice?
    public var handheldMode = HandheldMode.none
    public var isConnected = false
    public weak var delegate: HandheldServiceDelegate?
    public var isTagFocus = false
    private var batteryTrackingTimer: Timer = Timer()

    override init() {
        super.init()
        CSLRfidAppEngine.shared().reader.delegate = self
        CSLRfidAppEngine.shared().reader.readerDelegate = self
        CSLRfidAppEngine.shared().reader.scanDelegate = self
        ChainwayService.shared.delegate = self
    }
    
    public func selectHandheldSupport(selectedHandheldSupport: HandheldSupported) {
        handheldSupported = selectedHandheldSupport
    }
    
    func checkHandheldSupport(completion: @escaping (Result<HandheldSupported, HandheldError>) -> Void) {
        if handheldSupported != .none {
            completion(.success(handheldSupported))
        } else {
            completion(.failure(.init(message: "No Handheld Support Found.")))
        }
    }
    
    public func setupHandheld() {
        checkHandheldSupport { [self] handheldSupportResult in
            switch handheldSupportResult {
            case .success(let handheldSupport):
                switch handheldSupport {
                case .cs108:
                    findCS108Devices()
                case .r6:
                    findR6Devices()
                case .none:
                    break
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    public func connectToHandheld(with name: String) {
        checkHandheldSupport { [self] handheldSupportResult in
            switch handheldSupportResult {
            case .success(let handheldSupport):
                switch handheldSupport {
                case .cs108:
                    connectCS108Reader(readerName: name)
                case .r6:
                    connectR6Reader(readerName: name)
                case .none:
                    break
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    public func didConnectToDevice(handheld: HandheldDevice) {
        connectedDevice = handheld
        isConnected = true
        delegate?.didConnectToHandheld(handheld: handheld)
    }
    
    public func setReaderMode(readerMode: HandheldMode) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        switch readerMode {
                        case .barcode:
                            CSLRfidAppEngine.shared().isBarcodeMode = true
                            handheldMode = .barcode
                        case .rfid:
                            CSLRfidAppEngine.shared().isBarcodeMode = false
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
                    case .none:
                        break
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    public func setReaderPower(power: Int) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        CSLRfidAppEngine.shared().reader.setPower(Double(power / 10))
                    case .r6:
                        ChainwayService.shared.setReadPower(intPower: power / 10)
                    case .none:
                        break
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    public func startBatteryTracking() {
        batteryTrackingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [self] _ in
            checkHandheldSupport { handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        if CSLRfidAppEngine.shared().reader.connectStatus != .BUSY || CSLRfidAppEngine.shared().reader.connectStatus != .SCANNING || CSLRfidAppEngine.shared().reader.connectStatus != .TAG_OPERATIONS {
                            CSLRfidAppEngine.shared().reader.getSingleBatteryReport()
                        }
                    case .r6:
                        break
                    case .none:
                        break
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
    public func findCS108Devices() {
        CSLRfidAppEngine.shared().reader.startScanDevice()
    }
    
    public func connectCS108Reader(readerName: String) {
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
    
    public func cs108loadSpecialSauceWithImpinjExtension() {
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
    
    public func cs108loadSpecialSauceWithoutImpinjExtension() {
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
    
    public func cs108setPreFilter(prefix: String) {
        CSLRfidAppEngine.shared().settings.prefilterMask = prefix
        CSLRfidAppEngine.shared().settings.prefilterOffset = 0
        CSLRfidAppEngine.shared().settings.prefilterBank = .EPC
        CSLRfidAppEngine.shared().settings.prefilterIsEnabled = true
        
        CSLRfidAppEngine.shared().saveSettingsToUserDefaults()
    }
}

//MARK: CSL Reader Delegates
extension HandheldService: CSLBleReaderDelegate, CSLBleInterfaceDelegate, CSLBleScanDelegate {
    public func deviceListWasUpdated(_ deviceDiscovered: CBPeripheral!) {
        DispatchQueue.global().async { [self] in
            if !handheldDevicesList.contains(where: {$0.handheldName == deviceDiscovered.name}) {
                handheldDevicesList.append(HandheldDevice(peripheral: deviceDiscovered, handheldName: deviceDiscovered.name ?? "", handheldMacAddress: ""))
            }
            delegate?.didUpdateDeviceList(deviceList: handheldDevicesList)
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
                    }
                }
                                
                CSLReaderConfigurations.setReaderRegionAndFrequencies()
                CSLReaderConfigurations.setAntennaPortsAndPowerForTags(false)
                CSLReaderConfigurations.setConfigurationsForTags()
                if let handheldConfigured = lastSelectedHandheld {
                    didConnectToDevice(handheld: handheldConfigured)
                }
            }
        }))
    }
    
    public func didDisconnectDevice(_ deviceDisconnected: CBPeripheral!) {
        if let hasConnectedDevice = connectedDevice {
            delegate?.didDisconnectWithHandheld(disconnectedHandheld: hasConnectedDevice)
        }
    }
    
    public func didFailed(toConnect deviceFailedToConnect: CBPeripheral!) {
        if let hasConnectedDevice = connectedDevice {
            delegate?.didFailWithHandheld(failedHandheld: hasConnectedDevice)
        }
    }
    
    public func didInterfaceChangeConnectStatus(_ sender: CSLBleInterface!) {
        
    }
    
    public func didReceiveTagResponsePacket(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        let rfidResponse = RFIDResponse(value: tag.epc, rssi: Int(tag.rssi))
        delegate?.didScanRFID(value: rfidResponse)
    }
    
    public func didTriggerKeyChangedState(_ sender: CSLBleReader!, keyState state: Bool) {
        DispatchQueue.global().async { [self] in
            if state == true {
                if handheldMode == .barcode {
                    CSLRfidAppEngine.shared().reader.startBarcodeReading()
                } else if handheldMode == .rfid {
                    CSLRfidAppEngine.shared().reader.startInventory()
                }
            } else {
                if handheldMode == .barcode {
                    CSLRfidAppEngine.shared().reader.stopBarcodeReading()
                } else if handheldMode == .rfid {
                    CSLRfidAppEngine.shared().reader.stopInventory()
                }
                CSLRfidAppEngine.shared().reader.filteredBuffer.removeAllObjects()
            }
        }
    }
    
    public func didReceiveBatteryLevelIndicator(_ sender: CSLBleReader!, batteryPercentage battPct: Int32) {
        delegate?.didUpdateBatteryLevel(batteryLevel: Int(battPct))
    }
    
    public func didReceiveBarcodeData(_ sender: CSLBleReader!, scannedBarcode barcode: CSLReaderBarcode!) {
        let barcodeResponse = BarcodeResponse(value: barcode.barcodeValue)
        delegate?.didScanBarcode(value: barcodeResponse)
    }
    
    public func didReceiveTagAccessData(_ sender: CSLBleReader!, tagReceived tag: CSLBleTag!) {
        
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
}

//MARK: ChainwayService Delegate
extension HandheldService: ChainwayServiceDelegate {
    public func didConnectToDevice(deviceName: String) {
        if let device = handheldDevicesList.first(where: {$0.handheldName == deviceName}) {
            didConnectToDevice(handheld: device)
        }
    }
    
    public func didDisconnectToDevice(deviceName: String) {
        if let hasConnectedDevice = connectedDevice {
            delegate?.didDisconnectWithHandheld(disconnectedHandheld: hasConnectedDevice)
        }
    }
    
    public func didFailWithDevice(deviceName: String) {
        if let hasConnectedDevice = connectedDevice {
            delegate?.didFailWithHandheld(failedHandheld: hasConnectedDevice)
        }
    }
    
    public func didReceiveDevices(devices: [String]) {
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
    
    public func didReceiveRFTags(tags: [String]) {
        if let temporaryTag = tags.last {
            let rfidResponse = RFIDResponse(value: temporaryTag, rssi: Int(0))
            delegate?.didScanRFID(value: rfidResponse)
        }
    }
    
    public func didReceiveBarcode(barcode: String) {
        let barcodeResponse = BarcodeResponse(value: barcode)
        delegate?.didScanBarcode(value: barcodeResponse)
    }
}

//MARK: HandheldService Delegate
public protocol HandheldServiceDelegate: AnyObject {
    func didUpdateDeviceList(deviceList: [HandheldDevice])
    func didConnectToHandheld(handheld: HandheldDevice)
    func didFailWithHandheld(failedHandheld: HandheldDevice)
    func didDisconnectWithHandheld(disconnectedHandheld: HandheldDevice)
    func didUpdateBatteryLevel(batteryLevel: Int)
    func didScanRFID(value: RFIDResponse)
    func didScanBarcode(value: BarcodeResponse)
}

public extension HandheldServiceDelegate {
    func didUpdateDeviceList(deviceList: [HandheldDevice]) {}
    func didConnectToHandheld(handheld: HandheldDevice) {}
    func didFailWithHandheld(failedHandheld: HandheldDevice) {}
    func didDisconnectWithHandheld(disconnectedHandheld: HandheldDevice) {}
    func didUpdateBatteryLevel(batteryLevel: Int) {}
    func didScanRFID(value: RFIDResponse) {}
    func didScanBarcode(value: BarcodeResponse) {}
}
