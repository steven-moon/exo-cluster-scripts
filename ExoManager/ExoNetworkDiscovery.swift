import Foundation
import SwiftUI
import Network
import Darwin

class ExoNetworkDiscovery: ObservableObject {
    @Published var discoveredNodes: [ExoNode] = []
    @Published var isDiscovering = false
    @Published var lastError: String?
    
    private var discoveryTimer: Timer?
    private var udpListener: NWConnection?
    private let discoveryPort: UInt16 = 52416
    
    struct ExoNode: Identifiable, Codable, Hashable {
        var id: UUID
        let name: String
        let address: String
        let port: Int
        let capabilities: [String]
        let memory: Int64
        let gpu: String?
        let lastSeen: Date
        let isOnline: Bool
        
        var displayName: String {
            return name.isEmpty ? address : name
        }
        
        init(name: String, address: String, port: Int, capabilities: [String], memory: Int64, gpu: String?, lastSeen: Date, isOnline: Bool) {
            self.id = UUID()
            self.name = name
            self.address = address
            self.port = port
            self.capabilities = capabilities
            self.memory = memory
            self.gpu = gpu
            self.lastSeen = lastSeen
            self.isOnline = isOnline
        }
        
        // Hashable conformance
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: ExoNode, rhs: ExoNode) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    init() {
        startDiscovery()
    }
    
    deinit {
        stopDiscovery()
    }
    
    // MARK: - Discovery Control
    
    func startDiscovery() {
        guard !isDiscovering else { return }
        
        isDiscovering = true
        lastError = nil
        
        // Start UDP listener for exo discovery
        startUDPListener()
        
        // Start periodic discovery
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performDiscovery()
        }
        
