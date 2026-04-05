import AppKit
import Combine
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                Rectangle()
                    .fill(CosmoTheme.panelGradient(tier: .workspace, tone: .neutral))
                    .overlay(
                        Rectangle()
                            .strokeBorder(CosmoTheme.divider, lineWidth: 1)
                    )
                    .shadow(color: CosmoTheme.panelShadow.opacity(0.72), radius: 14, x: 0, y: 8)
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
                Rectangle()
                    .fill(fill)
                    .overlay(
                        Rectangle()
                            .strokeBorder(border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .shadow(color: CosmoTheme.panelShadow.opacity(configuration.isPressed ? 0.35 : 0.68), radius: 8, x: 0, y: 4)
            .animation(.spring(response: 0.20, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct StatusToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CosmoTheme.industrialGold)
            Text(message)
                .cosmoUIFont(message, size: 13, weight: .bold)
                .foregroundStyle(CosmoTheme.bone)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: CosmoRadius.lg, style: .continuous)
                .fill(CosmoTheme.panelGradient(tier: .chrome, tone: .neutral))
                .overlay(
                    RoundedRectangle(cornerRadius: CosmoRadius.lg, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 12)
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
    let isSearching: Bool
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CosmoPalette.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .cosmoInputFont()
                .foregroundStyle(CosmoPalette.ink)
                .onSubmit(onSubmit)

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }
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

private struct DropdownItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? CosmoPalette.surfaceSoft : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct HoverDropdownMenu<Content: View>: View {
    let menuID: String
    let title: String
    let value: String
    let isTemporarilyDisabled: Bool
    @Binding var activeMenuID: String?
    @ViewBuilder var content: Content
    @State private var isHoveringControl = false
    @State private var isHoveringPanel = false
    @State private var collapseTask: Task<Void, Never>?

    init(
        menuID: String,
        title: String,
        value: String,
        isTemporarilyDisabled: Bool = false,
        activeMenuID: Binding<String?>,
        @ViewBuilder content: () -> Content
    ) {
        self.menuID = menuID
        self.title = title
        self.value = value
        self.isTemporarilyDisabled = isTemporarilyDisabled
        _activeMenuID = activeMenuID
        self.content = content()
    }

    var body: some View {
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isExpanded ? CosmoPalette.surfaceStrong : CosmoPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isExpanded ? CosmoPalette.moss.opacity(0.35) : CosmoPalette.line, lineWidth: 1)
                )
        )
        .shadow(color: CosmoPalette.shadow.opacity(isExpanded ? 0.9 : 0.55), radius: isExpanded ? 16 : 10, x: 0, y: isExpanded ? 12 : 8)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            guard !isTemporarilyDisabled else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                activeMenuID = isExpanded ? nil : menuID
            }
        }
        .onHover { hovering in
            isHoveringControl = hovering
            updateExpandedState()
        }
        .overlay(alignment: .topLeading) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    content
                }
                .padding(8)
                .frame(minWidth: 220, alignment: .leading)
                .buttonStyle(DropdownItemButtonStyle())
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CosmoPalette.surfaceStrong,
                                    CosmoPalette.fog.opacity(0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(CosmoPalette.line, lineWidth: 1)
                        )
                        .shadow(color: CosmoPalette.shadow, radius: 20, x: 0, y: 14)
                )
                .offset(y: 58)
                .onHover { hovering in
                    isHoveringPanel = hovering
                    updateExpandedState()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(30)
            }
        }
        .disabled(isTemporarilyDisabled)
        .opacity(isTemporarilyDisabled ? 0.52 : 1)
        .zIndex(isExpanded ? 40 : 1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var isExpanded: Bool {
        activeMenuID == menuID
    }

    private func updateExpandedState() {
        guard !isTemporarilyDisabled else {
            collapseTask?.cancel()
            activeMenuID = nil
            return
        }
        let shouldExpand = isHoveringControl || isHoveringPanel
        if shouldExpand {
            collapseTask?.cancel()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                activeMenuID = menuID
            }
            return
        }

        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isHoveringControl, !isHoveringPanel, activeMenuID == menuID else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                    activeMenuID = nil
                }
            }
        }
    }
}

private struct ClipRowAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

private struct ClipRowActionButton: View {
    let action: ClipRowAction

