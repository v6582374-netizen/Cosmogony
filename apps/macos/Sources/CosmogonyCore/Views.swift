import AppKit
import SwiftUI

private enum CosmoPalette {
    static let canvasTop = adaptiveColor(light: NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1), dark: NSColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1))
    static let canvasBottom = adaptiveColor(light: NSColor(red: 0.89, green: 0.92, blue: 0.88, alpha: 1), dark: NSColor(red: 0.13, green: 0.15, blue: 0.16, alpha: 1))
    static let fog = adaptiveColor(light: NSColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1), dark: NSColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1))
    static let ink = adaptiveColor(light: NSColor(red: 0.16, green: 0.18, blue: 0.16, alpha: 1), dark: NSColor(red: 0.93, green: 0.94, blue: 0.92, alpha: 1))
    static let textSecondary = adaptiveColor(light: NSColor(red: 0.37, green: 0.40, blue: 0.37, alpha: 1), dark: NSColor(red: 0.72, green: 0.76, blue: 0.73, alpha: 1))
    static let moss = adaptiveColor(light: NSColor(red: 0.36, green: 0.47, blue: 0.40, alpha: 1), dark: NSColor(red: 0.61, green: 0.77, blue: 0.67, alpha: 1))
    static let clay = adaptiveColor(light: NSColor(red: 0.74, green: 0.59, blue: 0.49, alpha: 1), dark: NSColor(red: 0.80, green: 0.65, blue: 0.54, alpha: 1))
    static let gold = adaptiveColor(light: NSColor(red: 0.83, green: 0.72, blue: 0.48, alpha: 1), dark: NSColor(red: 0.83, green: 0.74, blue: 0.52, alpha: 1))
    static let surface = adaptiveColor(light: NSColor(white: 1.0, alpha: 0.70), dark: NSColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 0.92))
    static let surfaceStrong = adaptiveColor(light: NSColor(white: 1.0, alpha: 0.88), dark: NSColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 0.97))
    static let surfaceSoft = adaptiveColor(light: NSColor(white: 1.0, alpha: 0.62), dark: NSColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 0.94))
    static let line = adaptiveColor(light: NSColor(white: 1.0, alpha: 0.52), dark: NSColor(white: 1.0, alpha: 0.10))
    static let shadow = adaptiveColor(light: NSColor(white: 0.0, alpha: 0.08), dark: NSColor(white: 0.0, alpha: 0.35))
    static let chipSelectedText = adaptiveColor(light: .white, dark: NSColor(red: 0.93, green: 0.94, blue: 0.92, alpha: 1))
    static let chipSelectedFill = adaptiveColor(light: NSColor(red: 0.16, green: 0.18, blue: 0.16, alpha: 0.94), dark: NSColor(red: 0.28, green: 0.32, blue: 0.35, alpha: 0.98))
    static let chipSelectedStroke = adaptiveColor(light: NSColor(white: 1.0, alpha: 0.16), dark: NSColor(white: 1.0, alpha: 0.14))
}

private func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua ? dark : light
    })
}

struct CardSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CosmoPalette.fog.opacity(0.90),
                                CosmoPalette.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(CosmoPalette.line, lineWidth: 1)
                    )
                    .shadow(color: CosmoPalette.shadow, radius: 18, x: 0, y: 14)
            )
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .cosmoTextFont(title, size: 15, weight: .semibold)
                    .foregroundStyle(CosmoPalette.ink)
                if let subtitle {
                    Text(subtitle)
                        .cosmoTextFont(subtitle, size: 12)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
            }
            content
        }
    }
}

private struct SoftBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CosmoPalette.canvasTop, CosmoPalette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(CosmoPalette.clay.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 18)
                .offset(x: -280, y: -250)
            Circle()
                .fill(CosmoPalette.moss.opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 18)
                .offset(x: 330, y: -210)
            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(CosmoPalette.gold.opacity(0.08))
                .frame(width: 520, height: 260)
                .rotationEffect(.degrees(-12))
                .offset(x: 260, y: 260)
        }
        .ignoresSafeArea()
    }
}

private struct SurfaceButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = CosmoPalette.ink
    var border: Color = CosmoPalette.line

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .shadow(color: CosmoPalette.shadow.opacity(configuration.isPressed ? 0.45 : 1), radius: 10, x: 0, y: 8)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct ClipCardButtonStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected ? CosmoPalette.surfaceStrong : CosmoPalette.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(selected ? CosmoPalette.moss.opacity(0.55) : CosmoPalette.line, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .shadow(color: CosmoPalette.shadow.opacity(selected ? 1 : 0.7), radius: selected ? 16 : 10, x: 0, y: selected ? 14 : 8)
            .animation(.spring(response: 0.24, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

private struct FilterChipStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? CosmoPalette.chipSelectedText : CosmoPalette.ink)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? CosmoPalette.chipSelectedFill : CosmoPalette.surface)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(selected ? CosmoPalette.chipSelectedStroke : CosmoPalette.line, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? CosmoPalette.chipSelectedText : CosmoPalette.ink)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? CosmoPalette.chipSelectedFill : CosmoPalette.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? CosmoPalette.chipSelectedStroke : CosmoPalette.line, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CosmoPalette.textSecondary)
            TextField("Search title, domain, tags, notes…", text: $text)
                .textFieldStyle(.plain)
                .cosmoInputFont()
                .foregroundStyle(CosmoPalette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CosmoPalette.surfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                )
        )
    }
}

