import SwiftUI

struct PollMessageView: View {
    let message: Message
    @ObservedObject var webSocketService: WebSocketService
    let poll: Poll
    let isCurrentUser: Bool

    @State private var errorMessage: String?
    @State private var pendingSelection: Set<Int>?
    @State private var inFlightSelection: Set<Int>?
    @State private var baselineSelection: Set<Int> = []
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var requestSequence: Int = 0
    @State private var activeRequestId: Int = 0

    private var answers: [PollAnswer] {
        poll.answers ?? []
    }

    private var allowMultiselect: Bool {
        poll.allowMultiselect ?? false
    }

    private var isFinalized: Bool {
        poll.results?.isFinalized ?? false
    }

    private var serverSelection: Set<Int> {
        Set(poll.results?.answerCounts?.compactMap { answerCount in
            guard answerCount.meVoted == true else { return nil }
            return answerCount.answerId
        } ?? [])
    }

    private var committedSelection: Set<Int> {
        inFlightSelection ?? baselineSelection
    }

    private var optimisticSelection: Set<Int> {
        pendingSelection ?? inFlightSelection ?? baselineSelection
    }

    private var totalVotes: Int {
        let base = poll.results?.answerCounts?.compactMap { $0.count }.reduce(0, +) ?? 0
        let committed = serverSelection
        let optimistic = optimisticSelection
        let added = optimistic.subtracting(committed).count
        let removed = committed.subtracting(optimistic).count
        return max(base + added - removed, 0)
    }

