import SwiftUI

struct ExoLogViewer: View {
    @EnvironmentObject var monitor: ExoMonitor
    @State private var searchText = ""
    @State private var selectedLogLevel: LogLevel = .all
    @State private var showErrorsOnly = false
    @State private var autoScroll = true
    @State private var logEntries: [ExoMonitor.LogEntry] = []
    
    enum LogLevel: String, CaseIterable {
        case all = "All"
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .frame(width: 250)
                
                // Log level filter
                Picker("Log Level", selection: $selectedLogLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
                
                // Show errors only toggle
                Toggle("Errors Only", isOn: $showErrorsOnly)
                    .toggleStyle(SwitchToggleStyle())
                
                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(SwitchToggleStyle())
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button("Clear") {
                        monitor.clearLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Export") {
                        exportLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Refresh") {
                        refreshLogs()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 0.5)
            
            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLogEntries) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: filteredLogEntries.count) { _, _ in
                    if autoScroll && !filteredLogEntries.isEmpty {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(filteredLogEntries.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshLogs()
        }
        .onReceive(monitor.$logEntries) { entries in
            logEntries = entries
        }
    }
    
    private var filteredLogEntries: [ExoMonitor.LogEntry] {
        var filtered = logEntries
        
        // Filter by log level
        if selectedLogLevel != .all {
            filtered = filtered.filter { $0.level.uppercased() == selectedLogLevel.rawValue }
        }
        
        // Filter by errors only
        if showErrorsOnly {
            filtered = filtered.filter { $0.isError }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.level.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    private func refreshLogs() {
        // The monitor should automatically update logEntries
        // This is just a manual refresh trigger
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "exo_logs_\(Date().formatted(.dateTime.year().month().day().hour().minute())).txt"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let logContent = filteredLogEntries.map { entry in
                    "\(entry.timestamp.formatted(.dateTime.year().month().day().hour().minute().second())) - \(entry.level): \(entry.message)"
                }.joined(separator: "\n")
                
                do {
                    try logContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export logs: \(error)")
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: ExoMonitor.LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Log level badge
            Text(entry.level)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(levelColor.opacity(0.2))
                .foregroundColor(levelColor)
                .cornerRadius(4)
                .frame(width: 60, alignment: .center)
            
            // Message
            Text(entry.message)
                .font(.caption)
                .foregroundColor(entry.isError ? .red : .primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .background(entry.isError ? Color.red.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
    
    private var levelColor: Color {
        switch entry.level.uppercased() {
        case "DEBUG":
            return .gray
        case "INFO":
            return .blue
        case "WARNING":
            return .orange
        case "ERROR":
            return .red
        case "CRITICAL":
            return .purple
        default:
            return .secondary
        }
    }
}

struct LogStatisticsView: View {
    @EnvironmentObject var monitor: ExoMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Statistics")
                .font(.headline)
            
            let stats = calculateStatistics()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    StatRow(title: "Total Entries", value: "\(stats.total)")
                    StatRow(title: "Errors", value: "\(stats.errors)")
                    StatRow(title: "Warnings", value: "\(stats.warnings)")
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatRow(title: "Info", value: "\(stats.info)")
                    StatRow(title: "Debug", value: "\(stats.debug)")
                    StatRow(title: "Error Rate", value: "\(String(format: "%.1f", stats.errorRate))%")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func calculateStatistics() -> (total: Int, errors: Int, warnings: Int, info: Int, debug: Int, errorRate: Double) {
        let entries = monitor.logEntries
        
        let total = entries.count
        let errors = entries.filter { $0.isError }.count
        let warnings = entries.filter { $0.level.uppercased() == "WARNING" }.count
        let info = entries.filter { $0.level.uppercased() == "INFO" }.count
        let debug = entries.filter { $0.level.uppercased() == "DEBUG" }.count
        
        let errorRate = total > 0 ? Double(errors) / Double(total) * 100.0 : 0.0
        
        return (total, errors, warnings, info, debug, errorRate)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct LogFilterView: View {
    @Binding var selectedLogLevel: ExoLogViewer.LogLevel
    @Binding var showErrorsOnly: Bool
    @Binding var searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Log Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Log Level", selection: $selectedLogLevel) {
                    ForEach(ExoLogViewer.LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Toggle("Show Errors Only", isOn: $showErrorsOnly)
                .toggleStyle(SwitchToggleStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Search in logs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ExoLogViewer()
        .environmentObject(ExoMonitor())
} 