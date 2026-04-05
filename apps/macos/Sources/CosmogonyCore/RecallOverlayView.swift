import AppKit
import Carbon
import SwiftUI

public struct RecallOverlayRootView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focusedField: OverlayFocusField?
    @State private var todoHoverID: String?
    @State private var promptHoverID: String?

    public init() {}

    private var hasQuery: Bool {
        !SemanticSearchToolkit.normalizedQuery(model.searchDraft).isEmpty
    }

    private var recallStatusLine: String {
        switch model.aiSearchStatus {
        case .idle:
            return "先写下你还记得的碎片，哪怕只有时间、平台或一句模糊描述。"
        case .indexing:
            return "AI 正在翻阅更长的正文片段，把零散记忆压缩成可检索线索。"
        case .searching:
            return "AI 正在理解你的描述，并持续重排候选可能性。"
        case .complete:
            return "更接近的候选已经浮现，继续补充细节会让排序更稳定。"
        case .lexicalFallback:
            return "语义结果不够稳定，系统已补入本地词法线索继续召回。"
        case .semanticUnavailable:
            return "语义能力暂时不可用，系统正在用本地线索维持召回。"
        case .failed:
            return "这次 AI 推断中断了，当前候选已回退为本地结果。"
        }
    }

    private var todoStatusLine: String {
        "Enter 新建待办 · Tab 切换视图 · Cmd+单击完成 · 双击快速编辑"
    }

    private var promptStatusLine: String {
        "单击复制 · 双击改标题 · Cmd+单击进入后台编辑 · Tab 切换视图"
    }

    public var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(760, proxy.size.width - 120)
            let previewOffset = min(240, proxy.size.height * 0.23)
            let candidateTopInset = (proxy.size.height * 0.5) + 82
            let candidateHeight = max(200, proxy.size.height - candidateTopInset - 40)
            let cloudWidth = min(max(contentWidth + 240, 900), proxy.size.width - 56)
            let cloudHeight = min(proxy.size.height - 96, 760)
            let overlayHorizontalPadding = model.overlayMode == .promptLibrary ? 0.0 : 28.0
            let overlayVerticalPadding = model.overlayMode == .promptLibrary ? 0.0 : 48.0

            ZStack {
                RecallBackdrop(mode: model.overlayMode)

                switch model.overlayMode {
                case .recall:
                    recallScene(
                        contentWidth: contentWidth,
                        previewOffset: previewOffset,
                        candidateTopInset: candidateTopInset,
                        candidateHeight: candidateHeight
                    )
                case .todo:
                    todoScene(contentWidth: contentWidth, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                case .promptLibrary:
                    promptScene(in: proxy.size)
                }

                if let toast = model.overlayToast {
                    overlayToastView(message: toast.message)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 26)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .padding(.horizontal, overlayHorizontalPadding)
            .padding(.vertical, overlayVerticalPadding)
        }
        .ignoresSafeArea()
        .modifier(OverlayKeyboardMonitor())
        .onAppear {
            normalizeRecallSelection()
            focusPrimaryFieldSoon()
        }
        .onChange(of: model.aiSearchResults.map(\.id)) { _, _ in
            normalizeRecallSelection()
        }
        .onChange(of: model.searchDraft) { _, _ in
            guard model.overlayMode == .recall else { return }
            model.scheduleAISearch()
        }
        .onChange(of: model.overlayMode) { _, _ in
            focusPrimaryFieldSoon()
        }
        .onChange(of: model.todoEditingItemID) { _, nextID in
            if let nextID {
                DispatchQueue.main.async {
                    focusedField = .todoEdit(nextID)
                }
            } else if model.overlayMode == .todo {
                focusPrimaryFieldSoon()
            }
        }
        .onChange(of: model.promptRenamingItemID) { _, nextID in
            if let nextID {
                DispatchQueue.main.async {
                    focusedField = .promptRename(nextID)
                }
            } else if model.overlayMode == .promptLibrary {
                focusedField = nil
            }
        }
        .onChange(of: focusedField) { _, nextField in
            if let editingID = model.todoEditingItemID, nextField != .todoEdit(editingID) {
                model.finishTodoEditing(commit: true)
            }
            if let renamingID = model.promptRenamingItemID, nextField != .promptRename(renamingID) {
                model.finishPromptRenaming(commit: true)
            }
        }
    }

    @ViewBuilder
    private func recallScene(
        contentWidth: CGFloat,
        previewOffset: CGFloat,
        candidateTopInset: CGFloat,
        candidateHeight: CGFloat
    ) -> some View {
        previewSection
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -previewOffset)
            .zIndex(2)

        VStack(spacing: 12) {
            recallSearchTrack
            overlayStatusCaption(text: recallStatusLine)
        }
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 6)
        .zIndex(3)

        recallCandidateSection(maxHeight: candidateHeight)
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, candidateTopInset)
            .zIndex(1)
    }

    private func todoScene(contentWidth: CGFloat, cloudWidth: CGFloat, cloudHeight: CGFloat) -> some View {
        ZStack {
            todoCloud(width: cloudWidth, height: cloudHeight)

            VStack(spacing: 14) {
                todoComposerTrack(width: contentWidth)
                overlayStatusCaption(text: todoStatusLine)
                    .frame(width: contentWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .zIndex(3)
        }
        .frame(width: cloudWidth, height: cloudHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.todoEditingItemID != nil {
                model.finishTodoEditing(commit: true)
            }
        }
    }

    private func promptScene(in size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            promptHive(in: size)
                .frame(width: size.width, height: size.height)

            overlayStatusCaption(text: promptStatusLine)
                .frame(width: min(size.width - 84, 760))
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.promptRenamingItemID != nil {
                model.finishPromptRenaming(commit: true)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let result = model.recallHighlightedResult {
            RecallPreviewCard(
                result: result,
                onOpenOriginal: {
                    model.openRecallHighlightedResultURL()
                },
                onEnterBackstage: {
                    model.enterBackstageFromRecall()
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 210)
        }
    }

    private var recallSearchTrack: some View {
        sharedTrackContainer(isActive: hasQuery || model.aiSearchStatus.isBusy) {
            HStack(spacing: 14) {
                backstageButton

                TextField("", text: $model.searchDraft)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .recallSearch)
                    .font(CosmoTypography.songti(size: 19))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .padding(.vertical, 1)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await model.submitAISearch(forceImmediate: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

                if model.aiSearchStatus.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.white.opacity(0.72))
                }
            }
        }
    }

    private func todoComposerTrack(width: CGFloat) -> some View {
        sharedTrackContainer(isActive: !model.todoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.todoEditingItemID != nil) {
            HStack(spacing: 14) {
                backstageButton

                TextField("", text: $model.todoDraft)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .todoComposer)
                    .font(CosmoTypography.songti(size: 19))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.vertical, 1)
                    .submitLabel(.done)
                    .onSubmit {
                        model.submitTodoDraft()
                    }
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

                Text("Todo")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(RecallResultPalette.champagne.opacity(0.58))
            }
        }
        .frame(width: width)
    }

    private func sharedTrackContainer<Content: View>(isActive: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.052 : 0.034),
                            Color.white.opacity(isActive ? 0.022 : 0.014)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(isActive ? 0.044 : 0.024), lineWidth: 0.75)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 18)
    }

    private var backstageButton: some View {
        Button {
            model.enterBackstageFromOverlay()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.038))
                )
        }
        .buttonStyle(.plain)
        .help("进入后台工作台")
    }

    private func overlayStatusCaption(text: String) -> some View {
        Text(text)
            .font(CosmoTypography.songti(size: 13))
            .foregroundStyle(Color.white.opacity(0.36))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func recallCandidateSection(maxHeight: CGFloat) -> some View {
        if !model.recallResults.isEmpty {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(model.recallResults) { result in
                        RecallCandidateRow(
                            result: result,
                            selected: model.recallHighlightedResult?.id == result.id,
                            onSelect: {
                                model.setRecallHighlightedResult(result.id)
                            }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight, alignment: .top)
            .contentShape(Rectangle())
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if hasQuery || model.aiSearchStatus.isBusy {
            VStack(spacing: 10) {
                Text(model.aiSearchStatus.isBusy ? "正在让结果浮现…" : "暂时还没有更接近的候选")
                    .font(CosmoTypography.songti(size: 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                Text("继续补充平台、时间、关键词、作者或一句你模糊记得的表达。")
                    .font(CosmoTypography.songti(size: 14))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            Spacer()
                .frame(height: 180)
        }
    }

    private func todoCloud(width: CGFloat, height: CGFloat) -> some View {
        let entries = todoLayoutEntries(in: CGSize(width: width, height: height))

        return ZStack {
            ForEach(entries) { entry in
                TodoCloudWord(
                    item: entry.item,
                    fontSize: entry.fontSize,
                    isHovering: todoHoverID == entry.item.id,
                    isFocused: model.todoFocusedItemID == entry.item.id,
                    isEditing: model.todoEditingItemID == entry.item.id,
                    editBinding: Binding(
                        get: { model.todoEditingDraft },
                        set: { model.todoEditingDraft = $0 }
                    ),
                    focusField: $focusedField,
                    onHover: { isHovering in
                        todoHoverID = isHovering ? entry.item.id : (todoHoverID == entry.item.id ? nil : todoHoverID)
                        if isHovering {
                            model.selectTodoItem(entry.item.id)
                        }
                    },
                    onSelect: {
                        if model.todoEditingItemID != nil, model.todoEditingItemID != entry.item.id {
                            model.finishTodoEditing(commit: true)
                        }
                        model.selectTodoItem(entry.item.id)
                    },
                    onComplete: {
                        model.completeTodo(entry.item.id)
                    },
                    onBeginEdit: {
                        model.beginTodoEditing(entry.item)
                    },
                    onCommitEdit: {
                        model.finishTodoEditing(commit: true)
                    }
                )
                .position(x: width / 2 + entry.offset.width, y: height / 2 + entry.offset.height)
                .zIndex(entry.zIndex)
            }
        }
        .frame(width: width, height: height)
        .animation(.easeInOut(duration: 0.22), value: model.todoItems.map(\.id))
    }

    private func promptHive(in size: CGSize) -> some View {
        let entries = promptLayoutEntries(in: size)

        return ZStack {
            PromptHiveAtmosphere()
                .frame(width: size.width, height: size.height)

            if entries.isEmpty {
                VStack(spacing: 10) {
                    Text("提示词库还没有可用条目")
                        .font(CosmoTypography.songti(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text("后台工作台里可以继续补充和编辑完整提示词。")
                        .font(CosmoTypography.songti(size: 14))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
            }

            ForEach(entries) { entry in
                PromptHiveTile(
                    item: entry.item,
                    size: entry.size,
                    isHovering: promptHoverID == entry.item.id,
                    isSelected: model.selectedPromptID == entry.item.id,
                    isRenaming: model.promptRenamingItemID == entry.item.id,
                    renameBinding: Binding(
                        get: { model.promptRenamingDraft },
                        set: { model.promptRenamingDraft = $0 }
                    ),
                    focusField: $focusedField,
                    onHover: { isHovering in
                        promptHoverID = isHovering ? entry.item.id : (promptHoverID == entry.item.id ? nil : promptHoverID)
                        if isHovering {
                            model.selectPromptItem(entry.item.id)
                        }
                    },
                    onCopy: {
                        model.copyPromptLibraryContent(entry.item)
                    },
                    onBeginRename: {
                        model.beginPromptRenaming(entry.item)
                    },
                    onCommitRename: {
                        model.finishPromptRenaming(commit: true)
                    },
                    onEnterBackstage: {
                        model.enterBackstageForPromptLibrary(entry.item.id)
                    }
                )
                .position(x: size.width / 2 + entry.offset.width, y: size.height / 2 + entry.offset.height)
                .zIndex(promptHoverID == entry.item.id ? 3 : model.selectedPromptID == entry.item.id ? 2 : 1)
            }
        }
        .frame(width: size.width, height: size.height)
        .mask(
            PromptSoftEdgeMask(
                inset: 26,
                blur: 52,
                cornerRadius: min(size.width, size.height) * 0.18
            )
        )
        .animation(.easeInOut(duration: 0.24), value: model.promptItems.map(\.id))
    }

    private func todoLayoutEntries(in size: CGSize) -> [TodoCloudEntry] {
        let items = model.todoItems
        guard !items.isEmpty else { return [] }

        let slotsPerRing = 8
        let centerClearHalfHeight: CGFloat = 98
        let centerClearHalfWidth: CGFloat = 250
        let maxRadiusX = max(220, (size.width * 0.5) - 110)
        let maxRadiusY = max(170, (size.height * 0.5) - 90)

        return items.enumerated().map { index, item in
            let ring = index / slotsPerRing
            let slot = index % slotsPerRing
            let ringProgress = CGFloat(ring + 1)
            let baseAngle = (Double(slot) / Double(slotsPerRing)) * (.pi * 2) - (.pi / 2)
            let jitter = Double((item.visualSeed % 41) - 20) * 0.011
            let angle = baseAngle + jitter

            let xRadius = min(maxRadiusX, 230 + (ringProgress * 78) + CGFloat(item.visualSeed % 27))
            let yRadius = min(maxRadiusY, 126 + (ringProgress * 56) + CGFloat((item.visualSeed / 13) % 21))

            var x = CGFloat(cos(angle)) * xRadius
            var y = CGFloat(sin(angle)) * yRadius

            if abs(y) < centerClearHalfHeight {
                let push = centerClearHalfHeight + CGFloat((item.visualSeed % 22) + 20)
                y = y < 0 ? -push : push
            }
            if abs(x) < centerClearHalfWidth && abs(y) < centerClearHalfHeight + 24 {
                let push = centerClearHalfWidth + CGFloat((item.visualSeed % 28) + 18)
                x = x < 0 ? -push : push
            }

            x = max(-size.width * 0.5 + 90, min(size.width * 0.5 - 90, x))
            y = max(-size.height * 0.5 + 80, min(size.height * 0.5 - 80, y))

            let fontSize = todoFontSize(for: item)
            let zIndex = Double(fontSize) + Double(max(0, 6 - ring))

            return TodoCloudEntry(item: item, offset: CGSize(width: x, height: y), fontSize: fontSize, zIndex: zIndex)
        }
    }

    private func promptLayoutEntries(in size: CGSize) -> [PromptHiveEntry] {
        let items = model.promptItems
        guard !items.isEmpty else { return [] }

        let configuration = promptGridConfiguration(for: items.count, in: size)
        let columns = configuration.columns
        let rows = configuration.rows
        let tileSize = CGSize(width: configuration.tileWidth, height: configuration.tileHeight)
        let countsByColumn = balancedPromptColumnCounts(itemCount: items.count, columns: columns)
        let xOrigin = -CGFloat(columns - 1) * configuration.pitchX / 2
        let yOrigin = -(CGFloat(rows) * configuration.pitchY / 2) + (configuration.pitchY / 4)

        var itemIndex = 0
        var entries: [PromptHiveEntry] = []
        entries.reserveCapacity(items.count)

        for columnIndex in 0..<columns {
            let count = countsByColumn[columnIndex]
            guard count > 0 else { continue }

            let startRow = max(0, (rows - count) / 2)
            let columnOffsetY = columnIndex.isMultiple(of: 2) ? 0.0 : (configuration.pitchY / 2)

            for localRow in 0..<count {
                guard itemIndex < items.count else { break }

                let rowIndex = startRow + localRow
                let x = xOrigin + CGFloat(columnIndex) * configuration.pitchX
                let y = yOrigin + CGFloat(rowIndex) * configuration.pitchY + columnOffsetY

                entries.append(
                    PromptHiveEntry(
                        item: items[itemIndex],
                        offset: CGSize(width: x, height: y),
                        size: tileSize
                    )
                )
                itemIndex += 1
            }
        }

        return entries
    }

    private func promptGridConfiguration(for itemCount: Int, in size: CGSize) -> PromptGridConfiguration {
        let overscanWidth = size.width + 180
        let overscanHeight = size.height + 140
        let aspectRatio = max(0.75, overscanWidth / max(overscanHeight, 1))
        let preferredMinimumColumns = max(4, Int(floor(sqrt(Double(itemCount)) * 0.7)))
        let minimumColumns = min(itemCount, preferredMinimumColumns)
        let preferredMaximumColumns = max(minimumColumns, Int(ceil(sqrt(CGFloat(itemCount) * aspectRatio))) + 4)
        let maximumColumns = min(itemCount, preferredMaximumColumns)

        var best = PromptGridConfiguration(columns: minimumColumns, rows: itemCount, tileWidth: 150)
        var bestScore = CGFloat.leastNormalMagnitude

        for columns in minimumColumns...maximumColumns {
            let rows = Int(ceil(Double(itemCount) / Double(columns)))
            let tileWidthByWidth = overscanWidth / (1 + (CGFloat(columns - 1) * 0.75))
            let tileWidthByHeight = overscanHeight / (HexagonShape.regularHeightRatio * (CGFloat(rows) + 0.5))
            let tileWidth = floor(min(tileWidthByWidth, tileWidthByHeight))

            guard tileWidth >= 138 else { continue }

            let configuration = PromptGridConfiguration(columns: columns, rows: rows, tileWidth: tileWidth)
            let widthFill = configuration.occupiedWidth / max(size.width, 1)
            let heightFill = configuration.occupiedHeight / max(size.height, 1)
            let emptySlots = CGFloat((columns * rows) - itemCount)
            let score = min(widthFill, 1.18) * 1.35
                + min(heightFill, 1.18) * 1.15
                + (tileWidth / 260)
                - (abs(widthFill - heightFill) * 0.28)
                - (emptySlots * 0.032)

            if score > bestScore {
                best = configuration
                bestScore = score
            }
        }

        return best
    }

    private func balancedPromptColumnCounts(itemCount: Int, columns: Int) -> [Int] {
        guard columns > 0 else { return [] }

        let base = itemCount / columns
        let remainder = itemCount % columns
        var counts = Array(repeating: base, count: columns)
        let start = max(0, (columns - remainder) / 2)

        for index in 0..<remainder {
            let target = min(columns - 1, start + index)
            counts[target] += 1
        }

        return counts
    }

    private func todoFontSize(for item: TodoItem) -> CGFloat {
        let titleLength = item.title.count
        let ageHours = max(0, Date().timeIntervalSince(item.updatedAt) / 3_600)
        let recencyBoost: CGFloat
        switch ageHours {
        case ..<12:
            recencyBoost = 2
        case ..<72:
            recencyBoost = 1
        default:
            recencyBoost = 0
        }

        let lengthAdjustment: CGFloat
        switch titleLength {
        case ..<7:
            lengthAdjustment = 4
        case ..<13:
            lengthAdjustment = 2
        case ..<22:
            lengthAdjustment = 0
        default:
            lengthAdjustment = -2
        }

        return max(18, min(34, 20 + recencyBoost + lengthAdjustment))
    }

    private func normalizeRecallSelection() {
        guard !model.recallResults.isEmpty else { return }
        if let highlightedID = model.recallHighlightedResultID,
           model.recallResults.contains(where: { $0.id == highlightedID }) {
            return
        }
        if let first = model.recallResults.first {
            model.setRecallHighlightedResult(first.id)
        }
    }

    private func focusPrimaryFieldSoon() {
        DispatchQueue.main.async {
            switch model.overlayMode {
            case .recall:
                focusedField = .recallSearch
            case .todo:
                focusedField = model.todoEditingItemID.map(OverlayFocusField.todoEdit) ?? .todoComposer
            case .promptLibrary:
                focusedField = model.promptRenamingItemID.map(OverlayFocusField.promptRename)
            }
        }
    }

    private func overlayToastView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.72, green: 0.88, blue: 0.75))
            Text(message)
                .font(CosmoTypography.songti(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.94))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.60))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

private enum OverlayFocusField: Hashable {
    case recallSearch
    case todoComposer
    case todoEdit(String)
    case promptRename(String)
}

private struct TodoCloudEntry: Identifiable {
    let item: TodoItem
    let offset: CGSize
    let fontSize: CGFloat
    let zIndex: Double

    var id: String { item.id }
}

private struct PromptHiveEntry: Identifiable {
    let item: PromptLibraryItem
    let offset: CGSize
    let size: CGSize

    var id: String { item.id }
}

private struct PromptGridConfiguration {
    let columns: Int
    let rows: Int
    let tileWidth: CGFloat

    var tileHeight: CGFloat {
        tileWidth * HexagonShape.regularHeightRatio
    }

    var pitchX: CGFloat {
        tileWidth * 0.75
    }

    var pitchY: CGFloat {
        tileHeight
    }

    var occupiedWidth: CGFloat {
        tileWidth * (1 + (CGFloat(columns - 1) * 0.75))
    }

    var occupiedHeight: CGFloat {
        tileHeight * (CGFloat(rows) + 0.5)
    }
}

private struct RecallBackdrop: View {
    let mode: OverlayMode

    var body: some View {
        Group {
            if mode == .promptLibrary {
                promptLibraryBackdrop
            } else {
                standardBackdrop
            }
        }
        .ignoresSafeArea()
    }

    private var standardBackdrop: some View {
        ZStack {
            Color.black.opacity(mode == .todo ? 0.08 : 0.10)

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(0.985), location: 0.0),
                    .init(color: Color.black.opacity(0.952), location: 0.18),
                    .init(color: Color.black.opacity(0.84), location: 0.44),
                    .init(color: Color.black.opacity(0.54), location: 0.72),
                    .init(color: Color.black.opacity(0.18), location: 0.90),
                    .init(color: Color.clear, location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: mode == .todo ? 1_020 : 1_080
            )

            Circle()
                .fill(Color.black.opacity(0.23))
                .frame(width: mode == .todo ? 900 : 940, height: mode == .todo ? 900 : 940)
                .blur(radius: 68)

            Circle()
                .fill(Color(red: 0.12, green: 0.34, blue: 0.54).opacity(mode == .todo ? 0.13 : 0.16))
                .frame(width: 620, height: 620)
                .blur(radius: 76)
                .offset(x: -240, y: -180)

            Circle()
                .fill(Color(red: 0.70, green: 0.55, blue: 0.35).opacity(mode == .todo ? 0.11 : 0.09))
                .frame(width: 560, height: 560)
                .blur(radius: 78)
                .offset(x: 250, y: 190)

            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(Color.white.opacity(0.020))
                .frame(width: mode == .todo ? 880 : 780, height: mode == .todo ? 320 : 280)
                .rotationEffect(.degrees(-12))
                .blur(radius: 44)
                .offset(y: 160)
        }
    }

    private var promptLibraryBackdrop: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.05),
                        Color(red: 0.04, green: 0.04, blue: 0.05),
                        Color(red: 0.06, green: 0.05, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                PromptHiveAtmosphere()
                    .frame(width: size.width, height: size.height)
                    .mask(
                        PromptSoftEdgeMask(
                            inset: 18,
                            blur: 72,
                            cornerRadius: min(size.width, size.height) * 0.22
                        )
                    )

                Circle()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: max(size.width, size.height) * 0.96, height: max(size.width, size.height) * 0.96)
                    .blur(radius: 82)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.18),
                                Color.clear,
                                Color.black.opacity(0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

private struct PromptHiveAtmosphere: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.07, green: 0.18, blue: 0.32).opacity(0.34))
                .frame(width: 1080, height: 820)
                .blur(radius: 108)
                .offset(x: -320, y: -200)

            Ellipse()
                .fill(Color(red: 0.72, green: 0.54, blue: 0.22).opacity(0.24))
                .frame(width: 980, height: 740)
                .blur(radius: 112)
                .offset(x: 310, y: 180)

            RoundedRectangle(cornerRadius: 280, style: .continuous)
                .fill(Color.white.opacity(0.026))
                .frame(width: 1140, height: 460)
                .rotationEffect(.degrees(-11))
                .blur(radius: 64)
                .offset(y: 70)
        }
    }
}

