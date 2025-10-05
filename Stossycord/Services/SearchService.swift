import Foundation

final class SearchService {
    private var tasks: [URLSessionDataTask] = []
    
    func searchMessages(token: String,
                        query: String,
                        tab: UnifiedSearchTab? = nil,
                        cursor: SearchCursor? = nil,
                        limit: Int? = nil,
                        cancelExisting: Bool = true,
                        completion: @escaping (Result<UnifiedSearchResults, Error>) -> Void) {
        if cancelExisting {
            cancelOngoing()
        }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            completion(.success(.empty))
            return
        }
        
        var taskReference: URLSessionDataTask?
        taskReference = UserSearch(token: token,
                                   query: trimmedQuery,
                                   tab: tab,
                                   cursor: cursor,
                                   limit: limit) { [weak self] result in
            if let task = taskReference {
                self?.remove(task: task)
            }
            taskReference = nil
            completion(result)
        }
        guard let task = taskReference else {
            DispatchQueue.main.async {
                completion(.failure(SearchServiceError.invalidRequest))
            }
            return
        }
        tasks.append(task)
        task.resume()
    }
    
    func cancelOngoing() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
    
    private func remove(task: URLSessionDataTask) {
        DispatchQueue.main.async { [weak self] in
            self?.tasks.removeAll { $0 === task }
        }
    }
    
}

enum SearchServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case http(status: Int, message: String)
    case emptyPayload
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to build search request."
        case .invalidResponse:
            return "The server response was invalid."
        case .http(let status, let message):
            return "Request failed with status \(status): \(message)."
        case .emptyPayload:
            return "The response contained no data."
        }
    }
}
