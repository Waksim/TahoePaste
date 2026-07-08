import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: ClipboardHistoryViewModel
    @ObservedObject var settingsManager: SettingsManager

    @State private var scrollPositionID: UUID?

    private var themePalette: SettingsManager.ThemePalette {
        settingsManager.themePalette
    }

    private var overlayLayout: SettingsManager.OverlayLayout {
        settingsManager.overlayLayout
    }

    var body: some View {
        ZStack {
            overlayShape
                .fill(
                    LinearGradient(
                        colors: [
                            themePalette.overlayGradientTop,
                            themePalette.overlayGradientBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(themePalette.overlayEdgeHighlight)
                        .frame(height: 1)
                }

            VStack(spacing: 0) {
                topBar

                Group {
                    if viewModel.visibleItems.isEmpty {
                        if viewModel.isSearching {
                            noResultsState
                        } else {
                            emptyState
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .center, spacing: overlayLayout.cardSpacing) {
                                ForEach(viewModel.visibleItems) { item in
                                    ClipboardCardView(
                                        item: item,
                                        image: viewModel.image(for: item),
                                        settingsManager: settingsManager,
                                        activeTagFilter: viewModel.activeTagFilter
                                    ) {
                                        viewModel.select(item)
                                    } tagAction: { tag in
                                        viewModel.toggleTagFilter(tag)
                                    } deleteAction: {
                                        viewModel.delete(item)
                                    }
                                    .id(item.id)
                                }
                            }
                            .scrollTargetLayout()
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, overlayLayout.bottomInset)
                        }
                        .scrollPosition(id: $scrollPositionID, anchor: .leading)
                        .contentMargins(.horizontal, overlayLayout.cardSpacing, for: .scrollContent)
                        .scrollClipDisabled()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .onAppear {
                            scrollToMostRecent(animated: false)
                        }
                        .onChange(of: scrollPositionID) { _, newAnchorID in
                            viewModel.currentScrollAnchorID = newAnchorID
                        }
                        .onChange(of: viewModel.overlayPresentationID) {
                            scrollToMostRecent(animated: false)
                        }
                        .onChange(of: viewModel.visibleItems.first?.id) {
                            scrollToMostRecent()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.locale, settingsManager.appLanguage.locale)
        .preferredColorScheme(settingsManager.preferredColorScheme)
    }

    private var overlayShape: UnevenRoundedRectangle {
        let radius = CGFloat(settingsManager.cornerRadiusIntensity)
        // Square top corners only make sense while the overlay hugs the
        // screen edges; once it floats, round all four.
        let isDetachedFromScreenEdges = overlayLayout.overlayScreenBottomInset > 0
            || overlayLayout.overlayScreenHorizontalInset > 0
        let topRadius = isDetachedFromScreenEdges ? radius : 0

        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: topRadius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: topRadius
            ),
            style: .continuous
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("overlay.empty_title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(themePalette.overlayPrimaryText)

            Text(L10n.tr("overlay.empty_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.92))
                .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("overlay.no_matches_title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(themePalette.overlayPrimaryText)

            Text(L10n.tr("overlay.no_matches_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.92))
                .lineLimit(2)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if viewModel.isSearchBubbleVisible {
                searchBubble
                    .offset(
                        x: overlayLayout.searchBubbleHorizontalOffset,
                        y: overlayLayout.searchBubbleVerticalOffset
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Spacer(minLength: 0)
            }

            overlayControls
                .offset(y: overlayLayout.toolbarVerticalOffset)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: overlayLayout.topBarHeight)
    }

    private var searchBubble: some View {
        HStack(spacing: 10) {
            Text(viewModel.searchDisplayText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    themePalette.overlayPrimaryText.opacity(viewModel.isSearching ? 0.92 : 0.64)
                )
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Button(action: {
                viewModel.clearTransientState()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.74))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: overlayLayout.searchBubbleHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(themePalette.overlayBubbleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(themePalette.overlayBubbleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .frame(maxWidth: overlayLayout.searchBubbleWidth)
    }

    private var overlayControls: some View {
        HStack(spacing: overlayLayout.toolbarIconSpacing) {
            toolbarButton(systemName: "gearshape") {
                viewModel.openSettings()
            }

            toolbarButton(systemName: "magnifyingglass") {
                viewModel.beginSearch()
            }

            if let returnTargetID = viewModel.sessionReturnTargetID {
                toolbarButton(systemName: "clock.arrow.circlepath") {
                    withAnimation(.snappy(duration: 0.18)) {
                        scrollPositionID = returnTargetID
                    }
                }
                .help(L10n.tr("overlay.return_to_previous_position"))
            }

            toolbarButton(systemName: "arrow.left.to.line") {
                scrollToMostRecent()
            }
        }
    }

    private func toolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: overlayLayout.toolbarIconSize, weight: .semibold))
                .foregroundStyle(themePalette.overlayToolbarIcon.opacity(0.78))
                .frame(
                    width: overlayLayout.toolbarIconSize + 8,
                    height: overlayLayout.toolbarIconSize + 8
                )
                .padding(overlayLayout.toolbarIconPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scrollToMostRecent(animated: Bool = true) {
        guard let newestItemID = viewModel.visibleItems.first?.id else {
            return
        }

        if animated {
            withAnimation(.snappy(duration: 0.18)) {
                scrollPositionID = newestItemID
            }
        } else {
            scrollPositionID = newestItemID
        }
    }
}