private struct PromptSoftEdgeMask: View {
    let inset: CGFloat
    let blur: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white)
            .padding(inset)
            .blur(radius: blur)
            .padding(-blur * 1.15)
    }
}

private struct RecallPreviewCard: View {
    let result: AISearchResult
    let onOpenOriginal: () -> Void
    let onEnterBackstage: () -> Void

    private var accent: Color {
        RecallResultPalette.accent(for: result.clip.platformBucket)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.clip.title)
                        .font(CosmoTypography.font(for: result.clip.title, size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    RecallResultPalette.champagne.opacity(0.96),
                                    accent.opacity(0.72),
                                    Color.white.opacity(0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(2)
                    Text(result.matchedSnippet)
                        .font(CosmoTypography.songti(size: 16))
                        .foregroundStyle(RecallResultPalette.body.opacity(0.78))
                        .lineSpacing(5)
                        .lineLimit(4)
                }

                Spacer(minLength: 18)

                VStack(alignment: .trailing, spacing: 10) {
                    Button("打开原文") {
                        onOpenOriginal()
                    }
                    .buttonStyle(RecallGlassButtonStyle(emphasis: .solid))

                    Button("进入后台") {
                        onEnterBackstage()
                    }
                    .buttonStyle(RecallGlassButtonStyle(emphasis: .soft))
                }
            }

            HStack(spacing: 12) {
                RecallMetaPill(text: result.clip.platformBucket.title)
                RecallMetaPill(text: result.clip.domain)
                RecallMetaPill(text: result.clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                RecallMetaPill(text: result.source == .semantic ? "AI 语义召回" : "本地补全召回")
                if let field = result.matchedFields.first {
                    RecallMetaPill(text: field.label)
                }
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.048))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.045), lineWidth: 0.75)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 18)
    }
}

