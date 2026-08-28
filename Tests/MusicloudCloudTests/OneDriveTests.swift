import Foundation
import Testing
import MusicloudCore
@testable import MusicloudCloud

private let clientID = "00000000-0000-0000-0000-000000000001"
private let driveJSON = #"{"id":"drive-one","name":"Music Drive"}"#
private let tokenJSON = #"{"access_token":"test-new","refresh_token":"test-refresh-new","expires_in":3600,"token_type":"Bearer"}"#

private final class MemoryVault: TokenVault, @unchecked Sendable {
    private let lock = NSLock()
    private var value: OneDriveTokens?
    init(_ value: OneDriveTokens? = nil) { self.value = value }
    func load() throws -> OneDriveTokens? { lock.withLock { value } }
    func save(_ tokens: OneDriveTokens) throws { lock.withLock { value = tokens } }
    func remove() throws { lock.withLock { value = nil } }
}

private actor StubHTTP: CloudHTTP {
    var requests: [URLRequest] = []
    private var replies: [CloudResponse]
    private let delay: Duration
    init(_ replies: [(Int, String)], delay: Duration = .zero) {
        self.replies = replies.map { CloudResponse(data: Data($0.1.utf8), status: $0.0) }
        self.delay = delay
    }
    func send(_ request: URLRequest) async throws -> CloudResponse {
        requests.append(request)
        guard !replies.isEmpty else { throw CloudError.invalidResponse }
        let response = replies.removeFirst()
        if delay > .zero { try await Task.sleep(for: delay) }
        return response
    }
}

private func tokens(expired: Bool = false) -> OneDriveTokens {
    OneDriveTokens(accessToken: "test-access", refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(expired ? -10 : 3600))
}

@Test func pkceAndCallbackValidation() throws {
    #expect(OneDriveAuthorization.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    let request = try OneDriveAuthorization(clientID: clientID)
    let second = try OneDriveAuthorization(clientID: clientID)
    #expect(request.verifier != second.verifier)
    #expect(request.state != second.state)
    #expect(request.verifier.count == 43)
    let url = try #require(URL(string: "musicloud://oauth?state=\(request.state)&code=test-code"))
    #expect(try request.code(from: url) == "test-code")
    for callback in ["musicloud://oauth?state=wrong&code=test", "musicloud://wrong?state=\(request.state)&code=test",
                     "musicloud://oauth?state=\(request.state)&state=\(request.state)&code=test",
                     "musicloud://oauth?state=\(request.state)&code=a&code=b"] {
        #expect(throws: CloudError.self) { try request.code(from: URL(string: callback)!) }
    }
    #expect(String(data: OneDriveAuthorization.form(["value": "a+b&c=d e"]), encoding: .utf8) == "value=a%2Bb%26c%3Dd%20e")
}

@Test func authorizationExchangesCodeAndStoresTokens() async throws {
    let http = StubHTTP([(200, tokenJSON)])
    let vault = MemoryVault()
    let service = try OneDriveService(clientID: clientID, vault: vault, http: http)
    let authorization = try OneDriveAuthorization(clientID: clientID)
    let callback = URL(string: "musicloud://oauth?state=\(authorization.state)&code=test-code")!
    try await service.authenticate(authorization, callback: callback)
    #expect(try vault.load()?.accessToken == "test-new")
    let request = try #require(await http.requests.first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.host == "login.microsoftonline.com")
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    #expect(body.contains("code_verifier=\(authorization.verifier)"))
    #expect(!body.contains("client_secret"))
}

@Test func graphBlocksUntrustedPaginationURLs() async throws {
    for address in ["https://evil.example/v1.0/me", "http://graph.microsoft.com/v1.0/me",
                    "https://graph.microsoft.com.evil.example/v1.0/me", "https://graph.microsoft.com:444/v1.0/me",
                    "https://user@graph.microsoft.com/v1.0/me", "https://graph.microsoft.com/beta/me"] {
        #expect(!OneDriveService.isGraphURL(URL(string: address)!))
    }
    let http = StubHTTP([(200, driveJSON)])
    let service = try OneDriveService(clientID: clientID, vault: MemoryVault(tokens()), http: http)
    await #expect(throws: CloudError.self) { try await service.children(nextLink: URL(string: "https://evil.example/page")!) }
    #expect(await http.requests.count == 1)
}

