import SwiftUI

struct ExoSettingsView: View {
    @EnvironmentObject var settings: ExoSettings
    @EnvironmentObject var serviceManager: ExoServiceManager
    
    private var webPortBinding: Binding<String> {
        Binding<String>(
            get: { String(settings.webPort) },
            set: {
                if let value = Int($0) {
                    settings.webPort = value
                }
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Basic Configuration")) {
                TextField("Exo Home Directory", text: Binding(
                    get: { settings.exoHome ?? "" },
                    set: { settings.exoHome = $0 }
                ))
                TextField("Hugging Face Endpoint", text: Binding(
                    get: { settings.hfEndpoint ?? "" },
                    set: { settings.hfEndpoint = $0 }
                ))
                Stepper("Debug Level: \(settings.debugLevel)", value: $settings.debugLevel, in: 0...9)
            }
            
            Section(header: Text("Web Interface")) {
                TextField("Web UI Host", text: $settings.webHost)
                TextField("Web UI Port", text: webPortBinding)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Save and Restart Service") {
                    settings.saveSettings()
                    if serviceManager.isInstalled && serviceManager.isRunning {
                        serviceManager.restartService()
                    }
                }
                .disabled(!serviceManager.isInstalled)
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}

#Preview {
    ExoSettingsView()
        .environmentObject(ExoSettings())
        .environmentObject(ExoServiceManager())
} 