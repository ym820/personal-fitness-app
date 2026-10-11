import Foundation

/// 动作示范视频。只存链接，视频本身在 YouTube / B 站上，播放需要联网。
public struct ExerciseVideo: Codable, Hashable, Identifiable, Sendable {
    public enum Platform: String, Codable, Sendable {
        case youtube
        case bilibili

        public var nameZh: String {
            switch self {
            case .youtube: "YouTube"
            case .bilibili: "B 站"
            }
        }
    }

    public let platform: Platform
    /// YouTube 的视频 id（watch?v= 后面那串），或 B 站的 BV 号
    public let id: String
    public let title: String
    public let author: String
    public let durationSeconds: Int?
    /// false 表示作者关闭了嵌入播放，点了直接跳到 YouTube / B 站 app
    public let embeddable: Bool
    /// 封面图地址。YouTube 可以从 id 推出来，不用填；B 站要填
    public let thumbnail: String?

    public init(platform: Platform, id: String, title: String, author: String, durationSeconds: Int?, embeddable: Bool, thumbnail: String?) {
        self.platform = platform
        self.id = id
        self.title = title
        self.author = author
        self.durationSeconds = durationSeconds
        self.embeddable = embeddable
        self.thumbnail = thumbnail
    }

    enum CodingKeys: String, CodingKey {
        case platform, id, title, author, durationSeconds, embeddable, thumbnail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platform = try container.decode(Platform.self, forKey: .platform)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        embeddable = try container.decodeIfPresent(Bool.self, forKey: .embeddable) ?? true
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
    }

    /// 在 YouTube / B 站打开的地址（装了 app 会直接跳到 app）
    public var watchURL: URL {
        switch platform {
        case .youtube: URL(string: "https://www.youtube.com/watch?v=\(id)")!
        case .bilibili: URL(string: "https://www.bilibili.com/video/\(id)")!
        }
    }

    /// 嵌入播放器地址
    public var embedURL: URL {
        switch platform {
        case .youtube: URL(string: "https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0")!
        case .bilibili: URL(string: "https://player.bilibili.com/player.html?bvid=\(id)&autoplay=0&high_quality=1")!
        }
    }

    public var thumbnailURL: URL? {
        if let thumbnail { return URL(string: thumbnail) }
        switch platform {
        case .youtube: return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        case .bilibili: return nil
        }
    }
}
