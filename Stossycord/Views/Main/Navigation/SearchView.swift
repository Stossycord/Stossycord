// @sayborduu | alexbadi.es
// SearchView.swift

import SwiftUI

struct SearchView: View {
    @StateObject var webSocketService: WebSocketService
    @StateObject private var viewModel: SearchViewModel
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    private var activeFilters: [SearchViewModel.Filter] {
        var filters: [SearchViewModel.Filter] = [.all]
        if !viewModel.results.messages.isEmpty { filters.append(.messages) }
        if !viewModel.results.links.isEmpty { filters.append(.links) }
        if !viewModel.results.files.isEmpty { filters.append(.files) }
        if !viewModel.results.pins.isEmpty { filters.append(.pins) }
        if !viewModel.results.media.isEmpty { filters.append(.media) }
        if !viewModel.results.people.isEmpty { filters.append(.people) }
        return filters
    }
    
    init(webSocketService: WebSocketService) {
        _webSocketService = StateObject(wrappedValue: webSocketService)
        _viewModel = StateObject(wrappedValue: SearchViewModel(webSocketService: webSocketService))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.didSearch && !viewModel.showMinimumQueryHint {
                        filterPicker
                    }
                    
                    if viewModel.showMinimumQueryHint {
                        infoBanner(systemImage: "info.circle", text: "Type at least 2 characters to search messages.")
                    }
                    
                    if let error = viewModel.errorMessage {
                        infoBanner(systemImage: "exclamationmark.triangle.fill", text: error)
                            .foregroundColor(.red)
                    }
                    
                    if viewModel.isLoading && viewModel.results.messages.isEmpty {
                        loadingIndicator
                    }
                    
                    resultsContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Search")
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search messages, media, or people"
            )
            .onAppear { viewModel.refreshDefaults() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refreshDefaults) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
    
