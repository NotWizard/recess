import AppKit
import Foundation

/// 更新检测：查询 GitHub Releases API 比较版本，按需下载 DMG 并挂载。
/// 不做 in-place 替换——下载完 open DMG 弹出 Finder 拖拽窗口，安装留给用户手动。
/// 详见 ADR-0001。
final class UpdateChecker: ObservableObject {

    /// 查询到的最新版本（无新版或未查询时为 nil）。
    @Published private(set) var latestVersion: String?
    /// 最新版 DMG 下载地址（与 latestVersion 同时就绪）。
    private(set) var downloadURL: URL?
    /// 下载中。
    @Published private(set) var isDownloading = false

    private let repo = "NotWizard/recess"
    private let session: URLSession

    init() {
        // 直连 GitHub（环境里 SOCKS5 代理对 github 不通，用自定义配置去掉代理）。
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        self.session = URLSession(configuration: config)
    }

    /// 查询 GitHub 最新 Release；成功且版本更新时更新 latestVersion/downloadURL。
    /// 静默失败：网络错或解析错都不抛、不打扰。
    func checkLatest(currentVersion: String) {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // GitHub API 要求 User-Agent，否则拒绝。
        req.setValue("Recess", forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: req) { [weak self] data, _, error in
            guard let self, error == nil, let data,
                  let body = try? JSONDecoder().decode(GHRelease.self, from: data) else { return }
            let tag = body.tagName.hasPrefix("v") ? String(body.tagName.dropFirst()) : body.tagName
            guard let asset = body.assets.first(where: { $0.name.hasSuffix(".dmg") }) else { return }
            guard let dl = URL(string: asset.browserDownloadURL) else { return }
            guard UpdateChecker.isNewer(tag, than: currentVersion) else { return }
            DispatchQueue.main.async {
                self.latestVersion = tag
                self.downloadURL = dl
            }
        }
        task.resume()
    }

    /// 下载 DMG 到临时目录并 open 挂载（弹出 Finder 拖拽窗口）。
    func downloadAndOpen() {
        guard !isDownloading, let url = downloadURL else { return }
        DispatchQueue.main.async { self.isDownloading = true }
        let task = session.downloadTask(with: url) { [weak self] tmpURL, _, error in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.isDownloading = false } }
            guard error == nil, let tmpURL else { return }
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: tmpURL, to: dest)
            } catch {
                return
            }
            DispatchQueue.main.async {
                NSWorkspace.shared.open(dest)
            }
        }
        task.resume()
    }

    /// 简单语义版本比较：a 是否比 b 新（均形如 "0.1.3"）。
    /// 仅支持数字段，prerelease 等不处理（当前版本号均为简单 0.x.y）。
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

private struct GHRelease: Decodable {
    let tagName: String
    let assets: [GHAsset]
    enum CodingKeys: String, CodingKey { case tagName = "tag_name"; case assets }
}

private struct GHAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
