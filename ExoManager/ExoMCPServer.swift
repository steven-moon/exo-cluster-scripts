import Foundation
import Network
import SwiftUI
import Combine

class ExoMCPServer: ObservableObject {
    @Published var isRunning = false
    @Published var connectedClients: Int = 0
    @Published var lastError: String?
    
    private var server: NWListener?
    private var connections: [NWConnection] = []
    private let port: UInt16 = 52417 // MCP server port
    private let queue = DispatchQueue(label: "exo.mcp.server", qos: .userInitiated)
    
    // References to other managers for data streaming
    private weak var monitor: ExoMonitor?
    private weak var serviceManager: ExoServiceManager?
    private weak var networkDiscovery: ExoNetworkDiscovery?
    
    struct MCPMessage: Codable {
        let type: String
        let timestamp: Date
        let data: [String: String]
    }
    
    init(monitor: ExoMonitor, serviceManager: ExoServiceManager, networkDiscovery: ExoNetworkDiscovery) {
        self.monitor = monitor
        self.serviceManager = serviceManager
        self.networkDiscovery = networkDiscovery
        
        setupDataBroadcasting()
    }
    
    // MARK: - Server Control
    
    func start() {
        queue.async { [weak self] in
            self?.startServer()
        }
    }
    
    func stop() {
        queue.async { [weak self] in
            self?.stopServer()
        }
    }
    
    private func startServer() {
        do {
            server = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: port))
            
            server?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                        print("MCP Server started on port \(self?.port ?? 0)")
                        self?.broadcastMessage(type: "server_status", data: ["status": "running", "port": "\(self?.port ?? 0)"])
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                        print("MCP Server failed to start: \(error)")
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            server?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            server?.start(queue: queue)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Failed to create listener: \(error.localizedDescription)"
                print("MCP Server creation error: \(error)")
            }
        }
    }
    
    private func stopServer() {
        server?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectedClients = 0
        }
    }
    
    // MARK: - Connection Management
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        DispatchQueue.main.async {
            self.connectedClients = self.connections.count
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Client connected: \(connection.endpoint)")
                self?.receive(on: connection)
            case .failed(let error):
                print("Client connection failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                print("Client disconnected: \(connection.endpoint)")
                self?.removeConnection(connection)
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        DispatchQueue.main.async {
            self.connectedClients = self.connections.count
        }
    }
    
    // MARK: - Message Handling
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                // We don't expect incoming data in this simple broadcast server
            }
            
            if isComplete {
                self?.removeConnection(connection)
            } else if let error = error {
                print("Receive error: \(error)")
                self?.removeConnection(connection)
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    // MARK: - Broadcasting
    
    private func broadcast(_ data: Data) {
        for connection in connections {
            connection.send(content: data, completion: .idempotent)
        }
    }
    
    private func setupDataBroadcasting() {
        // Broadcast performance metrics
        monitor?.objectWillChange.sink { [weak self] _ in
            self?.broadcastPerformanceMetrics()
        }.store(in: &cancellables)
        
        // Broadcast service status
        serviceManager?.objectWillChange.sink { [weak self] _ in
            self?.broadcastServiceStatus()
        }.store(in: &cancellables)
        
        // Broadcast network discovery
        networkDiscovery?.objectWillChange.sink { [weak self] _ in
            self?.broadcastNetworkDiscovery()
        }.store(in: &cancellables)
        
        // Broadcast log entries
        monitor?.$logEntries.sink { [weak self] entries in
            if let lastEntry = entries.last {
                self?.broadcastLogEntry(lastEntry)
            }
        }.store(in: &cancellables)
    }
    
    // MARK: - Public Broadcast Methods
    
    func broadcastLogEntry(_ entry: ExoMonitor.LogEntry) {
        broadcastMessage(type: "log_entry", data: [
            "level": entry.level,
            "message": entry.message,
            "isError": entry.isError
        ])
    }
    
    func broadcastPerformanceMetrics() {
        guard let monitor = monitor else { return }
        broadcastMessage(type: "performance_metrics", data: [
            "cpu": monitor.cpuUsage,
            "memory": monitor.memoryUsage,
            "disk": monitor.diskUsage,
            "gpu": monitor.gpuUsage
        ])
    }
    
    func broadcastServiceStatus() {
        guard let serviceManager = serviceManager else { return }
        broadcastMessage(type: "service_status", data: [
            "is_running": serviceManager.isRunning,
            "is_installed": serviceManager.isInstalled
        ])
    }
    
    func broadcastNetworkDiscovery() {
        guard let networkDiscovery = networkDiscovery else { return }
        broadcastMessage(type: "network_discovery", data: [
            "discovered_nodes_count": networkDiscovery.discoveredNodes.count,
            "is_discovering": networkDiscovery.isDiscovering
        ])
    }
    
    func broadcastDebugMessage(_ message: String, component: String) {
        broadcastMessage(type: "debug_message", data: [
            "level": "DEBUG",
            "message": message,
            "source": component
        ])
    }
    
    private func broadcastMessage(type: String, data: [String: Any]) {
        let stringData = data.mapValues { String(describing: $0) }

        let message = MCPMessage(
            type: type,
            timestamp: Date(),
            data: stringData
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let encodedData = try encoder.encode(message)
            broadcast(encodedData)
        } catch {
            DispatchQueue.main.async {
                self.lastError = "MCP encoding error: \(error.localizedDescription)"
            }
        }
    }
    
    // Store cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
} 