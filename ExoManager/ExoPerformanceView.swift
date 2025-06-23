import SwiftUI
import Charts

struct ExoPerformanceView: View {
    @EnvironmentObject var monitor: ExoMonitor
    @State private var selectedTimeRange: TimeRange = .last5Minutes
    @State private var selectedMetric: PerformanceMetric = .cpu
    
    enum TimeRange: String, CaseIterable {
        case last5Minutes = "5 Minutes"
        case last15Minutes = "15 Minutes"
        case lastHour = "1 Hour"
        case last6Hours = "6 Hours"
        
        var timeInterval: TimeInterval {
            switch self {
            case .last5Minutes: return 5 * 60
            case .last15Minutes: return 15 * 60
            case .lastHour: return 60 * 60
            case .last6Hours: return 6 * 60 * 60
            }
        }
    }
    
    enum PerformanceMetric: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case disk = "Disk"
        case gpu = "GPU"
        
        var color: Color {
            switch self {
            case .cpu: return .red
            case .memory: return .blue
            case .disk: return .green
            case .gpu: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header controls
            HStack {
                Text("Performance Monitor")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }
            .padding(.horizontal)
            
            // Metric selector
            HStack {
                ForEach(PerformanceMetric.allCases, id: \.self) { metric in
                    Button(action: {
                        selectedMetric = metric
                    }) {
                        HStack {
                            Circle()
                                .fill(metric.color)
                                .frame(width: 12, height: 12)
                            Text(metric.rawValue)
                                .fontWeight(selectedMetric == metric ? .bold : .regular)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMetric == metric ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Main chart
            VStack(alignment: .leading, spacing: 8) {
                Text("\(selectedMetric.rawValue) Usage")
                    .font(.headline)
                
                Chart {
                    ForEach(monitor.getPerformanceData(for: selectedTimeRange.timeInterval)) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Usage", getMetricValue(for: point))
                        )
                        .foregroundStyle(selectedMetric.color)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Usage", getMetricValue(for: point))
                        )
                        .foregroundStyle(selectedMetric.color.opacity(0.1))
                    }
                }
                .frame(height: 300)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(value.as(Double.self)?.formatted(.number) ?? "")%")
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, style: .time)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Current metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "CPU",
                    value: "\(Int(monitor.cpuUsage))%",
                    color: .red,
                    icon: "cpu"
                )
                
                MetricCard(
                    title: "Memory",
                    value: "\(Int(monitor.memoryUsage))%",
                    color: .blue,
                    icon: "memorychip"
                )
                
                MetricCard(
                    title: "Disk",
                    value: "\(Int(monitor.diskUsage))%",
                    color: .green,
                    icon: "externaldrive"
                )
                
                MetricCard(
                    title: "GPU",
                    value: "\(Int(monitor.gpuUsage))%",
                    color: .purple,
                    icon: "gpu"
                )
            }
            .padding(.horizontal)
            
            // Process information
            if let processInfo = monitor.exoProcessInfo {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exo Process")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PID: \(processInfo.pid)")
                                .font(.caption)
                            Text("CPU: \(String(format: "%.1f", processInfo.cpuPercent))%")
                                .font(.caption)
                            Text("Memory: \(String(format: "%.1f", processInfo.memoryMB)) MB")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Started: \(processInfo.startTime, style: .time)")
                                .font(.caption)
                            Text("Command: \(processInfo.command)")
                                .font(.caption)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private func getMetricValue(for point: ExoMonitor.PerformancePoint) -> Double {
        switch selectedMetric {
        case .cpu:
            return point.cpu
        case .memory:
            return point.memory
        case .disk:
            return point.disk
        case .gpu:
            return point.gpu
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct PerformanceSummaryView: View {
    @EnvironmentObject var monitor: ExoMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Summary")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(title: "Peak CPU", value: "\(Int(getPeakCPU()))%")
                    SummaryRow(title: "Peak Memory", value: "\(Int(getPeakMemory()))%")
                    SummaryRow(title: "Peak GPU", value: "\(Int(getPeakGPU()))%")
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    SummaryRow(title: "Avg CPU", value: "\(Int(getAverageCPU()))%")
                    SummaryRow(title: "Avg Memory", value: "\(Int(getAverageMemory()))%")
                    SummaryRow(title: "Avg GPU", value: "\(Int(getAverageGPU()))%")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func getPeakCPU() -> Double {
        return monitor.performanceHistory.map { $0.cpu }.max() ?? 0
    }
    
    private func getPeakMemory() -> Double {
        return monitor.performanceHistory.map { $0.memory }.max() ?? 0
    }
    
    private func getPeakGPU() -> Double {
        return monitor.performanceHistory.map { $0.gpu }.max() ?? 0
    }
    
    private func getAverageCPU() -> Double {
        let values = monitor.performanceHistory.map { $0.cpu }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    
    private func getAverageMemory() -> Double {
        let values = monitor.performanceHistory.map { $0.memory }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    
    private func getAverageGPU() -> Double {
        let values = monitor.performanceHistory.map { $0.gpu }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

struct SummaryRow: View {
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

#Preview {
    ExoPerformanceView()
        .environmentObject(ExoMonitor())
} 