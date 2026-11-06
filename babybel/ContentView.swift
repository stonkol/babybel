import AppKit
import SwiftUI
import UniformTypeIdentifiers
public import Combine

struct ContentView: View {
    @StateObject private var workspace = ManuscriptWorkspace()
    @State private var showingFolderPicker = false
    @State private var imageZoom: CGFloat = 1
    @State private var imagePan = CGSize.zero
    @State private var editorTabs: [EditorManuscriptTab] = []
    @State private var selectedEditorTabID: UUID?
    @Environment(\.openWindow) private var openWindow

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
        .focusedValue(\.babybelCommandActions, commandActions)
        .onChange(of: workspace.selectedImageURL) { _, _ in
            imageZoom = 1
            imagePan = .zero
        }
        .onChange(of: workspace.folderURL) { _, _ in
            editorTabs = []
            selectedEditorTabID = nil
            if let selected = workspace.selectedImageURL {
                let tab = EditorManuscriptTab(url: selected)
                editorTabs = [tab]
                selectedEditorTabID = tab.id
            }
        }
        .onChange(of: workspace.selectedImageURL) { _, selected in
            guard selectedEditorTabID == nil, let selected else { return }
            let tab = EditorManuscriptTab(url: selected)
            editorTabs = [tab]
            selectedEditorTabID = tab.id
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var commandActions: BabybelCommandActions {
        BabybelCommandActions(
            canSave: workspace.hasUnsavedChanges,
            canCloseFolder: workspace.folderURL != nil,
            canNavigateImages: workspace.currentImage != nil,
            canUseDocument: workspace.markdownURL != nil,
            recentFolders: workspace.recentFolders.map { recent in
                BabybelRecentFolderCommand(title: recent.name, path: recent.displayPath) {
                    workspace.openRecentFolder(recent)
                }
            },
            openFolder: { showingFolderPicker = true },
            newWindow: { openWindow(id: "main") },
            newTab: { openEditorTab() },
            save: { workspace.saveTranscription() },
            closeFolder: { workspace.closeFolder() },
            exportWord: { workspace.exportDocument(as: .word) },
            exportPDF: { workspace.exportDocument(as: .pdf) },
            exportText: { workspace.exportDocument(as: .plainText) },
            share: { workspace.shareDocument() },
            showInFinder: { workspace.showDocumentInFinder() },
            print: { workspace.printDocument() },
            zoomIn: { imageZoom = min(imageZoom * 1.25, 16) },
            zoomOut: { imageZoom = max(imageZoom / 1.25, 0.75) },
            fitImage: { imageZoom = 1; imagePan = .zero }
        )
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
                        selectManuscript(url)
                    } label: {
                        HStack(spacing: 10) {
                            SidebarImageThumbnail(image: workspace.thumbnail(for: url))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Text(workspace.hasSection(for: url) ? "In Transcription.md" : "No section yet")
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
                ManuscriptImageViewer(
                    image: image,
                    title: workspace.selectedImageURL?.lastPathComponent ?? "Manuscript",
                    zoom: $imageZoom,
                    pan: $imagePan
                )
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
            HStack(spacing: 6) {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(editorTabs) { tab in
                            HStack(spacing: 6) {
                                Button(tab.url.lastPathComponent) {
                                    activateEditorTab(tab)
                                }
                                .lineLimit(1)
                                .buttonStyle(.plain)
                                if editorTabs.count > 1 {
                                    Button {
                                        closeEditorTab(tab)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Close Tab")
                                }
                            }
                            .font(.system(size: 12, weight: selectedEditorTabID == tab.id ? .semibold : .regular))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(selectedEditorTabID == tab.id ? Color(nsColor: .controlBackgroundColor) : .clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .scrollIndicators(.hidden)

                Button(action: openEditorTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("New Manuscript Tab")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            HStack {
                Text(workspace.markdownURL?.lastPathComponent ?? "Transcription.md")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if workspace.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                        .help("Unsaved changes")
                }
            }
            .padding(12)

            Divider()

            MarkdownTextEditor(text: Binding(
                get: { workspace.transcription },
                set: { workspace.updateTranscription($0) }
            ))
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
        .onAppear {
            if editorTabs.isEmpty, let selected = workspace.selectedImageURL {
                let tab = EditorManuscriptTab(url: selected)
                editorTabs = [tab]
                selectedEditorTabID = tab.id
            }
        }
    }

    private func selectManuscript(_ url: URL) {
        workspace.selectImage(url)
        if let activeIndex = editorTabs.firstIndex(where: { $0.id == selectedEditorTabID }) {
            editorTabs[activeIndex].url = url
        } else {
            let tab = EditorManuscriptTab(url: url)
            editorTabs.append(tab)
            selectedEditorTabID = tab.id
        }
    }

    private func openEditorTab() {
        let openURLs = Set(editorTabs.map(\.url))
        let url = workspace.imageFiles.first(where: { !openURLs.contains($0) })
            ?? workspace.selectedImageURL
            ?? workspace.imageFiles.first
        guard let url else { return }
        let tab = EditorManuscriptTab(url: url)
        editorTabs.append(tab)
        selectedEditorTabID = tab.id
        workspace.selectImage(url)
    }

    private func activateEditorTab(_ tab: EditorManuscriptTab) {
        selectedEditorTabID = tab.id
        workspace.selectImage(tab.url)
    }

    private func closeEditorTab(_ tab: EditorManuscriptTab) {
        guard editorTabs.count > 1, let index = editorTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let wasSelected = selectedEditorTabID == tab.id
        editorTabs.remove(at: index)
        if wasSelected {
            let next = editorTabs[min(index, editorTabs.count - 1)]
            selectedEditorTabID = next.id
            workspace.selectImage(next.url)
        }
    }
}

private struct EditorManuscriptTab: Identifiable {
    let id = UUID()
    var url: URL
}

private struct SidebarImageThumbnail: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .padding(2)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ManuscriptImageViewer: View {
    let image: NSImage
    let title: String
    @Binding var zoom: CGFloat
    @Binding var pan: CGSize
    @State private var dragOrigin = CGSize.zero
    @State private var isDragging = false
    @State private var magnificationStart: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                    zoom = max(zoom / 1.25, 0.25)
                }
                .labelStyle(.iconOnly)
                .disabled(zoom <= 0.25)
                Button("Fit Image") {
                    zoom = 1
                    pan = .zero
                }
                .font(.caption.monospacedDigit())
                .help("Fit image to window")
                Button("Zoom In", systemImage: "plus.magnifyingglass") {
                    zoom = min(zoom * 1.25, 8)
                }
                .labelStyle(.iconOnly)
                .disabled(zoom >= 8)
            }
            .buttonStyle(.borderless)
            .padding(12)
            Divider()

            GeometryReader { geometry in
                let imageSize = image.size
                let fitScale = min(
                    geometry.size.width / max(imageSize.width, 1),
                    geometry.size.height / max(imageSize.height, 1)
                )
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(
                            width: max(imageSize.width * fitScale * zoom, 1),
                            height: max(imageSize.height * fitScale * zoom, 1)
                        )
                        .offset(pan)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .background(Color(nsColor: .windowBackgroundColor))
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if !isDragging {
                                dragOrigin = pan
                                isDragging = true
                            }
                            pan = CGSize(
                                width: dragOrigin.width + value.translation.width,
                                height: dragOrigin.height + value.translation.height
                            )
                        }
                        .onEnded { _ in isDragging = false }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let start = magnificationStart ?? zoom
                            magnificationStart = start
                            zoom = min(max(start * value, 0.25), 8)
                        }
                        .onEnded { _ in magnificationStart = nil }
                )
                .help("Drag to pan. Pinch or use the zoom buttons to resize.")
            }
        }
    }
}

