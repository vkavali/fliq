import Foundation

enum AuthClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(message: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The backend URL is invalid."
        case .invalidResponse:
            return "The backend returned an invalid response."
        case let .requestFailed(message, _):
            return message
        }
    }

    var statusCode: Int? {
        switch self {
        case let .requestFailed(_, statusCode):
            return statusCode
        default:
            return nil
        }
    }
}

final class AuthClient {
    private let baseURL = "https://www.fliq.co.in"
    private let sessionStore = AuthSessionStore()
    private let decoder = JSONDecoder()

    func restoreSession() async -> AuthSession? {
        guard let stored = sessionStore.load() else { return nil }
        do {
            let freshUser = try await currentUser(accessToken: stored.accessToken)
            let refreshed = AuthSession(
                accessToken: stored.accessToken,
                refreshToken: stored.refreshToken,
                user: freshUser
            )
            sessionStore.save(refreshed)
            return refreshed
        } catch let error as AuthClientError {
            if error.statusCode == 401 {
                sessionStore.clear()
                return nil
            }
            return stored
        } catch {
            return stored
        }
    }

    func sendCode(role: NativeRole, credential: String) async throws -> SendCodeResult {
        let path = role.usesEmail ? "/auth/otp/email/send" : "/auth/otp/send"
        let body: [String: Any] = role.usesEmail ? ["email": credential] : ["phone": credential]
        return try await request(path: path, method: "POST", body: body, accessToken: nil)
    }

    func verifyCode(role: NativeRole, credential: String, code: String) async throws -> AuthSession {
        let path = role.usesEmail ? "/auth/otp/email/verify" : "/auth/otp/verify"
        let body: [String: Any] = role.usesEmail
            ? ["email": credential, "code": code]
            : ["phone": credential, "code": code]

        let response: VerifyCodeResponse = try await request(path: path, method: "POST", body: body, accessToken: nil)
        let session = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            user: response.user
        )
        sessionStore.save(session)
        return session
    }

    func logout() {
        sessionStore.clear()
    }

    func persistSession(_ session: AuthSession) {
        sessionStore.save(session)
    }

    private func currentUser(accessToken: String) async throws -> AuthUser {
        return try await request(path: "/users/me", method: "GET", body: nil, accessToken: accessToken)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        accessToken: String?
    ) async throws -> Response {
        guard let url = URL(string: baseURL + path) else {
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthClientError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = (try? decoder.decode(APIMessageResponse.self, from: data).message) ?? "Request failed with \(httpResponse.statusCode)"
            throw AuthClientError.requestFailed(message: message, statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }
}