    private var token: String {
        webSocketService.token
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let question = poll.question?.text, !question.isEmpty {
                Text(question)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if allowMultiselect {
                Text("Multiple choice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Array(answers.enumerated()), id: \.element.answerId) { index, answer in
                    optionButton(answer: answer, index: index)
                }
            }

            HStack {
                Text(voteSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let expiryText = expiryDisplay {
                    Text(expiryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(isCurrentUser ? 0.8 : 1))
        )
        .onAppear {
            baselineSelection = serverSelection
            inFlightSelection = nil
        }
        .onChange(of: poll.results?.answerCounts) { _ in
            reconcileWithServerSelection()
        }
        .onDisappear {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
        }
    }

    private var voteSummary: String {
        if totalVotes == 1 {
            return "1 vote"
        }
        return "\(totalVotes) votes"
    }

    private var expiryDisplay: String? {
        guard let expiry = poll.expiry else {
            return nil
        }
        let date = ISO8601DateFormatter.full.date(from: expiry) ?? ISO8601DateFormatter.standard.date(from: expiry)
        guard let date else { return nil }
        if date < Date() {
            return "Poll ended"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func reconcileWithServerSelection() {
        let server = serverSelection

        if let pending = pendingSelection, server == pending {
            pendingSelection = nil
            baselineSelection = server
            if inFlightSelection == server {
                inFlightSelection = nil
            }
        } else if let inFlight = inFlightSelection, server == inFlight {
            baselineSelection = server
            inFlightSelection = nil
        } else {
            baselineSelection = server
        }

        errorMessage = nil
    }

    private func optionButton(answer: PollAnswer, index: Int) -> some View {
        let voteCount = voteCount(for: answer)
        let voted = userHasVoted(for: answer)
        let progress = progressValue(for: voteCount)
        let accent = Color.accentColor
        let progressColor = voted ? accent.opacity(isCurrentUser ? 0.35 : 0.28) : accent.opacity(0.16)
        let selectionGlow = voted ? accent.opacity(0.12) : Color.clear

        return Button {
            toggleVote(for: answer)
        } label: {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectionGlow)
                        )
                    if progress > 0 {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * CGFloat(progress))
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(optionTitle(for: answer, index: index))
                                .font(.subheadline.weight(voted ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(voteLabel(for: voteCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if voted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                        }
                    }
                    .padding(12)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(voted ? accent.opacity(0.6) : Color.secondary.opacity(0.14), lineWidth: 1)
                )
            }
            .frame(height: 60)
        }
        .buttonStyle(.plain)
        .disabled(isFinalized || token.isEmpty)
        .accessibilityLabel(optionTitle(for: answer, index: index))
    }

    private func toggleVote(for answer: PollAnswer) {
        guard !token.isEmpty else { return }
        var newSelection = optimisticSelection

        if allowMultiselect {
            if newSelection.contains(answer.answerId) {
                newSelection.remove(answer.answerId)
            } else {
                newSelection.insert(answer.answerId)
            }
        } else {
            if newSelection.contains(answer.answerId) {
                newSelection.removeAll()
            } else {
                newSelection = Set([answer.answerId])
            }
        }

        errorMessage = nil
        pendingSelection = newSelection

        if allowMultiselect {
            scheduleDebouncedSend(to: newSelection)
        } else {
            sendSelection(from: committedSelection, to: newSelection)
        }
    }

    private func scheduleDebouncedSend(to newSelection: Set<Int>) {
        debounceWorkItem?.cancel()

        let originSelection = committedSelection
        let workItem = DispatchWorkItem { [originSelection, newSelection] in
            sendSelection(from: originSelection, to: newSelection)
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func sendSelection(from oldSelection: Set<Int>, to newSelection: Set<Int>) {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if oldSelection == newSelection {
            pendingSelection = nil
            inFlightSelection = nil
            return
        }

        requestSequence += 1
        let requestId = requestSequence
        activeRequestId = requestId
        inFlightSelection = newSelection

        let oldArray = Array(oldSelection).sorted()
        let newArray = Array(newSelection).sorted()

        updatePollVotes(token: token, channelId: message.channelId, messageId: message.messageId, answerIds: newArray) { result in
            guard requestId == activeRequestId else { return }

            switch result {
            case .success:
                applyLocalSelectionChange(from: oldArray, to: newArray)
            case .failure(let error):
                errorMessage = error.localizedDescription
                pendingSelection = nil
                inFlightSelection = nil
                baselineSelection = oldSelection
            }
        }
    }

    private func applyLocalSelectionChange(from oldSelection: [Int], to newSelection: [Int]) {
        let newSet = Set(newSelection)
        let oldSet = Set(oldSelection)
        let allowMultiple = allowMultiselect

        webSocketService.updatePoll(messageId: message.messageId) { poll in
            let existingResults = poll.results ?? PollResults(isFinalized: false, totalVotes: 0, answerCounts: [])
            var counts = existingResults.answerCounts ?? []

            if let answers = poll.answers {
                for answer in answers where !counts.contains(where: { $0.answerId == answer.answerId }) {
                    counts.append(PollAnswerCount(answerId: answer.answerId, count: 0, meVoted: false))
                }
            }

            func indexForAnswer(_ id: Int) -> Int {
                if let index = counts.firstIndex(where: { $0.answerId == id }) {
                    return index
                }
                counts.append(PollAnswerCount(answerId: id, count: 0, meVoted: false))
                return counts.count - 1
            }

            let relevantIds = oldSet.union(newSet)

            for id in relevantIds {
                let index = indexForAnswer(id)
                let wasVoted = counts[index].meVoted == true
                let shouldVote = newSet.contains(id)
                let currentCount = counts[index].count ?? 0

                if shouldVote {
                    if !wasVoted {
                        counts[index].count = currentCount + 1
                    }
                    counts[index].meVoted = true
                } else {
                    if wasVoted && currentCount > 0 {
                        counts[index].count = max(currentCount - 1, 0)
                    }
                    counts[index].meVoted = false
                }
            }

            if !allowMultiple {
                for idx in counts.indices where !newSet.contains(counts[idx].answerId) {
                    counts[idx].meVoted = false
                }
            }

            let total = counts.compactMap { $0.count }.reduce(0, +)
            poll.results = PollResults(isFinalized: existingResults.isFinalized, totalVotes: total, answerCounts: counts)
        }
    }

    private func voteCount(for answer: PollAnswer) -> Int {
        let baseCount = poll.results?.answerCounts?.first(where: { $0.answerId == answer.answerId })?.count ?? 0
        let committed = serverSelection
        let optimistic = optimisticSelection
        let id = answer.answerId

        if optimistic == committed {
            return baseCount
        }

        if optimistic.contains(id) && !committed.contains(id) {
            return baseCount + 1
        }

        if !optimistic.contains(id) && committed.contains(id) {
            return max(baseCount - 1, 0)
        }

        return baseCount
    }

    private func userHasVoted(for answer: PollAnswer) -> Bool {
        optimisticSelection.contains(answer.answerId)
    }

    private func progressValue(for count: Int) -> Double {
        guard totalVotes > 0 else {
            return count > 0 ? 1.0 : 0.0
        }
        return Double(count) / Double(totalVotes)
    }

    private func optionTitle(for answer: PollAnswer, index: Int) -> String {
        var components: [String] = []
        if let emoji = answer.pollMedia?.emoji?.name {
            components.append(emoji)
        }
        if let text = answer.pollMedia?.text, !text.isEmpty {
            components.append(text)
        }
        if components.isEmpty {
            components.append("Option \(index + 1)")
        }
        return components.joined(separator: " ")
    }

    private func voteLabel(for count: Int) -> String {
        if count == 1 {
            return "1 vote"
        }
        return "\(count) votes"
    }
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
