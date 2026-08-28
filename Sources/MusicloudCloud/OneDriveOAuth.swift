import Foundation
import CryptoKit
import Security

public struct OneDriveAuthorization: Sendable {
    public static let redirectURI = "musicloud://oauth"
    public static let scope = "https://graph.microsoft.com/Files.Read offline_access"
    public let verifier: String
    public let state: String
    public let clientID: String

    public init(clientID: String) throws {
        guard UUID(uuidString: clientID) != nil else { throw CloudError.invalidClientID }
        self.clientID = clientID
        verifier = try Self.random()
        state = try Self.random()
    }

    public static func challenge(_ verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    public var url: URL {
        var url = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.challenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        return url.url!
    }

    public func code(from callback: URL) throws -> String {
        guard let url = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              url.scheme == "musicloud", url.host == "oauth", url.path.isEmpty,
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil else { throw CloudError.invalidCallback }
        let items = url.queryItems ?? []
        guard items.filter({ $0.name == "state" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == state else { throw CloudError.invalidCallback }
        if items.contains(where: { $0.name == "error" }) { throw CloudError.oauth("authorization_denied") }
        guard items.filter({ $0.name == "code" }).count == 1,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else { throw CloudError.invalidCallback }
        return code
    }

    public static func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return Data(fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw CloudError.invalidResponse }
        return base64URL(Data(bytes))
    }
}
