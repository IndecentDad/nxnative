import SwiftUI
import UIKit
import Combine

final class SaveFolderSyncModel: ObservableObject {
    let sync: DmSaveFolderSync
    @Published private(set) var revision = 0
    @Published private(set) var pendingResume = false
    private var notice: NSObjectProtocol?
    private var active: NSObjectProtocol?

    init?(_ sync: DmSaveFolderSync?) {
        guard let sync else { return nil }
        self.sync = sync
        notice = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: DmSaveFolderSyncNotice), object: nil, queue: .main) { [weak self] _ in
            self?.pendingResume = false
            self?.revision += 1
        }
        active = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.showsStatus else { return }
            self.pendingResume = true
            self.revision += 1
        }
    }

    deinit {
        if let notice { NotificationCenter.default.removeObserver(notice) }
        if let active { NotificationCenter.default.removeObserver(active) }
    }

    var folderName: String { sync.selectedFolderName ?? "Sync Folder" }
    var titleID: String { sync.titleID }
    var status: String { sync.statusText ?? "No folder selected" }
    var lastSync: String { sync.lastSuccessfulSync?.formatted(date: .abbreviated, time: .shortened) ?? "Never" }
    var configured: Bool { sync.selectedFolder != nil }
    var enabled: Bool { sync.enabled }
    var showsStatus: Bool { configured && (enabled || status == "Syncing") }
    var unavailable: Bool { sync.state.rawValue == 3 || sync.state.rawValue == 4 }
    var conflict: Bool { sync.state.rawValue == 2 }
    var visualState: SaveSyncVisualState {
        if conflict { return .conflict }
        if sync.state.rawValue == 3 { return .unavailable }
        if sync.state.rawValue == 4 { return .failed }
        if status == "Syncing" { return .syncing }
        if pendingResume { return .syncing }
        if sync.lastSuccessfulSync != nil,
           status == "Already Up to Date" || status.hasPrefix("Save files imported successfully") || status.hasPrefix("Save files exported") { return .ready }
        // A newly resolved sync object starts at "Ready" before its first status notice.
        // Do not treat that default as evidence that the current launch is synchronized.
        return .syncing
    }
    private func displayPath(_ url: URL) -> (String, Bool) {
        let path = url.standardizedFileURL.path
        do {
            let values = try url.resourceValues(forKeys: [.volumeNameKey])
            var volumeObject: AnyObject?
            try (url as NSURL).getResourceValue(&volumeObject, forKey: .volumeURLKey)
            if let volumeURL = volumeObject as? NSURL,
               let root = volumeURL.path,
               let volumeName = values.volumeName, !volumeName.isEmpty {
                let prefix = root.hasSuffix("/") ? root : root + "/"
                if path.hasPrefix(prefix) {
                    let relative = String(path.dropFirst(prefix.count))
                    if !relative.isEmpty { return ("\(volumeName)/\(relative)", true) }
                }
            }
        } catch { }
        return (path, false)
    }
    var linkedFolderPath: String? {
        guard let folder = sync.selectedFolder else { return nil }
        let (path, _) = displayPath(folder)
        return path.hasSuffix("/") ? path : path + "/"
    }
    var saveDestinationPath: String? {
        guard let folder = sync.selectedFolder else { return nil }
        let destination = folder.appendingPathComponent(titleID, isDirectory: true)
        let (folderPath, providerRelative) = displayPath(folder)
        let path = providerRelative ? folderPath + "/" + titleID : destination.standardizedFileURL.path
        return path.hasSuffix("/") ? path : path + "/"
    }
    var pathNote: String {
        guard let folder = sync.selectedFolder else { return "" }
        let (_, providerRelative) = displayPath(folder)
        return providerRelative ? "Provider-relative location from iOS Files" : "Location shown as exposed by iOS Files"
    }

    func refresh() { revision += 1 }
}

enum SaveSyncVisualState: Equatable {
    case ready, syncing, conflict, unavailable, failed

    var title: String {
        switch self {
        case .ready: return "Saves synchronized"
        case .syncing: return "Syncing saves…"
        case .conflict: return "Save conflict"
        case .unavailable: return "Save sync unavailable"
        case .failed: return "Save sync failed"
        }
    }
    var color: Color {
        switch self {
        case .ready: return .green
        case .syncing: return .orange
        case .conflict, .unavailable, .failed: return .red
        }
    }
    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .syncing: return "arrow.2.circlepath"
        case .conflict, .unavailable, .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct SaveSyncStatusLabel: View {
    let state: SaveSyncVisualState
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.symbol)
                .rotationEffect(.degrees(state == .syncing ? 360 : 0))
                .animation(state == .syncing ? .linear(duration: 1.1).repeatForever(autoreverses: false) : .default, value: state == .syncing)
            Text(state.title).lineLimit(2).multilineTextAlignment(.center)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(state.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.title)
    }
}

struct SaveSyncDetailsView: View {
    @ObservedObject var model: SaveFolderSyncModel
    @Environment(\.dismiss) private var dismiss
    @State private var copiedPath: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SaveSyncStatusLabel(state: model.visualState)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    detailRow(title: "Last successful sync", value: model.lastSync)
                    detailRow(title: "Last operation and result", value: model.status)
                    if let path = model.linkedFolderPath {
                        pathRow(title: "Linked folder", path: path)
                    }
                    if let path = model.saveDestinationPath {
                        pathRow(title: "Save destination", path: path)
                    }
                    Text(model.pathNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Save Sync Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }

    private func pathRow(title: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Text(path)
                    .font(.footnote.monospaced())
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = path
                    copiedPath = path
                } label: {
                    Image(systemName: copiedPath == path ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(title.lowercased()) path")
            }
        }
    }
}

struct SaveFolderSyncSection: View {
    @ObservedObject var model: SaveFolderSyncModel
    let presenter: () -> UIViewController?
    @State private var resolvingConflict = false
    @State private var confirmingUnlink = false

    var body: some View {
        Section("Save Folder Sync") {
            HStack(spacing: 8) {
                Button {
                    if let viewController = presenter() { dm_save_folder_sync_present(model.sync, viewController) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.enabled || (model.configured && model.status == "Syncing") ? "Save Sync Enabled" : "Save Sync Disabled")
                        Text(model.enabled || (model.configured && model.status == "Syncing") ? "\(model.folderName) · Tap to change folder" : model.configured ? "\(model.folderName) · Tap to enable or change folder" : "Tap to link folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if model.configured {
                    Button {
                        confirmingUnlink = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Unlink selected folder")
                }
            }
            Text("Automatically syncs saves to a shared folder. Saves are stored in a TitleID-named folder for Eden compatibility.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if model.conflict {
                Button("Resolve Save Conflict…") { resolvingConflict = true }
            }
        }
        .confirmationDialog("Resolve Conflicts", isPresented: $resolvingConflict) {
            Button("Use Folder Saves") { dm_save_folder_sync_import(model.sync) }
            Button("Use Device Saves") { dm_save_folder_sync_export(model.sync) }
            Button("Preserve Both", role: .cancel) { dm_save_folder_sync_preserve(model.sync) }
        } message: {
            Text("Both local and folder saves changed. Choose which complete save to keep.")
        }
        .confirmationDialog("Unlink Save Folder?", isPresented: $confirmingUnlink, titleVisibility: .visible) {
            Button("Unlink Folder", role: .destructive) {
                dm_save_folder_sync_clear(model.sync)
                model.refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the folder link only. Save files in both locations will be kept.")
        }
    }
}