        // Perform initial discovery
        performDiscovery()
    }
    
    func stopDiscovery() {
        isDiscovering = false
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        stopUDPListener()
    }
    
    // MARK: - UDP Discovery
    
    private func startUDPListener() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("0.0.0.0"),
            port: NWEndpoint.Port(integerLiteral: discoveryPort)
        )
        
        udpListener = NWConnection(to: endpoint, using: .udp)
        
        udpListener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.receiveUDPMessages()
                case .failed(let error):
                    self?.lastError = "UDP listener failed: \(error.localizedDescription)"
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        
        udpListener?.start(queue: .global(qos: .utility))
    }
    
    private func stopUDPListener() {
        udpListener?.cancel()
        udpListener = nil
    }
    
    private func receiveUDPMessages() {
        udpListener?.receiveMessage { [weak self] content, context, isComplete, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = "UDP receive error: \(error.localizedDescription)"
                }
                return
            }
            
            if let data = content, let message = String(data: data, encoding: .utf8) {
                self?.handleDiscoveryMessage(message)
            }
            
            // Continue receiving
            self?.receiveUDPMessages()
        }
    }
    
    private func handleDiscoveryMessage(_ message: String) {
        // Parse exo discovery message
        // Expected format: "EXO_DISCOVERY|name|address|port|capabilities|memory|gpu"
        let components = message.components(separatedBy: "|")
        
        guard components.count >= 7 && components[0] == "EXO_DISCOVERY" else { return }
        
        let name = components[1]
        let address = components[2]
        let port = Int(components[3]) ?? 52415
        let capabilities = components[4].components(separatedBy: ",")
        let memory = Int64(components[5]) ?? 0
        let gpu = components[6].isEmpty ? nil : components[6]
        
        let node = ExoNode(
            name: name,
            address: address,
            port: port,
            capabilities: capabilities,
            memory: memory,
            gpu: gpu,
            lastSeen: Date(),
            isOnline: true
        )
        
        DispatchQueue.main.async {
            self.addOrUpdateNode(node)
        }
    }
    
    // MARK: - Active Discovery
    
    private func performDiscovery() {
        // Send discovery broadcast
        sendDiscoveryBroadcast()
        
        // Scan common network ranges
        scanNetworkRanges()
        
        // Clean up stale nodes
        cleanupStaleNodes()
    }
    
    private func sendDiscoveryBroadcast() {
        let discoveryMessage = createDiscoveryMessage()
        
        // Send to broadcast address
        let broadcastAddresses = [
            "255.255.255.255",
            "192.168.1.255",
            "192.168.0.255",
            "10.0.0.255",
            "172.16.0.255"
        ]
        
        for address in broadcastAddresses {
            sendUDPMessage(discoveryMessage, to: address, port: discoveryPort)
        }
    }
    
    private func createDiscoveryMessage() -> String {
        let hostname = Host.current().localizedName ?? "Unknown"
        let memory = getSystemMemory()
        let gpu = getSystemGPU()
        let capabilities = getSystemCapabilities()
        
        return "EXO_DISCOVERY|\(hostname)|\(getLocalIPAddress())|52415|\(capabilities)|\(memory)|\(gpu)"
    }
    
    private func sendUDPMessage(_ message: String, to address: String, port: UInt16) {
        guard let data = message.data(using: .utf8) else { return }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(address),
            port: NWEndpoint.Port(integerLiteral: port)
        )
        
        let connection = NWConnection(to: endpoint, using: .udp)
        
        connection.stateUpdateHandler = { state in
            if state == .ready {
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send discovery message: \(error)")
                    }
                    connection.cancel()
                })
            }
        }
        
        connection.start(queue: .global(qos: .utility))
    }
    
    private func scanNetworkRanges() {
        let ranges = [
            "192.168.1",
            "192.168.0",
            "10.0.0",
            "172.16.0"
        ]
        
        for range in ranges {
            for i in 1...254 {
                let address = "\(range).\(i)"
                scanAddress(address)
            }
        }
    }
    
    private func scanAddress(_ address: String) {
        // Check if exo is running on this address
        let url = URL(string: "http://\(address):52415")!
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                
                // Found an exo server
                let node = ExoNode(
                    name: "Discovered Node",
                    address: address,
                    port: 52415,
                    capabilities: ["web_interface"],
                    memory: 0,
                    gpu: nil,
                    lastSeen: Date(),
                    isOnline: true
                )
                
                DispatchQueue.main.async {
                    self?.addOrUpdateNode(node)
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Node Management
    
    private func addOrUpdateNode(_ node: ExoNode) {
        if let existingIndex = discoveredNodes.firstIndex(where: { $0.address == node.address }) {
            discoveredNodes[existingIndex] = node
        } else {
            discoveredNodes.append(node)
        }
    }
    
    private func cleanupStaleNodes() {
        let cutoffTime = Date().addingTimeInterval(-60) // Remove nodes not seen in 1 minute
        discoveredNodes.removeAll { $0.lastSeen < cutoffTime }
    }
    
    // MARK: - System Information
    
    private func getLocalIPAddress() -> String {
        var address: String = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return address
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: (interface?.ifa_name)!)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        return address
    }
    
    private func getSystemMemory() -> Int64 {
        // Use a safer approach that doesn't require Process execution
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        
        if sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0) == 0 {
            return Int64(size)
        }
        
        // Fallback to a reasonable default
        return 8 * 1024 * 1024 * 1024 // 8GB default
    }
    
    private func getSystemGPU() -> String {
        // Use a safer approach that doesn't require Process execution
        var brand = [CChar](repeating: 0, count: 256)
        var brandLen = brand.count
        
        if sysctlbyname("machdep.cpu.brand_string", &brand, &brandLen, nil, 0) == 0 {
            let brandString = String(cString: brand)
            if brandString.contains("Apple M") {
                return "Apple Silicon"
            } else if brandString.contains("Intel") {
                return "Intel"
            }
        }
        
        // Fallback detection based on architecture
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }
    
    private func getSystemCapabilities() -> String {
        var capabilities: [String] = []
        
        // Check for MLX support (Apple Silicon)
        if getSystemGPU().contains("Apple Silicon") {
            capabilities.append("mlx")
        }
        
        // Check for CUDA support (would need additional detection)
        // capabilities.append("cuda")
        
        // Always available
        capabilities.append("tinygrad")
        capabilities.append("web_interface")
        capabilities.append("api")
        
        return capabilities.joined(separator: ",")
    }
    
    // MARK: - Public Methods
    
    func connectToNode(_ node: ExoNode) {
        guard let url = URL(string: "http://\(node.address):\(node.port)") else { return }
        
        NSWorkspace.shared.open(url)
    }
    
    func pingNode(_ node: ExoNode) {
        let url = URL(string: "http://\(node.address):\(node.port)/v1/chat/completions")!
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = "Failed to ping \(node.displayName): \(error.localizedDescription)"
                } else {
                    // Update node as online
                    var updatedNode = node
                    updatedNode = ExoNode(
                        name: node.name,
                        address: node.address,
                        port: node.port,
                        capabilities: node.capabilities,
                        memory: node.memory,
                        gpu: node.gpu,
                        lastSeen: Date(),
                        isOnline: true
                    )
                    self?.addOrUpdateNode(updatedNode)
                }
            }
        }
        
        task.resume()
    }
    
    func getClusterInfo() -> ClusterInfo {
        let totalMemory = discoveredNodes.reduce(0) { $0 + $1.memory }
        let onlineNodes = discoveredNodes.filter { $0.isOnline }
        let totalCapabilities = Set(discoveredNodes.flatMap { $0.capabilities })
        
        return ClusterInfo(
            totalNodes: discoveredNodes.count,
            onlineNodes: onlineNodes.count,
            totalMemory: totalMemory,
            capabilities: Array(totalCapabilities)
        )
    }
}

struct ClusterInfo {
    let totalNodes: Int
    let onlineNodes: Int
    let totalMemory: Int64
    let capabilities: [String]
    
    var totalMemoryGB: Double {
        return Double(totalMemory) / (1024 * 1024 * 1024)
    }
} 