    var body: some View {
        Button {
            action.action()
        } label: {
            Image(systemName: action.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(action.tint)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(action.tint.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(action.tint.opacity(0.22), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(action.title)
    }
}

private struct FlowTagList: View {
    let tags: [String]
    @Binding var selectedTag: String

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let selected = selectedTag.caseInsensitiveCompare(tag) == .orderedSame
                Button {
                    selectedTag = tag
                } label: {
                    Text(tag)
                        .cosmoUIFont(tag, size: 11, weight: .bold, design: .rounded)
                        .foregroundStyle(selected ? CosmoTheme.carbon : .white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? CosmoTheme.industrialGold : Color.white.opacity(0.08))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(selected ? CosmoTheme.industrialGold.opacity(0.22) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
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
                                ClipStripRow(clip: clip, selected: false, searchResult: nil, actions: [])
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
    let searchResult: AISearchResult?
    let actions: [ClipRowAction]

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
                    if let searchResult {
                        Text(searchResult.source == .semantic ? "AI \(Int(searchResult.score * 100))%" : "Fallback \(Int(searchResult.score * 100))%")
                            .cosmoTextFont(searchResult.source == .semantic ? "AI \(Int(searchResult.score * 100))%" : "Fallback \(Int(searchResult.score * 100))%", size: 11, weight: .semibold, design: .rounded)
                            .foregroundStyle(searchResult.source == .semantic ? CosmoPalette.moss : CosmoPalette.clay)
                    } else {
                        Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(CosmoPalette.textSecondary)
                    }
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

                Text(searchResult?.matchedSnippet.isEmpty == false ? searchResult?.matchedSnippet ?? "" : clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary)
                    .cosmoTextFont(searchResult?.matchedSnippet.isEmpty == false ? searchResult?.matchedSnippet ?? "" : clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary, size: 15)
                    .foregroundStyle(CosmoPalette.textSecondary)
                    .lineLimit(searchResult == nil ? 2 : 3)

                if let searchResult, !searchResult.matchedFields.isEmpty {
                    Text(searchResult.matchedFields.prefix(4).map(\.label).joined(separator: " · "))
                        .cosmoTextFont(searchResult.matchedFields.prefix(4).map(\.label).joined(separator: " · "), size: 12, weight: .medium)
                        .foregroundStyle(searchResult.source == .semantic ? CosmoPalette.moss : CosmoPalette.textSecondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        ClipRowActionButton(action: action)
                    }
                }

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(CosmoPalette.moss)
                } else {
                    Spacer(minLength: 0)
                }
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
    @State private var activeTopMenuID: String?
    @State private var transientStatusMessage: String?
    @State private var statusToastTask: Task<Void, Never>?
    @State private var isTimeboxPopoverPresented = false

    private let filters: [PlatformFilter] = [.all] + PlatformBucket.allCases.map(PlatformFilter.bucket)

    public init() {}

    private var canvasHeadline: String {
        if model.backstageModule == .promptLibrary {
            return "Prompt Library"
        }
        if model.backstageModule == .todo {
            return "Todo Console"
        }
        if model.backstageModule == .settings {
            return "Settings"
        }
        if model.isAISearchActive {
            return "Backstage Search Results"
        }
        switch model.timeboxDraft.filter {
        case let .day(day) where Calendar.current.isDateInToday(day):
            return "Today's Intake"
        default:
            return "Working Set"
        }
    }

    private var canvasSubheadline: String {
        if model.backstageModule == .promptLibrary {
            return "这里是提示词库后台工作台：蜂巢视图负责快速调用，这里负责完整编辑、整理和后续扩充。"
        }
        if model.backstageModule == .todo {
            return "待办事项被带回后台成为正式模块：更适合排队、重命名、完成和清空。"
        }
        if model.backstageModule == .settings {
            return "设置现在直接进入后台工作台，不再作为一张独立弹层漂浮在界面上。"
        }
        if model.isAISearchActive {
            return "Recall Overlay 的上下文已被带入后台，当前列表展示这次召回命中的工作结果。"
        }
        switch model.timeboxDraft.filter {
        case let .day(day) where Calendar.current.isDateInToday(day):
            return "后台默认先从今天的流入开始，方便把新增内容快速清点、修整和归档。"
        default:
            return "这里展示的是适合继续整理的工作集合，顶部负责筛选，侧边负责辅助动作。"
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                BackstageBackdrop(tone: backstageTone)

                HStack(alignment: .top, spacing: 12) {
                    backstageRailView
                        .frame(width: 96, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                    if !model.isBackstageSidebarCollapsed {
                        moduleSidebarView
                            .frame(width: sidebarWidth, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    moduleWorkspaceView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    if model.backstageModule == .clips {
                        clipInspectorColumn
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .animation(CosmoMotion.settle, value: model.isBackstageSidebarCollapsed)
                .animation(CosmoMotion.settle, value: model.backstageModule)

                if let activeOverlay = model.activeOverlay {
                    overlayBackdrop(activeOverlay)
                }

                if let transientStatusMessage {
                    VStack {
                        StatusToast(message: transientStatusMessage)
                        Spacer()
                    }
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(500)
                }
            }
        }
        .frame(minWidth: 1180, minHeight: 820)
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
            Button("Continue Editing", role: .cancel) {
                model.cancelPendingClipSelection()
            }
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
        .onChange(of: model.searchDraft) { _, _ in model.scheduleAISearch() }
        .onChange(of: model.timeboxDraft) { _, _ in model.refreshFilters() }
        .onReceive(model.$statusMessage.dropFirst()) { message in
            presentStatusToast(message)
        }
    }

    private func presentStatusToast(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        statusToastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            transientStatusMessage = trimmed
        }

        statusToastTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.22)) {
                    transientStatusMessage = nil
                }
            }
        }
    }

    private var currentSpace: Space? {
        guard let selectedSpaceID = model.selectedSpaceID else { return nil }
        return model.spaces.first(where: { $0.id == selectedSpaceID })
    }

    private var currentSpaceTone: SpaceTone {
        if let currentSpace {
            return CosmoTheme.tone(for: currentSpace.name)
        }

        if case let .bucket(bucket) = model.selectedPlatform {
            return CosmoTheme.platformTone(for: bucket)
        }

        return .neutral
    }

    private var backstageTone: SpaceTone {
        switch model.backstageModule {
        case .clips:
            return currentSpaceTone
        case .todo:
            return CosmoTheme.tone(for: "todo-console")
        case .promptLibrary:
            return CosmoTheme.tone(for: "prompt-library")
        case .settings:
            return .neutral
        }
    }

    private var sidebarWidth: CGFloat {
        switch model.backstageModule {
        case .clips:
            return 248
        case .promptLibrary:
            return 270
        case .todo:
            return 276
        case .settings:
            return 248
        }
    }

    private var backstageRailView: some View {
        BackstageRail(tone: backstageTone, padding: 12) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CG")
                        .cosmoDisplayFont("CG", size: 28, weight: .bold)
                        .foregroundStyle(backstageTone.accent)
                    Text("Console")
                        .cosmoUIFont("Console", size: 10, weight: .bold)
                        .foregroundStyle(CosmoTheme.textTertiary)
                }

                RuleDivider(strong: true)

                VStack(spacing: 4) {
                    ForEach(BackstageModule.allCases) { module in
                        RailButton(
                            title: module.title,
                            systemImage: module.systemImage,
                            tone: backstageTone,
                            isActive: model.backstageModule == module
                        ) {
                            withAnimation(CosmoMotion.settle) {
                                model.openBackstageModule(module)
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                if model.backstageModule == .clips {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.isAISearchContextActive ? "Query".uppercased() : "Visible".uppercased())
                            .cosmoUIFont(model.isAISearchContextActive ? "Query" : "Visible", size: 10, weight: .bold)
                            .foregroundStyle(CosmoTheme.textTertiary)
                        Text(model.isAISearchContextActive ? (model.activeSearchQuery.isEmpty ? model.searchDraft : model.activeSearchQuery) : "\(model.displayedClips.count)")
                            .cosmoTextFont(model.isAISearchContextActive ? (model.activeSearchQuery.isEmpty ? model.searchDraft : model.activeSearchQuery) : "\(model.displayedClips.count)", size: model.isAISearchContextActive ? 12 : 24, weight: model.isAISearchContextActive ? .medium : .semibold)
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .lineLimit(model.isAISearchContextActive ? 3 : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                Button {
                    withAnimation(CosmoMotion.settle) {
                        model.toggleBackstageSidebar()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: model.isBackstageSidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                            .font(.system(size: 14, weight: .bold))
                        Text(model.isBackstageSidebarCollapsed ? "Expand" : "Collapse")
                            .cosmoUIFont(model.isBackstageSidebarCollapsed ? "Expand" : "Collapse", size: 10, weight: .bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
            }
        }
    }

    private var moduleSidebarView: some View {
        BackstageSidebar(tone: backstageTone, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.backstageModule.title)
                            .cosmoDisplayFont(model.backstageModule.title, size: 20, weight: .semibold)
                            .foregroundStyle(CosmoTheme.textPrimary)
                        Text(sidebarSubtitle)
                            .cosmoTextFont(sidebarSubtitle, size: 12)
                            .foregroundStyle(CosmoTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        withAnimation(CosmoMotion.settle) {
                            model.setBackstageSidebarCollapsed(true)
                        }
                    } label: {
                        Image(systemName: "sidebar.leading")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .ghost))
                }

                RuleDivider(strong: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        moduleSidebarSections
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.never)
            }
        }
    }

    @ViewBuilder
    private var moduleSidebarSections: some View {
        switch model.backstageModule {
        case .clips:
            clipsSidebarSections
        case .promptLibrary:
            promptSidebarSections
        case .todo:
            todoSidebarSections
        case .settings:
            settingsSidebarSections
        }
    }

    @ViewBuilder
    private var moduleWorkspaceView: some View {
        switch model.backstageModule {
        case .clips:
            clipsWorkspaceView
        case .promptLibrary:
            promptWorkspaceView
        case .todo:
            todoWorkspaceView
        case .settings:
            settingsWorkspaceView
        }
    }

    private var clipsWorkspaceView: some View {
        WorkbenchSurface(role: .workspace, tone: backstageTone, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(title: canvasHeadline, subtitle: canvasSubheadline, tone: backstageTone) {
                    HStack(spacing: 8) {
                        ContextChip(title: "Visible", value: "\(model.displayedClips.count)", tone: backstageTone, isActive: true, icon: "square.grid.2x2")
                        if model.isAISearchActive {
                            ContextChip(title: "Mode", value: model.searchMode.label, tone: backstageTone, isActive: true, icon: "sparkles")
                        }
                        Button {
                            model.presentRecallOverlay()
                        } label: {
                            Label("Recall", systemImage: "sparkles")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))

                        Button {
                            model.captureCurrentPage()
                        } label: {
                            Label("Capture Page", systemImage: "safari")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .primary))

                        Button {
                            model.captureClipboard()
                        } label: {
                            Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
                    }
                }

                WorkbenchInputShell(tone: backstageTone) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(backstageTone.accent)

                        TextField("搜索整个库，用自然语言描述你还记得的碎片", text: $model.searchDraft)
                            .textFieldStyle(.plain)
                            .cosmoInputFont(size: 15)
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .onSubmit {
                                Task {
                                    await model.submitAISearch(forceImmediate: true)
                                }
                            }

                        if model.aiSearchStatus.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else if !model.searchDraft.isEmpty {
                            Button {
                                model.clearSearch()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .ghost))
                        }
                    }
                }

                activeClipsContextStrip

                RuleDivider(strong: true)

                if model.displayedClips.isEmpty {
                    ContentUnavailableView(
                        model.isAISearchActive ? "No AI matches found" : "No clips found",
                        systemImage: "tray",
                        description: Text(model.isAISearchActive ? "可以尝试换一种自然语言描述，或者从左侧折叠轨重置筛选。" : "调整左侧条件，或先通过网页 / 剪贴板继续采集。").cosmoTextFont(model.isAISearchActive ? "可以尝试换一种自然语言描述，或者从左侧折叠轨重置筛选。" : "调整左侧条件，或先通过网页 / 剪贴板继续采集。", size: 14)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if model.isAISearchActive {
                                ForEach(model.filteredAISearchResults) { result in
                                    clipRowButton(clip: result.clip, searchResult: result)
                                }
                            } else {
                                ForEach(model.clips) { clip in
                                    clipRowButton(clip: clip, searchResult: nil)
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .scrollIndicators(.never)
                }
            }
        }
    }

    private var promptWorkspaceView: some View {
        WorkbenchSurface(role: .workspace, tone: backstageTone, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(title: canvasHeadline, subtitle: canvasSubheadline, tone: backstageTone) {
                    HStack(spacing: 8) {
                        Button {
                            model.createPromptLibraryItem()
                        } label: {
                            Label("New Prompt", systemImage: "plus")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .primary))

                        Button {
                            model.presentRecallOverlay(initialMode: .promptLibrary)
                        } label: {
                            Label("Open Hive", systemImage: "hexagon")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
                    }
                }

                RuleDivider(strong: true)

                PromptLibraryWorkbenchView()
                    .environmentObject(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var todoWorkspaceView: some View {
        WorkbenchSurface(role: .workspace, tone: backstageTone, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(title: canvasHeadline, subtitle: canvasSubheadline, tone: backstageTone) {
                    HStack(spacing: 8) {
                        ContextChip(title: "Pending", value: "\(model.todoItems.count)", tone: backstageTone, isActive: true, icon: "checklist")
                        Button {
                            model.presentRecallOverlay(initialMode: .todo)
                        } label: {
                            Label("Open Cloud", systemImage: "sparkles")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
                    }
                }

                RuleDivider(strong: true)

                TodoWorkbenchView(tone: backstageTone)
                    .environmentObject(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var settingsWorkspaceView: some View {
        WorkbenchSurface(role: .workspace, tone: backstageTone, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(title: canvasHeadline, subtitle: canvasSubheadline, tone: backstageTone) {
                    ContextChip(title: "Current Tab", value: model.selectedSettingsTab.title, tone: backstageTone, isActive: true, icon: model.selectedSettingsTab.systemImage)
                }

                RuleDivider(strong: true)

                SettingsRootView()
                    .environmentObject(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var activeClipsContextStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ContextChip(title: "Platform", value: model.selectedPlatform.label, tone: backstageTone, isActive: model.selectedPlatform != .all, icon: "square.stack.3d.up")
                ContextChip(title: "Scope", value: model.selectedScope.title, tone: backstageTone, isActive: model.selectedScope != .all, icon: "line.3.horizontal.decrease.circle")
                ContextChip(title: "Space", value: selectedSpaceLabel, tone: backstageTone, isActive: model.selectedSpaceID != nil, icon: "square.split.2x2")
                Button {
                    isTimeboxPopoverPresented.toggle()
                } label: {
                    ContextChip(title: "Timebox", value: model.timeboxDraft.filter.summary, tone: backstageTone, isActive: model.timeboxDraft.filter != .all, icon: "clock")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isTimeboxPopoverPresented, arrowEdge: .bottom) {
                    clipTimeboxPopover
                }
                Button {
                    model.resetPrimaryFilters(clearSearch: true)
                } label: {
                    Label("Reset Context", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .ghost))
            }
        }
        .scrollIndicators(.never)
    }

    private var clipsSidebarSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarDisclosureSection(
                title: "Platform",
                subtitle: "平台条件彻底退回左侧，不再占据顶部视觉主权。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("platform"),
                onToggle: { toggleSidebarSection("platform") }
            ) {
                VStack(spacing: 8) {
                    ForEach(filters.indices, id: \.self) { index in
                        let filter = filters[index]
                        sidebarSelectionButton(
                            title: filter.label,
                            subtitle: filter.bucket == nil ? "取消平台限制" : "只查看 \(filter.label)",
                            isSelected: model.selectedPlatform == filter
                        ) {
                            model.focusPlatform(filter)
                        }
                    }
                }
            }

            SidebarDisclosureSection(
                title: "Scope",
                subtitle: "收起次级条件，让当前浏览范围保持明确。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("scope"),
                onToggle: { toggleSidebarSection("scope") }
            ) {
                VStack(spacing: 8) {
                    ForEach(ClipScope.allCases) { scope in
                        sidebarSelectionButton(
                            title: scope.title,
                            subtitle: scope == .all ? "查看全部条目" : "只看 \(scope.title)",
                            isSelected: model.selectedScope == scope
                        ) {
                            model.selectedScope = scope
                        }
                    }
                }
            }

            SidebarDisclosureSection(
                title: "Space",
                subtitle: "空间色彩只强化上下文，不再侵入正文内容。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("space"),
                onToggle: { toggleSidebarSection("space") }
            ) {
                VStack(spacing: 8) {
                    sidebarSelectionButton(
                        title: "All Spaces",
                        subtitle: "解除空间过滤",
                        isSelected: model.selectedSpaceID == nil
                    ) {
                        model.focusSpace(nil)
                    }

                    ForEach(model.spaces) { space in
                        sidebarSelectionButton(
                            title: space.name,
                            subtitle: space.tags.prefix(3).joined(separator: " · "),
                            isSelected: model.selectedSpaceID == space.id
                        ) {
                            model.focusSpace(space.id)
                            if let firstTag = space.tags.first {
                                model.captureTagDraft = firstTag
                            }
                        }
                    }
                }
            }

        }
    }

    private var clipTimeboxPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timebox")
                .cosmoDisplayFont("Timebox", size: 18, weight: .semibold)
                .foregroundStyle(CosmoTheme.textPrimary)

            Text("完整时间范围编辑已经迁移到这里。")
                .cosmoTextFont("完整时间范围编辑已经迁移到这里。", size: 12)
                .foregroundStyle(CosmoTheme.textSecondary)

            HStack(spacing: 8) {
                timeboxQuickButton("All") {
                    model.timeboxDraft = TimeboxDraft(mode: .all)
                }
                timeboxQuickButton("Today") {
                    model.timeboxDraft = .today()
                }
            }

            HStack(spacing: 8) {
                timeboxQuickButton("24h") {
                    model.timeboxDraft = TimeboxDraft(mode: .trailingHours, trailingHours: 24)
                }
                timeboxQuickButton("72h") {
                    model.timeboxDraft = TimeboxDraft(mode: .trailingHours, trailingHours: 72)
                }
            }

            TimeboxComposer(draft: $model.timeboxDraft, tone: backstageTone)
        }
        .padding(16)
        .frame(width: 320, alignment: .topLeading)
        .background(
            Rectangle()
                .fill(CosmoTheme.panelGradient(tier: .workspace, tone: backstageTone))
                .overlay(
                    Rectangle()
                        .strokeBorder(CosmoTheme.divider, lineWidth: 1)
                )
        )
    }

    private var promptSidebarSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarDisclosureSection(
                title: "Library Actions",
                subtitle: "新建、复制与快速回到 prompt hive。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("actions"),
                onToggle: { toggleSidebarSection("actions") }
            ) {
                VStack(spacing: 10) {
                    Button {
                        model.createPromptLibraryItem()
                    } label: {
                        Label("Create Prompt", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .primary))

                    Button {
                        model.copySelectedPromptContent()
                    } label: {
                        Label("Copy Selected Prompt", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
                    .disabled(model.selectedPrompt == nil)

                    Button {
                        model.presentRecallOverlay(initialMode: .promptLibrary)
                    } label: {
                        Label("Open Prompt Hive", systemImage: "hexagon")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .ghost))
                }
            }

            SidebarDisclosureSection(
                title: "Library",
                subtitle: "系统条目与自定义条目统一集中管理。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("library"),
                onToggle: { toggleSidebarSection("library") }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    sidebarMetricRow(title: "Prompts", value: "\(model.promptItems.count)")
                    sidebarMetricRow(title: "System", value: "\(model.promptItems.filter(\.isSystem).count)")
                    sidebarMetricRow(title: "Custom", value: "\(model.promptItems.filter { !$0.isSystem }.count)")
                }
            }

            SidebarDisclosureSection(
                title: "Source / Meta",
                subtitle: "只读来源在左侧，完整编辑动作交给主工作区。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("source"),
                onToggle: { toggleSidebarSection("source") }
            ) {
                if let selectedPrompt = model.selectedPrompt {
                    VStack(alignment: .leading, spacing: 10) {
                        sidebarMetricRow(title: "Type", value: selectedPrompt.isSystem ? "System Prompt" : "Custom Prompt")
                        sidebarMetricRow(title: "Source", value: selectedPrompt.sourceLabel.isEmpty ? "Custom" : selectedPrompt.sourceLabel)
                        if !selectedPrompt.sourceURL.isEmpty {
                            Text(selectedPrompt.sourceURL)
                                .cosmoTextFont(selectedPrompt.sourceURL, size: 12)
                                .foregroundStyle(CosmoTheme.textSecondary)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Rectangle()
                                        .fill(CosmoTheme.panelGradient(tier: .row, tone: backstageTone))
                                        .overlay(
                                            Rectangle()
                                                .stroke(CosmoTheme.divider, lineWidth: 1)
                                        )
                                )
                        }
                    }
                } else {
                    Text("Select a prompt to inspect its source.")
                        .cosmoTextFont("Select a prompt to inspect its source.", size: 13)
                        .foregroundStyle(CosmoTheme.textSecondary)
                }
            }
        }
    }

    private var todoSidebarSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarDisclosureSection(
                title: "Quick",
                subtitle: "待办成为正式模块后，侧栏只保留概览与快速跳转。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("quick"),
                onToggle: { toggleSidebarSection("quick") }
            ) {
                VStack(spacing: 10) {
                    sidebarMetricRow(title: "Pending", value: "\(model.todoItems.count)")
                    sidebarMetricRow(title: "Focused", value: model.todoItems.first(where: { $0.id == model.todoFocusedItemID })?.title ?? "None")

                    Button {
                        model.presentRecallOverlay(initialMode: .todo)
                    } label: {
                        Label("Open Todo Cloud", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
                }
            }

            SidebarDisclosureSection(
                title: "Queue",
                subtitle: "选择一个待办，主工作区里做重命名或完成。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("queue"),
                onToggle: { toggleSidebarSection("queue") }
            ) {
                if model.todoItems.isEmpty {
                    Text("No pending todos.")
                        .cosmoTextFont("No pending todos.", size: 13)
                        .foregroundStyle(CosmoTheme.textSecondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(model.todoItems.prefix(8))) { item in
                            sidebarSelectionButton(
                                title: item.title,
                                subtitle: item.updatedAt.formatted(date: .abbreviated, time: .shortened),
                                isSelected: model.todoFocusedItemID == item.id
                            ) {
                                if model.todoEditingItemID != nil, model.todoEditingItemID != item.id {
                                    model.finishTodoEditing(commit: true)
                                }
                                model.selectTodoItem(item.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsSidebarSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarDisclosureSection(
                title: "Tabs",
                subtitle: "所有设置入口现在都从后台侧边栏切换。",
                tone: backstageTone,
                isExpanded: isSidebarSectionExpanded("tabs"),
                onToggle: { toggleSidebarSection("tabs") }
            ) {
                VStack(spacing: 8) {
                    ForEach(SettingsTab.allCases) { tab in
                        sidebarSelectionButton(
                            title: tab.title,
                            subtitle: tab.systemImage,
                            isSelected: model.selectedSettingsTab == tab
                        ) {
                            model.selectedSettingsTab = tab
                        }
                    }
                }
            }
        }
    }

    private var sidebarSubtitle: String {
        switch model.backstageModule {
        case .clips:
            return "Filters and context"
        case .promptLibrary:
            return "Library meta and entry points"
        case .todo:
            return "Queue summary and selection"
        case .settings:
            return "Backstage settings navigation"
        }
    }

    private func isSidebarSectionExpanded(_ sectionID: String) -> Bool {
        model.isBackstageSectionExpanded(module: model.backstageModule, sectionID: sectionID)
    }

    private func toggleSidebarSection(_ sectionID: String) {
        withAnimation(CosmoMotion.quick) {
            model.toggleBackstageSection(module: model.backstageModule, sectionID: sectionID)
        }
    }

    private func sidebarMetricRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .cosmoUIFont(title.uppercased(), size: 10, weight: .bold)
                .foregroundStyle(CosmoTheme.textTertiary)
            Text(value)
                .cosmoTextFont(value, size: 13, weight: .medium)
                .foregroundStyle(CosmoTheme.textPrimary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(CosmoTheme.panelGradient(tier: .row, tone: backstageTone))
                .overlay(
                    Rectangle()
                        .stroke(CosmoTheme.divider, lineWidth: 1)
                )
        )
    }

    private func sidebarSelectionButton(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            WorkbenchRow(tone: backstageTone, isSelected: isSelected, padding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .cosmoTextFont(title, size: 13, weight: .semibold)
                        .foregroundStyle(CosmoTheme.textPrimary)
                        .lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .cosmoTextFont(subtitle, size: 11)
                            .foregroundStyle(CosmoTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func timeboxQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .frame(maxWidth: .infinity)
            .buttonStyle(ConsoleButtonStyle(tone: backstageTone, variant: .secondary))
    }

    private var topBar: some View {
        ContentPanel(tone: currentSpaceTone, padding: 24) {
            if model.backstageModule == .clips {
                clipCommandDeck
            } else {
                promptCommandDeck
            }
        }
        .frame(minHeight: model.backstageModule == .clips ? 260 : 180)
    }

    private var backstageModuleButtons: some View {
        HStack(spacing: 10) {
            ForEach(BackstageModule.allCases) { module in
                Button {
                    model.openBackstageModule(module)
                } label: {
                    ContextChip(
                        title: "Module",
                        value: module.title,
                        tone: currentSpaceTone,
                        isActive: model.backstageModule == module,
                        icon: module == .clips ? "square.stack.3d.up" : "text.badge.star"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var clipCommandDeck: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Backstage")
                        .cosmoDisplayFont("Backstage", size: 38, weight: .bold)
                        .foregroundStyle(CosmoTheme.textPrimary)
                    Text("把 Recall 之外的显式整理动作，收束成更锐利的指挥台。搜索、召回、采集是第一视觉，其余条件退为上下文。")
                        .cosmoTextFont("把 Recall 之外的显式整理动作，收束成更锐利的指挥台。搜索、召回、采集是第一视觉，其余条件退为上下文。", size: 14)
                        .foregroundStyle(CosmoTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    backstageModuleButtons
                }

                Spacer(minLength: 24)

                if let currentSpace {
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Current Space".uppercased())
                            .cosmoUIFont("Current Space", size: 10, weight: .semibold, design: .rounded)
                            .foregroundStyle(CosmoTheme.textTertiary)
                        Text(currentSpace.name)
                            .cosmoDisplayFont(currentSpace.name, size: 22, weight: .semibold)
                            .foregroundStyle(currentSpaceTone.accent)
                        Text(currentSpace.tags.prefix(3).joined(separator: " · "))
                            .cosmoTextFont(currentSpace.tags.prefix(3).joined(separator: " · "), size: 12)
                            .foregroundStyle(CosmoTheme.textSecondary)
                    }
                    .frame(maxWidth: 220, alignment: .trailing)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                ChromePanel(tone: currentSpaceTone, padding: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Command Spine")
                            .cosmoUIFont("Command Spine", size: 11, weight: .bold, design: .rounded)
                            .foregroundStyle(CosmoTheme.textTertiary)

                        HStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(currentSpaceTone.accent)

                            TextField("搜索整个库，用自然语言描述你还记得的碎片", text: $model.searchDraft)
                                .textFieldStyle(.plain)
                                .font(CosmoTypography.font(
                                    for: model.searchDraft.isEmpty ? "搜索整个库，用自然语言描述你还记得的碎片" : model.searchDraft,
                                    role: .display,
                                    size: 20,
                                    weight: .medium
                                ))
                                .foregroundStyle(Color.white.opacity(0.96))
                                .onSubmit {
                                    Task {
                                        await model.submitAISearch(forceImmediate: true)
                                    }
                                }

                            if model.aiSearchStatus.isBusy {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color.white.opacity(0.7))
                            } else if !model.searchDraft.isEmpty {
                                Button {
                                    model.clearSearch()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.82))
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(model.isAISearchContextActive ? "AI 检索正在接管上下文；Platform / Scope / Space / Timebox 暂退为过滤背景。" : "需要更沉浸的记忆召回时，直接打开 Recall Overlay；这里专注于显式整理与精修。")
                            .cosmoTextFont(model.isAISearchContextActive ? "AI 检索正在接管上下文；Platform / Scope / Space / Timebox 暂退为过滤背景。" : "需要更沉浸的记忆召回时，直接打开 Recall Overlay；这里专注于显式整理与精修。", size: 12)
                            .foregroundStyle(Color.white.opacity(model.isAISearchContextActive ? 0.82 : 0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    PrimaryCommandButton(
                        title: "Open Recall",
                        subtitle: "进入全屏召回层，保持未来感与沉浸感。",
                        systemImage: "sparkles",
                        tone: currentSpaceTone,
                        prominent: true
                    ) {
                        model.presentRecallOverlay()
                    }

                    PrimaryCommandButton(
                        title: "Capture Page",
                        subtitle: "把当前网页送进当前工作台。",
                        systemImage: "safari",
                        tone: currentSpaceTone
                    ) {
                        model.captureCurrentPage()
                    }

                    PrimaryCommandButton(
                        title: "Capture Clipboard",
                        subtitle: "收下剪贴板文字或链接，继续整理。",
                        systemImage: "doc.on.clipboard",
                        tone: currentSpaceTone
                    ) {
                        model.captureClipboard()
                    }
                }
                .frame(width: 320)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(SettingsTab.allCases) { tab in
                            Button(tab.title) {
                                model.openSettingsTab(tab)
                            }
                        }
                    } label: {
                        ContextChip(title: "Settings", value: model.selectedSettingsTab.title, tone: currentSpaceTone, icon: "slider.horizontal.3")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        ForEach(filters.indices, id: \.self) { index in
                            let filter = filters[index]
                            Button(filter.label) {
                                model.focusPlatform(filter)
                            }
                        }
                    } label: {
                        ContextChip(title: "Platform", value: model.selectedPlatform.label, tone: currentSpaceTone, isActive: model.selectedPlatform != .all, icon: "square.stack.3d.up")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isAISearchContextActive)

                    Menu {
                        ForEach(ClipScope.allCases) { scope in
                            Button(scope.title) {
                                model.selectedScope = scope
                            }
                        }
                    } label: {
                        ContextChip(title: "Scope", value: model.selectedScope.title, tone: currentSpaceTone, isActive: model.selectedScope != .all, icon: "line.3.horizontal.decrease.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isAISearchContextActive)

                    Menu {
                        Button("All Spaces") {
                            model.focusSpace(nil)
                        }
                        if !model.spaces.isEmpty {
                            Divider()
                            ForEach(model.spaces) { space in
                                Button(space.name) {
                                    model.focusSpace(space.id)
                                    if let firstTag = space.tags.first {
                                        model.captureTagDraft = firstTag
                                    }
                                }
                            }
                        }
                    } label: {
                        ContextChip(title: "Space", value: selectedSpaceLabel, tone: currentSpaceTone, isActive: model.selectedSpaceID != nil, icon: "square.split.2x2")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isAISearchContextActive)

                    Menu {
                        Button("All time") {
                            model.timeboxDraft = TimeboxDraft(mode: .all)
                        }
                        Button("Today") {
                            model.timeboxDraft = .today()
                        }
                        Button("Past 24h") {
                            model.timeboxDraft = TimeboxDraft(mode: .trailingHours, trailingHours: 24)
                        }
                        Button("Past 72h") {
                            model.timeboxDraft = TimeboxDraft(mode: .trailingHours, trailingHours: 72)
                        }
                    } label: {
                        ContextChip(title: "Timebox", value: model.timeboxDraft.filter.summary, tone: currentSpaceTone, isActive: model.timeboxDraft.filter != .all, icon: "clock")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isAISearchContextActive)

                    Button {
                        model.resetPrimaryFilters()
                    } label: {
                        ContextChip(title: "Reset", value: "Today", tone: currentSpaceTone, icon: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptCommandDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt Library")
                        .cosmoDisplayFont("Prompt Library", size: 34, weight: .bold)
                        .foregroundStyle(CosmoTheme.textPrimary)
                    Text("快用层负责调用，这里负责完整编辑、来源追溯与系统化沉淀。")
                        .cosmoTextFont("快用层负责调用，这里负责完整编辑、来源追溯与系统化沉淀。", size: 14)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    backstageModuleButtons
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    PrimaryCommandButton(
                        title: "New Prompt",
                        subtitle: "创建新的系统提示词条目。",
                        systemImage: "plus",
                        tone: currentSpaceTone,
                        prominent: true
                    ) {
                        model.createPromptLibraryItem()
                    }

                    PrimaryCommandButton(
                        title: "Open Prompt Hive",
                        subtitle: "进入蜂巢视图，快速调用现有提示词。",
                        systemImage: "hexagon",
                        tone: currentSpaceTone
                    ) {
                        model.presentRecallOverlay(initialMode: .promptLibrary)
                    }
                }
                .frame(width: 320)
            }

            if let selectedPrompt = model.selectedPrompt, !selectedPrompt.sourceLabel.isEmpty {
                ContextChip(
                    title: selectedPrompt.isSystem ? "System Source" : "Source",
                    value: selectedPrompt.sourceLabel,
                    tone: currentSpaceTone,
                    isActive: true,
                    icon: selectedPrompt.isSystem ? "sparkles" : "square.and.pencil"
                )
            }
        }
    }

    private var selectedSpaceLabel: String {
        currentSpace?.name ?? "All Spaces"
    }

    private var clipSidebarView: some View {
        ChromePanel(tone: currentSpaceTone, padding: 18) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Operations")
                        .cosmoDisplayFont("Operations", size: 25, weight: .semibold)
                        .foregroundStyle(CosmoTheme.bone)
                    Text("侧栏退成暗箱，只保留高频动作和当前工作范围。主视觉权重交给内容区与右侧工作室。")
                        .cosmoTextFont("侧栏退成暗箱，只保留高频动作和当前工作范围。主视觉权重交给内容区与右侧工作室。", size: 12)
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Visible".uppercased())
                        .cosmoUIFont("Visible", size: 10, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.white.opacity(0.48))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatPill(title: "Visible", value: "\(model.displayedClips.count)")
                        StatPill(title: "Inbox", value: "\(model.stats.inboxCount)")
                        StatPill(title: "Library", value: "\(model.stats.libraryCount)")
                        StatPill(title: "Failed", value: "\(model.stats.failedCount)")
                        StatPill(title: "Trash", value: "\(model.stats.trashCount)")
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture Tag".uppercased())
                        .cosmoUIFont("Capture Tag", size: 10, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Text("剪藏前先定一个 tag，系统会自动回填到匹配 space。")
                        .cosmoTextFont("剪藏前先定一个 tag，系统会自动回填到匹配 space。", size: 12)
                        .foregroundStyle(Color.white.opacity(0.68))
                    TextField("例如 design / research / inspiration", text: $model.captureTagDraft)
                        .cosmoInputFont()
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: CosmoRadius.md, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CosmoRadius.md, style: .continuous)
                                        .strokeBorder(currentSpaceTone.accent.opacity(0.18), lineWidth: 1)
                                )
                        )
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
                    .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Actions".uppercased())
                        .cosmoUIFont("Quick Actions", size: 10, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Text("只保留当前会真正用到的动作，其余出口让位给内容。")
                        .cosmoTextFont("只保留当前会真正用到的动作，其余出口让位给内容。", size: 12)
                        .foregroundStyle(Color.white.opacity(0.68))
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
                        .buttonStyle(SurfaceButtonStyle(fill: currentSpaceTone.accent, foreground: CosmoTheme.carbon, border: currentSpaceTone.ribbon.opacity(0.18)))

                        Button {
                            model.captureClipboard()
                        } label: {
                            Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))

                        Button {
                            model.openSelectedClipURL()
                        } label: {
                            Label("Open Selected URL", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                        .disabled(model.selectedClip?.url.hasPrefix("clipboard://") ?? true)

                        Button {
                            if model.selectedClip?.isPlainTextClipboardCapture == true {
                                model.copySelectedClipContent()
                            } else {
                                model.copySelectedClipURL()
                            }
                        } label: {
                            Label(
                                model.selectedClip?.isPlainTextClipboardCapture == true ? "Copy Selected Text" : "Copy Selected URL",
                                systemImage: model.selectedClip?.isPlainTextClipboardCapture == true ? "doc.on.doc" : "link"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                        .disabled(model.selectedClip == nil)

                        HStack(spacing: 10) {
                            Button("Inbox") {
                                model.updateSelectedClipStatus(.inbox)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                            .disabled(model.selectedClip == nil)

                            Button("Library") {
                                model.updateSelectedClipStatus(.library)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                            .disabled(model.selectedClip == nil)

                            Button("Trash") {
                                model.updateSelectedClipStatus(.trashed)
                            }
                            .buttonStyle(SurfaceButtonStyle(fill: Color.white.opacity(0.08), foreground: .white, border: Color.white.opacity(0.10)))
                            .disabled(model.selectedClip == nil)
                        }
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Timebox".uppercased())
                        .cosmoUIFont("Timebox", size: 10, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Text("精细时间范围仍然留在侧栏深处，顶部只保留快速语境。")
                        .cosmoTextFont("精细时间范围仍然留在侧栏深处，顶部只保留快速语境。", size: 12)
                        .foregroundStyle(Color.white.opacity(0.68))
                    TimeboxComposer(draft: $model.timeboxDraft)
                        .disabled(model.isAISearchContextActive)
                        .opacity(model.isAISearchContextActive ? 0.5 : 1)
                }
            }
        }
    }

    private var promptSidebarView: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt Workbench")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(CosmoPalette.ink)
                    Text("蜂巢蒙版只负责快用，这里承接完整编辑、来源追溯与后续扩充。")
                        .cosmoTextFont("蜂巢蒙版只负责快用，这里承接完整编辑、来源追溯与后续扩充。", size: 13)
                        .foregroundStyle(CosmoPalette.textSecondary)
                }

                SidebarSection(title: "Library", subtitle: "系统提示词与自定义提示词在这里统一管理。") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatPill(title: "Prompts", value: "\(model.promptItems.count)")
                        StatPill(title: "System", value: "\(model.promptItems.filter { $0.isSystem }.count)")
                        StatPill(title: "Custom", value: "\(model.promptItems.filter { !$0.isSystem }.count)")
                        StatPill(title: "Selected", value: model.selectedPrompt == nil ? "0" : "1")
                    }
                }

                Divider()
                    .overlay(CosmoPalette.line)

                SidebarSection(title: "Actions", subtitle: "新建、复制和快速进入 Overlay。") {
                    VStack(spacing: 10) {
                        Button {
                            model.createPromptLibraryItem()
                        } label: {
                            Label("Create Prompt", systemImage: "plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.chipSelectedFill, foreground: CosmoPalette.chipSelectedText, border: CosmoPalette.chipSelectedStroke))

                        Button {
                            model.copySelectedPromptContent()
                        } label: {
                            Label("Copy Selected Prompt", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                        .disabled(model.selectedPrompt == nil)

                        Button {
                            model.presentRecallOverlay(initialMode: .promptLibrary)
                        } label: {
                            Label("Open Prompt Hive", systemImage: "hexagon")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(SurfaceButtonStyle(fill: CosmoPalette.surface))
                    }
                }

                Divider()
                    .overlay(CosmoPalette.line)

                SidebarSection(title: "Source", subtitle: "当前选中条目的来源信息保留为只读。") {
                    if let selectedPrompt = model.selectedPrompt {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedPrompt.sourceLabel.isEmpty ? "Custom" : selectedPrompt.sourceLabel)
                                .cosmoTextFont(selectedPrompt.sourceLabel.isEmpty ? "Custom" : selectedPrompt.sourceLabel, size: 13, weight: .medium)
                                .foregroundStyle(CosmoPalette.ink)
                            Text(selectedPrompt.sourceURL.isEmpty ? "No source URL" : selectedPrompt.sourceURL)
                                .cosmoTextFont(selectedPrompt.sourceURL.isEmpty ? "No source URL" : selectedPrompt.sourceURL, size: 12)
                                .foregroundStyle(CosmoPalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CosmoPalette.surfaceSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(CosmoPalette.line, lineWidth: 1)
                                )
                        )
                    } else {
                        Text("Select a prompt to inspect its source.")
                            .cosmoTextFont("Select a prompt to inspect its source.", size: 13)
                            .foregroundStyle(CosmoPalette.textSecondary)
                    }
                }
            }
        }
    }

    private var clipCanvas: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(canvasHeadline)
                    .cosmoDisplayFont(canvasHeadline, size: 29, weight: .semibold)
                    .foregroundStyle(CosmoTheme.textPrimary)
                Text(canvasSubheadline)
                    .cosmoTextFont(canvasSubheadline, size: 13)
                    .foregroundStyle(CosmoTheme.textSecondary)
                if model.isAISearchActive {
                    Text("Query: \(model.activeSearchQuery)")
                        .cosmoUIFont("Query: \(model.activeSearchQuery)", size: 12, weight: .bold)
                        .foregroundStyle(currentSpaceTone.accent)
                }
                if let currentSpace {
                    Text("Current space filter: \(currentSpace.name)")
                        .cosmoUIFont("Current space filter: \(currentSpace.name)", size: 12, weight: .bold)
                        .foregroundStyle(currentSpaceTone.accent)
                }
            }

            if model.displayedClips.isEmpty {
                ContentUnavailableView(
                    model.isAISearchActive ? "No AI matches found" : "No clips found",
                    systemImage: "tray",
                    description: Text(model.isAISearchActive ? "可以尝试换一种自然语言描述，或者返回 Home 回到默认主页。" : "调整筛选条件，或先通过剪贴板 / 当前网页捕获内容。").cosmoTextFont(model.isAISearchActive ? "可以尝试换一种自然语言描述，或者返回 Home 回到默认主页。" : "调整筛选条件，或先通过剪贴板 / 当前网页捕获内容。", size: 14)
                )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else {
                LazyVStack(spacing: 12) {
                    if model.isAISearchActive {
                        ForEach(model.aiSearchResults) { result in
                            clipRowButton(clip: result.clip, searchResult: result)
                        }
                    } else {
                        ForEach(model.clips) { clip in
                            clipRowButton(clip: clip, searchResult: nil)
                        }
                    }
                }
            }
        }
    }

    private var promptLibraryCanvas: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(canvasHeadline)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(CosmoPalette.ink)
                Text(canvasSubheadline)
                    .cosmoTextFont(canvasSubheadline, size: 13)
                    .foregroundStyle(CosmoPalette.textSecondary)
            }

            PromptLibraryWorkbenchView()
                .environmentObject(model)
        }
    }

    private var sidebarPaneView: some View {
        Group {
            if model.backstageModule == .promptLibrary {
                promptSidebarView
            } else {
                clipSidebarView
            }
        }
        .frame(
            minWidth: model.backstageModule == .clips ? 194 : 248,
            idealWidth: model.backstageModule == .clips ? 202 : 260,
            maxWidth: model.backstageModule == .clips ? 208 : 278,
            alignment: .topLeading
        )
    }

    private var contentCanvas: some View {
        ContentPanel(tone: currentSpaceTone, padding: 22) {
            if model.backstageModule == .promptLibrary {
                promptLibraryCanvas
            } else {
                clipCanvas
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var clipInspectorColumn: some View {
        ContentPanel(tone: currentSpaceTone, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Object Studio")
                            .cosmoDisplayFont("Object Studio", size: 24, weight: .semibold)
                            .foregroundStyle(CosmoTheme.textPrimary)
                        Text("当前条目的摘要、分类、标签、笔记与状态，会在这里被精修。")
                            .cosmoTextFont("当前条目的摘要、分类、标签、笔记与状态，会在这里被精修。", size: 12)
                            .foregroundStyle(CosmoTheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if let selectedClip = model.selectedClip {
                        Button {
                            model.presentClipDetail(selectedClip)
                        } label: {
                            ContextChip(title: "View", value: "Expand", tone: currentSpaceTone, icon: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)

                ScrollView {
                    ClipInspectorView(clip: model.selectedClip)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.trailing, 2)
                }
                .scrollIndicators(.never)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 320, idealWidth: 340, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func clipRowButton(clip: ClipItem, searchResult: AISearchResult?) -> some View {
        AdaptiveClipCard(
            clip: clip,
            selected: model.selectedClipID == clip.id,
            searchResult: searchResult,
            actions: clipInlineActions(for: clip),
            tone: currentSpaceTone
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.focusClipInBackstage(clip)
        }
        .contextMenu {
            if clip.status != .trashed {
                Button("标记已读") {
                    model.markClipAsRead(clip)
                }
            }
            Button(clip.isPinned ? "取消置顶" : "置顶") {
                model.togglePin(for: clip)
            }
            Button(clip.status == .trashed ? "彻底删除" : "删除", role: .destructive) {
                model.deleteOrTrash(clip)
            }
            if let searchResult {
                Divider()
                Text(searchResult.source == .semantic ? "AI Match \(Int(searchResult.score * 100))%" : "Fallback \(Int(searchResult.score * 100))%")
                    .cosmoTextFont(searchResult.source == .semantic ? "AI Match \(Int(searchResult.score * 100))%" : "Fallback \(Int(searchResult.score * 100))%", size: 12, weight: .medium)
            }
        }
    }

    private func clipInlineActions(for clip: ClipItem) -> [AdaptiveClipAction] {
        var actions: [AdaptiveClipAction] = []

        if clip.status != .trashed {
            actions.append(
                AdaptiveClipAction(
                    title: "已读",
                    systemImage: "book.closed",
                    tint: currentSpaceTone.accent,
                    action: {
                        model.markClipAsRead(clip)
                    }
                )
            )
        }

        actions.append(
            AdaptiveClipAction(
                title: clip.isPinned ? "取消置顶" : "置顶",
                systemImage: clip.isPinned ? "pin.slash" : "pin",
                tint: CosmoTheme.industrialGold,
                action: {
                    model.togglePin(for: clip)
                }
            )
        )

        actions.append(
            AdaptiveClipAction(
                title: clip.status == .trashed ? "删除" : "移到废纸篓",
                systemImage: "trash",
                tint: Color.red,
                action: {
                    model.deleteOrTrash(clip)
                }
            )
        )

        return actions
    }

    private var suggestedTags: [String] {
        Array(Set(model.spaces.flatMap(\.tags))).sorted()
    }

    @ViewBuilder
    private func overlayBackdrop(_ overlay: AppOverlay) -> some View {
        GeometryReader { proxy in
            let availableWidth = max(320, proxy.size.width - 48)
            let clipDetailHeight = max(360, min(proxy.size.height - 64, 680))

            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.requestCloseOverlay()
                    }

                switch overlay {
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

private struct PromptLibraryWorkbenchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draftTitle = ""
    @State private var draftContent = ""

    private let tone = CosmoTheme.tone(for: "prompt-library")

    private var selectedPrompt: PromptLibraryItem? {
        model.selectedPrompt
    }

    private var hasUnsavedChanges: Bool {
        guard let selectedPrompt else { return false }
        return draftTitle != selectedPrompt.title || draftContent != selectedPrompt.content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WorkbenchSurface(role: .sidebar, tone: tone, padding: 0, showsAccentLine: false) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.promptItems) { item in
                            PromptLibraryListRow(
                                item: item,
                                selected: model.selectedPromptID == item.id,
                                tone: tone,
                                onSelect: {
                                    model.selectPromptItem(item.id)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .frame(minWidth: 280, idealWidth: 300, maxWidth: 320, maxHeight: .infinity)

            WorkbenchSurface(role: .workspace, tone: tone, padding: 18, showsAccentLine: false) {
                PromptLibraryEditorPanel(
                    prompt: selectedPrompt,
                    tone: tone,
                    draftTitle: $draftTitle,
                    draftContent: $draftContent,
                    hasUnsavedChanges: hasUnsavedChanges,
                    onSave: {
                        guard let selectedPrompt else { return }
                        model.savePromptLibraryItemEdits(id: selectedPrompt.id, title: draftTitle, content: draftContent)
                    },
                    onCopy: {
                        model.copySelectedPromptContent()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            syncDrafts(with: selectedPrompt)
        }
        .onChange(of: model.selectedPromptID) { _, _ in
            syncDrafts(with: selectedPrompt)
        }
        .onChange(of: model.promptItems) { _, _ in
            if let selectedPrompt {
                syncDrafts(with: selectedPrompt)
            }
        }
    }

    private func syncDrafts(with prompt: PromptLibraryItem?) {
        draftTitle = prompt?.title ?? ""
        draftContent = prompt?.content ?? ""
    }
}

private struct PromptLibraryListRow: View {
    let item: PromptLibraryItem
    let selected: Bool
    let tone: SpaceTone
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            WorkbenchRow(tone: tone, isSelected: selected, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.title)
                            .cosmoTextFont(item.title, size: 14, weight: .semibold)
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text(item.isSystem ? "System" : "Custom")
                            .cosmoUIFont(item.isSystem ? "System" : "Custom", size: 10, weight: .bold)
                            .foregroundStyle(item.isSystem ? tone.accent : CosmoTheme.textSecondary)
                    }

                    Text(item.sourceLabel.isEmpty ? "Custom" : item.sourceLabel)
                        .cosmoTextFont(item.sourceLabel.isEmpty ? "Custom" : item.sourceLabel, size: 12)
                        .foregroundStyle(CosmoTheme.textSecondary)
                        .lineLimit(1)

                    Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .cosmoTextFont(item.updatedAt.formatted(date: .abbreviated, time: .shortened), size: 11, weight: .medium)
                        .foregroundStyle(CosmoTheme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PromptLibraryEditorPanel: View {
    let prompt: PromptLibraryItem?
    let tone: SpaceTone
    @Binding var draftTitle: String
    @Binding var draftContent: String
    let hasUnsavedChanges: Bool
    let onSave: () -> Void
    let onCopy: () -> Void

    var body: some View {
        if let prompt {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(
                    title: draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? prompt.title : draftTitle,
                    subtitle: "这里承接完整提示词编辑、保存与来源追溯；蜂巢层只负责快速调用。",
                    tone: tone
                ) {
                    HStack(spacing: 8) {
                        Button(action: onCopy) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .secondary))

                        Button(action: onSave) {
                            Label("Save Prompt", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .primary))
                        .disabled(!hasUnsavedChanges)
                    }
                }

                HStack(spacing: 10) {
                    DetailMetaPill(text: prompt.isSystem ? "System Prompt" : "Custom Prompt", tint: prompt.isSystem ? tone.accent : CosmoTheme.textSecondary)
                    if !prompt.sourceLabel.isEmpty {
                        DetailMetaPill(text: prompt.sourceLabel, tint: CosmoTheme.textSecondary)
                    }
                    DetailMetaPill(text: prompt.updatedAt.formatted(date: .abbreviated, time: .shortened), tint: CosmoTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .cosmoUIFont("Title", size: 11, weight: .bold)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    WorkbenchInputShell(tone: tone) {
                        TextField("Prompt title", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .cosmoInputFont()
                            .foregroundStyle(CosmoTheme.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Content")
                            .cosmoUIFont("Content", size: 11, weight: .bold)
                            .foregroundStyle(CosmoTheme.textSecondary)
                        Spacer()
                        Text("\(draftContent.count) chars")
                            .cosmoTextFont("\(draftContent.count) chars", size: 11, weight: .medium)
                            .foregroundStyle(CosmoTheme.textTertiary)
                    }
                    WorkbenchInputShell(tone: tone) {
                        TextEditor(text: $draftContent)
                            .font(CosmoTypography.songti(size: 15))
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 360)
                    }
                }

                if !prompt.sourceURL.isEmpty, let url = URL(string: prompt.sourceURL) {
                    Link(destination: url) {
                        Label("Open Source Reference", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                }
            }
        } else {
            ContentUnavailableView(
                "No prompt selected",
                systemImage: "hexagon",
                description: Text("从左侧选择一个提示词，或者新建一条来开始编辑。").cosmoTextFont("从左侧选择一个提示词，或者新建一条来开始编辑。", size: 14)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DetailMetaPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .cosmoTextFont(text, size: 11, weight: .semibold, design: .rounded)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Rectangle()
                    .fill(CosmoTheme.rowFill)
                    .overlay(
                        Rectangle()
                            .strokeBorder(CosmoTheme.divider, lineWidth: 1)
                    )
            )
    }
}

struct TimeboxComposer: View {
    @Binding var draft: TimeboxDraft
    var tone: SpaceTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mode")
                .cosmoUIFont("Mode", size: 10, weight: .bold, design: .rounded)
                .foregroundStyle(CosmoTheme.textTertiary)
            Picker("Timebox", selection: $draft.mode) {
                Text("All").tag(TimeboxMode.all)
                Text("Past N Hours").tag(TimeboxMode.trailingHours)
                Text("Specific Day").tag(TimeboxMode.day)
                Text("Range").tag(TimeboxMode.range)
            }
            .pickerStyle(.menu)
            .labelsHidden()

            switch draft.mode {
            case .all:
                Text("All time")
                    .cosmoTextFont("All time", size: 12)
                    .foregroundStyle(CosmoTheme.textSecondary)
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
            Rectangle()
                .fill(CosmoTheme.panelGradient(tier: .input, tone: tone))
                .overlay(
                    Rectangle()
                        .strokeBorder(CosmoTheme.divider, lineWidth: 1)
                )
        )
    }
}

private struct TodoWorkbenchView: View {
    @EnvironmentObject private var model: AppModel

    let tone: SpaceTone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchInputShell(tone: tone) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tone.accent)

                    TextField("Add a task to the backstage queue", text: $model.todoDraft)
                        .textFieldStyle(.plain)
                        .cosmoInputFont()
                        .foregroundStyle(CosmoTheme.textPrimary)
                        .onSubmit {
                            model.submitTodoDraft()
                        }

                    Button("Add") {
                        model.submitTodoDraft()
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .primary))
                    .disabled(model.todoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if model.todoItems.isEmpty {
                ContentUnavailableView(
                    "No pending todos",
                    systemImage: "checklist.unchecked",
                    description: Text("在上方直接输入待办，或从 Recall 的 todo cloud 带回一条任务。").cosmoTextFont("在上方直接输入待办，或从 Recall 的 todo cloud 带回一条任务。", size: 14)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.todoItems) { item in
                            TodoWorkbenchRow(item: item, tone: tone)
                                .environmentObject(model)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TodoWorkbenchRow: View {
    @EnvironmentObject private var model: AppModel

    let item: TodoItem
    let tone: SpaceTone

    private var isSelected: Bool {
        model.todoFocusedItemID == item.id
    }

    private var isEditing: Bool {
        model.todoEditingItemID == item.id
    }

    var body: some View {
        WorkbenchRow(tone: tone, isSelected: isSelected, padding: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    model.completeTodo(item.id)
                } label: {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tone.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    if isEditing {
                        TextField("Todo title", text: $model.todoEditingDraft)
                            .textFieldStyle(.plain)
                            .cosmoInputFont()
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .onSubmit {
                                model.finishTodoEditing(commit: true)
                            }
                    } else {
                        Text(item.title)
                            .cosmoTextFont(item.title, size: 14, weight: .semibold)
                            .foregroundStyle(CosmoTheme.textPrimary)
                            .lineLimit(2)
                    }

                    Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .cosmoTextFont(item.updatedAt.formatted(date: .abbreviated, time: .shortened), size: 11)
                        .foregroundStyle(CosmoTheme.textSecondary)
                }

                Spacer(minLength: 8)

                if isEditing {
                    HStack(spacing: 8) {
                        Button("Save") {
                            model.finishTodoEditing(commit: true)
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .primary))

                        Button("Cancel") {
                            model.finishTodoEditing(commit: false)
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                    }
                } else {
                    Button {
                        model.beginTodoEditing(item)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.todoEditingItemID != nil, model.todoEditingItemID != item.id {
                model.finishTodoEditing(commit: true)
            }
            model.selectTodoItem(item.id)
        }
    }
}

private struct ClipboardReadingCard: View {
    @EnvironmentObject private var model: AppModel

    let clip: ClipItem
    @Binding var content: String
    @Binding var category: String
    @Binding var tags: String
    let onCopy: () -> Void
    let onSave: () -> Void

    private var payload: ClipboardReadingPayload? {
        hasUnsavedTextChanges ? nil : clip.readingPayload
    }

    private var tone: SpaceTone {
        if !clip.spaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CosmoTheme.tone(for: clip.spaceName)
        }
        return CosmoTheme.platformTone(for: clip.platformBucket)
    }

    private var isEnglish: Bool {
        isLikelyEnglishText(content)
    }

    private var hasUnsavedTextChanges: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines) != clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clipboard Reading")
                        .cosmoUIFont("Clipboard Reading", size: 11, weight: .bold, design: .rounded)
                        .foregroundStyle(tone.accent)
                    Text(payload?.titleChinese.isEmpty == false ? payload?.titleChinese ?? clip.title : clip.title)
                        .cosmoDisplayFont(payload?.titleChinese.isEmpty == false ? payload?.titleChinese ?? clip.title : clip.title, size: 28, weight: .semibold)
                        .foregroundStyle(CosmoTheme.textPrimary)
                    Text(isEnglish ? "英文原文已整理为双语对照，保留原始段落顺序。" : "纯文本内容已转成更适合沉浸阅读的卡片。")
                        .cosmoTextFont(isEnglish ? "英文原文已整理为双语对照，保留原始段落顺序。" : "纯文本内容已转成更适合沉浸阅读的卡片。", size: 13)
                        .foregroundStyle(CosmoTheme.textSecondary)
                }
                Spacer()
                if isEnglish {
                    Button(model.readingGenerationRunning.contains(clip.id) ? "Generating…" : "Refresh Bilingual") {
                        model.refreshClipboardReading(for: clip.id, force: true)
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                    .disabled(model.readingGenerationRunning.contains(clip.id) || hasUnsavedTextChanges)
                }
            }

            RuleDivider(strong: true)

            if let summary = payload?.summaryChinese, !summary.isEmpty {
                Text(summary)
                    .cosmoTextFont(summary, size: 16)
                    .foregroundStyle(CosmoTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.readingGenerationRunning.contains(clip.id) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在生成双语阅读版…")
                        .cosmoTextFont("正在生成双语阅读版…", size: 14)
                        .foregroundStyle(CosmoTheme.textSecondary)
                }
            } else if hasUnsavedTextChanges && isEnglish {
                Text("当前正文已有未保存修改。保存后会按最新内容重新生成双语对照。")
                    .cosmoTextFont("当前正文已有未保存修改。保存后会按最新内容重新生成双语对照。", size: 13)
                    .foregroundStyle(CosmoTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Text")
                    .cosmoUIFont("Text", size: 11, weight: .bold)
                    .foregroundStyle(CosmoTheme.textSecondary)
                TextEditor(text: $content)
                    .font(CosmoTextClassifier.containsChinese(content) ? CosmoTypography.songti(size: 19) : .custom("Baskerville", size: 19))
                    .foregroundStyle(CosmoTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                RuleDivider()
            }

            VStack(alignment: .leading, spacing: 14) {
                if let payload, !payload.paragraphs.isEmpty {
                    Text("Bilingual Reading")
                        .cosmoUIFont("Bilingual Reading", size: 11, weight: .bold)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    ForEach(Array(payload.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        ClipboardParallelParagraph(paragraph: paragraph, tone: tone)
                    }

                    if payload.isPartial {
                        Text("当前双语对照基于导入内容的前几段自动生成，完整原文仍保留在上方可编辑区域。")
                            .cosmoTextFont("当前双语对照基于导入内容的前几段自动生成，完整原文仍保留在上方可编辑区域。", size: 12)
                            .foregroundStyle(CosmoTheme.textSecondary)
                    }
                }
            }

            RuleDivider()

            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .secondary))

                Button(action: onSave) {
                    Label("Save Clip", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .primary))
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .cosmoUIFont("Category", size: 11, weight: .bold)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    TextField("Category", text: $category)
                        .textFieldStyle(.plain)
                        .font(CosmoTypography.songti(size: 16))
                        .foregroundStyle(CosmoTheme.textPrimary)
                    RuleDivider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .cosmoUIFont("Tags", size: 11, weight: .bold)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    TextField("tag1, tag2", text: $tags)
                        .textFieldStyle(.plain)
                        .font(CosmoTypography.songti(size: 16))
                        .foregroundStyle(CosmoTheme.textPrimary)
                    RuleDivider()
                }
            }
        }
    }
}

private struct ClipboardParallelParagraph: View {
    let paragraph: ClipboardReadingParagraph
    let tone: SpaceTone

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Original")
                    .cosmoUIFont("Original", size: 11, weight: .bold)
                    .foregroundStyle(CosmoTheme.textSecondary)
                Text(paragraph.original)
                    .font(.custom("Baskerville", size: 18))
                    .foregroundStyle(CosmoTheme.textPrimary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }

            if !paragraph.translation.isEmpty {
                RuleDivider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("中文")
                        .cosmoUIFont("中文", size: 11, weight: .bold)
                        .foregroundStyle(CosmoTheme.textSecondary)
                    Text(paragraph.translation)
                        .font(CosmoTypography.songti(size: 18))
                        .foregroundStyle(CosmoTheme.textPrimary)
                        .lineSpacing(8)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct ClipInspectorView: View {
    @EnvironmentObject private var model: AppModel

    let clip: ClipItem?

    @State private var bodyText = ""
    @State private var aiSummary = ""
    @State private var category = ""
    @State private var tags = ""
    @State private var note = ""
    @State private var status: ClipStatus = .inbox

    var body: some View {
        Group {
            if let clip {
                VStack(alignment: .leading, spacing: 16) {
                    standardInspectorBody(for: clip)
                }
                .onAppear {
                    populate(from: clip)
                    updateDirtyState(for: clip)
                    model.refreshAIEnrichment(for: clip.id, force: false)
                    if clip.isPlainTextClipboardCapture {
                        model.refreshClipboardReading(for: clip.id)
                    }
                }
                .onChange(of: clip.id) { _, _ in
                    populate(from: clip)
                    updateDirtyState(for: clip)
                    model.refreshAIEnrichment(for: clip.id, force: false)
                    if clip.isPlainTextClipboardCapture {
                        model.refreshClipboardReading(for: clip.id)
                    }
                }
                .onChange(of: clip.aiSummary) { _, value in
                    guard !model.clipEditorHasUnsavedChanges else { return }
                    aiSummary = value
                    updateDirtyState(for: clip)
                }
                .onChange(of: clip.content) { _, value in
                    guard !model.clipEditorHasUnsavedChanges else { return }
                    bodyText = value
                    updateDirtyState(for: clip)
                }
                .onChange(of: clip.readingPayloadJSON) { _, _ in
                    guard !model.clipEditorHasUnsavedChanges else { return }
                    populate(from: clip)
                    updateDirtyState(for: clip)
                }
                .onChange(of: aiSummary) { _, _ in
                    updateDirtyState(for: clip)
                }
                .onChange(of: bodyText) { _, _ in
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

    @ViewBuilder
    private func standardInspectorBody(for clip: ClipItem) -> some View {
        let tone = inspectorTone(for: clip)
        let isPlainTextClipboard = clip.isPlainTextClipboardCapture
        let hasOriginalURL = !(URL(string: clip.url)?.scheme?.lowercased() == "clipboard")
        let hasUnsavedClipboardTextChanges = isPlainTextClipboard && bodyText.trimmingCharacters(in: .whitespacesAndNewlines) != clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipboardPayload = isPlainTextClipboard && !hasUnsavedClipboardTextChanges ? clip.readingPayload : nil
        let isEnglishClipboard = isPlainTextClipboard && isLikelyEnglishText(bodyText)
        let clipboardLocalizedTitle = clipboardPayload?.titleChinese.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = clipboardLocalizedTitle.isEmpty ? clip.title : clipboardLocalizedTitle

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(clip.platformBucket.title)
                    .cosmoUIFont(clip.platformBucket.title, size: 11, weight: .bold, design: .rounded)
                    .foregroundStyle(tone.accent)
                Text(displayTitle)
                    .cosmoDisplayFont(displayTitle, size: 29, weight: .semibold)
                    .foregroundStyle(CosmoTheme.textPrimary)
                Text(clip.url)
                    .cosmoTextFont(clip.url, size: 13)
                    .foregroundStyle(CosmoTheme.textSecondary)
                    .textSelection(.enabled)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    documentMetaLabel(text: clip.capturedAt.formatted(date: .abbreviated, time: .shortened), tone: tone)
                    documentMetaLabel(text: clip.sourceType == .clipboard ? "clipboard" : "web", tone: tone)
                    if !clip.spaceName.isEmpty {
                        documentMetaLabel(text: clip.spaceName, tone: tone)
                    }
                    if !clip.tags.isEmpty {
                        ForEach(Array(clip.tags.prefix(6)), id: \.self) { tag in
                            documentMetaLabel(text: tag, tone: tone)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if hasOriginalURL {
                    Button {
                        model.openClipURL(clip)
                    } label: {
                        Label("Open Original", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .secondary))
                } else {
                    Button {
                        model.copyText(clip.content)
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .secondary))

                    if isEnglishClipboard {
                        Button {
                            model.refreshClipboardReading(for: clip.id, force: true)
                        } label: {
                            Label(model.readingGenerationRunning.contains(clip.id) ? "Generating…" : "Refresh Bilingual", systemImage: "character.book.closed")
                        }
                        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                        .disabled(model.readingGenerationRunning.contains(clip.id) || hasUnsavedClipboardTextChanges)
                    }
                }

                if hasOriginalURL {
                    Button {
                        model.copyClipURL(clip)
                    } label: {
                        Label("Copy Source", systemImage: "link")
                    }
                    .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                }

                Spacer(minLength: 0)

                Button {
                    model.refreshAIEnrichment(for: clip.id)
                } label: {
                    Label(model.summaryGenerationRunning.contains(clip.id) ? "Analyzing…" : "Refresh Analysis", systemImage: "sparkles")
                }
                .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .ghost))
                .disabled(model.summaryGenerationRunning.contains(clip.id))
            }

            RuleDivider(strong: true)

            documentSection(title: "Summary", subtitle: "AI enrichment 会在首次整理后直接持久化，后续只在你主动刷新或内容变化时重算。") {
                documentTextArea(
                    text: $aiSummary,
                    placeholder: model.summaryGenerationRunning.contains(clip.id) ? "正在深度分析内容并生成摘要与标签…" : "这里会显示持久化后的 AI 摘要。你也可以继续人工精修。",
                    minHeight: 130
                )
            }

            if isPlainTextClipboard {
                documentSection(title: "Text", subtitle: isEnglishClipboard ? "正文在这里保持可编辑，保存后会基于最新文本刷新双语阅读结果。" : "剪贴板内容在这里作为正文继续整理，不再套用独立卡片。") {
                    documentEditor(
                        text: $bodyText,
                        placeholder: "Paste or edit the captured text here",
                        minHeight: 220,
                        font: CosmoTextClassifier.containsChinese(bodyText) ? CosmoTypography.songti(size: 18) : .custom("Baskerville", size: 18)
                    )
                }
            }

            if isPlainTextClipboard {
                documentSection(
                    title: isEnglishClipboard ? "Bilingual Reading" : "Reading Notes",
                    subtitle: isEnglishClipboard ? "双语结果和原文保持同一阅读流，避免再出现独立卡片容器。" : "非英文文本以正文编辑为主，这里保留阅读层信息。"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let summary = clipboardPayload?.summaryChinese, !summary.isEmpty {
                            Text(summary)
                                .cosmoTextFont(summary, size: 15)
                                .foregroundStyle(CosmoTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let clipboardPayload, !clipboardPayload.paragraphs.isEmpty {
                            ForEach(Array(clipboardPayload.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                ClipboardParallelParagraph(paragraph: paragraph, tone: tone)
                            }

                            if clipboardPayload.isPartial {
                                Text("当前双语对照基于导入内容的前几段自动生成，完整原文仍保留在上方正文中。")
                                    .cosmoTextFont("当前双语对照基于导入内容的前几段自动生成，完整原文仍保留在上方正文中。", size: 12)
                                    .foregroundStyle(CosmoTheme.textSecondary)
                            }
                        } else if model.readingGenerationRunning.contains(clip.id) {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在生成双语阅读版…")
                                    .cosmoTextFont("正在生成双语阅读版…", size: 14)
                                    .foregroundStyle(CosmoTheme.textSecondary)
                            }
                        } else if hasUnsavedClipboardTextChanges && isEnglishClipboard {
                            Text("当前正文有未保存修改。先保存，再基于最新文本刷新双语阅读结果。")
                                .cosmoTextFont("当前正文有未保存修改。先保存，再基于最新文本刷新双语阅读结果。", size: 13)
                                .foregroundStyle(CosmoTheme.textSecondary)
                        } else {
                            Text(isEnglishClipboard ? "保存当前正文后，可以继续生成或刷新双语阅读结果。" : "这类条目主要以正文、摘要、标签和笔记为主，不再额外包裹成阅读卡片。")
                                .cosmoTextFont(isEnglishClipboard ? "保存当前正文后，可以继续生成或刷新双语阅读结果。" : "这类条目主要以正文、摘要、标签和笔记为主，不再额外包裹成阅读卡片。", size: 13)
                                .foregroundStyle(CosmoTheme.textSecondary)
                        }
                    }
                }
            }

            documentSection(title: "Category", subtitle: "分类用于给对象一个人类可读的主语义。") {
                documentField(text: $category, placeholder: "例如：产品文档 / 视频 / 技术博客")
            }

            documentSection(title: "Tags", subtitle: "标签按重要性排序：前面是载体属性与结构用途，后面是主题与专有名词。") {
                documentTextArea(
                    text: $tags,
                    placeholder: "article, docs, tutorial, workflow, api, openai, agent, search, macos",
                    minHeight: 110
                )
            }

            documentSection(title: "Notes", subtitle: "把你的判断、批注和后续动作写在对象旁边。") {
                documentTextArea(
                    text: $note,
                    placeholder: "Write editorial notes, synthesis, or next actions",
                    minHeight: 150
                )
            }

            documentSection(title: "Status", subtitle: "文档页脚只保留一个轻量状态切换。") {
                HStack(spacing: 14) {
                    documentStatusButton(.inbox, tone: tone)
                    documentStatusButton(.library, tone: tone)
                    documentStatusButton(.failed, tone: tone)
                    documentStatusButton(.trashed, tone: tone)
                    Spacer(minLength: 0)
                }
            }

            RuleDivider(strong: true)

            Button {
                model.saveClipEdits(
                    id: clip.id,
                    aiSummary: aiSummary,
                    category: category,
                    tagsText: tags,
                    note: note,
                    status: status,
                    contentText: isPlainTextClipboard ? bodyText : nil
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .bold))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Save Clip")
                            .cosmoUIFont("Save Clip", size: 14, weight: .bold)
                        Text("提交当前对象的整理结果")
                            .cosmoTextFont("提交当前对象的整理结果", size: 12)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(CosmoTheme.carbon)
                .padding(.horizontal, 0)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConsoleButtonStyle(tone: tone, variant: .primary))
        }
    }

    private func inspectorTone(for clip: ClipItem) -> SpaceTone {
        if !clip.spaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CosmoTheme.tone(for: clip.spaceName)
        }
        return CosmoTheme.platformTone(for: clip.platformBucket)
    }

    private func documentMetaLabel(text: String, tone: SpaceTone) -> some View {
        Text(text)
            .cosmoUIFont(text, size: 11, weight: .bold, design: .rounded)
            .foregroundStyle(tone.ribbon)
            .padding(.horizontal, 0)
            .padding(.vertical, 2)
    }

    private func documentSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .cosmoDisplayFont(title, size: 19, weight: .semibold)
                .foregroundStyle(CosmoTheme.textPrimary)
            Text(subtitle)
                .cosmoTextFont(subtitle, size: 12)
                .foregroundStyle(CosmoTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func documentField(text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .leading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .cosmoTextFont(placeholder, size: 14)
                        .foregroundStyle(CosmoTheme.textTertiary)
                }
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .cosmoInputFont(size: 15)
                    .foregroundStyle(CosmoTheme.textPrimary)
            }
            RuleDivider()
        }
    }

    private func documentTextArea(text: Binding<String>, placeholder: String, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .cosmoTextFont(placeholder, size: 14)
                        .foregroundStyle(CosmoTheme.textTertiary)
                        .padding(.top, 2)
                }
                TextEditor(text: text)
                    .cosmoInputFont(size: 14)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
            }
            RuleDivider()
        }
    }

    private func documentEditor(text: Binding<String>, placeholder: String, minHeight: CGFloat, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .cosmoTextFont(placeholder, size: 14)
                        .foregroundStyle(CosmoTheme.textTertiary)
                        .padding(.top, 2)
                }
                TextEditor(text: text)
                    .font(font)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
            }
            RuleDivider()
        }
    }

    private func documentStatusButton(_ candidate: ClipStatus, tone: SpaceTone) -> some View {
        Button {
            status = candidate
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(statusLabel(candidate))
                    .cosmoUIFont(statusLabel(candidate), size: 12, weight: .bold, design: .rounded)
                    .foregroundStyle(status == candidate ? CosmoTheme.textPrimary : CosmoTheme.textSecondary)
                Rectangle()
                    .fill(status == candidate ? CosmoTheme.statusColor(for: candidate) : CosmoTheme.divider)
                    .frame(width: 54, height: status == candidate ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusLabel(_ candidate: ClipStatus) -> String {
        switch candidate {
        case .inbox:
            return "Inbox"
        case .library:
            return "Library"
        case .failed:
            return "Failed"
        case .trashed:
            return "Trash"
        }
    }

    private func populate(from clip: ClipItem) {
        bodyText = clip.content
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
            status: status,
            contentText: clip.isPlainTextClipboardCapture ? bodyText : nil
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsContent
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.never)
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
            Text("Recall Overlay 现在是系统级主入口；剪贴板采集保留为辅助快捷键。保存前会先拦截冲突。")
                .foregroundStyle(CosmoPalette.textSecondary)

            if let conflict = model.shortcutConflict {
                Text(conflict)
                    .cosmoTextFont(conflict, size: 14)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12)))
            }

            ShortcutRecorder(label: ShortcutAction.openRecallOverlay.title, combination: $localShortcuts.openRecallOverlay)
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
                .cosmoUIFont(title, size: 10, weight: .bold, design: .rounded)
                .foregroundStyle(Color.white.opacity(0.48))
            Text(value)
                .cosmoDisplayFont(value, size: 20, weight: .semibold)
                .foregroundStyle(.white.opacity(0.96))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
