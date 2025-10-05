import SwiftUI
import Foundation
import MarkdownUI

struct EmbedCardView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let embed: Embed
    let isCurrentUser: Bool

    private var accentColor: Color {
        print(embed)
        if let color = embed.color, let resolved = Color(hex: color) {
            return resolved
        }
        return Color.accentColor
    }

    private var displayTimestamp: String? {
        guard let timestamp = embed.timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            fields
            media
            footer
        }
        .padding(14)
        .frame(maxWidth: 420, alignment: .leading)
        .background(background)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(isCurrentUser ? 0.25 : 0.15), Color(.secondarySystemBackground).opacity(isCurrentUser ? 0.8 : 1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var header: some View {
        if let author = embed.author, author.name != nil || author.iconURL != nil {
            HStack(alignment: .center, spacing: 8) {
                if let icon = author.iconURL, let url = URL(string: icon) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if let name = author.name {
                    if let link = author.url, let url = URL(string: link) {
                        Link(name, destination: url)
                            .font(.subheadline.weight(.semibold))
                            .underline()
                            .foregroundStyle(accentColor)
                    } else {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = embed.title {
                if let link = embed.url, let url = URL(string: link) {
                    Link(title, destination: url)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }
            }
            if let description = embed.description, !description.isEmpty {
                Markdown(description)
                    .markdownTheme(.basic)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        if let fields = embed.fields, !fields.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                let inlineFields = fields.filter { $0.isInline == true }
                let blockFields = fields.filter { $0.isInline != true }
                if !inlineFields.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(inlineFields, id: \.self) { field in
                            fieldView(field)
                        }
                    }
                }
                if !blockFields.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(blockFields, id: \.self) { field in
                            fieldView(field)
                        }
                    }
                }
            }
        }
    }

    private func fieldView(_ field: EmbedField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = field.name {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            if let value = field.value {
                Markdown(value)
                    .markdownTheme(.basic)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var media: some View {
        if let thumbnail = embed.thumbnail?.url, let url = URL(string: thumbnail) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: 120, maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        if let image = embed.image?.url, let url = URL(string: image) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let footer = embed.footer?.text, let timestamp = displayTimestamp {
            Text("\(footer) • \(timestamp)")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let footer = embed.footer?.text {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let timestamp = displayTimestamp {
            Text(timestamp)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let provider = embed.provider?.name {
            Text(provider)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
    }
}