private struct TopBarMenu<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder var content: Content

    init(title: String, value: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .cosmoTextFont(title.uppercased(), size: 10, weight: .semibold, design: .rounded)
                        .foregroundStyle(CosmoPalette.textSecondary)
                    Text(value)
                        .cosmoTextFont(value, size: 14, weight: .medium)
                        .foregroundStyle(CosmoPalette.ink)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CosmoPalette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CosmoPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(CosmoPalette.line, lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct FlowTagList: View {
    let tags: [String]
    @Binding var selectedTag: String

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    selectedTag = tag
                } label: {
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(FilterChipStyle(selected: selectedTag.caseInsensitiveCompare(tag) == .orderedSame))
            }
        }
    }
}

private struct InfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .cosmoTextFont(title.uppercased(), size: 10, weight: .semibold, design: .rounded)
                .foregroundStyle(CosmoPalette.textSecondary)
            Text(value)
                .cosmoTextFont(value, size: 13, weight: .medium, design: .rounded)
                .foregroundStyle(CosmoPalette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(CosmoPalette.surfaceSoft)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                )
        )
    }
}

private struct ClipSiteIconBadge: View {
    let clip: ClipItem
    let accent: Color
    let fallbackIcon: String

    @StateObject private var model: SiteIconViewModel

    init(clip: ClipItem, accent: Color, fallbackIcon: String) {
        self.clip = clip
        self.accent = accent
        self.fallbackIcon = fallbackIcon
        _model = StateObject(wrappedValue: SiteIconViewModel(urlString: clip.url))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(0.16))
            .frame(width: 50, height: 50)
            .overlay {
                Group {
                    if let image = model.image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.title3)
                            .foregroundStyle(accent)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .task(id: clip.url) {
                await model.loadIfNeeded()
            }
    }
}

private struct PlatformShelfCard: View {
    let bucket: PlatformBucket
    let count: Int
    let clips: [ClipItem]
    let isSelected: Bool
    let onSelectBucket: () -> Void
    let onSelectClip: (ClipItem) -> Void

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bucket.title)
                            .cosmoTextFont(bucket.title, size: 22, weight: .semibold, design: .serif)
                            .foregroundStyle(CosmoPalette.ink)
                        Text("精选样例与最新命中会在这里形成一个更安静、更易扫读的内容分区。")
                            .cosmoTextFont("精选样例与最新命中会在这里形成一个更安静、更易扫读的内容分区。", size: 15)
                            .foregroundStyle(CosmoPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button {
                        onSelectBucket()
                    } label: {
                        HStack(spacing: 8) {
                            Text(isSelected ? "当前筛选" : "查看全部")
                                .cosmoTextFont(isSelected ? "当前筛选" : "查看全部", size: 14, weight: .medium)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(FilterChipStyle(selected: isSelected))
                }

                HStack(spacing: 10) {
                    InfoBadge(title: "Count", value: "\(count)")
                    InfoBadge(title: "Scope", value: clips.first?.status.rawValue.capitalized ?? "Library")
                    InfoBadge(title: "Mood", value: bucketShelfMood(bucket))
                }

                if clips.isEmpty {
                    ContentUnavailableView("No clips yet", systemImage: "square.grid.2x2", description: Text("该分类当前没有匹配数据。").cosmoTextFont("该分类当前没有匹配数据。", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    VStack(spacing: 10) {
                        ForEach(clips) { clip in
                            Button {
                                onSelectClip(clip)
                            } label: {
                                ClipStripRow(clip: clip, selected: false)
                            }
                            .buttonStyle(ClipCardButtonStyle(selected: false))
                        }
                    }
                }
            }
        }
    }

    private func bucketAccent(_ bucket: PlatformBucket) -> Color {
        switch bucket {
        case .xPosts:
            return Color(red: 0.28, green: 0.36, blue: 0.49)
        case .rednote:
            return Color(red: 0.80, green: 0.39, blue: 0.40)
        case .wechat:
            return Color(red: 0.31, green: 0.56, blue: 0.34)
        case .douyin:
            return Color(red: 0.28, green: 0.54, blue: 0.58)
        case .youtube:
            return Color(red: 0.82, green: 0.24, blue: 0.22)
        case .otherWeb:
            return CosmoPalette.clay
        }
    }

    private func bucketIcon(_ bucket: PlatformBucket) -> String {
        switch bucket {
        case .xPosts:
            return "text.bubble"
        case .rednote:
            return "heart.text.square"
        case .wechat:
            return "bubble.left.and.bubble.right"
        case .douyin:
            return "play.tv"
        case .youtube:
            return "play.rectangle"
        case .otherWeb:
            return "globe"
        }
    }

    private func bucketShelfMood(_ bucket: PlatformBucket) -> String {
        switch bucket {
        case .xPosts:
            return "Fast signals"
        case .rednote:
            return "Visual notes"
        case .wechat:
            return "Long reads"
        case .douyin:
            return "Short bursts"
        case .youtube:
            return "Deep watch"
        case .otherWeb:
            return "Open web"
        }
    }
}

