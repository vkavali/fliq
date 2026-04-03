import Foundation

enum CustomerClientError: LocalizedError {
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

final class CustomerClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func searchProviders(query: String) async throws -> [ProviderSearchResult] {
        let response: ProviderSearchResponse = try await request(
            path: "/providers/search",
            queryItems: [URLQueryItem(name: "q", value: query)],
            method: "GET",
            body: nil,
            accessToken: nil
        )
        return response.providers
    }

    func loadProvider(providerId: String) async throws -> ProviderProfile {
        try await request(
            path: "/providers/\(providerId)/public",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: nil
        )
    }

    func resolveQrCode(rawInput: String) async throws -> TipEntryContext {
        let qrCodeId = extractIdentifier(from: rawInput, expectedSegment: "qr")
        let response: ResolvedQrCodeResponse = try await request(
            path: "/qrcodes/\(qrCodeId)/resolve",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: nil
        )
        return TipEntryContext(
            providerId: response.providerId,
            providerName: response.providerName,
            category: response.category,
            source: .qrCode,
            entryLabel: "QR code",
            entryDetail: response.locationLabel,
            suggestedAmountPaise: nil,
            allowCustomAmount: true
        )
    }

    func resolvePaymentLink(rawInput: String) async throws -> TipEntryContext {
        let paymentLinkId = extractIdentifier(from: rawInput, expectedSegment: "tip")
        let response: ResolvedPaymentLinkResponse = try await request(
            path: "/payment-links/\(paymentLinkId)/resolve",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: nil
        )
        let detail = [response.description, response.workplace, response.role, response.shortCode]
            .compactMap { (value: String?) -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first
        return TipEntryContext(
            providerId: response.providerId,
            providerName: response.providerName,
            category: response.category,
            source: .paymentLink,
            entryLabel: "Payment link",
            entryDetail: detail,
            suggestedAmountPaise: response.suggestedAmountPaise,
            allowCustomAmount: response.allowCustomAmount
        )
    }

    func createTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        source: TipSourceOption,
        intent: TipIntentOption,
        message: String?,
        rating: Int,
        idempotencyKey: String = UUID().uuidString
    ) async throws -> CreatedTipOrder {
        var body: [String: Any] = [
            "providerId": providerId,
            "amountPaise": amountPaise,
            "source": source.rawValue,
            "intent": intent.rawValue,
            "rating": rating
        ]

        if let message, !message.isEmpty {
            body["message"] = message
        }

        return try await request(
            path: "/tips/authenticated",
            queryItems: [],
            method: "POST",
            body: body,
            accessToken: accessToken,
            extraHeaders: ["idempotency-key": idempotencyKey]
        )
    }

    func verifyPayment(
        tipId: String,
        orderId: String,
        paymentId: String,
        signature: String
    ) async throws -> VerifiedTipResult {
        try await request(
            path: "/tips/\(tipId)/verify",
            queryItems: [],
            method: "POST",
            body: [
                "razorpay_order_id": orderId,
                "razorpay_payment_id": paymentId,
                "razorpay_signature": signature
            ],
            accessToken: nil
        )
    }

    func verifyMockPayment(
        tipId: String,
        orderId: String
    ) async throws -> VerifiedTipResult {
        try await verifyPayment(
            tipId: tipId,
            orderId: orderId,
            paymentId: "mock_payment_\(Int(Date().timeIntervalSince1970))",
            signature: "mock_signature"
        )
    }

    func getTipStatus(tipId: String) async throws -> TipStatusSnapshot {
        try await request(
            path: "/tips/\(tipId)/status",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: nil
        )
    }

    func getTipImpact(tipId: String) async throws -> TipImpactSnapshot {
        try await request(
            path: "/tips/\(tipId)/impact",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: nil
        )
    }

    func getCustomerTipHistory(
        accessToken: String,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> CustomerTipHistoryResponse {
        try await request(
            path: "/tips/customer",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func getCurrentUserProfile(accessToken: String) async throws -> AuthUser {
        try await request(
            path: "/users/me",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func updateCurrentUserProfile(
        accessToken: String,
        name: String?,
        email: String?,
        phone: String?,
        languagePreference: String?
    ) async throws -> AuthUser {
        var body: [String: Any] = [:]
        if let name, !name.isEmpty {
            body["name"] = name
        }
        if let email, !email.isEmpty {
            body["email"] = email
        }
        if let phone, !phone.isEmpty {
            body["phone"] = phone
        }
        if let languagePreference, !languagePreference.isEmpty {
            body["languagePreference"] = languagePreference
        }

        return try await request(
            path: "/users/me",
            queryItems: [],
            method: "PATCH",
            body: body,
            accessToken: accessToken
        )
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: [String: Any]?,
        accessToken: String?,
        extraHeaders: [String: String] = [:]
    ) async throws -> Response {
        guard var components = URLComponents(string: baseURL + path) else {
            throw CustomerClientError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw CustomerClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        extraHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CustomerClientError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = (try? decoder.decode(APIMessageResponse.self, from: data).message) ?? "Request failed with \(httpResponse.statusCode)"
            throw CustomerClientError.requestFailed(message: message, statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func extractIdentifier(from rawInput: String, expectedSegment: String) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let urlPathComponents = URL(string: trimmed)?.pathComponents.filter { $0 != "/" } ?? []
        if !urlPathComponents.isEmpty {
            if let index = urlPathComponents.firstIndex(of: expectedSegment), index + 1 < urlPathComponents.count {
                return urlPathComponents[index + 1]
            }
            if let last = urlPathComponents.last {
                return last
            }
        }

        let rawSegments = trimmed.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        if let index = rawSegments.firstIndex(of: expectedSegment), index + 1 < rawSegments.count {
            return rawSegments[index + 1]
        }

        return rawSegments.last ?? trimmed
    }
}
