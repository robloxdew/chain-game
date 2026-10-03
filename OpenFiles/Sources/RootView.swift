import SwiftUI

struct RootView: View {
    @StateObject private var fs = FileSystem.shared
    @State private var currentPath: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let path = currentPath {
                    BrowserView(path: path)
                } else {
                    HomeView(onOpen: { currentPath = $0 })
                        .environmentObject(fs)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentPath != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            currentPath = nil
                        } label: {
                            Label("主页", systemImage: "house")
                        }
                    }
                }
            }
        }
        .environmentObject(fs)
        .onReceive(NotificationCenter.default.publisher(for: .openFilesNavigate)) { note in
            if let url = note.object as? URL { currentPath = url }
        }
    }
}

/// 起始页：环境状态 + 常用位置
struct HomeView: View {
    @EnvironmentObject var fs: FileSystem
    let onOpen: (URL) -> Void

    var body: some View {
        List {
            Section("环境") {
                HStack {
                    Label("越狱状态", systemImage: fs.jailbroken ? "checkmark.shield.fill" : "xmark.shield")
                        .foregroundStyle(fs.jailbroken ? .green : .secondary)
                    Spacer()
                    Text(fs.jailbroken ? "已越狱" : "未越狱").foregroundStyle(.secondary)
                }
                HStack {
                    Label("全盘访问", systemImage: fs.fullDiskAccess ? "externaldrive.fill.badge.checkmark" : "lock.shield")
                        .foregroundStyle(fs.fullDiskAccess ? .green : .orange)
                    Spacer()
                    Text(fs.fullDiskAccess ? "沙盒外可用" : "仅沙盒内").foregroundStyle(.secondary)
                }
                if !fs.fullDiskAccess {
                    Text("未检测到越狱或签名缺少 entitlements，浏览范围限制在应用沙盒内。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("位置") {
                ForEach(fs.locations) { loc in
                    Button {
                        onOpen(loc.path)
                    } label: {
                        Label(loc.name, systemImage: loc.icon)
                    }
                }
            }
        }
        .navigationTitle("OpenFiles")
    }
}
