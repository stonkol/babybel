import AppKit
import SwiftUI
import UniformTypeIdentifiers
public import Combine

struct ContentView: View {
    @StateObject private var workspace = ManuscriptWorkspace()
    @State private var showingFolderPicker = false

    var body: some View {
        Group {
            if workspace.folderURL == nil {
                homeView
            } else {
                workspaceNavigation
            }
        }
        .toolbar {
            if workspace.folderURL != nil {
                ToolbarItemGroup {
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("Open Folder", systemImage: "folder")
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button {
                        workspace.saveTranscription()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(workspace.selectedImageURL == nil || !workspace.hasUnsavedChanges)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { workspace.openFolder(url) }
                case .failure(let error):
                    workspace.report(error)
                }
            }
        )
        .alert("Babybel", isPresented: $workspace.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(workspace.errorMessage)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var workspaceNavigation: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            workspaceView
        }
        .navigationTitle(workspace.folderURL?.lastPathComponent ?? "")
    }

    private var homeView: some View {
        VStack(spacing: 0) {
            if workspace.recentFolders.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.orange)
                    Text("Start transcribing")
                        .font(.largeTitle.weight(.semibold))
                    Text("Open a folder of manuscript images and keep each transcription beside its image.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                            .font(.headline)
                            .frame(minWidth: 220, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut("o", modifiers: .command)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Recent Folders")
                            .font(.largeTitle.weight(.semibold))
                        Spacer()
                        Button {
                            showingFolderPicker = true
                        } label: {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                                .font(.headline)
                                .frame(minHeight: 42)
                                .padding(.horizontal, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .keyboardShortcut("o", modifiers: .command)
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 20)], alignment: .leading, spacing: 20) {
                            ForEach(workspace.recentFolders) { recent in
                                Button {
                                    workspace.openRecentFolder(recent)
                                } label: {
                                    RecentFolderCard(recent: recent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)
                    }
                }
                .padding(32)
                .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if let folderURL = workspace.folderURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.orange)
                    Text(folderURL.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()
            }

            if workspace.imageFiles.isEmpty {
                ContentUnavailableView(
                    workspace.folderURL == nil ? "Open a Folder" : "No Images Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(workspace.folderURL == nil
                        ? "Choose a folder containing manuscript images to begin."
                        : "Add supported image files to this folder, then reopen it.")
                )
                .padding(.horizontal, 8)
            } else {
                List(workspace.imageFiles, id: \.self) { url in
                    Button {
                        workspace.selectImage(url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Text(workspace.markdownExists(for: url) ? "Transcription available" : "No transcription yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if workspace.selectedImageURL == url {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(workspace.selectedImageURL == url ? Color.accentColor.opacity(0.12) : Color.clear)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 320)
    }

    @ViewBuilder
    private var workspaceView: some View {
        if let image = workspace.currentImage {
            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        Text(workspace.selectedImageURL?.lastPathComponent ?? "Manuscript")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(12)
                    Divider()

                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: max(geometry.size.width, 1), height: max(geometry.size.height, 1))
                        }
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
                .frame(minWidth: 300, idealWidth: 520)

                editor
                    .frame(minWidth: 300, idealWidth: 480)
            }
        } else {
            ContentUnavailableView(
                "Select a Manuscript",
                systemImage: "text.book.closed",
                description: Text("Open a folder and choose an image from the list.")
            )
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workspace.markdownURL?.lastPathComponent ?? "Transcription.md")
                        .font(.headline)
                        .lineLimit(1)
                    Text(workspace.hasUnsavedChanges ? "Unsaved changes" : "Saved as Markdown")
                        .font(.caption)
                        .foregroundStyle(workspace.hasUnsavedChanges ? .orange : .secondary)
                }
                Spacer()
                Button("Save") {
                    workspace.saveTranscription()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!workspace.hasUnsavedChanges)
            }
            .padding(12)

            Divider()

            TextEditor(text: Binding(
                get: { workspace.transcription },
                set: { workspace.updateTranscription($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .accessibilityLabel("Markdown transcription editor")

            Divider()

            HStack(spacing: 14) {
                Text("\(workspace.lineCount) lines")
                Text("\(workspace.characterCount) characters")
                Text("UTF-8")
                Spacer()
                Text("LF")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

private struct RecentFolderCard: View {
    let recent: RecentManuscriptFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let data = recent.previewImageData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.10))
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(recent.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(recent.markdownName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Text(recent.displayPath)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RecentManuscriptFolder: Codable, Identifiable {
    var id: String { path }
    let bookmarkData: Data
    let name: String
    let path: String
    let markdownName: String
    let previewImageData: Data?

    var displayPath: String {
        let home = NSHomeDirectory()
        return path == home ? "~" : (path.hasPrefix(home + "/") ? "~" + String(path.dropFirst(home.count)) : path)
    }
}

@MainActor
final class ManuscriptWorkspace: ObservableObject {
    @Published private(set) var folderURL: URL?
    @Published private(set) var imageFiles: [URL] = []
    @Published private(set) var selectedImageURL: URL?
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var markdownURL: URL?
    @Published private(set) var transcription = ""
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var recentFolders: [RecentManuscriptFolder] = []
    @Published var showingError = false
    @Published private(set) var errorMessage = ""

    private var hasFolderAccess = false

    private let recentFoldersDefaultsKey = "babybel.recentManuscriptFolders"

    private let imageExtensions: Set<String> = [
        "bmp", "gif", "heic", "jpeg", "jpg", "png", "tif", "tiff"
    ]

    init() {
        if let data = UserDefaults.standard.data(forKey: recentFoldersDefaultsKey),
           let folders = try? JSONDecoder().decode([RecentManuscriptFolder].self, from: data) {
            recentFolders = folders
        }
    }

    var lineCount: Int {
        transcription.isEmpty ? 0 : transcription.components(separatedBy: .newlines).count
    }

    var characterCount: Int { transcription.count }

    func openFolder(_ url: URL) {
        if hasUnsavedChanges && !saveTranscription() { return }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            let images = contents
                .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            if hasFolderAccess, let oldFolderURL = folderURL {
                oldFolderURL.stopAccessingSecurityScopedResource()
            }
            folderURL = url
            hasFolderAccess = didStartAccess
            imageFiles = images
            selectedImageURL = nil
            currentImage = nil
            markdownURL = nil
            transcription = ""
            hasUnsavedChanges = false

            if let firstImage = images.first {
                selectImage(firstImage)
            }
            saveRecentFolder(url, firstImage: images.first)
        } catch {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
            report(error)
        }
    }

    func openRecentFolder(_ recent: RecentManuscriptFolder) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: recent.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            openFolder(url)
        } catch {
            reportMessage("Babybel can’t reopen \(recent.name). Choose the folder again with Add Folder.\n\(error.localizedDescription)")
        }
    }

    func selectImage(_ url: URL) {
        if hasUnsavedChanges && !saveTranscription() { return }

        guard let image = NSImage(contentsOf: url) else {
            reportMessage("Babybel couldn’t open \(url.lastPathComponent) as an image.")
            return
        }

        let textURL = markdownURL(for: url)
        do {
            let text: String
            if FileManager.default.fileExists(atPath: textURL.path) {
                text = try String(contentsOf: textURL, encoding: .utf8)
            } else {
                text = ""
            }

            selectedImageURL = url
            currentImage = image
            markdownURL = textURL
            transcription = text
            hasUnsavedChanges = false
        } catch {
            report(error)
        }
    }

    func updateTranscription(_ text: String) {
        transcription = text
        hasUnsavedChanges = true
    }

    @discardableResult
    func saveTranscription() -> Bool {
        guard hasUnsavedChanges, let markdownURL else { return true }
        do {
            try Data(transcription.utf8).write(to: markdownURL, options: .atomic)
            hasUnsavedChanges = false
            return true
        } catch {
            report(error)
            return false
        }
    }

    func markdownExists(for imageURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: markdownURL(for: imageURL).path)
    }

    func report(_ error: Error) {
        reportMessage(error.localizedDescription)
    }

    private func reportMessage(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func markdownURL(for imageURL: URL) -> URL {
        imageURL.deletingPathExtension().appendingPathExtension("md")
    }

    private func saveRecentFolder(_ url: URL, firstImage: URL?) {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let previewData = firstImage.flatMap { makePreviewData(for: $0) }
            let markdownName = firstImage.map { markdownURL(for: $0).lastPathComponent } ?? "No images yet"
            let recent = RecentManuscriptFolder(
                bookmarkData: bookmark,
                name: url.lastPathComponent,
                path: url.path,
                markdownName: markdownName,
                previewImageData: previewData
            )
            recentFolders.removeAll { $0.path == url.path }
            recentFolders.insert(recent, at: 0)
            recentFolders = Array(recentFolders.prefix(12))
            if let data = try? JSONEncoder().encode(recentFolders) {
                UserDefaults.standard.set(data, forKey: recentFoldersDefaultsKey)
            }
        } catch {
            reportMessage("The folder opened, but Babybel couldn’t save it to Recent Folders.\n\(error.localizedDescription)")
        }
    }

    private func makePreviewData(for imageURL: URL) -> Data? {
        guard let image = NSImage(contentsOf: imageURL) else { return nil }
        let thumbnailSize = NSSize(width: 320, height: 180)
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: thumbnailSize)).fill()

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            thumbnail.unlockFocus()
            return nil
        }
        let scale = min(thumbnailSize.width / imageSize.width, thumbnailSize.height / imageSize.height)
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let destination = NSRect(
            x: (thumbnailSize.width - drawSize.width) / 2,
            y: (thumbnailSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        thumbnail.unlockFocus()

        guard let tiff = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }
}
