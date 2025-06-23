import Foundation
import SwiftUI
import Security

class ExoServiceManager: ObservableObject {
    @Published var isRunning = false
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var isUninstalling = false
    @Published var lastError: String?
    @Published var installationProgress: String = ""
    @Published var requiresAdmin = false
    
    // Helper to resolve script path robustly
    static func resolveScriptPath(_ scriptName: String) -> String? {
        let potentialPaths = [
            Bundle.main.resourceURL?.appendingPathComponent("scripts/\(scriptName)").path,
            Bundle.main.resourceURL?.appendingPathComponent(scriptName).path,
            Bundle.main.path(forResource: scriptName, ofType: nil)
        ]
        
        for path in potentialPaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    // Use the helper for all script paths
    private var installScriptPath: String { Self.resolveScriptPath("install_exo_service.sh") ?? "" }
    private var uninstallScriptPath: String { Self.resolveScriptPath("uninstall_exo_service.sh") ?? "" }
    private var checkStatusScriptPath: String { Self.resolveScriptPath("check_exo_status.sh") ?? "" }

    var scriptsAvailable: Bool {
        let installExists = !installScriptPath.isEmpty
        let uninstallExists = !uninstallScriptPath.isEmpty
        if !installExists || !uninstallExists {
            print("[DEBUG] Scripts missing. Install: '\(installScriptPath)', Uninstall: '\(uninstallScriptPath)'")
        }
        return installExists && uninstallExists
    }
    
    init() {
        checkInstallationStatus()
    }
    
    private func checkAdminAndScripts() -> Bool {
        requiresAdmin = false
        if getuid() != 0 {
            // lastError = "Administrator privileges required. Relaunch ExoManager as an administrator to continue."
            requiresAdmin = true
            return false
        }
        if !scriptsAvailable {
            lastError = "Installation scripts not found. Please rebuild the app."
            return false
        }
        return true
    }
    
    // MARK: - Installation Management
    
    func installService() {
        guard !isInstalling, checkAdminAndScripts() else { return }
        
        isInstalling = true
        lastError = nil
        installationProgress = "Starting installation..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.updateProgress("Running installation script...")
            let result = self.runScript(scriptPath: self.installScriptPath, timeout: 300) // 5 minute timeout
            
            DispatchQueue.main.async {
                self.isInstalling = false
                self.installationProgress = ""
                if let error = result.error {
                    self.lastError = "Installation failed: \(error)"
                } else {
                    self.isInstalled = true
                    self.checkServiceStatus()
                }
            }
        }
    }
    
    func uninstallService() {
        guard !isUninstalling, checkAdminAndScripts() else { return }

        isUninstalling = true
        lastError = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.runScript(scriptPath: self.uninstallScriptPath, timeout: 180)
            
            DispatchQueue.main.async {
                self.isUninstalling = false
                if let error = result.error {
                    self.lastError = "Uninstallation failed: \(error)"
                } else {
                    self.isInstalled = false
                    self.isRunning = false
                }
            }
        }
    }
    
    // MARK: - Service Control
    
    func startService() {
        guard isInstalled, !isRunning, checkAdminAndScripts() else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runScript(scriptPath: "/bin/launchctl", arguments: ["start", "com.exolabs.exo"])
            DispatchQueue.main.async {
                if let error = result?.error { self?.lastError = "Failed to start service: \(error)" }
                self?.checkServiceStatus()
            }
        }
    }

    func stopService() {
        guard isRunning, checkAdminAndScripts() else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runScript(scriptPath: "/bin/launchctl", arguments: ["stop", "com.exolabs.exo"])
            DispatchQueue.main.async {
                if let error = result?.error { self?.lastError = "Failed to stop service: \(error)" }
                self?.checkServiceStatus()
            }
        }
    }

    func restartService() {
        guard isRunning, checkAdminAndScripts() else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let stopResult = self?.runScript(scriptPath: "/bin/launchctl", arguments: ["stop", "com.exolabs.exo"])
            sleep(1) // Give it a moment to stop
            let startResult = self?.runScript(scriptPath: "/bin/launchctl", arguments: ["start", "com.exolabs.exo"])
            
            DispatchQueue.main.async {
                if let error = stopResult?.error ?? startResult?.error {
                    self?.lastError = "Failed to restart service: \(error)"
                }
                self?.checkServiceStatus()
            }
        }
    }
    
    // MARK: - Status Checking
    
    func checkInstallationStatus() {
        DispatchQueue.global(qos: .utility).async {
            let isInstalled = FileManager.default.fileExists(atPath: "/opt/exo/scripts/start_exo.sh") &&
                              FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.exolabs.exo.plist")
            
            DispatchQueue.main.async {
                self.isInstalled = isInstalled
                if isInstalled {
                    self.checkServiceStatus()
                } else {
                    self.isRunning = false
                }
            }
        }
    }
    
    func checkServiceStatus() {
        guard isInstalled else {
            isRunning = false
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let result = self.runScript(scriptPath: self.checkStatusScriptPath, arguments: ["quick"])
            
            DispatchQueue.main.async {
                if result.error != nil {
                    self.isRunning = false
                } else {
                    self.isRunning = result.output?.contains("RUNNING") ?? false
                }
            }
        }
    }
    
    private func updateProgress(_ message: String) {
        DispatchQueue.main.async {
            self.installationProgress = message
        }
    }

    // MARK: - Utility Methods
    
    private func runScript(scriptPath: String, arguments: [String] = [], timeout: TimeInterval = 60) -> (output: String?, error: String?) {
        guard !scriptPath.isEmpty, FileManager.default.fileExists(atPath: scriptPath) else {
            return (nil, "Script not found at path: \(scriptPath)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = arguments
        
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            return (nil, "Failed to launch script: \(error.localizedDescription)")
        }
        
        let group = DispatchGroup()
        group.enter()
        
        var timedOut = false
        let workItem = DispatchWorkItem {
            process.waitUntilExit()
            group.leave()
        }
        
        DispatchQueue.global().async(execute: workItem)
        
        if group.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if timedOut {
            return (output, "Script timed out after \(timeout) seconds.")
        }
        
        if process.terminationStatus != 0 {
            let errorDetails = errorOutput?.isEmpty == false ? errorOutput : "Script exited with code \(process.terminationStatus)."
            return (output, errorDetails)
        }
        
        return (output, nil)
    }
} 