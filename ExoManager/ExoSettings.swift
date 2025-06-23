import Foundation
import SwiftUI

// Define the enum outside the class to resolve membership errors.
enum ThrottlePreset: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case balanced = "Balanced"
    case powerSaving = "Power Saving"
    
    var id: String { self.rawValue }
}

class ExoSettings: ObservableObject {
    // MARK: - Basic Configuration
    @AppStorage("exoHome") var exoHome: String?
    @AppStorage("hfEndpoint") var hfEndpoint: String?
    @AppStorage("debugLevel") var debugLevel: Int = 0
    
    // MARK: - Network Configuration
    @AppStorage("discoveryModule") var discoveryModule: String?
    @AppStorage("tailscaleApiKey") var tailscaleApiKey: String?
    @AppStorage("manualPeers") var manualPeers: String?
    
    // MARK: - Performance Configuration
    @AppStorage("gpuMemoryFraction") var gpuMemoryFraction: Double = 0.9
    @AppStorage("defaultModel") var defaultModel: String?
    @AppStorage("tinygradDebugLevel") var tinygradDebugLevel: Int = 0
    
    // MARK: - Web Interface Configuration
    @AppStorage("webHost") var webHost: String = "0.0.0.0"
    @AppStorage("webPort") var webPort: Int = 52415
    
    // MARK: - Advanced Configuration
    @AppStorage("extraArgs") var extraArgs: String?
    
    // MARK: - Throttling Controls
    @AppStorage("enableThrottling") var enableThrottling: Bool = false
    @AppStorage("maxCpuUsage") var maxCpuUsage: Double = 80.0
    @AppStorage("maxMemoryUsage") var maxMemoryUsage: Double = 80.0
    @AppStorage("maxGpuUsage") var maxGpuUsage: Double = 90.0
    @AppStorage("throttleInterval") var throttleInterval: Double = 5.0
    
    // MARK: - Model Management
    @AppStorage("modelCacheSize") var modelCacheSize: Double = 10.0
    @AppStorage("throttlePreset") var throttlePreset: ThrottlePreset = .performance
    
    // MARK: - Logging Configuration
    @AppStorage("logLevel") var logLevel: String = "INFO"
    @AppStorage("logToFile") var logToFile: Bool = true
    @AppStorage("logMaxSize") var logMaxSize: Double = 100.0
    @AppStorage("logMaxFiles") var logMaxFiles: Int = 5
    
    // MARK: - Security Settings
    @AppStorage("enableAuthentication") var enableAuthentication: Bool = false
    @AppStorage("apiKey") var apiKey: String?
    @AppStorage("allowedOrigins") var allowedOrigins: String = "*"
    
    // MARK: - Discovery Settings
    @AppStorage("discoveryPort") var discoveryPort: String = "52416"
    @AppStorage("discoveryTimeout") var discoveryTimeout: Double = 30.0
    @AppStorage("autoConnect") var autoConnect: Bool = true
    
    // MARK: - Persistence
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "ExoSettings"
    
    init() {
        loadSettings()
    }
    
    // MARK: - Settings Persistence
    
    func saveSettings() {
        // AppStorage saves automatically, but we can add validation or other logic here
    }
    
