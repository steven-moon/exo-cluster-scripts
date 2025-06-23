import Foundation
import SwiftUI
import SystemConfiguration

class ExoMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var diskUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var networkStatus: String = "Unknown"
    @Published var webInterfaceAccessible: Bool = false
    @Published var apiEndpointAccessible: Bool = false
    @Published var exoProcessInfo: ExoProcessInfo?
    @Published var logEntries: [LogEntry] = []
    @Published var performanceHistory: [PerformancePoint] = []
    
    private var monitoringTimer: Timer?
    private var logFileHandle: FileHandle?
    private let logPath = "/var/log/exo/exo.log"
    private let maxHistoryPoints = 100
    
    struct ExoProcessInfo {
        let pid: Int
        let cpuPercent: Double
        let memoryMB: Double
        let command: String
        let startTime: Date
    }
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: String
        let message: String
        let isError: Bool
    }
    
    struct PerformancePoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let cpu: Double
        let memory: Double
        let disk: Double
        let gpu: Double
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        stopMonitoring()
        
        // Initial check
        updateSystemMetrics()
        checkNetworkStatus()
        checkExoProcess()
        startLogMonitoring()
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateSystemMetrics()
            self?.checkNetworkStatus()
            self?.checkExoProcess()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        stopLogMonitoring()
    }
    
    // MARK: - System Metrics
    
    private func updateSystemMetrics() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let cpu = self?.getCPUUsage() ?? 0.0
            let memory = self?.getMemoryUsage() ?? 0.0
            let disk = self?.getDiskUsage() ?? 0.0
            let gpu = self?.getGPUUsage() ?? 0.0
            
            DispatchQueue.main.async {
                self?.cpuUsage = cpu
                self?.memoryUsage = memory
                self?.diskUsage = disk
                self?.gpuUsage = gpu
                
                // Add to performance history
                let point = PerformancePoint(
                    timestamp: Date(),
                    cpu: cpu,
                    memory: memory,
                    disk: disk,
                    gpu: gpu
                )
                
                self?.performanceHistory.append(point)
                
                // Keep only recent history
                if self?.performanceHistory.count ?? 0 > self?.maxHistoryPoints ?? 100 {
                    self?.performanceHistory.removeFirst()
                }
            }
        }
    }
    
    private func getCPUUsage() -> Double {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-n", "0"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse CPU usage from top output
            if let cpuLine = output.components(separatedBy: "\n").first(where: { $0.contains("CPU usage") }) {
                let components = cpuLine.components(separatedBy: " ")
                if let userIndex = components.firstIndex(of: "user"),
                   userIndex + 1 < components.count {
                    let userStr = components[userIndex + 1].replacingOccurrences(of: "%", with: "")
                    return Double(userStr) ?? 0.0
                }
            }
        } catch {
            print("Error getting CPU usage: \(error)")
        }
        
        return 0.0
    }
    
    private func getMemoryUsage() -> Double {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse memory usage from vm_stat output
            var totalPages = 0
            var freePages = 0
            
            for line in output.components(separatedBy: "\n") {
                if line.contains("Pages free:") {
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        freePages = Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    }
                } else if line.contains("Pages active:") || line.contains("Pages inactive:") || line.contains("Pages wired down:") {
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        totalPages += Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    }
                }
            }
            
            totalPages += freePages
            
            if totalPages > 0 {
                let usedPages = totalPages - freePages
                return Double(usedPages) / Double(totalPages) * 100.0
            }
        } catch {
            print("Error getting memory usage: \(error)")
        }
        
        return 0.0
    }
    
    private func getDiskUsage() -> Double {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/df")
        task.arguments = ["/opt"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse disk usage from df output
            let lines = output.components(separatedBy: "\n")
            if lines.count > 1 {
                let components = lines[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count > 4 {
                    let usedStr = components[2]
                    let totalStr = components[1]
                    
                    if let used = Double(usedStr), let total = Double(totalStr), total > 0 {
                        return (used / total) * 100.0
                    }
                }
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        
        return 0.0
    }
    
    private func getGPUUsage() -> Double {
        // For Apple Silicon, we can use powermetrics to get GPU usage
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        task.arguments = ["-n", "1", "-i", "1000", "--samplers", "gpu_power"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse GPU usage from powermetrics output
            if let gpuLine = output.components(separatedBy: "\n").first(where: { $0.contains("GPU Active") }) {
                let components = gpuLine.components(separatedBy: " ")
                if let percentIndex = components.firstIndex(of: "%"),
                   percentIndex > 0 {
                    let percentStr = components[percentIndex - 1]
                    return Double(percentStr) ?? 0.0
                }
            }
        } catch {
            print("Error getting GPU usage: \(error)")
        }
        
        return 0.0
    }
    
    // MARK: - Network Status
    
    private func checkNetworkStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let webAccessible = self?.checkWebInterface() ?? false
            let apiAccessible = self?.checkAPIEndpoint() ?? false
            
            DispatchQueue.main.async {
                self?.webInterfaceAccessible = webAccessible
                self?.apiEndpointAccessible = apiAccessible
                self?.networkStatus = webAccessible ? "Connected" : "Disconnected"
            }
        }
    }
    
    private func checkWebInterface() -> Bool {
        guard let url = URL(string: "http://localhost:52415") else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAccessible = false
        
        let task = URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                isAccessible = httpResponse.statusCode == 200 || httpResponse.statusCode == 302
            }
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return isAccessible
    }
    
    private func checkAPIEndpoint() -> Bool {
        guard let url = URL(string: "http://localhost:52415/v1/chat/completions") else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAccessible = false
        
        let task = URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                // API is accessible if it returns OK (200), or Method Not Allowed (405) for a GET request to a POST endpoint.
                // Any other code (especially 404 or 5xx) means it's not accessible.
                isAccessible = httpResponse.statusCode == 200 || httpResponse.statusCode == 405
            }
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return isAccessible
    }
    
    // MARK: - Process Monitoring
    
    private func checkExoProcess() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let processInfo = self?.getExoProcessInfo()
            
            DispatchQueue.main.async {
                self?.exoProcessInfo = processInfo
            }
        }
    }
    
    private func getExoProcessInfo() -> ExoProcessInfo? {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-eo", "pid,pcpu,pmem,command"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Find exo process
            for line in output.components(separatedBy: "\n") {
                if line.contains("exo") && !line.contains("grep") {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if components.count >= 4 {
                        let pid = Int(components[0]) ?? 0
                        let cpuPercent = Double(components[1]) ?? 0.0
                        let memoryMB = Double(components[2]) ?? 0.0
                        let command = components[3...].joined(separator: " ")
                        
                        return ExoProcessInfo(
                            pid: pid,
                            cpuPercent: cpuPercent,
                            memoryMB: memoryMB,
                            command: command,
                            startTime: Date()
                        )
                    }
                }
            }
        } catch {
            print("Error getting exo process info: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Log Monitoring
    
    private func startLogMonitoring() {
        guard FileManager.default.fileExists(atPath: logPath) else { return }
        
        do {
            logFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: logPath))
            logFileHandle?.seekToEndOfFile()
            
            // Start monitoring for new log entries
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(logFileChanged),
                name: .NSFileHandleDataAvailable,
                object: logFileHandle
            )
            
            logFileHandle?.waitForDataInBackgroundAndNotify()
        } catch {
            print("Error opening log file: \(error)")
        }
    }
    
    private func stopLogMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .NSFileHandleDataAvailable, object: nil)
        logFileHandle?.closeFile()
        logFileHandle = nil
    }
    
    @objc private func logFileChanged() {
        guard let fileHandle = logFileHandle else { return }
        
        let data = fileHandle.availableData
        if !data.isEmpty {
            if let newLogs = String(data: data, encoding: .utf8) {
                parseLogEntries(newLogs)
            }
        }
        
        fileHandle.waitForDataInBackgroundAndNotify()
    }
    
    private func parseLogEntries(_ logText: String) {
        let lines = logText.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let entry = parseLogLine(line)
            if let entry = entry {
                DispatchQueue.main.async {
                    self.logEntries.append(entry)
                    
                    // Keep only recent log entries
                    if self.logEntries.count > 1000 {
                        self.logEntries.removeFirst()
                    }
                }
            }
        }
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Parse log line format: "2024-01-01 12:00:00 - INFO: Message"
        let components = line.components(separatedBy: " - ")
        guard components.count >= 2 else { return nil }
        
        let timestampStr = components[0]
        let messagePart = components[1]
        
        let messageComponents = messagePart.components(separatedBy: ": ")
        guard messageComponents.count >= 2 else { return nil }
        
        let level = messageComponents[0]
        let message = messageComponents[1...].joined(separator: ": ")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.date(from: timestampStr) ?? Date()
        
        let isError = level.uppercased().contains("ERROR") || level.uppercased().contains("CRITICAL")
        
        return LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            isError: isError
        )
    }
    
    // MARK: - Public Methods
    
    func clearLogs() {
        logEntries.removeAll()
    }
    
    func getRecentLogs(count: Int = 50) -> [LogEntry] {
        return Array(logEntries.suffix(count))
    }
    
    func getErrorLogs() -> [LogEntry] {
        return logEntries.filter { $0.isError }
    }
    
    func getPerformanceData(for timeRange: TimeInterval) -> [PerformancePoint] {
        let cutoffDate = Date().addingTimeInterval(-timeRange)
        return performanceHistory.filter { $0.timestamp > cutoffDate }
    }
} 