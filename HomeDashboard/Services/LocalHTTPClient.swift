import Foundation

enum LocalHTTPError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid local URL."
        case .invalidResponse:
            return "Unexpected response from device."
        case .httpStatus(let code):
            return "Device returned HTTP \(code)."
        case .decodingFailed:
            return "Could not read device response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

/// Thin wrapper around URLSession for local LAN requests only.
final class LocalHTTPClient {

    private let session: URLSession

    init(timeout: TimeInterval) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    func get(urlString: String, completion: @escaping (Result<Data, LocalHTTPError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DebugLog.shared.error("GET \(urlString) → \(error.localizedDescription)")
                completion(.failure(.transport(error)))
                return
            }

            guard
                let http = response as? HTTPURLResponse,
                let data = data
            else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(http.statusCode) else {
                DebugLog.shared.error("GET \(urlString) → HTTP \(http.statusCode)")
                completion(.failure(.httpStatus(http.statusCode)))
                return
            }

            if let hueError = Self.hueError(from: data) {
                DebugLog.shared.error("GET \(urlString) → \(hueError.localizedDescription ?? "Hue error")")
                completion(.failure(hueError))
                return
            }

            DebugLog.shared.http("GET", url: urlString, detail: "OK \(data.count) bytes")
            completion(.success(data))
        }
        task.resume()
    }

    func post(urlString: String, body: [String: Any], completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        send(urlString: urlString, method: "POST", body: body, completion: completion)
    }

    func put(urlString: String, body: [String: Any], completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        send(urlString: urlString, method: "PUT", body: body, completion: completion)
    }

    private func send(urlString: String, method: String, body: [String: Any], completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        guard JSONSerialization.isValidJSONObject(body) else {
            completion(.failure(.decodingFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.transport(error)))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DebugLog.shared.error("\(method) \(urlString) → \(error.localizedDescription)")
                completion(.failure(.transport(error)))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(http.statusCode) else {
                DebugLog.shared.error("\(method) \(urlString) → HTTP \(http.statusCode)")
                completion(.failure(.httpStatus(http.statusCode)))
                return
            }

            if let data = data, let hueError = Self.hueError(from: data) {
                DebugLog.shared.error("\(method) \(urlString) → \(hueError.localizedDescription ?? "Hue error")")
                completion(.failure(hueError))
                return
            }

            DebugLog.shared.http(method, url: urlString, detail: "OK \(http.statusCode)")
            completion(.success(()))
        }
        task.resume()
    }

    private static func hueError(from data: Data) -> LocalHTTPError? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let errors = json as? [[String: Any]],
            let first = errors.first,
            let error = first["error"] as? [String: Any],
            let description = error["description"] as? String
        else {
            return nil
        }

        return .transport(NSError(
            domain: "HueBridge",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        ))
    }
}
