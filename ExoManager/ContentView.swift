import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serviceManager: ExoServiceManager
    @EnvironmentObject var settings: ExoSettings
    @EnvironmentObject var monitor: ExoMonitor
    @EnvironmentObject var networkDiscovery: ExoNetworkDiscovery
    @EnvironmentObject var mcpServer: ExoMCPServer
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerView
            
            // Main content - show installation workflow if not installed
            if !serviceManager.isInstalled {
                installationWorkflowView
            } else {
                // Main content with tabs
                TabView(selection: $selectedTab) {
                    // Dashboard Tab
                    dashboardView
                        .tabItem {
                            Image(systemName: "gauge")
                            Text("Dashboard")
                        }
                        .tag(0)
                    
                    // Chat Tab
                    ExoWebView(url: URL(string: "http://localhost:52415")!)
                        .tabItem {
                            Image(systemName: "message")
                            Text("Chat")
                        }
                        .tag(1)
                    
                    // Performance Tab
                    ExoPerformanceView()
                        .environmentObject(monitor)
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Performance")
                        }
                        .tag(2)
                    
                    // Network Tab
                    ExoNetworkView()
                        .environmentObject(networkDiscovery)
                        .tabItem {
                            Image(systemName: "network")
                            Text("Network")
                        }
                        .tag(3)
                    
                    // Logs Tab
                    ExoLogViewer()
                        .environmentObject(monitor)
                        .tabItem {
                            Image(systemName: "doc.text")
                            Text("Logs")
                        }
                        .tag(4)
                    
                    // Settings Tab
                    ExoSettingsView()
                        .environmentObject(settings)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(5)
                }
                .tabViewStyle(DefaultTabViewStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Only start monitoring if exo is installed
            if serviceManager.isInstalled {
                monitor.startMonitoring()
                networkDiscovery.startDiscovery()
            }
        }
        .onDisappear {
            monitor.stopMonitoring()
            networkDiscovery.stopDiscovery()
        }
        .onChange(of: serviceManager.isInstalled) { oldValue, newValue in
            if newValue {
                // Start monitoring when exo gets installed
                monitor.startMonitoring()
                networkDiscovery.startDiscovery()
                mcpServer.broadcastDebugMessage("Exo service installed", component: "service_manager")
            } else {
                // Stop monitoring when exo gets uninstalled
                monitor.stopMonitoring()
                networkDiscovery.stopDiscovery()
                mcpServer.broadcastDebugMessage("Exo service uninstalled", component: "service_manager")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // Service status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(serviceManager.isInstalled ? (serviceManager.isRunning ? Color.green : Color.red) : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(serviceManager.isInstalled ? (serviceManager.isRunning ? "Running" : "Stopped") : "Not Installed")
                        .font(.headline)
                        .foregroundColor(serviceManager.isInstalled ? (serviceManager.isRunning ? .green : .red) : .orange)
                }
                
                // MCP Server status
                HStack(spacing: 8) {
                    Circle()
                        .fill(mcpServer.isRunning ? Color.blue : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text("MCP: \(mcpServer.connectedClients) clients")
                        .font(.caption)
                        .foregroundColor(mcpServer.isRunning ? .blue : .gray)
                }
                
                Spacer()
                
                // Control buttons - only show if installed
                if serviceManager.isInstalled {
                    HStack(spacing: 12) {
                        Button(action: {
                            if serviceManager.isRunning {
                                serviceManager.stopService()
                                mcpServer.broadcastDebugMessage("Stopping Exo service", component: "service_manager")
                            } else {
                                serviceManager.startService()
                                mcpServer.broadcastDebugMessage("Starting Exo service", component: "service_manager")
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: serviceManager.isRunning ? "stop.fill" : "play.fill")
                                Text(serviceManager.isRunning ? "Stop" : "Start")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(serviceManager.isRunning ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .disabled(serviceManager.isInstalling || serviceManager.isUninstalling)
                        
                        Button(action: {
                            serviceManager.restartService()
                            mcpServer.broadcastDebugMessage("Restarting Exo service", component: "service_manager")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Restart")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .disabled(!serviceManager.isRunning || serviceManager.isInstalling || serviceManager.isUninstalling)
                    }
                }
            }
            
            // Progress indicators
            if serviceManager.isInstalling {
                VStack(spacing: 8) {
                    ProgressView("Installing Exo Service...")
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    if !serviceManager.installationProgress.isEmpty {
                        Text(serviceManager.installationProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if serviceManager.isUninstalling {
                ProgressView("Uninstalling Exo Service...")
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Error display
            if let error = serviceManager.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") {
                        serviceManager.lastError = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
            
            // MCP Server error display
            if let mcpError = mcpServer.lastError {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.orange)
                    Text("MCP Server: \(mcpError)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") {
                        mcpServer.lastError = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
            if serviceManager.requiresAdmin {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.yellow)
                    Text("Administrator privileges required. Please relaunch using the button below.")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Spacer()
                    Button("Relaunch as Admin") {
                        relaunchAsAdmin()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }
    
    private func relaunchAsAdmin() {
        let appPath = Bundle.main.bundlePath
        let script = """
        do shell script "open -a \\"\(appPath)\\"" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        
        if let anError = error {
            let errorNumber = (anError[NSAppleScript.errorNumber] as? Int) ?? 0
            if errorNumber == -128 {
                // User cancelled, do nothing.
                serviceManager.lastError = nil
            } else {
                // We can't show a useful error message here, just log it.
                // The user will see a system-level authentication dialog.
                print("AppleScript execution error: \(anError)")
            }
        } else {
            // Quit the current non-admin instance on success
            NSApplication.shared.terminate(nil)
        }
    }
    
    private var installationWorkflowView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Welcome section
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to ExoManager")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("ExoManager helps you install and manage the Exo AI cluster server on your Mac.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // What is Exo section
                VStack(alignment: .leading, spacing: 16) {
                    Text("What is Exo?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "cpu", title: "AI Cluster Server", description: "Run AI models across multiple devices")
                        FeatureRow(icon: "network", title: "Network Discovery", description: "Automatically find and connect to other Exo nodes")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Performance Monitoring", description: "Real-time monitoring of system resources")
                        FeatureRow(icon: "message", title: "Web Interface", description: "Built-in chat interface for interacting with AI models")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // System Requirements section
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Requirements")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        RequirementRow(icon: "checkmark.circle.fill", title: "macOS 14.0 or later", isMet: true)
                        RequirementRow(icon: "checkmark.circle.fill", title: "Administrator privileges", isMet: true)
                        RequirementRow(icon: "checkmark.circle.fill", title: "Internet connection", isMet: true)
                        RequirementRow(icon: "checkmark.circle.fill", title: "At least 5GB free disk space", isMet: true)
                        RequirementRow(icon: "checkmark.circle.fill", title: "Python 3.8+", isMet: true)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Installation section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Installation")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Script availability warning
                    if !serviceManager.scriptsAvailable {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Installation Scripts Missing")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("The installation scripts are not available in the app bundle. This usually means the app wasn't built properly.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Text("Please rebuild the app using: ./build.sh --install")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if serviceManager.isInstalling {
                        VStack(spacing: 16) {
                            ProgressView("Installing Exo Service...")
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            if !serviceManager.installationProgress.isEmpty {
                                Text(serviceManager.installationProgress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("This may take several minutes. Please don't close the app.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The installation will:")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InstallStepRow(number: "1", title: "Download Exo from GitHub", description: "Latest version with MLX support")
                                InstallStepRow(number: "2", title: "Install Python dependencies", description: "Virtual environment with optimized packages")
                                InstallStepRow(number: "3", title: "Configure system service", description: "Automatic startup and management")
                                InstallStepRow(number: "4", title: "Set up web interface", description: "Accessible at http://localhost:52415")
                            }
                            
                            Button(action: {
                                serviceManager.installService()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Install Exo Service")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .disabled(serviceManager.isInstalling || !serviceManager.scriptsAvailable)
                        }
                    }
                    
                    // Error display
                    if let error = serviceManager.lastError {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Installation Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            
                            Text(error)
                                .font(.body)
                                .foregroundColor(.red)
                            
                            Button("Try Again") {
                                serviceManager.lastError = nil
                                serviceManager.installService()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // What happens after installation
                VStack(alignment: .leading, spacing: 16) {
                    Text("After Installation")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        AfterInstallRow(icon: "gauge", title: "Dashboard", description: "Monitor system resources and service status")
                        AfterInstallRow(icon: "message", title: "Chat Interface", description: "Built-in web interface for AI interactions")
                        AfterInstallRow(icon: "chart.line.uptrend.xyaxis", title: "Performance", description: "Real-time charts and metrics")
                        AfterInstallRow(icon: "network", title: "Network Discovery", description: "Find and connect to other Exo nodes")
                        AfterInstallRow(icon: "doc.text", title: "Logs", description: "View and filter service logs")
                        AfterInstallRow(icon: "gear", title: "Settings", description: "Configure Exo behavior and performance")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
    
    private var dashboardView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                // Service Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text("Service Status")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        StatusRow(title: "Service", status: serviceManager.isRunning ? "Running" : "Stopped", isGood: serviceManager.isRunning)
                        StatusRow(title: "Installation", status: serviceManager.isInstalled ? "Installed" : "Not Installed", isGood: serviceManager.isInstalled)
                        StatusRow(title: "Web Interface", status: monitor.webInterfaceAccessible ? "Accessible" : "Not Accessible", isGood: monitor.webInterfaceAccessible)
                        StatusRow(title: "API Endpoint", status: monitor.apiEndpointAccessible ? "Accessible" : "Not Accessible", isGood: monitor.apiEndpointAccessible)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                // System Resources Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        Text("System Resources")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ResourceRow(title: "CPU Usage", value: "\(Int(monitor.cpuUsage))%", color: monitor.cpuUsage > 80 ? .red : .green)
                        ResourceRow(title: "Memory Usage", value: "\(Int(monitor.memoryUsage))%", color: monitor.memoryUsage > 80 ? .red : .green)
                        ResourceRow(title: "Disk Space", value: "\(Int(monitor.diskUsage))%", color: monitor.diskUsage > 90 ? .red : .green)
                        ResourceRow(title: "Network", value: monitor.networkStatus, color: .blue)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                // Network Discovery Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.orange)
                        Text("Network Discovery")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discovered Nodes: \(networkDiscovery.discoveredNodes.count)")
                            .font(.subheadline)
                        
                        ForEach(networkDiscovery.discoveredNodes, id: \.id) { node in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(node.name)
                                Spacer()
                                Text(node.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if networkDiscovery.discoveredNodes.isEmpty {
                            Text("No nodes discovered")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                // Quick Actions Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt")
                            .foregroundColor(.purple)
                        Text("Quick Actions")
                            .font(.headline)
                    }
                    
                    VStack(spacing: 8) {
                        Button("Install Exo Service") {
                            serviceManager.installService()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(serviceManager.isInstalled || serviceManager.isInstalling)
                        
                        Button("Uninstall Exo Service") {
                            serviceManager.uninstallService()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!serviceManager.isInstalled || serviceManager.isUninstalling)
                        
                        Button("Open Web Interface") {
                            NSWorkspace.shared.open(URL(string: "http://localhost:52415")!)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!monitor.webInterfaceAccessible)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(status)
                .font(.subheadline)
                .foregroundColor(isGood ? .green : .red)
        }
    }
}

struct ResourceRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
        }
    }
}

struct AfterInstallRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct RequirementRow: View {
    let icon: String
    let title: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isMet ? .green : .red)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct InstallStepRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    let serviceManager = ExoServiceManager()
    let settings = ExoSettings()
    let monitor = ExoMonitor()
    let networkDiscovery = ExoNetworkDiscovery()
    let mcpServer = ExoMCPServer(monitor: monitor, serviceManager: serviceManager, networkDiscovery: networkDiscovery)
    
    return ContentView()
        .environmentObject(serviceManager)
        .environmentObject(settings)
        .environmentObject(monitor)
        .environmentObject(networkDiscovery)
        .environmentObject(mcpServer)
} 