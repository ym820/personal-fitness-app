import Foundation
import Testing
@testable import FitnessCore

@Suite struct VideoTests {
    let youtube = ExerciseVideo(platform: .youtube, id: "abc123XYZ_-", title: "How to Do a Leg Press", author: "NASM", durationSeconds: 48, embeddable: true, thumbnail: nil)
    let bilibili = ExerciseVideo(platform: .bilibili, id: "BV1Ep4y1o7n9", title: "腿举动作教学", author: "ALEX健身频道", durationSeconds: nil, embeddable: true, thumbnail: "https://i0.hdslb.com/bfs/archive/x.jpg")

    @Test func youtubeURLs() {
        #expect(youtube.watchURL.absoluteString == "https://www.youtube.com/watch?v=abc123XYZ_-")
        #expect(youtube.embedURL.absoluteString == "https://www.youtube-nocookie.com/embed/abc123XYZ_-?playsinline=1&rel=0")
        #expect(youtube.thumbnailURL?.absoluteString == "https://i.ytimg.com/vi/abc123XYZ_-/hqdefault.jpg")
        #expect(youtube.platform.nameZh == "YouTube")
    }

    @Test func bilibiliURLs() {
        #expect(bilibili.watchURL.absoluteString == "https://www.bilibili.com/video/BV1Ep4y1o7n9")
        #expect(bilibili.embedURL.absoluteString == "https://player.bilibili.com/player.html?bvid=BV1Ep4y1o7n9&autoplay=0&high_quality=1")
        #expect(bilibili.thumbnailURL?.absoluteString == "https://i0.hdslb.com/bfs/archive/x.jpg")
        #expect(bilibili.platform.nameZh == "B 站")
    }

    @Test func decodesWithOptionalFields() throws {
        let json = """
        {"Leg_Press": [{"platform": "youtube", "id": "abc", "title": "T", "author": "A"}]}
        """
        let videos = try JSONDecoder().decode([String: [ExerciseVideo]].self, from: Data(json.utf8))
        let video = try #require(videos["Leg_Press"]?.first)
        #expect(video.durationSeconds == nil)
        #expect(video.embeddable)
        #expect(video.thumbnail == nil)
    }

    @Test func catalogLoadsBundledVideos() throws {
        let catalog = try Catalog.load()
        for (exerciseId, videos) in catalog.videosByExercise {
            #expect(catalog.exercise(exerciseId) != nil, "videos.json 里的 \(exerciseId) 不是已知动作")
            #expect((1...2).contains(videos.count), "\(exerciseId) 应该有 1 到 2 个视频")
        }
        #expect(catalog.videos(for: "Not_An_Exercise").isEmpty)
    }

    @Test func catalogDecodeWithoutVideosStillWorks() throws {
        let catalog = Catalog(exercises: [], plan: Plan(restSeconds: 90, templates: []))
        #expect(catalog.videos(for: "Leg_Press").isEmpty)
    }
}