private struct ClipCanvasCard: View {
    let clip: ClipItem
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(clip.platformBucket.title)
                        .cosmoTextFont(clip.platformBucket.title, size: 11, weight: .semibold, design: .rounded)
                        .foregroundStyle(CosmoPalette.textSecondary)
                    Text(clip.title)
                        .cosmoTextFont(clip.title, size: 19, weight: .semibold, design: .serif)
                        .foregroundStyle(CosmoPalette.ink)
                        .lineLimit(2)
                }
                Spacer()
                Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(CosmoPalette.textSecondary)
            }

            Text(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary)
                .cosmoTextFont(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary, size: 15)
                .foregroundStyle(CosmoPalette.textSecondary)
                .lineLimit(4)

            HStack(spacing: 8) {
                Text(clip.domain)
                    .cosmoTextFont(clip.domain, size: 12, weight: .medium)
                    .foregroundStyle(CosmoPalette.moss)
                if !clip.category.isEmpty {
                    Text(clip.category)
                        .cosmoTextFont(clip.category, size: 12)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CosmoPalette.gold.opacity(0.18))
                        )
                }
            }

            if !clip.tags.isEmpty {
                Text(clip.tags.prefix(3).joined(separator: " · "))
                    .cosmoTextFont(clip.tags.prefix(3).joined(separator: " · "), size: 12)
                    .foregroundStyle(CosmoPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .padding(18)
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CosmoPalette.moss)
                    .padding(14)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ClipStripRow: View {
    let clip: ClipItem
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ClipSiteIconBadge(clip: clip, accent: accent, fallbackIcon: icon)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(clip.title)
                        .cosmoTextFont(clip.title, size: 17, weight: .semibold)
                        .foregroundStyle(CosmoPalette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }

                HStack(spacing: 8) {
                    Text(clip.platformBucket.title)
                        .cosmoTextFont(clip.platformBucket.title, size: 12, weight: .semibold)
                        .foregroundStyle(accent)
                    Text(clip.domain)
                        .cosmoTextFont(clip.domain, size: 12)
                        .foregroundStyle(CosmoPalette.textSecondary)
                    if !clip.spaceName.isEmpty {
                        Text("• \(clip.spaceName)")
                            .cosmoTextFont("• \(clip.spaceName)", size: 12, weight: .medium)
                            .foregroundStyle(CosmoPalette.moss)
                    }
                }

                Text(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary)
                    .cosmoTextFont(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary, size: 15)
                    .foregroundStyle(CosmoPalette.textSecondary)
                    .lineLimit(2)
            }

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CosmoPalette.moss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var accent: Color {
        switch clip.platformBucket {
        case .xPosts:
            return Color(red: 0.28, green: 0.36, blue: 0.49)
        case .rednote:
            return Color(red: 0.80, green: 0.39, blue: 0.40)
        case .wechat:
            return Color(red: 0.31, green: 0.56, blue: 0.34)
        case .douyin:
            return Color(red: 0.28, green: 0.54, blue: 0.58)
        case .youtube:
            return Color(red: 0.82, green: 0.24, blue: 0.22)
        case .otherWeb:
            return CosmoPalette.clay
        }
    }

    private var icon: String {
        switch clip.platformBucket {
        case .xPosts:
            return "text.bubble"
        case .rednote:
            return "heart.text.square"
        case .wechat:
            return "bubble.left.and.bubble.right"
        case .douyin:
            return "play.tv"
        case .youtube:
            return "play.rectangle"
        case .otherWeb:
            return "globe"
        }
    }
}

private struct SettingsSidebarButtonStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? CosmoPalette.chipSelectedText : CosmoPalette.ink)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? CosmoPalette.chipSelectedFill : CosmoPalette.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? CosmoPalette.chipSelectedStroke : CosmoPalette.line, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

public struct RootView: View {
    @EnvironmentObject private var model: AppModel

    private let filters: [PlatformFilter] = [.all] + PlatformBucket.allCases.map(PlatformFilter.bucket)

    public init() {}

    private var canvasHeadline: String {
        switch model.timeboxDraft.filter {
        case let .day(day) where Calendar.current.isDateInToday(day):
            return "Today's Clips"
        default:
            return "Matching Clips"
        }
    }

    private var canvasSubheadline: String {
        switch model.timeboxDraft.filter {
        case let .day(day) where Calendar.current.isDateInToday(day):
            return "主界面默认展示今天收进来的全部剪藏，便于先完成当天的信息归拢。"
        default:
            return "当前全局视图命中的内容会在这里展开，顶部菜单负责主筛选，侧边补充辅助动作。"
        }
    }

