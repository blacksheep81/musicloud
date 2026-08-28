import Foundation

public struct CloudResponse: Sendable {
    public let data: Data
    public let status: Int
    public init(data: Data, status: Int) { self.data = data; self.status = status }
}

public protocol CloudHTTP: Sendable {
    func send(_ request: URLRequest) async throws -> CloudResponse
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public final class CloudURLSession: CloudHTTP, Sendable {
    private let session: URLSession
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpCookieStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    public func send(_ request: URLRequest) async throws -> CloudResponse {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CloudError.invalidResponse }
        return CloudResponse(data: data, status: response.statusCode)
    }
}

public enum CloudError: Error, LocalizedError {
    case invalidClientID, invalidCallback, invalidResponse, signInRequired, wrongDrive, unsafeURL
    case http(Int), oauth(String)
    public var errorDescription: String? {
        switch self {
        case .invalidClientID: "Enter a valid Microsoft application Client ID."
        case .invalidCallback: "The sign-in callback could not be verified."
        case .invalidResponse: "OneDrive returned an unexpected response."
        case .signInRequired: "Connect OneDrive again to continue."
        case .wrongDrive: "This song belongs to a different OneDrive account."
        case .unsafeURL: "An unexpected service URL was blocked."
        case .http(let status): "OneDrive request failed (HTTP \(status)). Please retry."
        case .oauth(let code): "Microsoft sign-in failed (\(code)). Check app registration or sign in again."
        }
    }
}