private struct RecallMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CosmoTypography.songti(size: 12))
            .foregroundStyle(RecallResultPalette.meta.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(RecallResultPalette.champagne.opacity(0.032))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(RecallResultPalette.champagne.opacity(0.048), lineWidth: 0.75)
                    )
            )
    }
}

private struct RecallCandidateRow: View {
    let result: AISearchResult
    let selected: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    private var accent: Color {
        RecallResultPalette.accent(for: result.clip.platformBucket)
    }

    private var titleTone: Color {
        selected ? RecallResultPalette.champagne.opacity(0.94) : accent.opacity(0.78)
    }

    private var snippetTone: Color {
        selected ? RecallResultPalette.body.opacity(0.74) : RecallResultPalette.body.opacity(0.54)
    }

    private var metaTone: Color {
        selected ? RecallResultPalette.meta.opacity(0.78) : RecallResultPalette.meta.opacity(0.58)
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(selected ? 0.14 : 0.05))
                    Image(systemName: platformIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? RecallResultPalette.champagne.opacity(0.92) : accent.opacity(0.68))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(result.clip.title)
                            .font(CosmoTypography.font(for: result.clip.title, size: 17, weight: .semibold))
                            .foregroundStyle(titleTone)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Text(result.clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(metaTone.opacity(0.70))
                    }

