//
//  BLEManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/3/2024.
//

import Foundation
import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()
    
    lazy var characteristicHandler = BLECharacteristicHandler()
    lazy var deviceManager = DeviceManager.shared
    let downloadManager = DownloadManager.shared
    
    var central: CBCentralManager!
    var blefsTransfer: CBCharacteristic!
    var currentTimeService: CBCharacteristic!
    var notifyCharacteristic: CBCharacteristic!
    var weatherCharacteristic: CBCharacteristic!
    
    var dfuControlPointCharacteristic: CBCharacteristic!
    var dfuPacketCharacteristic: CBCharacteristic!
    
    var navigationFlagsCharacteristic: CBCharacteristic!
    var navigationNarrativeCharacteristic: CBCharacteristic!
    var navigationDistanceCharacteristic: CBCharacteristic!
    var navigationProgressCharacteristic: CBCharacteristic!
    
    struct MusicCharacteristics {
        var control: CBCharacteristic!
        var track: CBCharacteristic!
        var artist: CBCharacteristic!
        var status: CBCharacteristic!
        var position: CBCharacteristic!
        var length: CBCharacteristic!
    }
    struct CBUUIDList {
        let hrm = CBUUID(string: "2A37")
        let bat = CBUUID(string: "2A19")
        let time = CBUUID(string: "2A2B")
        let notify = CBUUID(string: "2A46")
        let modelNumber = CBUUID(string: "2A24")
        let serial = CBUUID(string: "2A25")
        let firmware = CBUUID(string: "2A26")
        let hardwareRevision = CBUUID(string: "2A27")
        let softwareRevision = CBUUID(string: "2A28")
        let manufacturer = CBUUID(string: "2A29")
        let sleep = CBUUID(string: "2037")
        let blefsTransfer = CBUUID(string: "adaf0200-4669-6c65-5472-616e73666572")
        let motion = CBUUID(string: "00030002-78fc-48fe-8e23-433b3a1942d0")
        let weather = CBUUID(string: "00050001-78FC-48FE-8E23-433B3A1942D0")
        
        let dfuControlPoint = CBUUID(string: "00001531-1212-efde-1523-785feabcd123")
        let dfuPacket = CBUUID(string: "00001532-1212-efde-1523-785feabcd123")
        
        // We don't need the navigation service UUID, just its characteristics
        // let navigation = CBUUID(string: "00010000-78fc-48fe-8e23-433b3a1942d0")
        let navigationFlags = CBUUID(string: "00010001-78fc-48fe-8e23-433b3a1942d0")
        let navigationNarrative = CBUUID(string: "00010002-78fc-48fe-8e23-433b3a1942d0")
        let navigationDistance = CBUUID(string: "00010003-78fc-48fe-8e23-433b3a1942d0")
        let navigationProgress = CBUUID(string: "00010004-78fc-48fe-8e23-433b3a1942d0")
        
        let musicControl = CBUUID(string: "00000001-78FC-48FE-8E23-433B3A1942D0")
        let statusControl = CBUUID(string: "00000002-78FC-48FE-8E23-433B3A1942D0")
        let musicTrack = CBUUID(string: "00000004-78FC-48FE-8E23-433B3A1942D0")
        let musicArtist = CBUUID(string: "00000003-78FC-48FE-8E23-433B3A1942D0")
        let stepCount = CBUUID(string: "00030001-78FC-48FE-8E23-433B3A1942D0")
        let positionTrack = CBUUID(string: "00000006-78FC-48FE-8E23-433B3A1942D0")
        let lengthTrack = CBUUID(string: "00000007-78FC-48FE-8E23-433B3A1942D0")
    }
    
    let cbuuidList = CBUUIDList()
    var musicChars = MusicCharacteristics()
    
    @Published var isCentralOn = false
    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var setTimeError = false
    @Published var isConnectedToPinetime = false
    @Published var isPairingNewDevice = false
    @Published var hasDisconnectedForUpdate = false
    
    @Published var newPeripherals: [CBPeripheral] = []
    @Published var infiniTime: CBPeripheral!
    @Published var peripheralToConnect: CBPeripheral!
    
    @Published var weatherInformation = WeatherInformation()
    @Published var weatherForecastDays = [WeatherForecastDay]()
    @Published var loadingWeather = true
    @Published var hasLoadedBatteryLevel = false
    
    @Published var heartRate: Double = 0
    @Published var batteryLevel: Double = 0
    @Published var stepCount: Int = 0
    
    @Published var error: String = ""
    @Published var showError: Bool = false
    
    @Published var pairedDevice: Device!
    
    @AppStorage("pairedDeviceID") var pairedDeviceID: String?
    
    var hasLoadedCharacteristics: Bool {
        // Use currentTimeService because it's present in all firmware versions
        return currentTimeService != nil && isConnectedToPinetime
    }
    var isHeartRateBeingRead: Bool {
        return heartRate != 0
    }
    var isDeviceInRecoveryMode: Bool {
        let first = deviceManager.firmware.components(separatedBy: ".").first
        
        return first == "0"
    }
    var isBusy: Bool {
        return isConnecting || isScanning
    }
    
    override init() {
        super.init()
        self.central = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForNewDevices() {
        central.scanForPeripherals(withServices: nil, options: nil)
        newPeripherals = []
        isScanning = true
    }
    
    func startScanning() {
        guard central.state == .poweredOn else { return }
        
        if let pairedDeviceID = pairedDeviceID,
            let uuid = UUID(uuidString: pairedDeviceID), !isPairingNewDevice {
            
            let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
            log("\(peripherals)", type: .info, caller: "BLEManager - startScanning")
            
            if let peripheral = peripherals.first, !isConnectedToPinetime {
                connect(peripheral: peripheral) {}
            }
        } else {
            scanForNewDevices()
        }
    }
    
    func stopScanning() {
        central.stopScan()
        isScanning = false
    }
    
    func connect(peripheral: CBPeripheral, completion: @escaping() -> Void) {
        guard isCentralOn else { return }
        
        if peripheral.name == "InfiniTime" {
            isConnecting = true
            peripheralToConnect = peripheral
            
            central.connect(peripheralToConnect, options: nil)
            
            completion()
        }
    }
    
    func onConnect(peripheral: CBPeripheral) {
        stopScanning()
        
        if isConnectedToPinetime {
            disconnect()
        }
        
        downloadManager.updateAvailable = false
        pairedDevice = deviceManager.fetchDevice(with: peripheral.identifier.uuidString)
        hasDisconnectedForUpdate = false
        isConnecting = false
        
        infiniTime = peripheral
        infiniTime?.delegate = self
        infiniTime.discoverServices(nil)
        isConnectedToPinetime = true
        pairedDeviceID = peripheral.identifier.uuidString
        
        log("Connected to \(pairedDevice?.name ?? "InfiniTime")", type: .info, caller: "BLEManager", target: .ble)
    }
    
    func removeDevice(device: Device? = nil) {
        deviceManager.removeDevice(device ?? pairedDevice)
        unpair(device: device)
    }
    
    func resetDevice() {
        BLEFSHandler.shared.writeSettings(Settings())
        deviceManager.settings = Settings()
    }
    
    func unpair(device: Device? = nil) {
        if let pairedDevice {
            deviceManager.removeDevice(device ?? pairedDevice)
        }
        deviceManager.fetchAllDevices()
        
        if let first = deviceManager.watches.first, deviceManager.watches.count <= 1 {
            pairedDeviceID = first.uuid
            pairedDevice = deviceManager.fetchDevice()
        } else {
            pairedDeviceID = nil
        }
        
        log("Unpaired from \(pairedDevice?.name ?? "InfiniTime")", type: .info, caller: "BLEManager", target: .ble)
        
        if device == nil {
            // This only disconnects and removes the watch from the recognized device list. If using secure pairing, the bond will still be kept
            disconnect()
            startScanning()
        }
    }
    
    func disconnect() {
        if let infiniTime = infiniTime {
            self.central.cancelPeripheralConnection(infiniTime)
            self.infiniTime = nil
            self.blefsTransfer = nil
            self.currentTimeService = nil
            self.notifyCharacteristic = nil
            self.hasLoadedBatteryLevel = false
            self.isConnectedToPinetime = false
            
            log("Disconnected from \(pairedDevice?.name ?? "InfiniTime")", type: .info, caller: "BLEManager", target: .ble)
        }
    }
    
    func switchDevice(device: Device) {
        self.pairedDeviceID = device.uuid
        self.pairedDevice = deviceManager.fetchDevice()
        self.deviceManager.getSettings()
        self.disconnect()
        
        log("Device switched to \(pairedDevice?.name ?? "InfiniTime")", type: .info, caller: "BLEManager", target: .ble)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let pairedDeviceID = pairedDeviceID, pairedDeviceID == peripheral.identifier.uuidString && !isPairingNewDevice {
            connect(peripheral: peripheral) {}
        }
        if peripheral.name == "InfiniTime" && !newPeripherals.contains(where: { $0.identifier.uuidString == peripheral.identifier.uuidString }) {
            if isPairingNewDevice {
                if !deviceManager.watches.compactMap({ $0.uuid }).contains(peripheral.identifier.uuidString) {
                    newPeripherals.append(peripheral)
                }
            } else {
                newPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.isConnecting = false
        
        if let error = error {
            log("Failed to connect to peripheral: \(error.localizedDescription)", caller: "BLEManager", target: .ble)
            
            // We can't do anything like check an error code, so this is sufficient for a "bond removed" message
            // Won't work when language is not English? (localizedDescription)
            if error.localizedDescription.contains("removed pairing information") {
                self.error = NSLocalizedString("InfiniLink could not connect to your device because the bond is no longer present. Please remove the watch from Bluetooth settings to reconnect.", comment: "")
                self.showError = true
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.onConnect(peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnectedToPinetime = false
        notifyCharacteristic = nil
        
        if pairedDeviceID != nil {
            connect(peripheral: peripheral) {}
        }
        
        if let error {
            log(error.localizedDescription, caller: "didDisconnectPeripheral", target: .ble)
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isCentralOn = (central.state == .poweredOn)
        
        if isCentralOn && !isConnectedToPinetime {
            startScanning()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            if let error {
                log("Error discovering services: \(error.localizedDescription)", caller: "BLEManager", target: .ble)
            }
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            deviceManager.readInfoCharacteristics(characteristic: characteristic, peripheral: peripheral)
            characteristicHandler.handleDiscoveredCharacteristics(characteristic: characteristic, peripheral: peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        deviceManager.updateInfo(characteristic: characteristic)
        characteristicHandler.handleUpdates(characteristic: characteristic, peripheral: peripheral)
    }
}
