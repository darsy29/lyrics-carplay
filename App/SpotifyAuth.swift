import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class SpotifyAuth: NSObject, ObservableObject {
    static let shared = SpotifyAuth()

    // Your Spotify Client ID lives in Secrets.swift, which is not committed to git.
    // Copy Config/Secrets.swift.example to App/Secrets.swift and paste your ID there.
    private let clientID = Secrets.spotifyClientID
    private let redirectURI = "lyricscarplay://spotify-callback"
    private let scopes = "user-read-currently-playing user-read-playback-state"

    @Published var isAuthorized = false

    private var codeVerifier = ""
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        isAuthorized = KeychainHelper.load(key: "spotify_refresh_token") != nil
    }

    func login() {
        codeVerifier = Self.randomString(length: 64)
        let challenge = Self.codeChallenge(for: codeVerifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        let session = ASWebAuthenticationSession(
            url: components.url!,
            callbackURLScheme: "lyricscarplay"
        ) { [weak self] callbackURL, error in
            guard let self, let callbackURL, error == nil else { return }
            self.handleCallback(url: callbackURL)
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        authSession = session
        session.start()
    }

    private func handleCallback(url: URL) {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else { return }
        Task { try? await exchangeCodeForToken(code: code) }
    }

    private func exchangeCodeForToken(code: String) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": codeVerifier
        ]
        request.httpBody = Self.formURLEncoded(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        try storeTokens(from: data)
        isAuthorized = true
    }

    func validAccessToken() async throws -> String {
        if let expiry = UserDefaults.standard.object(forKey: "spotify_token_expiry") as? Date,
           expiry > Date(),
           let token = KeychainHelper.load(key: "spotify_access_token") {
            return token
        }
        return try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainHelper.load(key: "spotify_refresh_token") else {
            throw AuthError.notAuthorized
        }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ]
        request.httpBody = Self.formURLEncoded(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        try storeTokens(from: data)
        return KeychainHelper.load(key: "spotify_access_token") ?? ""
    }

    private func storeTokens(from data: Data) throws {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainHelper.save(response.access_token, key: "spotify_access_token")
        if let refresh = response.refresh_token {
            KeychainHelper.save(refresh, key: "spotify_refresh_token")
        }
        let expiry = Date().addingTimeInterval(TimeInterval(response.expires_in - 60))
        UserDefaults.standard.set(expiry, forKey: "spotify_token_expiry")
    }

    enum AuthError: Error { case notAuthorized }

    private static func randomString(length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }

    // Percent-encodes each value before joining, so characters like the
    // "://" in redirectURI can't be misread as part of the field structure.
    private static func formURLEncoded(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = params.map { key, value -> String in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encoded)"
        }
        return pairs.joined(separator: "&").data(using: .utf8)!
    }
}

extension SpotifyAuth: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