                    Text(result.matchedSnippet)
                        .font(CosmoTypography.songti(size: 14))
                        .foregroundStyle(snippetTone)
                        .lineLimit(2)

                    Text("\(result.clip.platformBucket.title) · \(result.clip.domain)")
                        .font(CosmoTypography.songti(size: 12))
                        .foregroundStyle(metaTone)

                    if !result.matchedFields.isEmpty {
                        Text(result.matchedFields.prefix(4).map(\.label).joined(separator: " · "))
                            .font(CosmoTypography.songti(size: 12))
                            .foregroundStyle(metaTone.opacity(0.78))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(selected ? accent.opacity(0.050) : hovering ? accent.opacity(0.026) : Color.white.opacity(0.012))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(selected ? accent.opacity(0.07) : Color.white.opacity(0.020), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hovering = isHovering
            if isHovering {
                onSelect()
            }
        }
    }

    private var platformIcon: String {
        switch result.clip.platformBucket {
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

private struct TodoCloudWord: View {
    let item: TodoItem
    let fontSize: CGFloat
    let isHovering: Bool
    let isFocused: Bool
    let isEditing: Bool
    @Binding var editBinding: String
    @FocusState.Binding var focusField: OverlayFocusField?
    let onHover: (Bool) -> Void
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void

    private var accent: Color {
        RecallResultPalette.todoAccent(for: item.visualSeed)
    }

    private var textColor: Color {
        if isEditing {
            return Color.white.opacity(0.94)
        }
        if isFocused {
            return accent.opacity(0.95)
        }
        return accent.opacity(0.80)
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $editBinding)
                    .textFieldStyle(.plain)
                    .focused($focusField, equals: .todoEdit(item.id))
                    .font(CosmoTypography.font(for: item.title, size: fontSize, weight: .medium, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(backgroundCapsule(opacity: 0.090, strokeOpacity: 0.075))
                    .frame(maxWidth: 360)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .onSubmit {
                        onCommitEdit()
                    }
            } else {
                Text(item.title)
                    .font(CosmoTypography.font(for: item.title, size: fontSize, weight: .medium, design: .serif))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        backgroundCapsule(
                            opacity: isHovering || isFocused ? 0.052 : 0.0,
                            strokeOpacity: isHovering || isFocused ? 0.045 : 0.0
                        )
                    )
                    .contentShape(Capsule(style: .continuous))
                    .onTapGesture(count: 2) {
                        onBeginEdit()
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            if (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags).contains(.command) {
                                onComplete()
                            } else {
                                onSelect()
                            }
                        }
                    )
            }
        }
        .shadow(color: Color.black.opacity(isFocused ? 0.20 : 0.10), radius: isFocused ? 18 : 12, x: 0, y: 10)
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: isHovering)
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: isFocused)
        .onHover(perform: onHover)
    }

    private func backgroundCapsule(opacity: Double, strokeOpacity: Double) -> some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(opacity))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(strokeOpacity), lineWidth: 0.8)
            )
    }
}

