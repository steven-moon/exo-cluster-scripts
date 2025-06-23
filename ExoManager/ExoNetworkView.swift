import SwiftUI

struct ExoNetworkView: View {
    @EnvironmentObject var networkDiscovery: ExoNetworkDiscovery
    @State private var selectedNode: ExoNetworkDiscovery.ExoNode?
    @State private var showNodeDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Network Discovery")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        networkDiscovery.startDiscovery()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(networkDiscovery.isDiscovering)
                    
                    Button(action: {
                        networkDiscovery.stopDiscovery()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!networkDiscovery.isDiscovering)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 0.5)
            
            // Content
            HStack(spacing: 0) {
                // Node list
                VStack(spacing: 0) {
                    HStack {
                        Text("Discovered Nodes")
                            .font(.headline)
                        Spacer()
                        Text("\(networkDiscovery.discoveredNodes.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 0.5)
                    
                    if networkDiscovery.discoveredNodes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "network")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Nodes Discovered")
                                .font(.headline)
                            
                            Text("Start discovery to find other exo nodes on your network")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            if networkDiscovery.isDiscovering {
                                ProgressView("Discovering...")
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Button("Start Discovery") {
                                    networkDiscovery.startDiscovery()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(networkDiscovery.discoveredNodes, id: \.id, selection: $selectedNode) { node in
                            NodeRow(node: node)
                                .onTapGesture {
                                    selectedNode = node
                                    showNodeDetails = true
                                }
                        }
                    }
                }
                .frame(width: 300)
                
                // Details panel
                if let node = selectedNode {
                    NodeDetailsView(node: node)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Select a Node")
                            .font(.headline)
                        
                        Text("Choose a node from the list to view details and manage connections")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showNodeDetails) {
            if let node = selectedNode {
                NodeDetailsSheet(node: node)
            }
        }
        .onAppear {
            networkDiscovery.startDiscovery()
        }
    }
}

struct NodeRow: View {
    let node: ExoNetworkDiscovery.ExoNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(node.isOnline ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(node.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(node.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Port: \(node.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(node.lastSeen, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !node.capabilities.isEmpty {
                HStack {
                    ForEach(node.capabilities.prefix(3), id: \.self) { capability in
                        Text(capability)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    
                    if node.capabilities.count > 3 {
                        Text("+\(node.capabilities.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NodeDetailsView: View {
    let node: ExoNetworkDiscovery.ExoNode
    @EnvironmentObject var networkDiscovery: ExoNetworkDiscovery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(node.isOnline ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(node.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Connect") {
                        networkDiscovery.connectToNode(node)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Text(node.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Node information
            VStack(alignment: .leading, spacing: 16) {
                Text("Node Information")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    InfoCard(title: "Status", value: node.isOnline ? "Online" : "Offline", color: node.isOnline ? .green : .red)
                    InfoCard(title: "Port", value: "\(node.port)", color: .blue)
                    InfoCard(title: "Memory", value: formatMemory(node.memory), color: .purple)
                    InfoCard(title: "GPU", value: node.gpu ?? "Unknown", color: .orange)
                    InfoCard(title: "Last Seen", value: node.lastSeen.formatted(.dateTime), color: .secondary)
                    InfoCard(title: "Capabilities", value: "\(node.capabilities.count)", color: .accentColor)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Capabilities
            if !node.capabilities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Capabilities")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100))
                    ], spacing: 8) {
                        ForEach(node.capabilities, id: \.self) { capability in
                            Text(capability)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Ping Node") {
                        networkDiscovery.pingNode(node)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Open Web Interface") {
                        networkDiscovery.connectToNode(node)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Copy Address") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(node.address, forType: .string)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            Spacer()
        }
        .padding()
    }
    
    private func formatMemory(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
}

struct NodeDetailsSheet: View {
    let node: ExoNetworkDiscovery.ExoNode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkDiscovery: ExoNetworkDiscovery
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Node Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Basic info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                        
                        InfoRow(title: "Name", value: node.displayName)
                        InfoRow(title: "Address", value: node.address)
                        InfoRow(title: "Port", value: "\(node.port)")
                        InfoRow(title: "Status", value: node.isOnline ? "Online" : "Offline")
                        InfoRow(title: "Last Seen", value: node.lastSeen.formatted())
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // System info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Information")
                            .font(.headline)
                        
                        InfoRow(title: "Memory", value: formatMemory(node.memory))
                        InfoRow(title: "GPU", value: node.gpu ?? "Unknown")
                        InfoRow(title: "Capabilities", value: "\(node.capabilities.count) available")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Capabilities list
                    if !node.capabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Capabilities")
                                .font(.headline)
                            
                            ForEach(node.capabilities, id: \.self) { capability in
                                HStack {
                                    Image(systemName: capabilityIcon(for: capability))
                                        .foregroundColor(.accentColor)
                                    Text(capability)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    
                    // Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            Button("Connect to Web Interface") {
                                networkDiscovery.connectToNode(node)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            
                            Button("Ping Node") {
                                networkDiscovery.pingNode(node)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Copy Connection Info") {
                                let info = "http://\(node.address):\(node.port)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(info, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func formatMemory(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
    
    private func capabilityIcon(for capability: String) -> String {
        switch capability.lowercased() {
        case "mlx": return "cpu"
        case "tinygrad": return "cpu"
        case "cuda": return "gpu"
        case "web_interface": return "globe"
        case "api": return "network"
        default: return "gear"
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ClusterInfoView: View {
    @EnvironmentObject var networkDiscovery: ExoNetworkDiscovery
    
    var body: some View {
        let clusterInfo = networkDiscovery.getClusterInfo()
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Cluster Information")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InfoCard(title: "Total Nodes", value: "\(clusterInfo.totalNodes)", color: .blue)
                InfoCard(title: "Online Nodes", value: "\(clusterInfo.onlineNodes)", color: .green)
                InfoCard(title: "Total Memory", value: String(format: "%.1f GB", clusterInfo.totalMemoryGB), color: .purple)
                InfoCard(title: "Capabilities", value: "\(clusterInfo.capabilities.count)", color: .orange)
            }
            
            if !clusterInfo.capabilities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cluster Capabilities")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100))
                    ], spacing: 8) {
                        ForEach(clusterInfo.capabilities, id: \.self) { capability in
                            Text(capability)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ExoNetworkView()
        .environmentObject(ExoNetworkDiscovery())
} 