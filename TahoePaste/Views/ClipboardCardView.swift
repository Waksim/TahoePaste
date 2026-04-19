import AppKit
import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    let image: NSImage?
    @ObservedObject var settingsManager: SettingsManager
    let activeTagFilter: ClipboardTag?
    let action: () -> Void
    let tagAction: (ClipboardTag) -> Void
    let deleteAction: () -> Void

    @State private var isHovered = false

    private var cardWidth: CGFloat {
        item.isImage ? settingsManager.cardSizePreset.imageCardWidth : settingsManager.cardSizePreset.textCardWidth
    }

    private var cardHeight: CGFloat {
        settingsManager.cardSizePreset.cardHeight
    }

    private var cardPadding: CGFloat {
        settingsManager.cardSizePreset.contentPadding
    }

    private var textBottomPadding: CGFloat {
        max(cardPadding * 0.35, 6)
    }

    private var cardCornerRadius: CGFloat {
        max(CGFloat(settingsManager.cornerRadiusIntensity), 10)
    }

    private var totalCardWidth: CGFloat {
        cardWidth + (cardPadding * 2)
    }

    private var totalCardHeight: CGFloat {
        cardHeight + (cardPadding * 2)
    }

    private var controlInset: CGFloat {
        max(cardPadding - 6, 8)
    }

    private var deleteButtonReservedWidth: CGFloat {
        24
    }

    private var headerReservedHeight: CGFloat {
        18
    }

    private var locale: Locale {
        settingsManager.appLanguage.locale
    }

    var body: some View {
        ZStack {
            Button(action: action) {
                cardShell
            }
            .buttonStyle(.plain)

            tagsRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Button(action: deleteAction) {
                deleteButtonLabel
            }
            .buttonStyle(.plain)
            .padding(.top, controlInset)
            .padding(.trailing, controlInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: totalCardWidth, height: totalCardHeight, alignment: .topLeading)
        .onHover { hovered in
            isHovered = hovered
        }
    }

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(metadataText: item.metadataText(locale: locale))

            Text(item.displayPreviewText)
                .font(previewFont)
                .foregroundStyle(previewColor)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.trailing, deleteButtonReservedWidth)
    }

    private var imageCard: some View {
        ZStack {
            imageCardBackground

            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                cardHeader(metadataText: item.metadataText(locale: locale))
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.trailing, deleteButtonReservedWidth)

                Spacer()
            }
        }
    }

    private var cardShell: some View {
        ZStack {
            cardBackground

            Group {
                if item.usesTextCardLayout {
                    textCard
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, cardPadding)
                        .padding(.leading, cardPadding)
                        .padding(.trailing, cardPadding)
                        .padding(.bottom, textBottomPadding)
                } else {
                    imageCard
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: totalCardWidth, height: totalCardHeight, alignment: .topLeading)
        .clipShape(cardShape)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(isHovered ? 0.22 : 0.14), radius: isHovered ? 22 : 12, y: 8)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.snappy(duration: 0.18), value: isHovered)
    }

    private func cardHeader(metadataText: String?) -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            if settingsManager.showMetadataOnCards, let metadataText, metadataText.isEmpty == false {
                Text(metadataText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(item.isImage ? 0.72 : 0.50))
                    .lineLimit(1)
            }

            if settingsManager.showTimestampsOnCards {
                Text(item.timestampText(locale: locale))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(item.isImage ? 0.72 : 0.46))
                    .lineLimit(1)
            }
        }
        .frame(height: headerReservedHeight, alignment: .topTrailing)
    }

    private var tagsRow: some View {
        HStack(spacing: 8) {
            ForEach(item.displayTags) { tag in
                Button(action: { tagAction(tag) }) {
                    Text(L10n.tr(tag.titleKey))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            activeTagFilter == tag
                                ? Color.white.opacity(0.96)
                                : Color.white.opacity(item.isImage ? 0.88 : 0.78)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, controlInset)
        .padding(.leading, controlInset)
    }

    private var deleteButtonLabel: some View {
        Image(systemName: "xmark")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(
                Color(red: 0.72, green: 0.75, blue: 0.80)
                    .opacity(isHovered ? 0.92 : 0.66)
            )
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
    }

    private var previewFont: Font {
        if item.isCode {
            return .system(size: settingsManager.cardSizePreset.textFontSize - 1, weight: .medium, design: .monospaced)
        }

        return .system(size: settingsManager.cardSizePreset.textFontSize, weight: .medium, design: .rounded)
    }

    private var previewColor: Color {
        if item.isLink {
            return Color(red: 0.84, green: 0.92, blue: 1.0)
        }

        return .white
    }

    private var cardBackground: some View {
        cardShape
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.23, blue: 0.29),
                        Color(red: 0.10, green: 0.12, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardBorder: some View {
        cardShape
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var imageCardBackground: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.23, blue: 0.29),
                        Color(red: 0.10, green: 0.12, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24, weight: .medium))
                    Text(L10n.tr("card.preview_unavailable"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.66))
            }
        }
    }
}