private struct PromptHiveTile: View {
    let item: PromptLibraryItem
    let size: CGSize
    let isHovering: Bool
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameBinding: String
    @FocusState.Binding var focusField: OverlayFocusField?
    let onHover: (Bool) -> Void
    let onCopy: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onEnterBackstage: () -> Void

    @State private var borderAngle = 0.0

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(tileFill)
                .overlay(defaultBorder)
                .overlay(animatedBorder.opacity(isHovering ? 1 : 0))
                .shadow(
                    color: Color.black.opacity(isHovering ? 0.18 : isSelected ? 0.12 : 0.0),
                    radius: isHovering ? 20 : isSelected ? 12 : 0,
                    x: 0,
                    y: isHovering ? 14 : 8
                )

            tileContent
                .frame(width: size.width * 0.72, height: size.height * 0.60)
                .multilineTextAlignment(.center)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(HexagonShape())
        .gesture(clickGesture)
        .onHover { isHovering in
            onHover(isHovering)
            if isHovering {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    borderAngle = 360
                }
            } else {
                borderAngle = 0
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isHovering)
    }

    @ViewBuilder
    private var tileContent: some View {
        if isRenaming {
            TextField("", text: $renameBinding)
                .textFieldStyle(.plain)
                .focused($focusField, equals: .promptRename(item.id))
                .font(CosmoTypography.font(for: item.title, size: titleSize - 1, weight: .semibold, design: .serif))
                .foregroundStyle(Color.white.opacity(0.94))
                .submitLabel(.done)
                .multilineTextAlignment(.center)
                .onSubmit {
                    onCommitRename()
                }
        } else if isHovering {
            Text(item.previewText)
                .font(CosmoTypography.songti(size: previewSize))
                .foregroundStyle(Color.white.opacity(0.78))
                .lineLimit(6)
                .lineSpacing(3)
                .mask(
                    LinearGradient(
                        colors: [Color.white, Color.white, Color.white, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            Text(item.title)
                .font(CosmoTypography.font(for: item.title, size: titleSize, weight: .semibold, design: .serif))
                .foregroundStyle(RecallResultPalette.champagne.opacity(isSelected ? 0.94 : 0.82))
                .lineLimit(3)
        }
    }

    private var defaultBorder: some View {
        HexagonShape()
            .stroke(Color.white.opacity(isSelected ? 0.16 : 0.058), lineWidth: isSelected ? 1.05 : 0.8)
    }

    private var animatedBorder: some View {
        HexagonShape()
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.39, green: 0.84, blue: 0.56),
                        Color(red: 0.26, green: 0.72, blue: 0.44),
                        Color(red: 0.73, green: 0.96, blue: 0.75),
                        Color(red: 0.31, green: 0.78, blue: 0.50),
                        Color(red: 0.39, green: 0.84, blue: 0.56)
                    ]),
                    center: .center,
                    angle: .degrees(borderAngle)
                ),
                lineWidth: 2.1
            )
            .shadow(color: Color(red: 0.39, green: 0.84, blue: 0.56).opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private var clickGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
                switch value {
                case .first:
                    onBeginRename()
                case .second:
                    let modifiers = (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags)
                        .intersection([.command, .control, .option, .shift])
                    if modifiers.contains(.command) {
                        onEnterBackstage()
                    } else {
                        onCopy()
                    }
                }
            }
    }

    private var tileFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isHovering ? 0.080 : isSelected ? 0.052 : 0.020),
                Color.white.opacity(isHovering ? 0.040 : isSelected ? 0.028 : 0.010),
                Color.black.opacity(isHovering ? 0.06 : 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var titleSize: CGFloat {
        min(18, max(15, size.width * 0.088))
    }

    private var previewSize: CGFloat {
        min(12, max(10.5, size.width * 0.060))
    }
}

