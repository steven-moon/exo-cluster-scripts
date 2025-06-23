import SwiftUI

struct ExoThrottleView: View {
    @EnvironmentObject var settings: ExoSettings
    @EnvironmentObject var serviceManager: ExoServiceManager
    
    var body: some View {
        Form {
            Section(header: Text("Performance Throttling")) {
                Toggle("Enable Throttling", isOn: $settings.enableThrottling)
                    .onChange(of: settings.enableThrottling) { oldValue, newValue in
                        if !newValue {
                            // Reset to default values when disabled
                            settings.throttlePreset = .performance
                            applyPreset(settings.throttlePreset)
                        }
                    }
                
                Picker("Throttle Preset", selection: $settings.throttlePreset) {
                    ForEach(ThrottlePreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .disabled(!settings.enableThrottling)
                .onChange(of: settings.throttlePreset) { oldValue, newValue in
                    applyPreset(newValue)
                }
            }
            
            Section(header: Text("Manual Throttling Controls")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max CPU Usage: \(Int(settings.maxCpuUsage))%")
                    Slider(value: $settings.maxCpuUsage, in: 10...100, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max Memory Usage: \(Int(settings.maxMemoryUsage))%")
                    Slider(value: $settings.maxMemoryUsage, in: 10...100, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max GPU Usage: \(Int(settings.maxGpuUsage))%")
                    Slider(value: $settings.maxGpuUsage, in: 10...100, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Throttle Interval: \(Int(settings.throttleInterval)) seconds")
                    Slider(value: $settings.throttleInterval, in: 1...60, step: 1)
                }
            }
            .disabled(!settings.enableThrottling)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Apply and Restart Service") {
                    settings.saveSettings()
                    if serviceManager.isInstalled && serviceManager.isRunning {
                        serviceManager.restartService()
                    }
                }
                .disabled(!serviceManager.isInstalled)
            }
        }
        .padding()
        .navigationTitle("Throttling")
        .onAppear {
            // No need to sync from AppStorage, it's automatic
        }
    }
    
    private func applyPreset(_ preset: ThrottlePreset) {
        settings.applyPreset(preset)
        settings.saveSettings() // Ensure presets are saved
    }
}

#Preview {
    ExoThrottleView()
        .environmentObject(ExoSettings())
        .environmentObject(ExoServiceManager())
} 