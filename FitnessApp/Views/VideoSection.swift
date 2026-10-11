import SwiftUI
import WebKit
import FitnessCore

/// 详情页的「示范视频」：1 到 2 张卡片。能嵌入的在 app 里弹出播放，不能嵌入的跳到 YouTube / B 站。
struct VideoSection: View {
    let videos: [ExerciseVideo]
    @Environment(\.openURL) private var openURL
    @State private var playing: ExerciseVideo?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("示范视频").font(.headline)
            HStack(alignment: .top, spacing: 10) {
                ForEach(videos) { video in
                    Button {
                        if video.embeddable {
                            playing = video
                        } else {
                            openURL(video.watchURL)
                        }
                    } label: {
                        VideoCard(video: video)
                    }
                    .buttonStyle(PressableStyle())
                }
                // 只有一个视频时占半宽，和两个视频时卡片大小一致
                if videos.count == 1 {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                }
            }
        }
        .sheet(item: $playing) { video in
            VideoPlayerSheet(video: video)
        }
    }
}

private struct VideoCard: View {
    let video: ExerciseVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Color(.secondarySystemBackground)
                AsyncImage(url: video.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.9), in: Circle())
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topLeading) {
                PlatformBadge(platform: video.platform).padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if let seconds = video.durationSeconds {
                    Text(Format.duration(TimeInterval(seconds)))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }

            Text(video.title)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(video.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(video.embeddable ? "在 app 里播放" : "在\(video.platform.nameZh)打开")
    }
}

private struct PlatformBadge: View {
    let platform: ExerciseVideo.Platform

    var body: some View {
        Text(platform == .youtube ? "YouTube" : "bilibili")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(platform == .youtube ? Color(red: 0.9, green: 0.13, blue: 0.09) : Color(red: 0, green: 0.63, blue: 0.84),
                        in: RoundedRectangle(cornerRadius: 4))
    }
}

/// 按下时轻微缩小，松手立刻恢复，让卡片有被按到的感觉
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 从底部弹出的播放页
private struct VideoPlayerSheet: View {
    let video: ExerciseVideo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                EmbeddedVideoPlayer(video: video)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    openURL(video.watchURL)
                } label: {
                    Label("在\(video.platform.nameZh)中打开", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()
            }
            .padding()
            .navigationTitle(video.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var meta: String {
        var parts = [video.author, video.platform.nameZh]
        if let seconds = video.durationSeconds {
            parts.append(Format.duration(TimeInterval(seconds)))
        }
        return parts.joined(separator: " · ")
    }
}

/// 用 WKWebView 嵌入 YouTube / B 站播放器。
/// YouTube 要求嵌入方带上来源（Referer），否则会报「错误 153」，所以用一段 iframe 页面加载，
/// 并把页面来源设成 https://<bundle id>，这是 YouTube 给 app 内嵌入推荐的做法。
private struct EmbeddedVideoPlayer: UIViewRepresentable {
    let video: ExerciseVideo

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedId != video.id else { return }
        context.coordinator.loadedId = video.id
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style></head>
        <body><iframe src="\(video.embedURL.absoluteString)" referrerpolicy="strict-origin-when-cross-origin"
        allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>
        """
        let origin = URL(string: "https://\(Bundle.main.bundleIdentifier ?? "com.ym820.fitness")")
        webView.loadHTMLString(html, baseURL: origin)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedId: String?
    }
}
