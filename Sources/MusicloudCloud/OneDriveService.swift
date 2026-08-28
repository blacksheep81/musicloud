import Foundation
import MusicloudCore

public struct OneDriveInfo: Decodable, Sendable {
    public let id: String
    public let name: String?
}

public struct OneDriveItem: Decodable, Identifiable, Sendable {
    public struct Folder: Decodable, Sendable {}
    public struct Audio: Decodable, Sendable {
        public let title: String?
        public let artist: String?
        public let album: String?
    }
    public struct Parent: Decodable, Sendable { public let id: String? }
    public let id: String
    public let name: String
    public let folder: Folder?
    public let audio: Audio?
    public let parentReference: Parent?
    public var isFolder: Bool { folder != nil }
    public var isAudio: Bool { !isFolder && Track.supports(URL(fileURLWithPath: name)) }

    public func track(driveID: String) -> Track {
        let url = URL(string: "musicloud://onedrive")!.appending(component: driveID)
            .appending(component: parentReference?.id ?? "root").appending(component: name)
        var track = Track(url: url, title: audio?.title ?? URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent,
                          artist: audio?.artist ?? "Unknown Artist", album: audio?.album ?? "Unknown Album")
        track.cloud = CloudTrackReference(driveID: driveID, itemID: id)
        return track
    }
}

public struct OneDrivePage: Decodable, Sendable {
    public let value: [OneDriveItem]
    public let nextLink: URL?
    enum CodingKeys: String, CodingKey { case value; case nextLink = "@odata.nextLink" }
}

public actor OneDriveService {
    private let clientID: String
    private let http: any CloudHTTP
    private let vault: any TokenVault
    private var tokens: OneDriveTokens?
    private var generation = 0
    private var refreshTask: Task<String, Error>?
    private var connectedDrive: OneDriveInfo?

    public init(clientID: String, vault: any TokenVault, http: any CloudHTTP = CloudURLSession()) throws {
        guard UUID(uuidString: clientID) != nil else { throw CloudError.invalidClientID }
        self.clientID = clientID
        self.vault = vault
        self.http = http
        tokens = try vault.load()
    }

    public func authenticate(_ authorization: OneDriveAuthorization, callback: URL) async throws {
        guard authorization.clientID == clientID else { throw CloudError.invalidClientID }
        let code = try authorization.code(from: callback)
        generation += 1
        let version = generation
        refreshTask?.cancel()
        refreshTask = nil
        let result = try await requestTokens([
            "client_id": clientID, "grant_type": "authorization_code", "code": code,
            "redirect_uri": OneDriveAuthorization.redirectURI, "code_verifier": authorization.verifier,
            "scope": OneDriveAuthorization.scope
        ])
        try Task.checkCancellation()
        guard version == generation else { throw CancellationError() }
        try vault.save(result)
        tokens = result
        connectedDrive = nil
    }

    public func disconnect() throws {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        connectedDrive = nil
        try vault.remove()
    }

    public func drive() async throws -> OneDriveInfo {
        if let connectedDrive { return connectedDrive }
        let version = generation
        let drive: OneDriveInfo = try await graph(URL(string: "https://graph.microsoft.com/v1.0/me/drive")!)
        guard version == generation else { throw CancellationError() }
        connectedDrive = drive
        return drive
    }

    public func children(folderID: String? = nil, nextLink: URL? = nil) async throws -> OneDrivePage {
        let drive = try await drive()
        var url = URL(string: "https://graph.microsoft.com/v1.0/drives")!.appending(component: drive.id)
        if let folderID { url = url.appending(path: "items").appending(component: folderID) }
        else { url = url.appending(path: "root") }
        url = url.appending(path: "children")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "$select", value: "id,name,folder,audio,parentReference"),
                                 URLQueryItem(name: "$top", value: "100")]
        return try await graph(nextLink ?? components.url!)
    }

    public func playbackURL(for reference: CloudTrackReference) async throws -> URL {
        let drive = try await drive()
        guard drive.id == reference.driveID else { throw CloudError.wrongDrive }
        let url = URL(string: "https://graph.microsoft.com/v1.0/drives")!.appending(component: drive.id)
            .appending(path: "items").appending(component: reference.itemID)
        struct Download: Decodable {
            let url: URL?
            enum CodingKeys: String, CodingKey { case url = "@microsoft.graph.downloadUrl" }
        }
        let download: Download = try await graph(url)
        guard let result = download.url, result.scheme == "https", result.host != nil,
              result.user == nil, result.password == nil else { throw CloudError.invalidResponse }
        return result
    }

    public static func isGraphURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "graph.microsoft.com" && (url.port == nil || url.port == 443)
            && url.user == nil && url.password == nil && url.fragment == nil && url.path.hasPrefix("/v1.0/")
    }

    private func graph<T: Decodable>(_ url: URL) async throws -> T {
        guard Self.isGraphURL(url) else { throw CloudError.unsafeURL }
        let version = generation
        for attempt in 0...1 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(try await accessToken(forceRefresh: attempt == 1))", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let response = try await http.send(request)
            try Task.checkCancellation()
            guard version == generation else { throw CancellationError() }
            if response.status == 401 && attempt == 0 { continue }
            guard (200..<300).contains(response.status) else { throw CloudError.http(response.status) }
            return try JSONDecoder().decode(T.self, from: response.data)
        }
        throw CloudError.signInRequired
    }

    private func accessToken(forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let tokens, tokens.expiresAt > Date().addingTimeInterval(60) { return tokens.accessToken }
        if let refreshTask { return try await refreshTask.value }
        guard let refresh = tokens?.refreshToken else { throw CloudError.signInRequired }
        let version = generation
        let task = Task { try await self.refresh(refresh, version: version) }
        refreshTask = task
        defer { if version == generation { refreshTask = nil } }
        return try await task.value
    }

    private func refresh(_ refresh: String, version: Int) async throws -> String {
        do {
            let result = try await requestTokens([
                "client_id": clientID, "grant_type": "refresh_token", "refresh_token": refresh,
                "scope": OneDriveAuthorization.scope
            ], previousRefresh: refresh)
            try Task.checkCancellation()
            guard generation == version else { throw CancellationError() }
            try vault.save(result)
            tokens = result
            return result.accessToken
        } catch CloudError.oauth("invalid_grant") {
            if generation == version { tokens = nil; try vault.remove() }
            throw CloudError.signInRequired
        }
    }

    private func requestTokens(_ fields: [String: String], previousRefresh: String? = nil) async throws -> OneDriveTokens {
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.httpBody = OneDriveAuthorization.form(fields)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let response = try await http.send(request)
        guard (200..<300).contains(response.status) else {
            struct OAuthError: Decodable { let error: String }
            let code = (try? JSONDecoder().decode(OAuthError.self, from: response.data))?.error ?? "oauth_error"
            let safe = ["invalid_grant", "invalid_client", "unauthorized_client", "invalid_scope", "access_denied"]
            throw CloudError.oauth(safe.contains(code) ? code : "oauth_error")
        }
        struct Reply: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
            let token_type: String
        }
        let reply = try JSONDecoder().decode(Reply.self, from: response.data)
        guard reply.token_type.lowercased() == "bearer", !reply.access_token.isEmpty, reply.expires_in > 0 else { throw CloudError.invalidResponse }
        return OneDriveTokens(accessToken: reply.access_token, refreshToken: reply.refresh_token ?? previousRefresh,
                              expiresAt: Date().addingTimeInterval(reply.expires_in))
    }
}
