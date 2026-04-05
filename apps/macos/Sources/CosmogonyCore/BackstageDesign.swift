import AppKit
import SwiftUI

private func themeAdaptiveColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua ? dark : light
    })
}

enum SurfaceTier {
    case canvas
    case rail
    case sidebar
    case workspace
    case inspector
    case row
    case input
    case chrome
    case content
    case overlay
}

enum AccentRole {
    case neutral
    case cobalt
    case rust
    case moss
    case gold
}

enum CosmoRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 14
    static let hero: CGFloat = 14
}

enum CosmoMotion {
    static let quick = Animation.easeInOut(duration: 0.18)
    static let settle = Animation.spring(response: 0.32, dampingFraction: 0.88)
    static let emphasize = Animation.spring(response: 0.38, dampingFraction: 0.82)
}

struct SpaceTone: Equatable {
    let id: String
    let accent: Color
    let accentMuted: Color
    let ribbon: Color
    let glow: Color

    static let neutral = SpaceTone(
        id: "neutral",
        accent: themeAdaptiveColor(
            light: NSColor(red: 0.31, green: 0.40, blue: 0.52, alpha: 1),
            dark: NSColor(red: 0.57, green: 0.67, blue: 0.78, alpha: 1)
        ),
        accentMuted: themeAdaptiveColor(
            light: NSColor(red: 0.70, green: 0.75, blue: 0.81, alpha: 1),
            dark: NSColor(red: 0.30, green: 0.36, blue: 0.43, alpha: 1)
        ),
        ribbon: themeAdaptiveColor(
            light: NSColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1),
            dark: NSColor(red: 0.75, green: 0.79, blue: 0.85, alpha: 1)
        ),
        glow: themeAdaptiveColor(
            light: NSColor(red: 0.85, green: 0.88, blue: 0.94, alpha: 1),
            dark: NSColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1)
        )
    )
}

