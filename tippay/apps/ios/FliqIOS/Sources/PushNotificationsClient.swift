import Foundation

final class PushNotificationsClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func registerToken(accessToken: String, token: String, platform: String = "ios") async throws {
        let _: APIMessageResponse = try await request(
            path: "/notifications/fcm-token",
            method: "POST",
            body: [
                "token": token,
                "platform": platform
            ],
            accessToken: accessToken
        )
    }

    func removeToken(accessToken: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/notifications/fcm-token",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        accessToken: String
    ) async throws -> Response {
        guard let url = URL(string: baseURL + path) else {
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        let payload = data.isEmpty ? Data("{\"message\":\"OK\"}".utf8) : data
        return try decoder.decode(Response.self, from: payload)
    }
}
