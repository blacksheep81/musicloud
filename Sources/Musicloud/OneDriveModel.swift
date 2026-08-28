import AppKit
import AuthenticationServices
import MusicloudCloud
import MusicloudCore
import SwiftUI

@MainActor
private final class MicrosoftBrowserLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var requestID: UUID?

    func authorize(_ request: OneDriveAuthorization) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let requestID = UUID()
            self.requestID = requestID
            self.continuation = continuation
            let session = ASWebAuthenticationSession(url: request.url, callbackURLScheme: "musicloud") { [weak self] url, error in
                Task { @MainActor in
                    guard let self, self.requestID == requestID, let continuation = self.continuation else { return }
                    self.requestID = nil
                    self.continuation = nil
                    self.session = nil
                    if let url { continuation.resume(returning: url) }
                    else { continuation.resume(throwing: error ?? CancellationError()) }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                self.requestID = nil
                self.continuation = nil
                self.session = nil
                continuation.resume(throwing: CloudError.invalidResponse)
            }
        }
    }

    func cancel() {
        requestID = nil
        session?.cancel()
        session = nil
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    }
}

@MainActor
final class OneDriveModel: ObservableObject {
    struct Folder { let id: String; let name: String }
    @Published var clientID = UserDefaults.standard.string(forKey: "oneDriveClientID") ?? ""
    @Published private(set) var drive: OneDriveInfo?
    @Published private(set) var items: [OneDriveItem] = []
    @Published private(set) var path: [Folder] = []
    @Published private(set) var nextLink: URL?
    @Published private(set) var isBusy = false
    @Published var error: String?
    private var service: OneDriveService?
    private let browser = MicrosoftBrowserLogin()
    private var task: Task<Void, Never>?
    var canConnect: Bool { UUID(uuidString: clientID.trimmingCharacters(in: .whitespacesAndNewlines)) != nil }

    func connect() {
        guard !isBusy else { return }
        run {
            let id = self.clientID.trimmingCharacters(in: .whitespacesAndNewlines)
            let service = try OneDriveService(clientID: id, vault: KeychainTokenVault(clientID: id))
            self.service = service
            UserDefaults.standard.set(id, forKey: "oneDriveClientID")
            let drive: OneDriveInfo
            do {
                drive = try await service.drive()
            } catch CloudError.signInRequired {
                let request = try OneDriveAuthorization(clientID: id)
                let callback = try await self.browser.authorize(request)
                try Task.checkCancellation()
                try await service.authenticate(request, callback: callback)
                drive = try await service.drive()
            }
            let page = try await service.children()
            try Task.checkCancellation()
            self.drive = drive
            self.path = []
            self.items = page.value
            self.nextLink = page.nextLink
        }
    }

    func open(_ folder: OneDriveItem) {
        guard folder.isFolder else { return }
        load(path + [Folder(id: folder.id, name: folder.name)])
    }
    func back() { if !path.isEmpty { load(Array(path.dropLast())) } }
    func reload() { load(path) }
    private func load(_ path: [Folder]) {
        guard !isBusy, let service else { return }
        run {
            let page = try await service.children(folderID: path.last?.id)
            try Task.checkCancellation()
            self.path = path
            self.items = page.value
            self.nextLink = page.nextLink
        }
    }
    func loadMore() {
        guard !isBusy, let service, let nextLink else { return }
        run {
            let page = try await service.children(nextLink: nextLink)
            try Task.checkCancellation()
            var seen = Set(self.items.map(\.id))
            self.items += page.value.filter { seen.insert($0.id).inserted }
            self.nextLink = page.nextLink
        }
    }
    func disconnect() {
        guard !isBusy else { return }
        run {
            try await self.service?.disconnect()
            self.service = nil
            self.drive = nil
            self.items = []
            self.path = []
            self.nextLink = nil
        }
    }
    func playbackURL(_ reference: CloudTrackReference) async throws -> URL {
        guard let service else { throw CloudError.signInRequired }
        return try await service.playbackURL(for: reference)
    }
    func cancel() { browser.cancel(); task?.cancel() }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        isBusy = true
        error = nil
        task = Task {
            defer { isBusy = false; task = nil }
            do { try await operation() }
            catch is CancellationError {}
            catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {}
            catch { self.error = error.localizedDescription }
        }
    }
}