private struct HexagonShape: InsettableShape {
    static let regularHeightRatio = CGFloat(0.8660254037844386)

    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let side = min(rect.width / 2, rect.height / CGFloat(1.7320508075688772))
        let height = side * CGFloat(1.7320508075688772)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.move(to: CGPoint(x: center.x - (side / 2), y: center.y - (height / 2)))
        path.addLine(to: CGPoint(x: center.x + (side / 2), y: center.y - (height / 2)))
        path.addLine(to: CGPoint(x: center.x + side, y: center.y))
        path.addLine(to: CGPoint(x: center.x + (side / 2), y: center.y + (height / 2)))
        path.addLine(to: CGPoint(x: center.x - (side / 2), y: center.y + (height / 2)))
        path.addLine(to: CGPoint(x: center.x - side, y: center.y))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private enum RecallResultPalette {
    static let champagne = Color(red: 0.88, green: 0.81, blue: 0.66)
    static let body = Color(red: 0.77, green: 0.74, blue: 0.68)
    static let meta = Color(red: 0.66, green: 0.62, blue: 0.57)

    static func accent(for bucket: PlatformBucket) -> Color {
        switch bucket {
        case .xPosts:
            return Color(red: 0.68, green: 0.73, blue: 0.84)
        case .rednote:
            return Color(red: 0.86, green: 0.66, blue: 0.66)
        case .wechat:
            return Color(red: 0.70, green: 0.81, blue: 0.67)
        case .douyin:
            return Color(red: 0.67, green: 0.79, blue: 0.80)
        case .youtube:
            return Color(red: 0.84, green: 0.67, blue: 0.62)
        case .otherWeb:
            return champagne
        }
    }

    static func todoAccent(for seed: Int) -> Color {
        switch abs(seed) % 5 {
        case 0:
            return champagne
        case 1:
            return Color(red: 0.74, green: 0.78, blue: 0.88)
        case 2:
            return Color(red: 0.78, green: 0.70, blue: 0.62)
        case 3:
            return Color(red: 0.72, green: 0.80, blue: 0.72)
        default:
            return Color(red: 0.82, green: 0.72, blue: 0.78)
        }
    }
}

private struct RecallGlassButtonStyle: ButtonStyle {
    enum Emphasis {
        case solid
        case soft
    }

