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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CosmoPalette.textSecondary)
            TextField("Search title, domain, tags, notes…", text: $text)
                .textFieldStyle(.plain)
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

private struct InfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(CosmoPalette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(CosmoPalette.ink)
                        Text("精选样例与最新命中会在这里形成一个更安静、更易扫读的内容分区。")
                            .font(.subheadline)
                            .foregroundStyle(CosmoPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button {
                        onSelectBucket()
                    } label: {
                        HStack(spacing: 8) {
                            Text(isSelected ? "当前筛选" : "查看全部")
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
                    ContentUnavailableView("No clips yet", systemImage: "square.grid.2x2", description: Text("该分类当前没有匹配数据。"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    VStack(spacing: 10) {
                        ForEach(clips) { clip in
                            Button {
                                onSelectClip(clip)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(bucketAccent(bucket).opacity(0.18))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            Image(systemName: bucketIcon(bucket))
                                                .font(.title3)
                                                .foregroundStyle(bucketAccent(bucket))
                                        )

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(clip.title)
                                                .font(.headline)
                                                .foregroundStyle(CosmoPalette.ink)
                                                .lineLimit(2)
                                            Spacer(minLength: 10)
                                            Text(clip.capturedAt.formatted(date: .omitted, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(CosmoPalette.textSecondary)
                                        }

                                        Text(clip.domain)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(CosmoPalette.moss)

                                        Text(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary)
                                            .font(.subheadline)
                                            .foregroundStyle(CosmoPalette.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(CosmoPalette.textSecondary)
                    Text(clip.title)
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                        .lineLimit(2)
                }
                Spacer()
                Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(CosmoPalette.textSecondary)
            }

            Text(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary)
                .font(.subheadline)
                .foregroundStyle(CosmoPalette.textSecondary)
                .lineLimit(4)

            HStack(spacing: 8) {
                Text(clip.domain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CosmoPalette.moss)
                if !clip.category.isEmpty {
                    Text(clip.category)
                        .font(.caption)
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
                    .font(.caption)
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

public struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inspectorPane = 0

    private let filters: [PlatformFilter] = [.all] + PlatformBucket.allCases.map(PlatformFilter.bucket)
    private let shelfColumns = [GridItem(.adaptive(minimum: 310, maximum: 440), spacing: 18)]
    private let clipColumns = [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 18)]

    public init() {}

    private var groupedClips: [PlatformBucket: [ClipItem]] {
        Dictionary(grouping: model.clips, by: \.platformBucket)
    }

    private var visibleBuckets: [PlatformBucket] {
        if let bucket = model.selectedPlatform.bucket {
            return [bucket]
        }
        return PlatformBucket.allCases
    }

    public var body: some View {
        ZStack {
            SoftBackground()

            VStack(spacing: 18) {
                header
                controlsPanel
                statsRow

                HStack(alignment: .top, spacing: 18) {
                    contentCanvas
                    inspectorPaneView
                }
            }
            .padding(22)
        }
        .frame(minWidth: 1320, minHeight: 860)
        .onChange(of: model.selectedScope) { _, _ in model.refreshFilters() }
        .onChange(of: model.selectedPlatform) { _, _ in model.refreshFilters() }
        .onChange(of: model.searchText) { _, _ in model.refreshFilters() }
        .onChange(of: model.timeboxDraft) { _, _ in model.refreshFilters() }
    }

    private var header: some View {
        CardSurface {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cosmogony")
                        .font(.system(size: 38, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("把链接、灵感和稍纵即逝的信息收拢成一块更安静的思绪画布。")
                        .font(.title3)
                        .foregroundStyle(CosmoPalette.textSecondary)
                    HStack(spacing: 10) {
                        InfoBadge(title: "Bridge", value: model.bridgeStatus)
                        InfoBadge(title: "Status", value: model.statusMessage)
                    }
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 10) {
                        SettingsLink {
                            Label("Settings", systemImage: "gearshape")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))

                        Button {
                            model.captureClipboard()
                        } label: {
                            Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))

                        Button {
                            model.captureCurrentPage()
                        } label: {
                            Label("Capture Current Page", systemImage: "safari")
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.chipSelectedFill, foreground: CosmoPalette.chipSelectedText, border: CosmoPalette.chipSelectedStroke))
                    }

                    Text("灵感不再淹没在表格里，而是先以平台分区展示，再进入深度检索。")
                        .font(.subheadline)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }
            }
        }
        .frame(height: 162)
    }

    private var controlsPanel: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Picker("Scope", selection: $model.selectedScope) {
                        ForEach(ClipScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    SearchField(text: $model.searchText)

                    Text(model.searchMode.label)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CosmoPalette.gold.opacity(0.18))
                        )
                        .foregroundStyle(CosmoPalette.ink)

                    TimeboxComposer(draft: $model.timeboxDraft)

                    Button {
                        model.selectedPlatform = .all
                        model.selectedScope = .library
                        model.searchText = ""
                        model.timeboxDraft = TimeboxDraft()
                        model.refreshFilters()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surfaceSoft))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters.indices, id: \.self) { index in
                            let filter = filters[index]
                            let title: String = switch filter {
                            case .all: "全部"
                            case let .bucket(bucket): bucket.title
                            }
                            let count: String = switch filter {
                            case .all:
                                "\(model.clips.count)"
                            case let .bucket(bucket):
                                "\(model.stats.bucketCounts[bucket, default: 0])"
                            }

                            Button {
                                model.selectedPlatform = filter
                            } label: {
                                HStack(spacing: 8) {
                                    Text(title)
                                    Text(count)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(filter == model.selectedPlatform ? CosmoPalette.chipSelectedStroke : CosmoPalette.gold.opacity(0.18))
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(FilterChipStyle(selected: filter == model.selectedPlatform))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(title: "Visible", value: "\(model.clips.count)")
            StatPill(title: "Inbox", value: "\(model.stats.inboxCount)")
            StatPill(title: "Library", value: "\(model.stats.libraryCount)")
            StatPill(title: "Failed", value: "\(model.stats.failedCount)")
            StatPill(title: "Trash", value: "\(model.stats.trashCount)")
            StatPill(title: "Timebox", value: model.timeboxDraft.filter.summary)
        }
    }

    private var contentCanvas: some View {
        CardSurface {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Platform Shelves")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(CosmoPalette.ink)
                        Text("每个平台先展示 3 个精选页面，下面再承接当前筛选命中的完整结果。")
                            .font(.subheadline)
                            .foregroundStyle(CosmoPalette.textSecondary)
                    }

                    LazyVGrid(columns: shelfColumns, alignment: .leading, spacing: 18) {
                        ForEach(visibleBuckets) { bucket in
                            PlatformShelfCard(
                                bucket: bucket,
                                count: model.stats.bucketCounts[bucket, default: 0],
                                clips: Array(groupedClips[bucket, default: []].prefix(3)),
                                isSelected: model.selectedPlatform.bucket == bucket,
                                onSelectBucket: { model.selectedPlatform = .bucket(bucket) },
                                onSelectClip: { clip in model.selectedClipID = clip.id }
                            )
                        }
                    }

                    Divider()
                        .overlay(CosmoPalette.line)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("All Matching Clips")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(CosmoPalette.ink)
                        Text("当前检索、时间范围和平台筛选命中的所有内容都会以卡片形式呈现。")
                            .font(.subheadline)
                            .foregroundStyle(CosmoPalette.textSecondary)
                    }

                    if model.clips.isEmpty {
                        ContentUnavailableView("No clips found", systemImage: "tray", description: Text("调整筛选条件，或先通过剪贴板 / 当前网页捕获内容。"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        LazyVGrid(columns: clipColumns, alignment: .leading, spacing: 18) {
                            ForEach(model.clips) { clip in
                                Button {
                                    model.selectedClipID = clip.id
                                } label: {
                                    ClipCanvasCard(clip: clip, selected: model.selectedClipID == clip.id)
                                }
                                .buttonStyle(ClipCardButtonStyle(selected: model.selectedClipID == clip.id))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var inspectorPaneView: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Inspector", selection: $inspectorPane) {
                    Text("Details").tag(0)
                    Text("Rules Studio").tag(1)
                }
                .pickerStyle(.segmented)

                if inspectorPane == 0 {
                    ClipInspectorView(clip: model.selectedClip)
                } else {
                    CategoryRulesStudio()
                }
            }
        }
        .frame(minWidth: 390, idealWidth: 410, maxWidth: 420, alignment: .top)
    }
}

struct TimeboxComposer: View {
    @Binding var draft: TimeboxDraft

    var body: some View {
        HStack(spacing: 10) {
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
                DatePicker("", selection: $draft.day, displayedComponents: [.date])
                    .labelsHidden()
            case .range:
                DatePicker("Start", selection: $draft.rangeStart)
                DatePicker("End", selection: $draft.rangeEnd)
            }
        }
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

    @State private var category = ""
    @State private var tags = ""
    @State private var note = ""
    @State private var status: ClipStatus = .inbox

    var body: some View {
        Group {
            if let clip {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(clip.platformBucket.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CosmoPalette.textSecondary)
                            Text(clip.title)
                                .font(.system(size: 28, weight: .semibold, design: .serif))
                                .foregroundStyle(CosmoPalette.ink)
                            Text(clip.url)
                                .font(.footnote)
                                .foregroundStyle(CosmoPalette.textSecondary)
                                .textSelection(.enabled)
                        }

                        HStack(spacing: 10) {
                            InfoBadge(title: "Captured", value: clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            InfoBadge(title: "Source", value: clip.sourceType.rawValue)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Summary")
                                .font(.headline)
                            TextEditor(text: .constant(clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary))
                                .frame(minHeight: 130)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(CosmoPalette.surfaceSoft)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(CosmoPalette.line, lineWidth: 1)
                                        )
                                )
                                .disabled(true)
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
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                            TextField("tag1, tag2", text: $tags)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.headline)
                            TextEditor(text: $note)
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
                }
                .onAppear {
                    populate(from: clip)
                }
                .onChange(of: clip.id) { _, _ in
                    populate(from: clip)
                }
            } else {
                ContentUnavailableView("No clip selected", systemImage: "square.stack.3d.up.slash", description: Text("从左侧画布里选择一张卡片，这里会显示详情与可编辑字段。"))
            }
        }
    }

    private func populate(from clip: ClipItem) {
        category = clip.category
        tags = clip.tags.joined(separator: ", ")
        note = clip.note
        status = clip.status
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
                    .textFieldStyle(.roundedBorder)
                TextField("Aliases (comma separated)", text: $aliases)
                    .textFieldStyle(.roundedBorder)
                Button("Add Rule") {
                    model.addCategoryRule(canonical: canonical, aliases: aliases)
                    canonical = ""
                    aliases = ""
                }
                .buttonStyle(.borderedProminent)
            }

            List {
                ForEach(model.categoryRules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.canonical)
                                .font(.headline)
                            Text(rule.aliases.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(CosmoPalette.textSecondary)
                        }
                        Spacer()
                        Button("Delete", role: .destructive) {
                            model.deleteCategoryRule(rule)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
}

public struct SettingsRootView: View {
    public init() {}

    public var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }
            ProvidersSettingsView()
                .tabItem { Label("Providers", systemImage: "brain.head.profile") }
            ShortcutSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "command") }
            CaptureSettingsView()
                .tabItem { Label("Capture", systemImage: "square.and.arrow.down") }
            StorageSettingsView()
                .tabItem { Label("Storage", systemImage: "internaldrive") }
        }
        .frame(minWidth: 980, minHeight: 700)
        .padding(18)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Appearance")
                .font(.title2.weight(.semibold))
            Text("选择 Cosmogony 使用浅色、深色，或跟随系统外观。")
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
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $profile.baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Default model", text: $profile.defaultModel)
                    .textFieldStyle(.roundedBorder)
                TextField("Embedding model", text: $profile.embeddingModel)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKey)
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
                        model.testProviderConnection(profile)
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
                        .font(.headline)
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
}