@Test func pagingAndPlaybackUseStableIDs() async throws {
    let page = #"{"value":[{"id":"folder","name":"Albums","folder":{}},{"id":"song","name":"Track.flac","audio":{"title":"Title","artist":"Artist","album":"Album"},"parentReference":{"id":"parent"}}],"@odata.nextLink":"https://graph.microsoft.com/v1.0/drives/drive-one/root/children?$skiptoken=next"}"#
    let http = StubHTTP([(200, driveJSON), (200, page), (200, #"{"value":[]}"#),
                         (200, #"{"@microsoft.graph.downloadUrl":"https://storage.example/song?temporary=test"}"#)])
    let service = try OneDriveService(clientID: clientID, vault: MemoryVault(tokens()), http: http)
    let first = try await service.children()
    #expect(first.value[0].isFolder)
    #expect(first.value[1].isAudio)
    let track = first.value[1].track(driveID: "drive-one")
    #expect(track.format == "FLAC")
    #expect(track.title == "Title")
    _ = try await service.children(nextLink: first.nextLink)
    let signedURL = try await service.playbackURL(for: #require(track.cloud))
    #expect(signedURL.host == "storage.example")
    #expect(!String(data: try JSONEncoder().encode(track), encoding: .utf8)!.contains("temporary"))
    let requests = await http.requests
    #expect(requests.allSatisfy { $0.url?.host == "graph.microsoft.com" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-access" })
    #expect(requests[2].url == first.nextLink)
}

@Test func refreshIsSharedByConcurrentRequests() async throws {
    let http = StubHTTP([(200, tokenJSON), (200, driveJSON), (200, driveJSON)], delay: .milliseconds(20))
    let vault = MemoryVault(tokens(expired: true))
    let service = try OneDriveService(clientID: clientID, vault: vault, http: http)
    async let first = service.drive()
    async let second = service.drive()
    _ = try await (first, second)
    let requests = await http.requests
    #expect(requests.filter { $0.httpMethod == "POST" }.count == 1)
    #expect(try vault.load()?.refreshToken == "test-refresh-new")
}

@Test func unauthorizedGraphRequestRefreshesOnce() async throws {
    let http = StubHTTP([(401, "{}"), (200, tokenJSON), (200, driveJSON)])
    let service = try OneDriveService(clientID: clientID, vault: MemoryVault(tokens()), http: http)
    #expect(try await service.drive().id == "drive-one")
    let requests = await http.requests
    #expect(requests.count == 3)
    #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer test-new")
}

@Test func disconnectCannotBeUndoneByPendingRefresh() async throws {
    let http = StubHTTP([(200, tokenJSON), (200, driveJSON)], delay: .milliseconds(100))
    let vault = MemoryVault(tokens(expired: true))
    let service = try OneDriveService(clientID: clientID, vault: vault, http: http)
    let pending = Task { try await service.drive() }
    for _ in 0..<100 {
        if await !http.requests.isEmpty { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    try await service.disconnect()
    await #expect(throws: CancellationError.self) { try await pending.value }
    #expect(try vault.load() == nil)
}

@Test func localLibrariesRemainCompatibleAndCloudIdentitySurvivesRename() throws {
    let original = Data(#"{"url":"file:///music/song.wav","title":"Song","artist":"Artist","album":"Album"}"#.utf8)
    let local = try JSONDecoder().decode(Track.self, from: original)
    #expect(local.cloud == nil)
    var first = Track(url: URL(string: "musicloud://onedrive/drive/folder/one.flac")!)
    first.cloud = CloudTrackReference(driveID: "drive", itemID: "stable")
    var renamed = Track(url: URL(string: "musicloud://onedrive/drive/folder/two.flac")!)
    renamed.cloud = first.cloud
    #expect(first.id == renamed.id)
    #expect(Library.merging([first], with: [renamed]).count == 1)
    #expect(try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(first)) == first)
}

@Test func playbackRejectsAnotherAccountAndInsecureDownload() async throws {
    let http = StubHTTP([(200, driveJSON), (200, #"{"@microsoft.graph.downloadUrl":"http://storage.example/song"}"#)])
    let service = try OneDriveService(clientID: clientID, vault: MemoryVault(tokens()), http: http)
    await #expect(throws: CloudError.self) {
        try await service.playbackURL(for: CloudTrackReference(driveID: "another-drive", itemID: "song"))
    }
    #expect(await http.requests.count == 1)
    await #expect(throws: CloudError.self) {
        try await service.playbackURL(for: CloudTrackReference(driveID: "drive-one", itemID: "song"))
    }
}

@Test func revokedRefreshTokenRequiresNewSignIn() async throws {
    let vault = MemoryVault(tokens(expired: true))
    let http = StubHTTP([(400, #"{"error":"invalid_grant"}"#)])
    let service = try OneDriveService(clientID: clientID, vault: vault, http: http)
    await #expect(throws: CloudError.self) { try await service.drive() }
    #expect(try vault.load() == nil)
}
