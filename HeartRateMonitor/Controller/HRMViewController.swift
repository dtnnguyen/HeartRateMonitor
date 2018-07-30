//
//  ViewController.swift
//  HeartRateMonitor
//
//  Created by Trang Nguyen on 2018-07-27.
//  Copyright © 2018 Blynkode. All rights reserved.
//

import UIKit
import CoreBluetooth

extension HRMViewController : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print ("central.state is .unknown")
        case .resetting:
            print ("central.state is .resetting")
        case .unsupported:
            print ("central.state is .unsupported")
        case .unauthorized:
            print ("central.state is .unauthorized")
        case .poweredOff:
            print ("central.state is .poweredOff")
        case .poweredOn:
            print ("central.state is .poweredOn")
            // 1. Scan for devices
            centralManager.scanForPeripherals(withServices: nil )
        }
    }


    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        
        if let localName = advertisementData[(CBAdvertisementDataLocalNameKey)] as? String {
            if ( localName.starts(with: "Polar ")) {
                let items = localName.split(separator: " ").map(String.init)
                if (items.count > 2) {
                    let polarDeviceID = items.last
                    
                    heartRatePeripheral = peripheral        // H10
                    heartRatePeripheral.delegate = self     // H10

                    if ( polarDeviceID == "2E39FE27" && peripheral.state == .disconnected){
                         self.centralManager.stopScan()
                         self.centralManager.connect(peripheral, options: nil)
                         let polarDeviceIDStr = polarDeviceID
                         print("Found device: ", polarDeviceIDStr ?? "Nil")
                    }
                }
                
            }
            
        }
        
        
       /* // 2. Look for heart rate device
        centralManager.scanForPeripherals(withServices: [heartRateSericeCBUUID])
        // 3. Save the device
        heartRatePeripheral = peripheral
        heartRatePeripheral.delegate = self
        // Receive this:
        // <CBPeripheral: 0x1d01158d0, identifier = 1333066E-43D1-89EB-2537-D62BAEEEC862, name = (null), state = disconnected>
        // 4. Stop scanning
        self.centralManager.stopScan()
        
        // 5. after find the device, connect to it
        self.centralManager.connect(heartRatePeripheral)
       */
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print ("Connected!");
        
        // 6.  Need to discover the device services
        self.heartRatePeripheral.discoverServices([HEAR_RATE_SERVICE])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // 6.a.
        self.centralManager.scanForPeripherals(withServices: [HEAR_RATE_SERVICE])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // 6.b.
        self.centralManager.scanForPeripherals(withServices: [HEAR_RATE_SERVICE])
    }
}

class HRMViewController: UIViewController {

    @IBOutlet weak var heartRateLabel: UILabel!
    
    @IBOutlet weak var bodySensorLocationLabel: UILabel!
    
    // Constant name of Heart device ID
    let HEAR_RATE_SERVICE = CBUUID(string: "180D")
    let HR_MEASUREMENT = CBUUID(string: "2A37")
    let BODY_SENSOR_CHAR = CBUUID(string: "2A38")
    
    var centralManager : CBCentralManager!
    var heartRatePeripheral : CBPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
        // Initialize data members
        centralManager = CBCentralManager (delegate: self, queue: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func onHeartRateReceived(_ heartRate: Int) {
        heartRateLabel.text = String(heartRate)
        print("BPM: \(heartRate)")
    }
    
    //////////// MOVE THESE INTO BLUE TOOTH CLASS/////////////////
    // Body sensing info
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.body_sensor_location.xml
    private func bodyLocation(from characteristic: CBCharacteristic) -> String {
        guard let characteristicData = characteristic.value, let byte = characteristicData.first else { return "error"}
        
        switch byte {
        case 0: return "Other"
        case 1: return "Chest"
        case 2: return "Wrist"
        case 3: return "Finger"
        case 4: return "Hand"
        case 5: return "Ear Lobe"
        case 6: return "Foot"
        default:
            return "Reserved for future use"
            
        }
    }
    
    // HEART RATE info
    // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml
    private func heartRate(from characteristic : CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1}

        let byteArray = [UInt8](characteristicData)
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart rate value format is in the second byte
            // HR is UINT8 format
            return Int(byteArray[1])
        }
        else {
            // HRT value format is in the 2nd and 3rd byte
            // HR is in UINT16
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
    }
    
}

extension HRMViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // 7.  Request one or more services that have been discovered.
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid.isEqual(HEAR_RATE_SERVICE) {
                peripheral.discoverCharacteristics(nil, for: service)
                print ("Heart Rate Service: ", service)
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error == nil {
            // 8. Look for a list of desired characteristics
            for characteristic in service.characteristics! {
                var bFoundChar = false
                if characteristic.uuid.isEqual(HR_MEASUREMENT) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("characteristic: ", characteristic)
                    bFoundChar = true
                }
                
                if characteristic.uuid.isEqual(BODY_SENSOR_CHAR) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Characteristic: ", characteristic)
                      bFoundChar = true
                }
                
                // 9. Look for properties of the found characteristics
                if ( bFoundChar ) {
                    if ( characteristic.properties.contains(.read)){
                        print ("\(characteristic.uuid): properties contain .read")
                        peripheral.readValue(for: characteristic)
                    }
                    if ( characteristic.properties.contains(.notify)){
                        print ("\(characteristic.uuid): properties contain .notify")
                    }
                }
                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case HR_MEASUREMENT:
            print(characteristic.value ?? "no value")
            let bpm = heartRate(from: characteristic)   // decode heart rate
            onHeartRateReceived(bpm)                    // display heart rate.
        case BODY_SENSOR_CHAR:
            print(characteristic.value ?? "no value")
            let bodySensorLocation = bodyLocation(from: characteristic)
            bodySensorLocationLabel.text = bodySensorLocation
        default:
            print("Unhandled characteristic UUID: \(characteristic.uuid)")
        }
        print ("did Write Value for Characteristic")
    }
    
}

