import Foundation

struct RecentItem: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    let name: String
    let date: Date
}

enum AppSettings {
    private static let binarySearchPaths: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin"
    ]

    static var ytDlpPath: String? { resolve("yt-dlp") }
    static var ffmpegPath: String? { resolve("ffmpeg") }

    static func makeWorkingDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("AudioRepeatMVP-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 최근 사용 목록
    private static let recentKey = "RecentItems"
    private static let maxRecent = 15

    static func loadRecent() -> [RecentItem] {
        guard let data = UserDefaults.standard.data(forKey: recentKey),
              let items = try? JSONDecoder().decode([RecentItem].self, from: data) else {
            return []
        }
        return items
    }

    static func addRecent(url: String, name: String) {
        var items = loadRecent()
        items.removeAll { $0.url == url }
        items.insert(RecentItem(id: UUID(), url: url, name: name, date: Date()), at: 0)
        if items.count > maxRecent { items = Array(items.prefix(maxRecent)) }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    static func clearRecent() {
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    private static func resolve(_ name: String) -> String? {
        for base in binarySearchPaths {
            let candidate = "\(base)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
