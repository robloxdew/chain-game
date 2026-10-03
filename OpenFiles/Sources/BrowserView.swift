import SwiftUI
import UIKit
import QuickLook

/// 文件浏览器主界面（Filza 风格列表）
struct BrowserView: View {
    @EnvironmentObject var fs: FileSystem
    let path: URL

    @State private var entries: [FileSystem.Entry] = []
    @State private var loadError: String?
    @State private var selection: Set<URL> = []
    @State private var editMode = false
    @State private var previewURL: URL?
    @State private var showNewSheet = false
    @State private var renameTarget: URL?
    @State private var showShare = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("无法访问", systemImage: "folder.badge.questionmark", description: Text(loadError))
            } else {
                List(selection: $selection) {
                    if path.hasParentDirectory {
                        Button {
                            navigate(to: path.deletingLastPathComponent())
                        } label: {
                            Label("..", systemImage: "arrowshape.turn.up.left")
                        }
                    }
                    ForEach(entries) { entry in
                        Row(entry: entry, onOpen: open)
                            .tag(entry.url)
                    }
                }
            }
        }
        .navigationTitle(path.lastPathComponent.isEmpty ? "/" : path.lastPathComponent)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .environment(\.editMode, .constant(editMode ? .active : .inactive))
        .onAppear(perform: reload)
        .sheet(item: $previewURL) { url in
            PreviewView(url: url)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: Array(selection))
        }
        .sheet(isPresented: $showNewSheet) {
            NewItemSheet(dir: path) { reload() }
        }
        .alert("重命名", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            RenameAlert(target: $renameTarget, dir: path) { reload() }
        } message: {
            Text("输入新的名称")
        }
    }

    private var parent: URL? { path.deletingLastPathComponent() }

    private func navigate(to url: URL) {
        // 通过根视图导航：简单做法是重新赋值 path 不可行（let），用通知让上层替换
        NotificationCenter.default.post(name: .openFilesNavigate, object: url)
    }

    private func open(_ entry: FileSystem.Entry) {
        if entry.isDirectory {
            navigate(to: entry.url)
        } else {
            previewURL = entry.url
        }
    }

    private func reload() {
        switch fs.listDirectory(path) {
        case .success(let list):
            entries = list
            loadError = nil
        case .failure(let error):
            entries = []
            loadError = error.localizedDescription
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showNewSheet = true } label: { Label("新建文件/文件夹", systemImage: "plus") }
                if !selection.isEmpty {
                    Divider()
                    Button {
                        _ = fs.delete(Array(selection)); selection.removeAll(); reload()
                    } label: { Label("删除所选", systemImage: "trash") }
                    Button {
                        showShare = true
                    } label: { Label("分享/导出", systemImage: "square.and.arrow.up") }
                    Button {
                        renameTarget = selection.first
                    } label: { Label("重命名", systemImage: "pencil") }
                }
                Divider()
                Button(role: .destructive) {
                    // 粘贴板中的文件 URL 拷到当前目录
                    if let urls = UIPasteboard.general.urls, !urls.isEmpty {
                        _ = fs.copy(urls, to: path)
                        reload()
                    }
                } label: { Label("粘贴", systemImage: "doc.on.doc") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(editMode ? "完成" : "选择") { editMode.toggle() }
        }
    }
}

extension Notification.Name {
    static let openFilesNavigate = Notification.Name("openFilesNavigate")
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension URL {
    var hasParentDirectory: Bool { absoluteString != "file:///" }
}

// MARK: - 行

struct Row: View {
    let entry: FileSystem.Entry
    let onOpen: (FileSystem.Entry) -> Void

    var body: some View {
        Button { onOpen(entry) } label: {
            HStack {
                Image(systemName: entry.isDirectory ? "folder.fill" : iconForFile)
                    .foregroundStyle(entry.isDirectory ? Color.blue : Color.gray)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.url.lastPathComponent)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let size = entry.size, !entry.isDirectory {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        }
                        if let mod = entry.modified {
                            Text(mod.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iconForFile: String {
        let ext = entry.url.pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log", "plist", "json", "xml", "swift", "h", "m", "c", "cpp", "sh":
            return "doc.plaintext"
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return "photo"
        case "mp3", "m4a", "wav", "flac":
            return "music.note"
        case "mp4", "mov", "m4v":
            return "film"
        case "zip", "tar", "gz", "7z", "ipa", "deb":
            return "doc.zipper"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }
}

// MARK: - 预览（QuickLook，支持文本/图片/视频/PDF 等）

struct PreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - 分享

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - 新建

struct NewItemSheet: View {
    let dir: URL
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isFolder = false
    private let fs = FileSystem.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $name)
                Picker("类型", selection: $isFolder) {
                    Text("文件").tag(false)
                    Text("文件夹").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("新建")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if isFolder { _ = fs.createFolder(named: name, in: dir) }
                        else { _ = fs.createFile(named: name, in: dir) }
                        onDone()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 重命名

struct RenameAlert: View {
    @Binding var target: URL?
    let dir: URL
    let onDone: () -> Void
    @State private var newName = ""
    private let fs = FileSystem.shared

    var body: some View {
        TextField("新名称", text: $newName)
        Button("确定") {
            if let t = target {
                _ = fs.rename(t, to: newName)
                onDone()
            }
            target = nil
        }
        .disabled(newName.isEmpty)
        Button("取消", role: .cancel) { target = nil }
    }
}
