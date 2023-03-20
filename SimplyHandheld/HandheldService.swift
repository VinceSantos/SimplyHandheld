//
//  HandheldService.swift
//  Wave 3
//
//  Created by Vince Carlo Santos on 11/8/22.
//

import Foundation
import CoreLocation

//MARK: HandheldService Delegate
@objc public protocol HandheldServiceDelegate: AnyObject {
    @objc optional func didUpdateDeviceList(deviceList: [HandheldDevice])
    @objc optional func didConnectToHandheld(handheld: HandheldDevice)
    @objc optional func didFailWithHandheld(failedHandheld: HandheldDevice)
    @objc optional func didDisconnectWithHandheld(disconnectedHandheld: HandheldDevice)
    @objc optional func didUpdateBatteryLevel(batteryLevel: Int)
    @objc optional func didScanRFID(rfid: RFIDResponse)
    @objc optional func didScanBarcode(barcode: BarcodeResponse)
    @objc optional func didReceiveTagAccess(rfid: RFIDAccessResponse)
    @objc optional func didPressTrigger()
    @objc optional func didReleaseTrigger()
}

@objcMembers
public class HandheldService: NSObject {
    public static let shared = HandheldService()
    private(set) var tagPopulation = 50
    public var handheldSupported = HandheldSupported.none
    public var handheldDevicesList = [HandheldDevice]()
    public var lastSelectedHandheld: HandheldDevice?
    public var storedHandheld: HandheldDevice?
    public var connectedDevice: HandheldDevice?
    public var handheldMode = HandheldMode.none
    public var isConnected = false
    private(set) var delegate = MulticastDelegate<HandheldServiceDelegate>()
    private var batteryTrackingTimer: Timer?
    public var connectedDeviceInfo = HandheldInfo()
    public var tagPrefix = ""
    private var isHandheldBusy = false
    private(set) var currentLocation = (0.0, 0.0)
    public var isTriggerDisabled = false
    public var isReadDisabled = false
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        // Create a CLLocationManager and assign a delegate
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        
        setCS108Delegates()
        setChainwayDelegates()
        if let hasStoredHandheldSupport = getData(type: Int.self, forKey: HandheldUserDefault.handheldSupport) {
            handheldSupported = HandheldSupported(rawValue: hasStoredHandheldSupport)!
        }
        if let hasStoredHandheldName = getData(type: String.self, forKey: HandheldUserDefault.handheldName) {
            storedHandheld = HandheldDevice(handheldName: hasStoredHandheldName)
        }
    }
    
    public func addDelegate(object: HandheldServiceDelegate) {
        delegate.add(object)
    }
    
    public func removeDelegate(object: HandheldServiceDelegate) {
        delegate.remove(object)
    }
    
    public func setUpdateLocation(isStart: Bool) {
        if isStart {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }
    
    public func selectHandheldSupport(selectedHandheldSupport: HandheldSupported) {
        DispatchQueue.global().async { [self] in
            handheldSupported = selectedHandheldSupport
        }
    }
    
    func checkHandheldSupport(completion: @escaping (Result<HandheldSupported, HandheldError>) -> Void) {
        if handheldSupported != .none {
            completion(.success(handheldSupported))
        } else {
            completion(.failure(.init(message: "No Handheld Support Found.")))
        }
    }
    
    public func findDevices() {
        handheldDevicesList.removeAll()
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
    
    public func stopFindingDevices() {
        checkHandheldSupport { handheldSupportResult in
            switch handheldSupportResult {
            case .success(let handheldSupport):
                DispatchQueue.global().async { [self] in
                    switch handheldSupport {
                    case .cs108:
                        cs108StopScanDevice()
                    case .r6:
                        chainwayStopScanDevice()
                    case .none:
                        break
                    }
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
        setData(value: handheldSupported.rawValue, key: HandheldUserDefault.handheldSupport)
        setData(value: connectedDevice?.handheldName, key: HandheldUserDefault.handheldName)
        delegate.invoke({$0.didConnectToHandheld?(handheld: handheld)})
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
                            cs108SetBarcodeMode(isEnabled: true)
                            handheldMode = .barcode
                        case .rfid:
                            cs108SetBarcodeMode(isEnabled: false)
                            handheldMode = .rfid
                        case .none:
                            handheldMode = .none
                        }
                    case .r6:
                        switch readerMode {
                        case .barcode:
                            chainwaySetReadMode(isBarcode: true)
                            handheldMode = .barcode
                        case .rfid:
                            chainwaySetReadMode(isBarcode: false)
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
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        cs108SetReadPower(power: power)
                    case .r6:
                        chainwaySetReadPower(power: power)
                    case .none:
                        break
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    public func setTagFocus(enabled: Bool) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        if enabled {
                            cs108loadSpecialSauceWithImpinjExtension()
                        } else {
                            cs108loadSpecialSauceWithoutImpinjExtension()
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
    
    public func startBatteryTracking() {
        batteryTrackingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [self] _ in
            DispatchQueue.global().async { [self] in
                if isConnected && !isHandheldBusy {
                    checkHandheldSupport { [self] handheldSupportResult in
                        switch handheldSupportResult {
                        case .success(let handheldSupport):
                            switch handheldSupport {
                            case .cs108:
                                cs108GetBatteryLevel()
                            case .r6:
                                chainwayGetBatteryLevel()
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
    }
    
    public func stopBatteryTracking() {
        if batteryTrackingTimer != nil {
            batteryTrackingTimer?.invalidate()
            batteryTrackingTimer = nil
        }
    }
    
    public func disconnectReader() {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        cs108DisconnectDevice()
                    case .r6:
                        chainwayDisconnectDevice()
                    case .none:
                        break
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    public func startReading() {
        DispatchQueue.global().async { [self] in
            delegate.invoke({$0.didPressTrigger?()})
            if !isReadDisabled {
                checkHandheldSupport { [self] handheldSupportResult in
                    switch handheldSupportResult {
                    case .success(let handheldSupport):
                        switch handheldSupport {
                        case .cs108:
                            isHandheldBusy = true
                            if handheldMode == .barcode {
                                cs108StartBarcodeRead()
                            } else if handheldMode == .rfid {
                                cs108StartRfidRead()
                            }
                        case .r6:
                            break //TODO: ADD START SCANNING ON CHAINWAYSERVICE
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
    
    public func stopReading() {
        DispatchQueue.global().async { [self] in
            delegate.invoke({$0.didReleaseTrigger?()})
            if !isReadDisabled {
                checkHandheldSupport { [self] handheldSupportResult in
                    switch handheldSupportResult {
                    case .success(let handheldSupport):
                        switch handheldSupport {
                        case .cs108:
                            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 3, execute: DispatchWorkItem.init(block: { [self] in
                                isHandheldBusy = false
                            }))
                            cs108StopRead()
                            cs108ClearBuffer()
                        case .r6:
                            break //TODO: ADD STOP SCANNING ON CHAINWAYSERVICE
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
    
    public func startAccessRead(selectedEpc: String) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        cs108StartAccessRead(selectedEpc: selectedEpc)
                    case .r6:
                        break //TODO: CHAINWAY
                    case .none:
                        break
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    public func startAccessWrite(selectedEpc: String, newEpc: String) {
        DispatchQueue.global().async { [self] in
            checkHandheldSupport { [self] handheldSupportResult in
                switch handheldSupportResult {
                case .success(let handheldSupport):
                    switch handheldSupport {
                    case .cs108:
                        cs108StartAccessWrite(selectedEpc: selectedEpc, newEpc: newEpc)
                    case .r6:
                        break //TODO: CHAINWAY
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

//MARK: Service CoreLocation Delegates
extension HandheldService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last?.coordinate {
            currentLocation = (lastLocation.latitude, lastLocation.longitude)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}