    public var body: some View {
        ZStack {
            SoftBackground()

            ScrollView {
                VStack(spacing: 18) {
                    topBar

                    HStack(alignment: .top, spacing: 18) {
                        sidebarPaneView
                        contentCanvas
                    }
                }
                .padding(22)
            }

            if let activeOverlay = model.activeOverlay {
                overlayBackdrop(activeOverlay)
            }
        }
        .frame(minWidth: 1060, minHeight: 820)
        .alert(
            "Link already exists",
            isPresented: Binding(
                get: { model.duplicateCapturePrompt != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelDuplicateCapture()
                    }
                }
            )
        ) {
            Button("Cancel", role: .cancel) {
                model.cancelDuplicateCapture()
            }
            Button("Add Anyway") {
                model.confirmDuplicateCapture()
            }
        } message: {
            let existingTitle = model.duplicateCapturePrompt?.existingClipTitle ?? ""
            Text("发现相同链接已存在：\(existingTitle)\n\n你可以取消本次添加，或仍然继续保存。")
                .cosmoTextFont("发现相同链接已存在：\(existingTitle)\n\n你可以取消本次添加，或仍然继续保存。", size: 14)
        }
        .alert("Discard unsaved changes?", isPresented: $model.showUnsavedClipClosePrompt) {
            Button("Continue Editing", role: .cancel) {}
            Button("Discard Changes", role: .destructive) {
                model.discardUnsavedClipChangesAndClose()
            }
        } message: {
            Text("当前详情卡片还有未保存的修改，关闭后这些改动会丢失。")
                .cosmoTextFont("当前详情卡片还有未保存的修改，关闭后这些改动会丢失。", size: 14)
        }
        .onChange(of: model.selectedScope) { _, _ in model.refreshFilters() }
        .onChange(of: model.selectedPlatform) { _, _ in model.refreshFilters() }
        .onChange(of: model.selectedSpaceID) { _, _ in model.refreshFilters() }
        .onChange(of: model.searchText) { _, _ in model.refreshFilters() }
        .onChange(of: model.timeboxDraft) { _, _ in model.refreshFilters() }
    }

    private var topBar: some View {
        CardSurface {
            HStack(alignment: .center, spacing: 12) {
                SearchField(text: $model.searchText)
                    .frame(maxWidth: .infinity)

                Button {
                    model.clearSearch()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))

                Button {
                    model.resetPrimaryFilters()
                } label: {
                    Label("Reset To Today", systemImage: "arrow.counterclockwise")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.chipSelectedFill, foreground: CosmoPalette.chipSelectedText, border: CosmoPalette.chipSelectedStroke))

                TopBarMenu(title: "Settings", value: model.selectedSettingsTab.title) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            model.openSettingsTab(tab)
                        } label: {
                            HStack {
                                Text(tab.title)
                                if model.selectedSettingsTab == tab {
                                    Spacer(minLength: 10)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                TopBarMenu(title: "Platforms", value: model.selectedPlatform.label) {
                    ForEach(filters.indices, id: \.self) { index in
                        let filter = filters[index]
                        Button {
                            model.focusPlatform(filter)
                        } label: {
                            HStack {
                                Text(filter.label)
                                    .cosmoTextFont(filter.label, size: 14, weight: .medium)
                                if filter == model.selectedPlatform {
                                    Spacer(minLength: 10)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                TopBarMenu(title: "View Scope", value: model.selectedScope.title) {
                    ForEach(ClipScope.allCases) { scope in
                        Button {
                            model.selectedScope = scope
                        } label: {
                            HStack {
                                Text(scope.title)
                                    .cosmoTextFont(scope.title, size: 14, weight: .medium)
                                if model.selectedScope == scope {
                                    Spacer(minLength: 10)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                TopBarMenu(title: "Spaces", value: selectedSpaceLabel) {
                    Button {
                        model.focusSpace(nil)
                    } label: {
                        HStack {
                            Text("All Spaces")
                            if model.selectedSpaceID == nil {
                                Spacer(minLength: 10)
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if model.spaces.isEmpty {
                        Text("No spaces yet")
                    } else {
                        Divider()
                        ForEach(model.spaces) { space in
                            Button {
                                model.focusSpace(space.id)
                                if let firstTag = space.tags.first {
                                    model.captureTagDraft = firstTag
                                }
                            } label: {
                                HStack {
                                    Text(space.name)
                                        .cosmoTextFont(space.name, size: 14, weight: .medium)
                                    if model.selectedSpaceID == space.id {
                                        Spacer(minLength: 10)
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minHeight: 94)
    }

    private var selectedSpaceLabel: String {
        guard
            let selectedSpaceID = model.selectedSpaceID,
            let space = model.spaces.first(where: { $0.id == selectedSpaceID })
        else {
            return "All Spaces"
        }

        return space.name
    }

    private var sidebarPaneView: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Utility")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("把捕获动作、时间范围和辅助状态收在侧边，搜索与筛选主控件全部回到顶部。")
                        .cosmoTextFont("把捕获动作、时间范围和辅助状态收在侧边，搜索与筛选主控件全部回到顶部。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }

                SidebarSection(title: "Visible", subtitle: "这些统计继续固定显示在侧边，方便快速感知当前范围。") {
                    VStack(spacing: 10) {
                        StatPill(title: "Visible", value: "\(model.clips.count)")
                        StatPill(title: "Inbox", value: "\(model.stats.inboxCount)")
                        StatPill(title: "Library", value: "\(model.stats.libraryCount)")
                        StatPill(title: "Failed", value: "\(model.stats.failedCount)")
                        StatPill(title: "Trash", value: "\(model.stats.trashCount)")
                    }
                }

                Divider()
                    .overlay(CosmoPalette.line)

                SidebarSection(title: "Capture Tag", subtitle: "剪藏前先选择 tag，系统会自动分配到匹配该 tag 的 space。") {
                    TextField("例如 design / research / inspiration", text: $model.captureTagDraft)
                        .cosmoInputFont()
                        .textFieldStyle(.roundedBorder)
                    if !model.spaces.isEmpty {
                        FlowTagList(tags: suggestedTags, selectedTag: $model.captureTagDraft)
                    }
                    Button {
                        model.captureTagDraft = ""
                    } label: {
                        Label("Clear Capture Tag", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                }

                Divider()
                    .overlay(CosmoPalette.line)

                SidebarSection(title: "Quick Actions", subtitle: "保留高频操作入口，方便在同一侧完成捕获与整理。") {
                    VStack(spacing: 10) {
                        Button {
                            model.captureCurrentPage()
                        } label: {
                            Label("Capture Current Page", systemImage: "safari")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.chipSelectedFill, foreground: CosmoPalette.chipSelectedText, border: CosmoPalette.chipSelectedStroke))

                        Button {
                            model.captureClipboard()
                        } label: {
                            Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))

                        Button {
                            model.openSelectedClipURL()
                        } label: {
                            Label("Open Selected URL", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                        .disabled(model.selectedClip?.url.hasPrefix("clipboard://") ?? true)

                        Button {
                            model.copySelectedClipURL()
                        } label: {
                            Label("Copy Selected URL", systemImage: "link")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                        .disabled(model.selectedClip == nil)

                        HStack(spacing: 10) {
                            Button("Inbox") {
                                model.updateSelectedClipStatus(.inbox)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                            .disabled(model.selectedClip == nil)

                            Button("Library") {
                                model.updateSelectedClipStatus(.library)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                            .disabled(model.selectedClip == nil)

                            Button("Trash") {
                                model.updateSelectedClipStatus(.trashed)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                            .disabled(model.selectedClip == nil)
                        }
                    }
                }

                Divider()
                    .overlay(CosmoPalette.line)

                SidebarSection(title: "Timebox", subtitle: "整个 app 只保留一个外层滚动条，时间范围也放回侧边栏。") {
                    TimeboxComposer(draft: $model.timeboxDraft)
                }
            }
        }
        .frame(minWidth: 248, idealWidth: 260, maxWidth: 278, alignment: .topLeading)
    }

    private var contentCanvas: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(canvasHeadline)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text(canvasSubheadline)
                        .cosmoTextFont(canvasSubheadline, size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                    if let selectedSpaceID = model.selectedSpaceID, let space = model.spaces.first(where: { $0.id == selectedSpaceID }) {
                        Text("Current space filter: \(space.name)")
                            .cosmoTextFont("Current space filter: \(space.name)", size: 12, weight: .medium)
                            .foregroundStyle(CosmoPalette.moss)
                    }
                }

                if model.clips.isEmpty {
                    ContentUnavailableView("No clips found", systemImage: "tray", description: Text("调整筛选条件，或先通过剪贴板 / 当前网页捕获内容。").cosmoTextFont("调整筛选条件，或先通过剪贴板 / 当前网页捕获内容。", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.clips) { clip in
                            Button {
                                model.presentClipDetail(clip)
                            } label: {
                                ClipStripRow(clip: clip, selected: model.selectedClipID == clip.id)
                            }
                            .buttonStyle(ClipCardButtonStyle(selected: model.selectedClipID == clip.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    model.deleteOrTrash(clip)
                                } label: {
                                    Label(clip.status == .trashed ? "Delete Forever" : "Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    model.togglePin(for: clip)
                                } label: {
                                    Label(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                Button(clip.isPinned ? "取消置顶" : "置顶") {
                                    model.togglePin(for: clip)
                                }
                                Button(clip.status == .trashed ? "彻底删除" : "删除", role: .destructive) {
                                    model.deleteOrTrash(clip)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var suggestedTags: [String] {
        Array(Set(model.spaces.flatMap(\.tags))).sorted()
    }

    @ViewBuilder
    private func overlayBackdrop(_ overlay: AppOverlay) -> some View {
        GeometryReader { proxy in
            let availableWidth = max(320, proxy.size.width - 48)
            let clipDetailHeight = max(360, min(proxy.size.height - 64, 680))
            let settingsHeight = max(560, min(proxy.size.height - 64, 760))

            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.requestCloseOverlay()
                    }

                switch overlay {
                case .settings:
                    overlayCard(width: min(960, availableWidth), maxHeight: settingsHeight) {
                        SettingsOverlayCard()
                            .environmentObject(model)
                    }
                case .clipDetail:
                    overlayCard(width: min(640, availableWidth), maxHeight: clipDetailHeight) {
                        ClipDetailOverlayCard()
                            .environmentObject(model)
                    }
                }
            }
        }
    }

    private func overlayCard<Content: View>(width: CGFloat, maxHeight: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        CardSurface {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: maxHeight, alignment: .topLeading)
        .shadow(color: CosmoPalette.shadow, radius: 28, x: 0, y: 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct TimeboxComposer: View {
    @Binding var draft: TimeboxDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Timebox", selection: $draft.mode) {
                Text("All").tag(TimeboxMode.all)
                Text("Past N Hours").tag(TimeboxMode.trailingHours)
                Text("Specific Day").tag(TimeboxMode.day)
                Text("Range").tag(TimeboxMode.range)
            }
            .pickerStyle(.menu)

            switch draft.mode {
            case .all:
                Text("All time")
                    .foregroundStyle(CosmoPalette.textSecondary)
            case .trailingHours:
                Stepper("\(draft.trailingHours)h", value: $draft.trailingHours, in: 1...720)
            case .day:
                DatePicker("Day", selection: $draft.day, displayedComponents: [.date])
            case .range:
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Start", selection: $draft.rangeStart)
                    DatePicker("End", selection: $draft.rangeEnd)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CosmoPalette.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                )
        )
    }
}

struct ClipInspectorView: View {
    @EnvironmentObject private var model: AppModel

    let clip: ClipItem?

    @State private var aiSummary = ""
    @State private var category = ""
    @State private var tags = ""
    @State private var note = ""
    @State private var status: ClipStatus = .inbox

    var body: some View {
        Group {
            if let clip {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(clip.platformBucket.title)
                            .cosmoTextFont(clip.platformBucket.title, size: 12, weight: .semibold)
                            .foregroundStyle(CosmoPalette.textSecondary)
                        Text(clip.title)
                            .cosmoTextFont(clip.title, size: 28, weight: .semibold, design: .serif)
                            .foregroundStyle(CosmoPalette.ink)
                        Text(clip.url)
                            .cosmoTextFont(clip.url, size: 13)
                            .foregroundStyle(CosmoPalette.textSecondary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 10) {
                        InfoBadge(title: "Captured", value: clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        InfoBadge(title: "Source", value: clip.sourceType.rawValue)
                        if !clip.spaceName.isEmpty {
                            InfoBadge(title: "Space", value: clip.spaceName)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Summary")
                                .font(.headline)
                            Spacer()
                            if model.summaryGenerationRunning.contains(clip.id) {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button("Refresh AI Summary") {
                                    model.refreshAISummary(for: clip.id)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        ZStack(alignment: .topLeading) {
                            if aiSummary.isEmpty {
                                Text("正在准备中文摘要…")
                                    .cosmoTextFont("正在准备中文摘要…", size: 14)
                                    .foregroundStyle(CosmoPalette.textSecondary)
                                    .padding(.top, 16)
                                    .padding(.leading, 14)
                            }
                            TextEditor(text: $aiSummary)
                                .cosmoInputFont(size: 14)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 130)
                                .padding(8)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CosmoPalette.surfaceSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                                )
                        )
                    }

                    HStack(spacing: 10) {
                        Button {
                            model.openSelectedClipURL()
                        } label: {
                            Label("Open URL", systemImage: "arrow.up.right.square")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                        .disabled(clip.url.hasPrefix("clipboard://"))

                        Button {
                            model.copySelectedClipURL()
                        } label: {
                            Label("Copy URL", systemImage: "link")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                        TextField("Category", text: $category)
                            .cosmoInputFont()
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        TextField("tag1, tag2", text: $tags)
                            .cosmoInputFont()
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.headline)
                        TextEditor(text: $note)
                            .cosmoInputFont()
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(CosmoPalette.surfaceSoft)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(CosmoPalette.line, lineWidth: 1)
                                    )
                            )
                    }

                    Picker("Status", selection: $status) {
                        Text("Inbox").tag(ClipStatus.inbox)
                        Text("Library").tag(ClipStatus.library)
                        Text("Failed").tag(ClipStatus.failed)
                        Text("Trash").tag(ClipStatus.trashed)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        model.saveClipEdits(
                            id: clip.id,
                            aiSummary: aiSummary,
                            category: category,
                            tagsText: tags,
                            note: note,
                            status: status
                        )
                    } label: {
                        Label("Save Clip", systemImage: "square.and.arrow.down")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.chipSelectedFill, foreground: CosmoPalette.chipSelectedText, border: CosmoPalette.chipSelectedStroke))
                }
                .onAppear {
                    populate(from: clip)
                    updateDirtyState(for: clip)
                }
                .onChange(of: clip.id) { _, _ in
                    populate(from: clip)
                    updateDirtyState(for: clip)
                }
                .onChange(of: clip.aiSummary) { _, value in
                    guard !model.clipEditorHasUnsavedChanges else { return }
                    aiSummary = value
                    updateDirtyState(for: clip)
                }
                .onChange(of: aiSummary) { _, _ in
                    updateDirtyState(for: clip)
                }
                .onChange(of: category) { _, _ in
                    updateDirtyState(for: clip)
                }
                .onChange(of: tags) { _, _ in
                    updateDirtyState(for: clip)
                }
                .onChange(of: note) { _, _ in
                    updateDirtyState(for: clip)
                }
                .onChange(of: status) { _, _ in
                    updateDirtyState(for: clip)
                }
            } else {
                ContentUnavailableView("No clip selected", systemImage: "square.stack.3d.up.slash", description: Text("从左侧画布里选择一张卡片，这里会显示详情与可编辑字段。").cosmoTextFont("从左侧画布里选择一张卡片，这里会显示详情与可编辑字段。", size: 14))
            }
        }
    }

    private func populate(from clip: ClipItem) {
        aiSummary = clip.aiSummary
        category = clip.category
        tags = clip.tags.joined(separator: ", ")
        note = clip.note
        status = clip.status
    }

    private func updateDirtyState(for clip: ClipItem) {
        model.syncClipEditorDirtyState(
            clipID: clip.id,
            aiSummary: aiSummary,
            category: category,
            tagsText: tags,
            note: note,
            status: status
        )
    }
}

private struct ClipDetailOverlayCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clip Detail")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("点击条目后这里会弹出详情卡片，摘要会自动尝试用 AI 生成中文版本。")
                        .cosmoTextFont("点击条目后这里会弹出详情卡片，摘要会自动尝试用 AI 生成中文版本。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
                Spacer()
                Button {
                    model.requestCloseOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .padding(10)
                        .contentShape(Circle())
                }
                .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
            }

            Divider()
                .overlay(CosmoPalette.line)

            ScrollView {
                ClipInspectorView(clip: model.selectedClip)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CategoryRulesStudio: View {
    @EnvironmentObject private var model: AppModel
    @State private var canonical = ""
    @State private var aliases = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category Rules")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                    Text("把人工维护的别名规则作为 AI 分类前的一层稳定语义约束。")
                        .cosmoTextFont("把人工维护的别名规则作为 AI 分类前的一层稳定语义约束。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
                Spacer()
                Button("Import Legacy JSON") {
                    model.importLegacyExport()
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Canonical category", text: $canonical)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                TextField("Aliases (comma separated)", text: $aliases)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                Button("Add Rule") {
                    model.addCategoryRule(canonical: canonical, aliases: aliases)
                    canonical = ""
                    aliases = ""
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(spacing: 10) {
                ForEach(model.categoryRules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.canonical)
                                .cosmoTextFont(rule.canonical, size: 17, weight: .semibold)
                            Text(rule.aliases.joined(separator: ", "))
                                .cosmoTextFont(rule.aliases.joined(separator: ", "), size: 12)
                                .foregroundStyle(CosmoPalette.textSecondary)
                        }
                        Spacer()
                        Button("Delete", role: .destructive) {
                            model.deleteCategoryRule(rule)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CosmoPalette.surfaceSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(CosmoPalette.line, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

public struct SettingsRootView: View {
    @EnvironmentObject private var model: AppModel

    public init() {}

    public var body: some View {
        settingsLayout
    }

    @ViewBuilder
    fileprivate var settingsLayout: some View {
        HStack(alignment: .top, spacing: 18) {
            CardSurface {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("这里使用自定义侧边导航，保证外部按钮点击后一定能切到对应页面。")
                        .cosmoTextFont("这里使用自定义侧边导航，保证外部按钮点击后一定能切到对应页面。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)

                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            model.selectedSettingsTab = tab
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SettingsSidebarButtonStyle(selected: model.selectedSettingsTab == tab))
                    }
                }
            }
            .frame(width: 250, alignment: .topLeading)

            CardSurface {
                settingsContent
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 860, minHeight: 700)
        .padding(18)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch model.selectedSettingsTab {
        case .appearance:
            AppearanceSettingsView()
        case .providers:
            ProvidersSettingsView()
        case .shortcuts:
            ShortcutSettingsView()
        case .capture:
            CaptureSettingsView()
        case .storage:
            StorageSettingsView()
        }
    }
}

private struct SettingsOverlayCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("这些入口现在直接在主窗口内切换，不再依赖系统设置窗口。")
                        .cosmoTextFont("这些入口现在直接在主窗口内切换，不再依赖系统设置窗口。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
                Spacer()
                Button {
                    model.closeOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .padding(10)
                        .contentShape(Circle())
                }
                .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
            }

            Divider()
                .overlay(CosmoPalette.line)

            ScrollView([.vertical, .horizontal]) {
                SettingsRootView()
                    .environmentObject(model)
                    .padding(0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Appearance")
                .font(.title2.weight(.semibold))
            Text("选择 Cosmogony 使用浅色、深色，或跟随系统外观。")
                .cosmoTextFont("选择 Cosmogony 使用浅色、深色，或跟随系统外观。", size: 14)
                .foregroundStyle(CosmoPalette.textSecondary)

            CardSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Appearance", selection: Binding(
                        get: { model.settings.appearance },
                        set: { model.updateAppearance($0) }
                    )) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(AppAppearance.allCases) { appearance in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: model.settings.appearance == appearance ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.settings.appearance == appearance ? CosmoPalette.moss : CosmoPalette.textSecondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appearance.title)
                                    .font(.headline)
                                    .foregroundStyle(CosmoPalette.ink)
                                Text(appearance.description)
                                    .cosmoTextFont(appearance.description, size: 14)
                                    .foregroundStyle(CosmoPalette.textSecondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

struct ProvidersSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Profiles")
                            .font(.title2.weight(.semibold))
                        Text("API keys are stored in Keychain; non-sensitive profile settings stay local.")
                            .foregroundStyle(CosmoPalette.textSecondary)
                    }
                    Spacer()
                    Button("Add Provider") {
                        model.addProviderProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Picker("Default reasoning profile", selection: Binding(
                    get: { model.settings.defaultReasoningProfileID ?? model.providerProfiles.first?.id ?? "" },
                    set: { model.updateDefaultReasoningProfile($0) }
                )) {
                    ForEach(model.providerProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }

                Picker("Default embedding profile", selection: Binding(
                    get: { model.settings.defaultEmbeddingProfileID ?? "" },
                    set: { model.updateDefaultEmbeddingProfile($0.isEmpty ? nil : $0) }
                )) {
                    Text("Local lexical fallback").tag("")
                    ForEach(model.providerProfiles.filter(\.supportsEmbeddings)) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }

                ForEach(model.providerProfiles) { profile in
                    ProviderEditorCard(profile: profile)
                }
            }
        }
    }
}

struct ProviderEditorCard: View {
    @EnvironmentObject private var model: AppModel
    @State var profile: ProviderProfile
    @State private var apiKey = ""

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(model.providerReadiness(for: profile))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(CosmoPalette.surfaceSoft))
                        .foregroundStyle(CosmoPalette.ink)
                    Text(profile.displayName)
                        .font(.headline)
                    Spacer()
                    Toggle("Enabled", isOn: $profile.enabled)
                        .toggleStyle(.switch)
                        .onChange(of: profile.enabled) { _, _ in save() }
                }

                Picker("Provider", selection: $profile.kind) {
                    ForEach(ProviderKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .onChange(of: profile.kind) { _, kind in
                    if profile.baseURL.isEmpty {
                        profile.baseURL = kind.suggestedBaseURL
                    }
                }

                TextField("Display name", text: $profile.displayName)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $profile.baseURL)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                TextField("Default model", text: $profile.defaultModel)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                TextField("Embedding model", text: $profile.embeddingModel)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKey)
                    .cosmoInputFont()
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Profile") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Save API Key") {
                        model.updateProviderSecret(apiKey, for: profile)
                    }
                    .buttonStyle(.bordered)

                    Button(model.providerProbeRunning.contains(profile.id) ? "Testing…" : "Test Connection") {
                        save()
                        model.testProviderConnection(profile, apiKeyOverride: apiKey)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.providerProbeRunning.contains(profile.id))

                    Button("Delete", role: .destructive) {
                        model.deleteProviderProfile(profile)
                    }
                }

                if let message = model.providerProbeMessages[profile.id] {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message == "Testing..." ? .secondary : .primary)
                }
            }
            .onAppear {
                apiKey = model.providerSecrets[profile.id] ?? ""
            }
        }
    }

    private func save() {
        model.saveProviderProfile(profile)
    }
}

struct ShortcutSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var localShortcuts = ShortcutSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Global Shortcuts")
                .font(.title2.weight(.semibold))
            Text("Record the shortcut you want, then save. Conflicts are blocked before Carbon rebinds the keys.")
                .foregroundStyle(CosmoPalette.textSecondary)

            if let conflict = model.shortcutConflict {
                Text(conflict)
                    .cosmoTextFont(conflict, size: 14)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12)))
            }

            ShortcutRecorder(label: ShortcutAction.captureCurrentPage.title, combination: $localShortcuts.captureCurrentPage)
            ShortcutRecorder(label: ShortcutAction.captureClipboard.title, combination: $localShortcuts.captureClipboard)

            Button("Save Shortcuts") {
                model.updateShortcuts(localShortcuts)
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            localShortcuts = model.settings.shortcuts
        }
    }
}

struct ShortcutRecorder: View {
    let label: String
    @Binding var combination: KeyCombination

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        CardSurface {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .cosmoTextFont(label, size: 17, weight: .semibold)
                    Text(combination.displayString)
                        .font(.title3.monospacedDigit())
                }
                Spacer()
                Button(recording ? "Recording…" : "Record") {
                    toggleRecording()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func toggleRecording() {
        if recording {
            stopRecording()
            return
        }
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !modifiers.isEmpty else { return nil }
            combination = KeyCombination(
                keyCode: UInt32(event.keyCode),
                command: modifiers.contains(.command),
                shift: modifiers.contains(.shift),
                option: modifiers.contains(.option),
                control: modifiers.contains(.control)
            )
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        recording = false
    }
}

struct CaptureSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var capture = CaptureSettings()

    var body: some View {
        Form {
            Toggle("Prefer bridge rich capture when extension sends DOM text", isOn: $capture.preferBridgeRichCapture)
            Toggle("Enrich public pages by fetching HTML in the desktop app", isOn: $capture.enrichPublicPages)

            Stepper("Max stored characters: \(capture.maxStoredCharacters)", value: $capture.maxStoredCharacters, in: 2_000...80_000, step: 1_000)

            Button("Save Capture Settings") {
                model.updateCaptureSettings(capture)
            }
            .buttonStyle(.borderedProminent)
        }
        .formStyle(.grouped)
        .onAppear {
            capture = model.settings.capture
        }
    }
}

struct StorageSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Storage & Migration")
                .font(.title2.weight(.semibold))

            CardSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.settings.storage.openAtLogin },
                        set: { model.updateOpenAtLogin($0) }
                    ))
                    Text(model.database.databaseURL.path)
                        .font(.footnote.monospaced())
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
            }
            .frame(height: 120)

            HStack(spacing: 12) {
                Button("Import Legacy MuseMark JSON") {
                    model.importLegacyExport()
                }
                .buttonStyle(.borderedProminent)

                Button("Export Current Library") {
                    model.exportCurrentLibrary()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }
}

struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(CosmoPalette.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(CosmoPalette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CosmoPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                )
        )
    }
}

private extension PlatformFilter {
    var bucket: PlatformBucket? {
        if case let .bucket(bucket) = self {
            return bucket
        }
        return nil
    }

    var label: String {
        switch self {
        case .all:
            "全部平台"
        case let .bucket(bucket):
            bucket.title
        }
    }
}
