import SwiftUI

struct GIFPickerView: View {
    let onSelect: (FavoriteGIF) -> Void

    @Environment(\.api) private var discordAPI
    @Environment(\.dismiss) private var dismiss
    @State private var favoriteGIFs: [FavoriteGIF] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 10)
    ]

    private var filteredGIFs: [FavoriteGIF] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return favoriteGIFs }

        return favoriteGIFs.filter {
            $0.url.localizedCaseInsensitiveContains(query) ||
            ($0.previewURL?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

            content
        }
        .task {
            await loadFavoriteGIFs()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search favorite GIFs", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear GIF search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading favorite GIFs")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            unavailableView(title: "Could not load GIFs", message: errorMessage, systemImage: "exclamationmark.triangle")
        } else if favoriteGIFs.isEmpty {
            unavailableView(title: "No favorite GIFs", message: "Favorite GIFs from Discord will show here.", systemImage: "star")
        } else if filteredGIFs.isEmpty {
            unavailableView(title: "No matches", message: "Try another search.", systemImage: "magnifyingglass")
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredGIFs) { gif in
                        GIFTile(gif: gif) {
                            dismiss()
                            onSelect(gif)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private func unavailableView(title: String, message: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadFavoriteGIFs() async {
        isLoading = true
        errorMessage = nil

        do {
            let gifs = try await discordAPI.makeRequest(.favoriteGIFs)
            favoriteGIFs = gifs
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct GIFTile: View {
    let gif: FavoriteGIF
    let onSelect: () -> Void

    @State private var resolvedDisplayURL: URL?

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                if let url = resolvedDisplayURL ?? gif.displayURL {
                    AnimatedImageView(url: url)
                        .aspectRatio(tileAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(tileAspectRatio, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send GIF")
        .task(id: gif.id) {
            await resolveDisplayURL()
        }
    }

    private var tileAspectRatio: CGFloat {
        guard let width = gif.width, let height = gif.height, width > 0, height > 0 else {
            return 1.4
        }

        return CGFloat(width) / CGFloat(height)
    }

    @MainActor
    private func resolveDisplayURL() async {
        guard let displayURL = gif.displayURL else {
            resolvedDisplayURL = nil
            return
        }
        
        if gif.needsResolvedDisplayURL {
            resolvedDisplayURL = await TenorMediaResolver.shared.mediaURL(for: displayURL)
        } else {
            resolvedDisplayURL = displayURL
        }
    }
}