    func loadSettings() {
        guard let settings = userDefaults.dictionary(forKey: settingsKey) else { return }
        
        exoHome = settings["exoHome"] as? String
        hfEndpoint = settings["hfEndpoint"] as? String
        debugLevel = settings["debugLevel"] as? Int ?? 0
        discoveryModule = settings["discoveryModule"] as? String
        tailscaleApiKey = settings["tailscaleApiKey"] as? String
        manualPeers = settings["manualPeers"] as? String
        gpuMemoryFraction = settings["gpuMemoryFraction"] as? Double ?? 0.9
        defaultModel = settings["defaultModel"] as? String
        tinygradDebugLevel = settings["tinygradDebugLevel"] as? Int ?? 0
        webPort = settings["webPort"] as? Int ?? 52415
        webHost = settings["webHost"] as? String ?? "0.0.0.0"
        extraArgs = settings["extraArgs"] as? String
        enableThrottling = settings["enableThrottling"] as? Bool ?? false
        maxCpuUsage = settings["maxCpuUsage"] as? Double ?? 80.0
        maxMemoryUsage = settings["maxMemoryUsage"] as? Double ?? 80.0
        maxGpuUsage = settings["maxGpuUsage"] as? Double ?? 90.0
        throttleInterval = settings["throttleInterval"] as? Double ?? 5.0
        modelCacheSize = settings["modelCacheSize"] as? Double ?? 10.0
        logLevel = settings["logLevel"] as? String ?? "INFO"
        logToFile = settings["logToFile"] as? Bool ?? true
        logMaxSize = settings["logMaxSize"] as? Double ?? 100.0
        logMaxFiles = settings["logMaxFiles"] as? Int ?? 5
        enableAuthentication = settings["enableAuthentication"] as? Bool ?? false
        apiKey = settings["apiKey"] as? String
        allowedOrigins = settings["allowedOrigins"] as? String ?? "*"
        discoveryPort = settings["discoveryPort"] as? String ?? "52416"
        discoveryTimeout = settings["discoveryTimeout"] as? Double ?? 30.0
        autoConnect = settings["autoConnect"] as? Bool ?? true
    }
    
    func resetToDefaults() {
        exoHome = nil
        hfEndpoint = nil
        debugLevel = 0
        discoveryModule = nil
        tailscaleApiKey = nil
        manualPeers = nil
        gpuMemoryFraction = 0.9
        defaultModel = nil
        tinygradDebugLevel = 0
        webPort = 52415
        webHost = "0.0.0.0"
        extraArgs = nil
        enableThrottling = false
        maxCpuUsage = 80.0
        maxMemoryUsage = 80.0
        maxGpuUsage = 90.0
        throttleInterval = 5.0
        modelCacheSize = 10.0
        logLevel = "INFO"
        logToFile = true
        logMaxSize = 100.0
        logMaxFiles = 5
        enableAuthentication = false
        apiKey = nil
        allowedOrigins = "*"
        discoveryPort = "52416"
        discoveryTimeout = 30.0
        autoConnect = true
        
        applyPreset(.performance)
        saveSettings()
    }
    
    // MARK: - Validation
    
    func validateSettings() -> [String] {
        var errors: [String] = []
        
        if webPort < 1 || webPort > 65535 {
            errors.append("Web port must be between 1 and 65535")
        }
        
        if gpuMemoryFraction < 0.1 || gpuMemoryFraction > 1.0 {
            errors.append("GPU memory fraction must be between 0.1 and 1.0")
        }
        
        if maxCpuUsage < 10 || maxCpuUsage > 100 {
            errors.append("Max CPU usage must be between 10% and 100%")
        }
        
        if maxMemoryUsage < 10 || maxMemoryUsage > 100 {
            errors.append("Max memory usage must be between 10% and 100%")
        }
        
        if maxGpuUsage < 10 || maxGpuUsage > 100 {
            errors.append("Max GPU usage must be between 10% and 100%")
        }
        
        if throttleInterval < 1 || throttleInterval > 60 {
            errors.append("Throttle interval must be between 1 and 60 seconds")
        }
        
        if modelCacheSize < 1 || modelCacheSize > 1000 {
            errors.append("Model cache size must be between 1 and 1000 GB")
        }
        
        if logMaxSize < 1 || logMaxSize > 10000 {
            errors.append("Log max size must be between 1 and 10000 MB")
        }
        
        if logMaxFiles < 1 || logMaxFiles > 100 {
            errors.append("Log max files must be between 1 and 100")
        }
        
        return errors
    }
    
    // MARK: - Preset Configurations
    
    func applyPreset(_ preset: ThrottlePreset) {
        switch preset {
        case .performance:
            maxCpuUsage = 95.0
            maxMemoryUsage = 95.0
            maxGpuUsage = 100.0
            throttleInterval = 2.0
        case .balanced:
            maxCpuUsage = 75.0
            maxMemoryUsage = 75.0
            maxGpuUsage = 80.0
            throttleInterval = 10.0
        case .powerSaving:
            maxCpuUsage = 50.0
            maxMemoryUsage = 50.0
            maxGpuUsage = 60.0
            throttleInterval = 30.0
        }
    }
} 