    private var filterPicker: some View {
        let filters = activeFilters
        return Picker("Filter", selection: $viewModel.filter) {
            ForEach(filters) { filter in
                Text(filter.rawValue)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: filters) { newFilters in
            if !newFilters.contains(viewModel.filter) {
                viewModel.filter = .all
            }
        }
    }
    
    @ViewBuilder
    private func infoBanner(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private var loadingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Searching for messages…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    @ViewBuilder
    private var resultsContent: some View {
        if isEmpty(for: viewModel.filter) {
            SearchEmptyStateView(filter: viewModel.filter, query: viewModel.query, isLoading: viewModel.isLoading)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            LazyVStack(alignment: .leading, spacing: 24) {
                if shouldShow(.messages), !viewModel.results.messages.isEmpty {
                    messageResultsSection(
                        filter: .messages,
                        title: "Messages",
                        systemImage: "text.bubble",
                        results: viewModel.results.messages,
                        highlightInitialLoading: true
                    )
                }
                
                if shouldShow(.links), !viewModel.results.links.isEmpty {
                    messageResultsSection(
                        filter: .links,
                        title: "Links",
                        systemImage: "link",
                        results: viewModel.results.links
                    )
                }
                
                if shouldShow(.files), !viewModel.results.files.isEmpty {
                    messageResultsSection(
                        filter: .files,
                        title: "Files",
                        systemImage: "doc",
                        results: viewModel.results.files
                    )
                }
                
                if shouldShow(.pins), !viewModel.results.pins.isEmpty {
                    messageResultsSection(
                        filter: .pins,
                        title: "Pins",
                        systemImage: "pin.fill",
                        results: viewModel.results.pins
                    )
                }
                
                if shouldShow(.media), !viewModel.results.media.isEmpty {
                    messageResultsSection(
                        filter: .media,
                        title: "Media",
                        systemImage: "photo.on.rectangle",
                        results: viewModel.results.media
                    )
                }
                
                if shouldShow(.people), !viewModel.results.people.isEmpty {
                    peopleSection(viewModel.results.people)
                }
            }
        }
    }
    
    private func shouldShow(_ filter: SearchViewModel.Filter) -> Bool {
        viewModel.filter == .all || viewModel.filter == filter
    }
    
    private func isEmpty(for filter: SearchViewModel.Filter) -> Bool {
        switch filter {
        case .all:
            return viewModel.results.isEmpty
        case .messages:
            return viewModel.results.messages.isEmpty
        case .links:
            return viewModel.results.links.isEmpty
        case .files:
            return viewModel.results.files.isEmpty
        case .pins:
            return viewModel.results.pins.isEmpty
        case .media:
            return viewModel.results.media.isEmpty
        case .people:
            return viewModel.results.people.isEmpty
        }
    }
    
    @ViewBuilder
    private func messageResultsSection(filter: SearchViewModel.Filter,
                                       title: String,
                                       systemImage: String,
                                       results: [MessageResult],
                                       highlightInitialLoading: Bool = false) -> some View {
        let isPaginating = viewModel.isLoadingMore(for: filter)
        let showInitialLoader = highlightInitialLoading && viewModel.isLoading
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: title,
                systemImage: systemImage,
                accessory: {
                    if showInitialLoader || isPaginating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let total = viewModel.totalResults(for: filter), total > 0 {
                        Text("\(results.count)/\(total)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            )
            
            VStack(spacing: 12) {
                ForEach(results) { result in
                    NavigationLink {
                        messageDestination(for: result)
                    } label: {
                        MessageResultRow(result: result, formatter: SearchView.relativeFormatter)
                    }
                    .buttonStyle(SearchRowButtonStyle())
                }
            }
            if viewModel.hasMoreResults(for: filter) {
                paginationFooter(for: filter)
            }
        }
    }
    
    @ViewBuilder
    private func paginationFooter(for filter: SearchViewModel.Filter) -> some View {
        Button {
            viewModel.loadMore(for: filter)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isLoadingMore(for: filter) {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(paginationButtonTitle(for: filter))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(Color.accentColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(SearchRowButtonStyle())
        .disabled(viewModel.isLoadingMore(for: filter))
    }
    
    private func paginationButtonTitle(for filter: SearchViewModel.Filter) -> String {
        switch filter {
        case .all, .messages:
            return "Show more results"
        case .links:
            return "Show more links"
        case .files:
            return "Show more files"
        case .pins:
            return "Show more pins"
        case .media:
            return "Show more media"
        case .people:
            return "Show more people"
        }
    }
    
    @ViewBuilder
    private func peopleSection(_ results: [UserResult]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "People", systemImage: "person.2")
            VStack(spacing: 12) {
                ForEach(results) { result in
                    if let channelId = result.dmChannelId {
                        NavigationLink {
                            ChannelView(
                                webSocketService: webSocketService,
                                currentchannelname: "@" + (result.user.username),
                                currentid: channelId
                            )
                        } label: {
                            UserResultRow(result: result)
                        }
                        .buttonStyle(SearchRowButtonStyle())
                    } else {
                        UserResultRow(result: result)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                    }
                }
            }
        }
    }
    
    private func sectionHeader<Accessory: View>(title: String, systemImage: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .labelStyle(.titleAndIcon)
            Spacer()
            accessory()
        }
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        sectionHeader(title: title, systemImage: systemImage) {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func messageDestination(for result: MessageResult) -> some View {
        ChannelView(
            webSocketService: webSocketService,
            currentchannelname: result.context.title,
            currentid: result.context.channelId,
            currentGuild: result.context.guild
        )
}

private struct MessageResultRow: View {
    let result: MessageResult
    let formatter: RelativeDateTimeFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                conversationIcon
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(result.message.author.currentname)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let timestamp = result.timestamp {
                            Text(formatter.localizedString(for: timestamp, relativeTo: Date()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let subtitle = result.context.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    highlightedPreview
                        .font(.callout)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    @ViewBuilder
    private var conversationIcon: some View {
        switch result.context.iconSource {
        case .user(let user):
            UserAvatarView(user: user)
        case .group(let users):
            GroupAvatarView(users: users)
        case .channel:
            ChannelSymbolView()
        }
    }
    
    private var highlightedPreview: Text {
        guard !result.highlightRanges.isEmpty else {
            return Text(result.preview)
        }
        var text = Text("")
        var currentIndex = result.preview.startIndex
        let sortedRanges = result.highlightRanges.sorted { $0.lowerBound < $1.lowerBound }
        for range in sortedRanges {
            if currentIndex < range.lowerBound {
                let segment = String(result.preview[currentIndex..<range.lowerBound])
                text = text + Text(segment)
            }
            let highlight = String(result.preview[range])
            text = text + Text(highlight).foregroundColor(Color.accentColor).fontWeight(.semibold)
            currentIndex = range.upperBound
        }
        if currentIndex < result.preview.endIndex {
            let trailing = String(result.preview[currentIndex..<result.preview.endIndex])
            text = text + Text(trailing)
        }
        return text
    }
}

private struct UserResultRow: View {
    let result: UserResult
    
    var body: some View {
        HStack(spacing: 14) {
            UserAvatarView(user: result.user)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if result.dmChannelId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            } else {
                Text("Profile only")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct SearchEmptyStateView: View {
    let filter: SearchViewModel.Filter
    let query: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isLoading ? "hourglass" : "sparkles.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .frame(maxWidth: .infinity)
    }
    
    private var title: String {
        switch filter {
        case .all:
            return query.isEmpty ? "Search Stossycord" : "Nothing matched"
        case .messages:
            return "No messages found"
        case .links:
            return "No links found"
        case .files:
            return "No files found"
        case .pins:
            return "No pins found"
        case .media:
            return "No media found"
        case .people:
            return "No people found"
        }
    }
    
    private var subtitle: String {
        if query.isEmpty {
            return "Try searching for messages, links, files, or the people you chat with."
        } else {
            return "We couldn't find anything for “\(query)”. Try a different keyword or broaden your search."
        }
    }
}

private struct ChannelSymbolView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemFill))
            Image(systemName: "number")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(width: 44, height: 44)
    }
}

private struct SearchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}
}
