//
//  MyDevicesView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/17/24.
//

import SwiftUI

struct MyDevicesView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var bleManager = BLEManager.shared
    
    @State private var showConnectSheet = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(deviceManager.watches, id: \.uuid) { watch in
                        Button {
                            bleManager.switchDevice(device: watch)
                            dismiss()
                        } label: {
                            DeviceRowView(watch: watch)
                                .foregroundStyle(Color.primary)
                        }
                        .disabled(bleManager.pairedDeviceID ?? "" == watch.uuid ?? "")
                    }
                    .onDelete(perform: { indexSet in
                        let watches = indexSet.map { deviceManager.watches[$0] }
                        
                        for watch in watches {
                            bleManager.unpair(device: watch)
                        }
                    })
                }
                Section {
                    Button {
                        showConnectSheet = true
                        bleManager.isPairingNewDevice = true
                    } label: {
                        Text("Pair New Device")
                    }
                }
            }
            .navigationTitle("My Watches")
            .toolbar {
                Button("Done", role: .cancel) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showConnectSheet, onDismiss: { bleManager.isPairingNewDevice = false }) {
                ConnectView()
            }
            .onChange(of: bleManager.pairedDevice) { _ in
                deviceManager.fetchAllDevices()
            }
            .onAppear {
                deviceManager.fetchAllDevices()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct DeviceRowView: View {
    let watch: Device
    
    @ObservedObject var bleManager = BLEManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            WatchFaceView(watchface: .constant(UInt8(watch.watchface)), device: watch)
                .frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 4) {
                Text(watch.name ?? "InfiniTime")
                    .font(.title2.weight(.semibold))
                Group {
                    Text("InfiniTime ") + Text(watch.firmware ?? "").font(.body.weight(.semibold))
                }
                .foregroundStyle(.gray)
            }
            Spacer()
            if bleManager.pairedDeviceID  == watch.uuid {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .font(.body.weight(.semibold))
            }
        }
    }
}

#Preview {
    MyDevicesView()
}