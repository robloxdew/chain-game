import Foundation
import SwiftUI

/// 文件系统访问层：
/// - 越狱设备（no-container entitlements + 有效签名）→ 可全盘浏览
/// - 未越狱 → 自动降级为沙盒内浏览
final class FileSystem: ObservableObject {
    static let shared = FileSystem()

    /// 是否具有全盘访问能力（运行时探测）
    @Published var fullDiskAccess: Bool = false
    /// 当前是否为越狱环境
    @Published var jailbroken: Bool = false

    private init() {
        detectEnvironment()
    }

    /// 可作为起始位置的常用目录
    struct Location: Identifiable {
        let id = UUID()
        let name: String
        let path: URL
        let icon: String
    }

    var locations: [Location] {
        var list: [Location] = []
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        list.append(Location(name: "文稿", path: docs, icon: "doc.text"))
        let fm = FileManager.default

        if fullDiskAccess {
            list.append(Location(name: "根目录 /", path: URL(fileURLWithPath: "/"), icon: "externaldrive.badge.icloud"))
            list.append(Location(name: "/var/mobile", path: URL(fileURLWithPath: "/var/mobile"), icon: "person.crop.square"))
            list.append(Location(name: "App 沙盒", path: URL(fileURLWithPath: "/var/mobile/Containers/Data/Application"), icon: "shippingbox"))
            list.append(Location(name: "应用安装目录", path: URL(fileURLWithPath: "/var/containers/Bundle/Application"), icon: "app.badge"))
        }

        // 所有设备都可访问的位置
        list.append(Location(name: "本应用沙盒", path: docs, icon: "internaldrive"))
        return list
    }

    private func detectEnvironment() {
        let fm = FileManager.default
        // 越狱特征检查
        let markers = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/var/lib/dpkg",
            "/var/jb",          // rootless 越狱 (Dopamine/ palera1n)
            "/.bootstrapped",   // rootful
        ].map { URL(fileURLWithPath: $0) }

        jailbroken = markers.contains { fm.fileExists(atPath: $0.path) }

        // 全盘访问能力探测：越狱机上尝试列根目录
        if jailbroken {
            let canReadRoot = (try? fm.contentsOfDirectory(atPath: "/")) != nil
            let canReadVar = (try? fm.contentsOfDirectory(atPath: "/var/mobile")) != nil
            fullDiskAccess = canReadRoot && canReadVar
        } else {
            fullDiskAccess = false
        }
    }

    struct Entry: Identifiable {
        let id = UUID()
        let url: URL
        let isDirectory: Bool
        let size: Int64?
        let modified: Date?
    }

    /// 列出目录内容；失败时返回错误说明
    func listDirectory(_ url: URL) -> Result<[Entry], Error> {
        let fm = FileManager.default
        do {
            let items = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: []
            )
            let entries = items.map { item -> Entry in
                let isDir = ((try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory) ?? false
                let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let mod  = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return Entry(url: item, isDirectory: isDir, size: size.map { Int64($0) }, modified: mod)
            }
            // 目录在前，各自按名称排序；隐藏文件排后
            let sorted = entries.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
            return .success(sorted)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - 文件操作

    @discardableResult
    func delete(_ urls: [URL]) -> Error? {
        for url in urls {
            do { try FileManager.default.removeItem(at: url) }
            catch { return error }
        }
        return nil
    }

    @discardableResult
    func copy(_ urls: [URL], to destDir: URL) -> Error? {
        let fm = FileManager.default
        for url in urls {
            let dest = uniqueURL(for: url.lastPathComponent, in: destDir)
            do { try fm.copyItem(at: url, to: dest) }
            catch { return error }
        }
        return nil
    }

    @discardableResult
    func move(_ urls: [URL], to destDir: URL) -> Error? {
        let fm = FileManager.default
        for url in urls {
            let dest = uniqueURL(for: url.lastPathComponent, in: destDir)
            do { try fm.moveItem(at: url, to: dest) }
            catch { return error }
        }
        return nil
    }

    @discardableResult
    func rename(_ url: URL, to newName: String) -> Error? {
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        do { try FileManager.default.moveItem(at: url, to: dest) }
        catch { return error }
        return nil
    }

    @discardableResult
    func createFolder(named name: String, in dir: URL) -> Error? {
        do {
            try FileManager.default.createDirectory(
                at: uniqueURL(for: name, in: dir),
                withIntermediateDirectories: false
            )
        } catch { return error }
        return nil
    }

    @discardableResult
    func createFile(named name: String, in dir: URL) -> Error? {
        let dest = uniqueURL(for: name, in: dir)
        return FileManager.default.createFile(atPath: dest.path, contents: Data()) ? nil
            : NSError(domain: "OpenFiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建文件"])
    }

    func readText(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    /// 目标目录内生成不重名的路径
    private func uniqueURL(for name: String, in dir: URL) -> URL {
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var candidate = dir.appendingPathComponent(name)
        var i = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = ext.isEmpty
                ? dir.appendingPathComponent("\(base) (\(i))")
                : dir.appendingPathComponent("\(base) (\(i)).\(ext)")
            i += 1
        }
        return candidate
    }

    func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
