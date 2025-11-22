import SwiftUI
import AppKit
import Combine

struct FolderUsage: Identifiable {
    let id = UUID()
    let url: URL
    let bytes: Int64
    let isDirectory: Bool
}

@MainActor
final class DiskUsageViewModel: ObservableObject {
    @Published var folderUsage: [FolderUsage] = []
    @Published var isScanning = false
    @Published var statusText = "Pick a folder to see where the space goes."
    @Published var scannedRoot: URL?
    @Published var usedCapacityBytes: Int64?
    @Published var totalCapacityBytes: Int64?
    @Published var canGoBack = false
    @Published var selectionTotalBytes: Int64 = 0

    private var scanTask: Task<Void, Never>?
    private let scanner = DiskScanner()
    private var history: [URL] = []

    func scan(root: URL, appendHistory: Bool = false, preserveHistory: Bool = false) {
        scanTask?.cancel()
        folderUsage = []
        isScanning = true
        scannedRoot = root
        statusText = "Scanning \(root.path)..."
        usedCapacityBytes = nil
        totalCapacityBytes = nil
        selectionTotalBytes = 0
        if appendHistory, let current = scannedRoot {
            history.append(current)
        } else if !preserveHistory {
            history.removeAll()
        }
        canGoBack = !history.isEmpty

        scanTask = Task {
            let results = await scanner.computeUsage(at: root)
            let volumeInfo = await scanner.volumeUsage(for: root)
            guard !Task.isCancelled else { return }
            folderUsage = results
                .filter { $0.bytes > 0 }
                .sorted { $0.bytes > $1.bytes }
            selectionTotalBytes = folderUsage.reduce(into: Int64(0)) { $0 += $1.bytes }
            if let info = volumeInfo {
                usedCapacityBytes = info.used
                totalCapacityBytes = info.total
            }
            isScanning = false
            statusText = folderUsage.isEmpty ? "Nothing to show here." : "Scan complete."
            canGoBack = !history.isEmpty
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusText = "Scan cancelled."
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        scan(root: previous, appendHistory: false, preserveHistory: true)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DiskUsageViewModel()
    @AppStorage("showFullDiskAccessPrompt") private var showFullDiskAccessPrompt = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            status
            list
            totals
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 520)
        .sheet(isPresented: $showFullDiskAccessPrompt) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Allow Full Disk Access")
                    .font(.title2.weight(.semibold))
                Text("""
                For the best results please grant Full Disk Access to this app in System Settings > Privacy & Security > Full Disk Access, then relaunch.
                """)
                .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open Settings") {
                        openFullDiskAccessSettings()
                        showFullDiskAccessPrompt = false
                    }
                    Button("Got it") {
                        showFullDiskAccessPrompt = false
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(width: 420)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disk Usage Snapshot")
                .font(.largeTitle.weight(.semibold))
            Text("Quickly see which top-level folders eat the most space. Scans recurse into each child and totals their sizes.")
                .foregroundColor(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.scan(root: URL(fileURLWithPath: "/"))
            } label: {
                label(action: "Scan Entire Disk", icon: "internaldrive")
            }
            .disabled(viewModel.isScanning)

            Button {
                viewModel.scan(root: FileManager.default.homeDirectoryForCurrentUser)
            } label: {
                label(action: "Scan Home Folder", icon: "house")
            }
            .disabled(viewModel.isScanning)

            Button {
                pickFolder()
            } label: {
                label(action: "Choose Folder…", icon: "folder")
            }
            .disabled(viewModel.isScanning)

            Button {
                if let root = viewModel.scannedRoot {
                    viewModel.scan(root: root, preserveHistory: true)
                }
            } label: {
                label(action: "Refresh", icon: "arrow.clockwise")
            }
            .disabled(viewModel.scannedRoot == nil)
            .disabled(viewModel.isScanning)

            if viewModel.canGoBack {
                Button {
                    viewModel.goBack()
                } label: {
                    label(action: "Back", icon: "arrow.backward")
                }
                .disabled(viewModel.isScanning)
            }

            Spacer()

            if viewModel.isScanning {
                Button {
                    viewModel.cancelScan()
                } label: {
                    label(action: "Stop", icon: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private func label(action: String, icon: String) -> some View {
        Label(action, systemImage: icon)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isScanning {
                EmptyView()
            } else {
                Text(viewModel.statusText)
                    .foregroundColor(.secondary)
            }

            if let root = viewModel.scannedRoot {
                Text("Current root: \(root.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var list: some View {
        Group {
            if viewModel.folderUsage.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: .init(lineWidth: 1, dash: [6, 8]))
                    .overlay(
                        VStack(spacing: 8) {
                            if viewModel.isScanning {
                                ProgressView()
                                Text("Scanning folders…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Results will appear here.")
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                List(viewModel.folderUsage) { usage in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(usage.url.lastPathComponent.isEmpty ? usage.url.path : usage.url.lastPathComponent)
                                .font(.headline)
                            Text(usage.url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(bytesString(usage.bytes))
                            .font(.headline.monospacedDigit())
                            .frame(minWidth: 110, alignment: .trailing)
                        if usage.isDirectory {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "chevron.right")
                                .opacity(0)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard usage.isDirectory else { return }
                        viewModel.scan(root: usage.url, appendHistory: true)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"

        if panel.runModal() == .OK, let url = panel.urls.first {
            viewModel.scan(root: url)
        }
    }
    
    private func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    private var totals: some View {
        Group {
            if let used = viewModel.usedCapacityBytes, let total = viewModel.totalCapacityBytes {
                let percent = Double(used) / Double(max(total, 1))
                let accounted = viewModel.folderUsage.reduce(into: Int64(0)) { $0 += $1.bytes }
                let unaccounted = max(used - accounted, 0)
                VStack(alignment: .leading, spacing: 4) {
                    
                    HStack {
                        Text("Total of listed items:")
                            .font(.subheadline)
                        Spacer()
                        Text(bytesString(viewModel.selectionTotalBytes))
                            .font(.headline.monospacedDigit())
                    }
                    
                    Divider()
                    
                    Text("Disk usage for \(viewModel.scannedRoot?.path ?? "volume")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("\(bytesString(used)) used / \(bytesString(total)) total")
                        Spacer()
                        Text("\(percentString(percent)) used")
                            .monospacedDigit()
                    }
                    ProgressView(value: percent)
                        .progressViewStyle(.linear)
                    if unaccounted > 0 {
                        Text("Unaccounted (system/purgeable/snapshots): \(bytesString(unaccounted))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

private func bytesString(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func percentString(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 1
    return formatter.string(from: NSNumber(value: value)) ?? ""
}

actor DiskScanner {
    private let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey
    ]

    func computeUsage(at root: URL) async -> [FolderUsage] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ) else {
            debugLog("Failed to list children of \(root.path)")
            return []
        }

        var usages: [FolderUsage] = []
        for child in children {
            if Task.isCancelled { break }
            guard let values = try? child.resourceValues(forKeys: resourceKeys) else {
                debugLog("Could not read resource values for \(child.path)")
                continue
            }
            if values.isSymbolicLink == true {
                continue
            }
            let size = folderSize(at: child, fileManager: fm)
            if size == 0 {
                debugLog("Zero-sized or inaccessible: \(child.path)")
            }
            guard size > 0 else { continue }
            let isDir = values.isDirectory == true
            usages.append(FolderUsage(url: child, bytes: size, isDirectory: isDir))
        }
        return usages
    }
    
    func volumeUsage(for root: URL) async -> (used: Int64, total: Int64)? {
        let path = root.path
        guard
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
            let total = (attrs[.systemSize] as? NSNumber)?.int64Value,
            let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value
        else {
            debugLog("Failed to read filesystem attributes for \(path)")
            return nil
        }
        let used = max(total - free, 0)
        return (used, total)
    }

    private func folderSize(at url: URL, fileManager: FileManager) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
            debugLog("Could not read resource values for \(url.path)")
            return 0
        }
        if values.isSymbolicLink == true { return 0 }
        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        var size: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ) else {
            debugLog("Could not enumerate \(url.path)")
            return 0
        }

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { return 0 }
            guard let v = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                debugLog("Resource value failure for \(fileURL.path)")
                continue
            }
            if v.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if v.isRegularFile == true {
                size += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            }
        }
        return size
    }
    
    nonisolated private func debugLog(_ message: String) {
        #if DEBUG
        print("[DiskScanner] \(message)")
        #endif
    }
}
