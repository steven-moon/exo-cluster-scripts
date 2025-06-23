import SwiftUI

@main
struct ExoManagerApp: App {
    @StateObject private var serviceManager = ExoServiceManager()
    @StateObject private var settings = ExoSettings()
    @StateObject private var monitor = ExoMonitor()
    @StateObject private var networkDiscovery = ExoNetworkDiscovery()
    @StateObject private var mcpServer: ExoMCPServer
    
    init() {
        // Initialize MCP server with references to other managers
        let tempMonitor = ExoMonitor()
        let tempServiceManager = ExoServiceManager()
        let tempNetworkDiscovery = ExoNetworkDiscovery()
        
        self._monitor = StateObject(wrappedValue: tempMonitor)
        self._serviceManager = StateObject(wrappedValue: tempServiceManager)
        self._networkDiscovery = StateObject(wrappedValue: tempNetworkDiscovery)
        self._mcpServer = StateObject(wrappedValue: ExoMCPServer(
            monitor: tempMonitor,
            serviceManager: tempServiceManager,
            networkDiscovery: tempNetworkDiscovery
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceManager)
                .environmentObject(settings)
                .environmentObject(monitor)
                .environmentObject(networkDiscovery)
                .environmentObject(mcpServer)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Start MCP server when app launches
                    mcpServer.start()
                    
                    // Broadcast app startup message
                    mcpServer.broadcastDebugMessage("ExoManager app started", component: "app")
                }
                .onDisappear {
                    // Stop MCP server when app closes
                    mcpServer.broadcastDebugMessage("ExoManager app shutting down", component: "app")
                    mcpServer.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            ExoSettingsView()
                .environmentObject(settings)
        }
    }
} 