enum CosmoTheme {
    static let canvasTop = themeAdaptiveColor(
        light: NSColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1),
        dark: NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    )
    static let canvasBottom = themeAdaptiveColor(
        light: NSColor(red: 0.90, green: 0.89, blue: 0.85, alpha: 1),
        dark: NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
    )
    static let railTop = themeAdaptiveColor(
        light: NSColor(red: 0.87, green: 0.85, blue: 0.81, alpha: 0.98),
        dark: NSColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 0.98)
    )
    static let railBottom = themeAdaptiveColor(
        light: NSColor(red: 0.83, green: 0.81, blue: 0.77, alpha: 0.98),
        dark: NSColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 0.99)
    )
    static let sidebarTop = themeAdaptiveColor(
        light: NSColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 0.99),
        dark: NSColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 0.99)
    )
    static let sidebarBottom = themeAdaptiveColor(
        light: NSColor(red: 0.91, green: 0.90, blue: 0.86, alpha: 0.99),
        dark: NSColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 0.99)
    )
    static let workspaceTop = themeAdaptiveColor(
        light: NSColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 0.99),
        dark: NSColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 0.99)
    )
    static let workspaceBottom = themeAdaptiveColor(
        light: NSColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.99),
        dark: NSColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 0.99)
    )
    static let inspectorTop = themeAdaptiveColor(
        light: NSColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 0.99),
        dark: NSColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 0.99)
    )
    static let inspectorBottom = themeAdaptiveColor(
        light: NSColor(red: 0.92, green: 0.91, blue: 0.87, alpha: 0.99),
        dark: NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.99)
    )
    static let rowFill = themeAdaptiveColor(
        light: NSColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.90),
        dark: NSColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 0.94)
    )
    static let rowHoverFill = themeAdaptiveColor(
        light: NSColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 0.96),
        dark: NSColor(red: 0.19, green: 0.20, blue: 0.23, alpha: 0.97)
    )
    static let rowSelectedFill = themeAdaptiveColor(
        light: NSColor(red: 0.92, green: 0.91, blue: 0.86, alpha: 0.98),
        dark: NSColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 0.99)
    )
    static let inputFill = themeAdaptiveColor(
        light: NSColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 0.98),
        dark: NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.98)
    )
    static let chromeBorder = themeAdaptiveColor(
        light: NSColor(red: 0.18, green: 0.17, blue: 0.15, alpha: 0.12),
        dark: NSColor(white: 1.0, alpha: 0.08)
    )
    static let contentBorder = themeAdaptiveColor(
        light: NSColor(red: 0.16, green: 0.16, blue: 0.14, alpha: 0.10),
        dark: NSColor(white: 1.0, alpha: 0.08)
    )
    static let divider = themeAdaptiveColor(
        light: NSColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 0.10),
        dark: NSColor(white: 1.0, alpha: 0.08)
    )
    static let dividerStrong = themeAdaptiveColor(
        light: NSColor(red: 0.14, green: 0.13, blue: 0.12, alpha: 0.16),
        dark: NSColor(white: 1.0, alpha: 0.14)
    )
    static let textPrimary = themeAdaptiveColor(
        light: NSColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1),
        dark: NSColor(red: 0.94, green: 0.93, blue: 0.91, alpha: 1)
    )
    static let textSecondary = themeAdaptiveColor(
        light: NSColor(red: 0.38, green: 0.37, blue: 0.35, alpha: 1),
        dark: NSColor(red: 0.68, green: 0.69, blue: 0.71, alpha: 1)
    )
    static let textTertiary = themeAdaptiveColor(
        light: NSColor(red: 0.49, green: 0.47, blue: 0.45, alpha: 1),
        dark: NSColor(red: 0.53, green: 0.55, blue: 0.59, alpha: 1)
    )
    static let bone = themeAdaptiveColor(
        light: NSColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1),
        dark: NSColor(red: 0.88, green: 0.88, blue: 0.86, alpha: 1)
    )
    static let carbon = themeAdaptiveColor(
        light: NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
        dark: NSColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
    )
    static let haze = themeAdaptiveColor(
        light: NSColor(white: 1.0, alpha: 0.58),
        dark: NSColor(white: 1.0, alpha: 0.04)
    )
    static let industrialGold = themeAdaptiveColor(
        light: NSColor(red: 0.78, green: 0.62, blue: 0.24, alpha: 1),
        dark: NSColor(red: 0.86, green: 0.73, blue: 0.34, alpha: 1)
    )
    static let overlayScrim = Color.black.opacity(0.34)
    static let panelShadow = themeAdaptiveColor(
        light: NSColor(white: 0.0, alpha: 0.06),
        dark: NSColor(white: 0.0, alpha: 0.24)
    )

    static func panelGradient(tier: SurfaceTier, tone: SpaceTone) -> LinearGradient {
        switch tier {
        case .canvas:
            return LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rail:
            return LinearGradient(colors: [railTop, railBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sidebar, .chrome:
            return LinearGradient(colors: [sidebarTop, sidebarBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .workspace, .content, .overlay:
            return LinearGradient(colors: [workspaceTop, workspaceBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .inspector:
            return LinearGradient(colors: [inspectorTop, inspectorBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .row:
            return LinearGradient(colors: [rowFill, rowFill], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .input:
            return LinearGradient(colors: [inputFill, inputFill], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func surfaceBorder(for tier: SurfaceTier) -> Color {
        switch tier {
        case .canvas:
            return divider
        case .rail, .sidebar, .chrome:
            return chromeBorder
        case .workspace, .content, .overlay, .inspector:
            return contentBorder
        case .row, .input:
            return divider
        }
    }

    static func surfaceAccent(for tier: SurfaceTier, tone: SpaceTone) -> Color {
        switch tier {
        case .rail:
            return tone.accent.opacity(0.12)
        case .sidebar, .chrome:
            return tone.accent.opacity(0.10)
        case .workspace, .content, .overlay:
            return tone.accent.opacity(0.18)
        case .inspector:
            return tone.accent.opacity(0.14)
        case .row:
            return tone.accent.opacity(0.22)
        case .input:
            return tone.accent.opacity(0.16)
        case .canvas:
            return tone.accent.opacity(0.08)
        }
    }

    static func rowBackground(selected: Bool, hovered: Bool, tone: SpaceTone) -> Color {
        if selected {
            return themeAdaptiveColor(
                light: NSColor(red: 0.93, green: 0.92, blue: 0.88, alpha: 0.98),
                dark: NSColor(red: 0.19, green: 0.20, blue: 0.23, alpha: 0.99)
            )
        }
        if hovered {
            return rowHoverFill
        }
        return rowFill
    }

    static func buttonFill(tone: SpaceTone, prominent: Bool) -> Color {
        prominent ? tone.accent : themeAdaptiveColor(
            light: NSColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 0.98),
            dark: NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 0.98)
        )
    }

    static func tone(for spaceName: String?, platform: PlatformBucket? = nil) -> SpaceTone {
        if let platform {
            return platformTone(for: platform)
        }

        let trimmed = spaceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return .neutral }

        let tones = [
            SpaceTone(
                id: "cobalt",
                accent: themeAdaptiveColor(light: NSColor(red: 0.22, green: 0.39, blue: 0.67, alpha: 1), dark: NSColor(red: 0.53, green: 0.67, blue: 0.92, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.77, green: 0.84, blue: 0.96, alpha: 1), dark: NSColor(red: 0.23, green: 0.31, blue: 0.42, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.14, green: 0.20, blue: 0.31, alpha: 1), dark: NSColor(red: 0.74, green: 0.82, blue: 0.94, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.84, green: 0.89, blue: 0.99, alpha: 1), dark: NSColor(red: 0.17, green: 0.22, blue: 0.29, alpha: 1))
            ),
            SpaceTone(
                id: "rust",
                accent: themeAdaptiveColor(light: NSColor(red: 0.71, green: 0.29, blue: 0.18, alpha: 1), dark: NSColor(red: 0.89, green: 0.53, blue: 0.42, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.96, green: 0.84, blue: 0.77, alpha: 1), dark: NSColor(red: 0.38, green: 0.24, blue: 0.20, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.33, green: 0.16, blue: 0.12, alpha: 1), dark: NSColor(red: 0.94, green: 0.78, blue: 0.70, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.98, green: 0.90, blue: 0.86, alpha: 1), dark: NSColor(red: 0.25, green: 0.17, blue: 0.15, alpha: 1))
            ),
            SpaceTone(
                id: "moss",
                accent: themeAdaptiveColor(light: NSColor(red: 0.26, green: 0.45, blue: 0.27, alpha: 1), dark: NSColor(red: 0.63, green: 0.82, blue: 0.60, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.84, green: 0.92, blue: 0.83, alpha: 1), dark: NSColor(red: 0.24, green: 0.32, blue: 0.24, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1), dark: NSColor(red: 0.84, green: 0.94, blue: 0.81, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.90, green: 0.96, blue: 0.90, alpha: 1), dark: NSColor(red: 0.17, green: 0.22, blue: 0.16, alpha: 1))
            ),
            SpaceTone(
                id: "gold",
                accent: themeAdaptiveColor(light: NSColor(red: 0.72, green: 0.58, blue: 0.18, alpha: 1), dark: NSColor(red: 0.87, green: 0.77, blue: 0.40, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.95, green: 0.90, blue: 0.75, alpha: 1), dark: NSColor(red: 0.38, green: 0.34, blue: 0.18, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.28, green: 0.23, blue: 0.08, alpha: 1), dark: NSColor(red: 0.94, green: 0.88, blue: 0.67, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.97, green: 0.94, blue: 0.84, alpha: 1), dark: NSColor(red: 0.25, green: 0.21, blue: 0.12, alpha: 1))
            )
        ]

        let hash = trimmed.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult * 33) + Int(scalar.value)) & 0x7fffffff
        }
        return tones[hash % tones.count]
    }

    static func platformTone(for bucket: PlatformBucket) -> SpaceTone {
        switch bucket {
        case .xPosts:
            return tone(for: "x", platform: nil)
        case .rednote:
            return SpaceTone(
                id: "rednote",
                accent: themeAdaptiveColor(light: NSColor(red: 0.79, green: 0.27, blue: 0.31, alpha: 1), dark: NSColor(red: 0.95, green: 0.56, blue: 0.59, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.98, green: 0.83, blue: 0.85, alpha: 1), dark: NSColor(red: 0.36, green: 0.18, blue: 0.22, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.32, green: 0.11, blue: 0.13, alpha: 1), dark: NSColor(red: 0.98, green: 0.78, blue: 0.80, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.99, green: 0.91, blue: 0.92, alpha: 1), dark: NSColor(red: 0.25, green: 0.13, blue: 0.16, alpha: 1))
            )
        case .wechat:
            return tone(for: "wechat-green")
        case .douyin:
            return SpaceTone(
                id: "douyin",
                accent: themeAdaptiveColor(light: NSColor(red: 0.18, green: 0.58, blue: 0.65, alpha: 1), dark: NSColor(red: 0.52, green: 0.86, blue: 0.90, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.81, green: 0.94, blue: 0.95, alpha: 1), dark: NSColor(red: 0.18, green: 0.31, blue: 0.34, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.08, green: 0.24, blue: 0.27, alpha: 1), dark: NSColor(red: 0.78, green: 0.95, blue: 0.98, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.89, green: 0.98, blue: 0.98, alpha: 1), dark: NSColor(red: 0.12, green: 0.22, blue: 0.24, alpha: 1))
            )
        case .youtube:
            return SpaceTone(
                id: "youtube",
                accent: themeAdaptiveColor(light: NSColor(red: 0.82, green: 0.21, blue: 0.17, alpha: 1), dark: NSColor(red: 0.96, green: 0.50, blue: 0.46, alpha: 1)),
                accentMuted: themeAdaptiveColor(light: NSColor(red: 0.99, green: 0.85, blue: 0.81, alpha: 1), dark: NSColor(red: 0.39, green: 0.18, blue: 0.18, alpha: 1)),
                ribbon: themeAdaptiveColor(light: NSColor(red: 0.32, green: 0.08, blue: 0.07, alpha: 1), dark: NSColor(red: 0.98, green: 0.78, blue: 0.76, alpha: 1)),
                glow: themeAdaptiveColor(light: NSColor(red: 0.99, green: 0.91, blue: 0.89, alpha: 1), dark: NSColor(red: 0.24, green: 0.12, blue: 0.12, alpha: 1))
            )
        case .otherWeb:
            return .neutral
        }
    }

    static func statusColor(for status: ClipStatus) -> Color {
        switch status {
        case .inbox:
            return industrialGold
        case .library:
            return themeAdaptiveColor(
                light: NSColor(red: 0.26, green: 0.45, blue: 0.27, alpha: 1),
                dark: NSColor(red: 0.62, green: 0.82, blue: 0.60, alpha: 1)
            )
        case .failed:
            return themeAdaptiveColor(
                light: NSColor(red: 0.71, green: 0.29, blue: 0.18, alpha: 1),
                dark: NSColor(red: 0.89, green: 0.57, blue: 0.44, alpha: 1)
            )
        case .trashed:
            return themeAdaptiveColor(
                light: NSColor(red: 0.47, green: 0.47, blue: 0.50, alpha: 1),
                dark: NSColor(red: 0.63, green: 0.65, blue: 0.68, alpha: 1)
            )
        }
    }
}

enum WorkbenchRole {
    case rail
    case sidebar
    case workspace
    case inspector

    fileprivate var surfaceTier: SurfaceTier {
        switch self {
        case .rail:
            return .rail
        case .sidebar:
            return .sidebar
        case .workspace:
            return .workspace
        case .inspector:
            return .inspector
        }
    }
}

struct BackstageBackdrop: View {
    let tone: SpaceTone

    var body: some View {
        ZStack {
            CosmoTheme.panelGradient(tier: .canvas, tone: tone)

            Rectangle()
                .fill(tone.glow.opacity(0.28))
                .frame(width: 720, height: 720)
                .blur(radius: 120)
                .offset(x: -380, y: -260)

            Rectangle()
                .fill(tone.accent.opacity(0.08))
                .frame(width: 620, height: 360)
                .rotationEffect(.degrees(-10))
                .blur(radius: 28)
                .offset(x: 360, y: 220)

            grid
                .opacity(0.26)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.02),
                            Color.clear,
                            Color.black.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }

    private var grid: some View {
        GeometryReader { proxy in
            Path { path in
                let columns = 12
                let rows = 8
                for column in 0...columns {
                    let x = proxy.size.width * CGFloat(column) / CGFloat(columns)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                }
                for row in 0...rows {
                    let y = proxy.size.height * CGFloat(row) / CGFloat(rows)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(CosmoTheme.divider, lineWidth: 0.8)
        }
    }
}

struct RuleDivider: View {
    var vertical: Bool = false
    var strong: Bool = false

    var body: some View {
        Rectangle()
            .fill(strong ? CosmoTheme.dividerStrong : CosmoTheme.divider)
            .frame(
                width: vertical ? 1 : nil,
                height: vertical ? nil : 1
            )
    }
}

struct WorkbenchSurface<Content: View>: View {
    let role: WorkbenchRole
    let tone: SpaceTone
    var padding: CGFloat
    var showsAccentLine: Bool
    @ViewBuilder var content: Content

    init(
        role: WorkbenchRole,
        tone: SpaceTone,
        padding: CGFloat = 18,
        showsAccentLine: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.tone = tone
        self.padding = padding
        self.showsAccentLine = showsAccentLine
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(surfaceBackground)
    }

    private var surfaceBackground: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(CosmoTheme.panelGradient(tier: role.surfaceTier, tone: tone))

            Rectangle()
                .stroke(CosmoTheme.surfaceBorder(for: role.surfaceTier), lineWidth: 1)

            if showsAccentLine {
                Rectangle()
                    .fill(CosmoTheme.surfaceAccent(for: role.surfaceTier, tone: tone))
                    .frame(height: role == .workspace ? 2 : 1)
            }
        }
        .shadow(
            color: CosmoTheme.panelShadow.opacity(role == .workspace ? 0.95 : 0.65),
            radius: role == .workspace ? 18 : 12,
            x: 0,
            y: role == .workspace ? 10 : 6
        )
    }
}

struct BackstageRail<Content: View>: View {
    let tone: SpaceTone
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(tone: SpaceTone, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        WorkbenchSurface(role: .rail, tone: tone, padding: padding) {
            content
        }
    }
}

struct BackstageSidebar<Content: View>: View {
    let tone: SpaceTone
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(tone: SpaceTone, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        WorkbenchSurface(role: .sidebar, tone: tone, padding: padding) {
            content
        }
    }
}

struct WorkbenchHeader<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let tone: SpaceTone
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        tone: SpaceTone,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .cosmoDisplayFont(title, size: 30, weight: .semibold)
                    .foregroundStyle(CosmoTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .cosmoTextFont(subtitle, size: 13)
                        .foregroundStyle(CosmoTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)
            accessory
        }
    }
}

struct RailButton: View {
    let title: String
    let systemImage: String
    let tone: SpaceTone
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isActive ? tone.ribbon : CosmoTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        Rectangle()
                            .fill(isActive ? tone.accentMuted.opacity(0.75) : Color.clear)
                            .overlay(
                                Rectangle()
                                    .stroke(isActive ? tone.accent.opacity(0.28) : Color.clear, lineWidth: 1)
                            )
                    )

                Text(title)
                    .cosmoUIFont(title, size: 11, weight: .bold)
                    .foregroundStyle(isActive ? CosmoTheme.textPrimary : CosmoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(isActive ? CosmoTheme.rowSelectedFill.opacity(0.92) : Color.clear)
                    if isActive {
                        Rectangle()
                            .fill(tone.accent)
                            .frame(width: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct SidebarDisclosureSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let tone: SpaceTone
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tone: SpaceTone,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tone.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.uppercased())
                            .cosmoUIFont(title.uppercased(), size: 10, weight: .bold)
                            .foregroundStyle(CosmoTheme.textTertiary)
                        if let subtitle {
                            Text(subtitle)
                                .cosmoTextFont(subtitle, size: 12)
                                .foregroundStyle(CosmoTheme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
    }
}

struct WorkbenchRow<Content: View>: View {
    let tone: SpaceTone
    var isSelected: Bool = false
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    @State private var hovering = false

    init(tone: SpaceTone, isSelected: Bool = false, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.isSelected = isSelected
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CosmoTheme.rowBackground(selected: isSelected, hovered: hovering, tone: tone))
                        .overlay(
                            Rectangle()
                                .stroke(isSelected ? tone.accent.opacity(0.22) : CosmoTheme.divider, lineWidth: 1)
                        )
                    if isSelected {
                        Rectangle()
                            .fill(tone.accent)
                            .frame(width: 3)
                    }
                }
            )
            .onHover { hovering = $0 }
    }
}

struct WorkbenchInputShell<Content: View>: View {
    let tone: SpaceTone
    @ViewBuilder var content: Content

    init(tone: SpaceTone, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(CosmoTheme.panelGradient(tier: .input, tone: tone))
                    .overlay(
                        Rectangle()
                            .stroke(tone.accent.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

struct ConsoleButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
        case destructive
    }

    let tone: SpaceTone
    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color
        let border: Color
        let foreground: Color

        switch variant {
        case .primary:
            fill = tone.accent
            border = tone.ribbon.opacity(0.24)
            foreground = CosmoTheme.carbon
        case .secondary:
            fill = CosmoTheme.buttonFill(tone: tone, prominent: false)
            border = tone.accent.opacity(0.10)
            foreground = CosmoTheme.textPrimary
        case .ghost:
            fill = Color.clear
            border = CosmoTheme.divider
            foreground = CosmoTheme.textSecondary
        case .destructive:
            fill = themeAdaptiveColor(
                light: NSColor(red: 0.82, green: 0.30, blue: 0.24, alpha: 0.12),
                dark: NSColor(red: 0.54, green: 0.18, blue: 0.16, alpha: 0.36)
            )
            border = Color.red.opacity(0.22)
            foreground = themeAdaptiveColor(
                light: NSColor(red: 0.58, green: 0.15, blue: 0.13, alpha: 1),
                dark: NSColor(red: 0.97, green: 0.72, blue: 0.70, alpha: 1)
            )
        }

        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.90 : 1))
            .background(
                Rectangle()
                    .fill(fill.opacity(configuration.isPressed ? 0.92 : 1))
                    .overlay(
                        Rectangle()
                            .stroke(border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(CosmoMotion.quick, value: configuration.isPressed)
    }
}

struct ChromePanel<Content: View>: View {
    let tone: SpaceTone
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(tone: SpaceTone, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        WorkbenchSurface(role: .sidebar, tone: tone, padding: padding) {
            content
        }
    }
}

struct ContentPanel<Content: View>: View {
    let tone: SpaceTone
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(tone: SpaceTone, padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        WorkbenchSurface(role: .workspace, tone: tone, padding: padding) {
            content
        }
    }
}

struct ContextChip: View {
    let title: String
    let value: String
    let tone: SpaceTone
    var isActive: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? tone.accent : CosmoTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .cosmoUIFont(title.uppercased(), size: 9, weight: .bold)
                    .foregroundStyle(CosmoTheme.textTertiary)
                Text(value)
                    .cosmoUIFont(value, size: 12, weight: .bold)
                    .foregroundStyle(isActive ? CosmoTheme.textPrimary : CosmoTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Rectangle()
                .fill(isActive ? CosmoTheme.rowSelectedFill : CosmoTheme.rowFill)
                .overlay(
                    Rectangle()
                        .stroke(isActive ? tone.accent.opacity(0.20) : CosmoTheme.divider, lineWidth: 1)
                )
        )
    }
}

struct PrimaryCommandButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: SpaceTone
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(prominent ? CosmoTheme.carbon : tone.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        Rectangle()
                            .fill(prominent ? CosmoTheme.bone : tone.accentMuted.opacity(0.55))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .cosmoUIFont(title, size: 13, weight: .bold)
                        .foregroundStyle(prominent ? CosmoTheme.carbon : CosmoTheme.textPrimary)
                    Text(subtitle)
                        .cosmoTextFont(subtitle, size: 12)
                        .foregroundStyle(prominent ? CosmoTheme.carbon.opacity(0.70) : CosmoTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(ConsoleButtonStyle(tone: tone, variant: prominent ? .primary : .secondary))
    }
}

struct InspectorSection<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String?
    let tone: SpaceTone
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tone: SpaceTone = .neutral,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .cosmoDisplayFont(title, size: 18, weight: .semibold)
                        .foregroundStyle(CosmoTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .cosmoTextFont(subtitle, size: 12)
                            .foregroundStyle(CosmoTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
                accessory
            }

            content
        }
        .padding(14)
        .background(
            Rectangle()
                .fill(CosmoTheme.panelGradient(tier: .row, tone: tone))
                .overlay(
                    Rectangle()
                        .stroke(tone.accent.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct InspectorInputShell<Content: View>: View {
    let tone: SpaceTone
    @ViewBuilder var content: Content

    init(tone: SpaceTone, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        WorkbenchInputShell(tone: tone) {
            content
        }
    }
}

struct AdaptiveClipAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

private enum AdaptiveClipVariant {
    case article
    case video
    case signal
    case clipboard

    static func resolve(for clip: ClipItem) -> AdaptiveClipVariant {
        if clip.isPlainTextClipboardCapture {
            return .clipboard
        }

        switch clip.platformBucket {
        case .youtube:
            return .video
        case .xPosts, .douyin, .rednote:
            return .signal
        case .wechat, .otherWeb:
            return .article
        }
    }
}

struct AdaptiveClipCard: View {
    let clip: ClipItem
    let selected: Bool
    let searchResult: AISearchResult?
    let actions: [AdaptiveClipAction]
    let tone: SpaceTone

    private var variant: AdaptiveClipVariant {
        AdaptiveClipVariant.resolve(for: clip)
    }

    private var platformTone: SpaceTone {
        CosmoTheme.platformTone(for: clip.platformBucket)
    }

    private var statusLabel: String {
        switch clip.status {
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

    private var scoreOrTimestampLabel: String {
        if let searchResult {
            return searchResult.source == .semantic
                ? "AI \(Int(searchResult.score * 100))%"
                : "Fallback \(Int(searchResult.score * 100))%"
        }

        return clip.capturedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var summaryText: String {
        if searchResult?.matchedSnippet.isEmpty == false {
            return searchResult?.matchedSnippet ?? ""
        }

        return clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary
    }

    private var trailingDetailText: String? {
        if let searchResult, !searchResult.matchedFields.isEmpty {
            return searchResult.matchedFields.prefix(4).map(\.label).joined(separator: " · ")
        }

        if !clip.tags.isEmpty {
            return clip.tags.prefix(4).joined(separator: " · ")
        }

        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(platformTone.accent)
                .frame(width: selected ? 8 : 4)

            HStack(alignment: .top, spacing: 16) {
                AdaptiveClipIconBadge(clip: clip, tone: platformTone)

                VStack(alignment: .leading, spacing: 5) {
                    topRow
                    summaryBlock
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .background(
            Rectangle()
                .fill(CosmoTheme.rowBackground(selected: selected, hovered: false, tone: tone))
                .overlay(
                    Rectangle()
                        .stroke(selected ? tone.accent.opacity(0.24) : CosmoTheme.divider, lineWidth: 1)
                )
        )
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(clip.title)
                .cosmoDisplayFont(clip.title, size: 16, weight: .semibold)
                .foregroundStyle(CosmoTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 5) {
                compactBadge(
                    scoreOrTimestampLabel,
                    foreground: searchResult?.source == .semantic ? tone.accent : CosmoTheme.textTertiary,
                    background: searchResult == nil ? CosmoTheme.inputFill : tone.accentMuted.opacity(0.32),
                    isMonospaced: searchResult == nil
                )

                compactBadge(
                    statusLabel.uppercased(),
                    foreground: CosmoTheme.statusColor(for: clip.status),
                    background: CosmoTheme.inputFill
                )

                if clip.isPinned {
                    compactBadge(
                        "PINNED",
                        foreground: platformTone.accent,
                        background: platformTone.accentMuted.opacity(0.32)
                    )
                }

                ForEach(actions) { action in
                    AdaptiveClipActionButton(action: action)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        }
    }

    @ViewBuilder
    private var summaryBlock: some View {
        switch variant {
        case .article:
            Text(summaryText)
                .cosmoTextFont(summaryText, size: 12)
                .foregroundStyle(CosmoTheme.textSecondary)
                .lineLimit(1)
        case .video:
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(platformTone.accent)
                Text(summaryText)
                    .cosmoTextFont(summaryText, size: 12)
                    .foregroundStyle(CosmoTheme.textSecondary)
                    .lineLimit(1)
            }
        case .signal:
            Text(summaryText)
                .cosmoTextFont(summaryText, size: 11)
                .foregroundStyle(CosmoTheme.textSecondary)
                .lineLimit(1)
        case .clipboard:
            Text(summaryText)
                .cosmoTextFont(summaryText, size: 12)
                .foregroundStyle(CosmoTheme.textSecondary)
                .lineLimit(2)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            infoPill(text: clip.domain, tone: platformTone, emphasized: true)
                .fixedSize(horizontal: true, vertical: false)

            if !clip.spaceName.isEmpty {
                infoPill(text: clip.spaceName, tone: tone)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !clip.category.isEmpty {
                infoPill(text: clip.category, tone: platformTone)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if let trailingDetailText {
                Text(trailingDetailText)
                    .cosmoUIFont(trailingDetailText, size: 10, weight: .semibold)
                    .foregroundStyle(searchResult == nil ? CosmoTheme.textTertiary : tone.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private func infoPill(text: String, tone: SpaceTone, emphasized: Bool = false) -> some View {
        Text(text)
            .cosmoUIFont(text, size: 10, weight: .semibold)
            .foregroundStyle(emphasized ? tone.ribbon : CosmoTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Rectangle()
                    .fill(emphasized ? tone.accentMuted.opacity(0.56) : CosmoTheme.inputFill)
            )
    }

    private func compactBadge(
        _ text: String,
        foreground: Color,
        background: Color,
        isMonospaced: Bool = false
    ) -> some View {
        Group {
            if isMonospaced {
                Text(text)
                    .cosmoMonoFont(size: 10, weight: .semibold)
            } else {
                Text(text)
                    .cosmoUIFont(text, size: 10, weight: .bold, design: .rounded)
            }
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Rectangle()
                .fill(background)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct AdaptiveClipActionButton: View {
    let action: AdaptiveClipAction

    var body: some View {
        Button(action: action.action) {
            Image(systemName: action.systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(action.tint)
                .frame(width: 22, height: 22)
                .background(
                    Rectangle()
                        .fill(action.tint.opacity(0.12))
                        .overlay(
                            Rectangle()
                                .strokeBorder(action.tint.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(action.title)
    }
}

private struct AdaptiveClipIconBadge: View {
    let clip: ClipItem
    let tone: SpaceTone

    @StateObject private var model: SiteIconViewModel

    init(clip: ClipItem, tone: SpaceTone) {
        self.clip = clip
        self.tone = tone
        _model = StateObject(wrappedValue: SiteIconViewModel(urlString: clip.url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(clip.platformBucket.title)
                .cosmoUIFont(clip.platformBucket.title, size: 9, weight: .bold, design: .rounded)
                .foregroundStyle(tone.ribbon)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 54, alignment: .leading)

            Rectangle()
                .fill(tone.accentMuted.opacity(0.70))
                .frame(width: 38, height: 38)
                .overlay {
                    Group {
                        if let image = model.image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        } else {
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(tone.ribbon)
                        }
                    }
                    .clipShape(Rectangle())
                }
        }
        .task(id: clip.url) {
            await model.loadIfNeeded()
        }
    }

    private var fallbackIcon: String {
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
            return clip.isPlainTextClipboardCapture ? "doc.text" : "globe"
        }
    }
}