    let emphasis: Emphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CosmoTypography.songti(size: 14, weight: .medium))
            .foregroundStyle(emphasis == .solid ? Color.black.opacity(0.82) : Color.white.opacity(0.90))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasis == .solid ? Color.white.opacity(configuration.isPressed ? 0.80 : 0.92) : Color.white.opacity(configuration.isPressed ? 0.12 : 0.07))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(emphasis == .solid ? 0.12 : 0.10), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct OverlayKeyboardMonitor: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handle(event)
                }
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
            }
            .onExitCommand {
                handleExit()
            }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard model.isRecallOverlayPresented else { return event }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if Int(event.keyCode) == kVK_Tab && modifiers.isEmpty && !isTextCompositionActive() {
            model.cycleOverlayMode()
            return nil
        }

        if Int(event.keyCode) == kVK_Escape {
            handleExit()
            return nil
        }

        guard modifiers.isEmpty else { return event }
        guard !isTextCompositionActive() else { return event }

        switch model.overlayMode {
        case .recall:
            switch Int(event.keyCode) {
            case kVK_UpArrow:
                model.moveRecallSelection(offset: -1)
                return nil
            case kVK_DownArrow:
                model.moveRecallSelection(offset: 1)
                return nil
            default:
                return event
            }
        case .todo, .promptLibrary:
            return event
        }
    }

    private func handleExit() {
        if model.todoEditingItemID != nil {
            model.finishTodoEditing(commit: false)
            return
        }
        if model.promptRenamingItemID != nil {
            model.finishPromptRenaming(commit: false)
            return
        }
        model.dismissRecallOverlay()
    }

    private func isTextCompositionActive() -> Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return textView.hasMarkedText()
    }
}