struct BabybelCommandActions {
    let canSave: Bool
    let canCloseFolder: Bool
    let canNavigateImages: Bool
    let canUseDocument: Bool
    let recentFolders: [BabybelRecentFolderCommand]
    let openFolder: () -> Void
    let newWindow: () -> Void
    let newTab: () -> Void
    let save: () -> Void
    let closeFolder: () -> Void
    let exportWord: () -> Void
    let exportPDF: () -> Void
    let exportText: () -> Void
    let share: () -> Void
    let showInFinder: () -> Void
    let print: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let fitImage: () -> Void
}

struct BabybelRecentFolderCommand: Identifiable {
    var id: String { path }
    let title: String
    let path: String
    let open: () -> Void
}

private struct BabybelCommandActionsKey: FocusedValueKey {
    typealias Value = BabybelCommandActions
}

extension FocusedValues {
    var babybelCommandActions: BabybelCommandActions? {
        get { self[BabybelCommandActionsKey.self] }
        set { self[BabybelCommandActionsKey.self] = newValue }
    }
}

struct BabybelCommands: Commands {
    @FocusedValue(\.babybelCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") { actions?.newWindow() }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Tab") { actions?.newTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Open…") { actions?.openFolder() }
                .keyboardShortcut("o", modifiers: .command)
            Menu("Open Recent") {
                if let recentFolders = actions?.recentFolders, !recentFolders.isEmpty {
                    ForEach(recentFolders) { recent in
                        Button(recent.title) { recent.open() }
                    }
                } else {
                    Button("No Recent Folders") { }
                        .disabled(true)
                }
            }
            .disabled(actions?.recentFolders.isEmpty != false)
            Button("Save Transcription") { actions?.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(actions?.canSave != true)
            Menu("Export") {
                Button("Word Document (.docx)") { actions?.exportWord() }
                Button("PDF (.pdf)") { actions?.exportPDF() }
                Button("Plain Text (.txt)") { actions?.exportText() }
            }
            .disabled(actions?.canUseDocument != true)
            Button("Share…") { actions?.share() }
                .disabled(actions?.canUseDocument != true)
            Button("Show in Finder") { actions?.showInFinder() }
                .disabled(actions?.canUseDocument != true)
            Button("Print…") { actions?.print() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(actions?.canUseDocument != true)
            Divider()
            Button("Close Folder") { actions?.closeFolder() }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(actions?.canCloseFolder != true)
        }

        CommandMenu("Image") {
            Button("Zoom In") { actions?.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(actions?.canNavigateImages != true)
            Button("Zoom Out") { actions?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(actions?.canNavigateImages != true)
            Button("Fit Image to Window") { actions?.fitImage() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(actions?.canNavigateImages != true)
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
    private var imageThumbnails: [URL: NSImage] = [:]
    @Published private(set) var selectedImageURL: URL?
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var markdownURL: URL?
    @Published private(set) var transcription = ""
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var recentFolders: [RecentManuscriptFolder] = []
    @Published var showingError = false
    @Published private(set) var errorMessage = ""

    private var hasFolderAccess = false
    private var documentPreamble = ""
    private var sections: [String: String] = [:]
    private var sectionOrder: [String] = []

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
            imageThumbnails = Dictionary(uniqueKeysWithValues: images.compactMap { url in
                makeThumbnail(for: url).map { (url, $0) }
            })
            selectedImageURL = nil
            currentImage = nil
            markdownURL = url.appendingPathComponent("Transcription.md")
            transcription = ""
            hasUnsavedChanges = false
            loadSharedDocument(importingImagesFrom: images, in: url)

            if let firstImage = images.first {
                selectImage(firstImage)
            }
            saveRecentFolder(url, firstImage: images.first)
        } catch {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
            report(error)
        }
    }

    func closeFolder() {
        if hasUnsavedChanges && !saveTranscription() { return }
        if hasFolderAccess, let folderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
        hasFolderAccess = false
        folderURL = nil
        imageFiles = []
        imageThumbnails = [:]
        selectedImageURL = nil
        currentImage = nil
        markdownURL = nil
        transcription = ""
        sections = [:]
        sectionOrder = []
        documentPreamble = ""
        hasUnsavedChanges = false
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

        let key = url.lastPathComponent
        let createdSection = sections[key] == nil
        if createdSection {
            sections[key] = ""
            sectionOrder.append(key)
        }
        selectedImageURL = url
        currentImage = image
        transcription = sections[key] ?? ""
        hasUnsavedChanges = hasUnsavedChanges || createdSection
    }

    func updateTranscription(_ text: String) {
        transcription = text
        if let selectedImageURL {
            sections[selectedImageURL.lastPathComponent] = text
        }
        hasUnsavedChanges = true
    }

    @discardableResult
    func saveTranscription() -> Bool {
        guard hasUnsavedChanges, let markdownURL else { return true }
        do {
            try Data(serializedDocument.utf8).write(to: markdownURL, options: .atomic)
            hasUnsavedChanges = false
            return true
        } catch {
            report(error)
            return false
        }
    }

    func hasSection(for imageURL: URL) -> Bool {
        sections[imageURL.lastPathComponent] != nil
    }

    func thumbnail(for imageURL: URL) -> NSImage? {
        imageThumbnails[imageURL]
    }

    func exportDocument(as format: BabybelExportFormat) {
        guard markdownURL != nil else { return }
        guard saveTranscription() else { return }
        do {
            try BabybelDocumentExporter.export(
                text: serializedDocument,
                format: format,
                suggestedName: "\(folderURL?.lastPathComponent ?? "Babybel")-Transcription"
            )
        } catch {
            report(error)
        }
    }

    func shareDocument() {
        guard let markdownURL, saveDocumentForExternalAction() else { return }
        guard let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [markdownURL])
        picker.show(
            relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0),
            of: view,
            preferredEdge: .minY
        )
    }

    func showDocumentInFinder() {
        guard let markdownURL, saveDocumentForExternalAction() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([markdownURL])
    }

    func printDocument() {
        guard markdownURL != nil, saveTranscription() else { return }
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.string = serializedDocument
        textView.font = .systemFont(ofSize: 12)
        textView.isEditable = false

        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        NSPrintOperation(view: textView, printInfo: printInfo).run()
    }

    private func saveDocumentForExternalAction() -> Bool {
        guard let markdownURL else { return false }
        guard saveTranscription() else { return false }
        guard !FileManager.default.fileExists(atPath: markdownURL.path) else { return true }
        do {
            try Data(serializedDocument.utf8).write(to: markdownURL, options: .atomic)
            return true
        } catch {
            report(error)
            return false
        }
    }

    func report(_ error: Error) {
        reportMessage(error.localizedDescription)
    }

    private func reportMessage(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private var serializedDocument: String {
        let renderedSections = sectionOrder.compactMap { key -> String? in
            guard let text = sections[key] else { return nil }
            return "## \(key)\n\n\(text)"
        }
        return ([documentPreamble.trimmingCharacters(in: .newlines)] + renderedSections)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n") + "\n"
    }

    private func loadSharedDocument(importingImagesFrom images: [URL], in folder: URL) {
        guard let markdownURL else { return }
        documentPreamble = "# \(folder.lastPathComponent)\n\n"
        sections = [:]
        sectionOrder = []

        if FileManager.default.fileExists(atPath: markdownURL.path) {
            do {
                let contents = try String(contentsOf: markdownURL, encoding: .utf8)
                parseDocument(contents, imageNames: Set(images.map(\.lastPathComponent)))
                if sections.isEmpty, !contents.isEmpty, let firstImage = images.first {
                    sections[firstImage.lastPathComponent] = contents.trimmingCharacters(in: .newlines)
                    sectionOrder.append(firstImage.lastPathComponent)
                    hasUnsavedChanges = true
                }
            } catch {
                report(error)
            }
            return
        }

        // Migrate transcriptions created by the first prototype into the shared file.
        for image in images {
            let oldURL = image.deletingPathExtension().appendingPathExtension("md")
            guard FileManager.default.fileExists(atPath: oldURL.path),
                  let text = try? String(contentsOf: oldURL, encoding: .utf8) else { continue }
            let key = image.lastPathComponent
            sections[key] = text
            sectionOrder.append(key)
        }
        if !sections.isEmpty {
            hasUnsavedChanges = true
        }
    }

    private func parseDocument(_ text: String, imageNames: Set<String>) {
        var preambleLines: [String] = []
        var currentSection: String?
        var sectionLines: [String] = []

        func saveCurrentSection() {
            guard let currentSection else { return }
            sections[currentSection] = sectionLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !sectionOrder.contains(currentSection) { sectionOrder.append(currentSection) }
            sectionLines = []
        }

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                let candidate = String(line.dropFirst(3))
                if imageNames.contains(candidate) {
                    saveCurrentSection()
                    currentSection = candidate
                    continue
                }
            }
            if currentSection == nil {
                preambleLines.append(line)
            } else {
                sectionLines.append(line)
            }
        }
        saveCurrentSection()
        let savedPreamble = preambleLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        if !savedPreamble.isEmpty { documentPreamble = savedPreamble }
    }

    private func saveRecentFolder(_ url: URL, firstImage: URL?) {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let previewData = firstImage.flatMap { makePreviewData(for: $0) }
            let markdownName = "Transcription.md"
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

    private func makeThumbnail(for imageURL: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: imageURL), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let thumbnailSize = NSSize(width: 104, height: 104)
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        let scale = min(thumbnailSize.width / image.size.width, thumbnailSize.height / image.size.height)
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(
            in: NSRect(
                x: (thumbnailSize.width - drawSize.width) / 2,
                y: (thumbnailSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        thumbnail.unlockFocus()
        return thumbnail
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
