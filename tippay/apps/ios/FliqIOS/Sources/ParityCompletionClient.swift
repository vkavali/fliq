import Foundation

enum NativeRecurringFrequency: String, CaseIterable, Identifiable {
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

struct NativeRecurringAuthorization: Decodable {
    let recurringTipId: String
    let subscriptionId: String
    let authorizationUrl: String
    let razorpayKeyId: String
    let provider: TipOrderProvider?

    var providerName: String {
        provider?.name ?? "Provider"
    }
}

struct NativeRecurringTipProviderProfile: Decodable {
    let category: String?
}

struct NativeRecurringTipProvider: Decodable {
    let name: String?
    let providerProfile: NativeRecurringTipProviderProfile?
}

struct NativeRecurringTip: Decodable, Identifiable {
    let id: String
    let amountPaise: Int
    let frequency: String
    let status: String
    let nextChargeDate: String?
    let totalCharges: Int
    let createdAt: String?
    let provider: NativeRecurringTipProvider?

    var providerName: String? { provider?.name }
    var providerCategory: String? { provider?.providerProfile?.category }
}

struct NativeDeferredTipProviderProfile: Decodable {
    let category: String?
}

struct NativeDeferredTipProvider: Decodable {
    let name: String?
    let providerProfile: NativeDeferredTipProviderProfile?
}

struct NativeDeferredTip: Decodable, Identifiable {
    let id: String
    let providerId: String
    let amountPaise: Int
    let message: String?
    let rating: Int?
    let promisedAt: String?
    let dueAt: String?
    let status: String
    let tipId: String?
    let provider: NativeDeferredTipProvider?

    var providerName: String? { provider?.name }
    var providerCategory: String? { provider?.providerProfile?.category }
}

struct NativeBadge: Decodable, Identifiable {
    let id: String
    let code: String
    let name: String
    let description: String
    let category: String
    let threshold: Int
    let earned: Bool
    let earnedAt: String?
}

struct NativeStreak: Decodable {
    let currentStreak: Int
    let longestStreak: Int
    let lastTipDate: String?
}

struct NativeLeaderboardEntry: Decodable, Identifiable {
    let rank: Int
    let userId: String?
    let name: String
    let tipCount: Int
    let totalAmountPaise: Int?
    let totalEarnedPaise: Int?

    var id: String { userId ?? "\(rank)-\(name)" }
    var displayAmountPaise: Int { totalAmountPaise ?? totalEarnedPaise ?? 0 }
}

struct NativePaymentOrder: Decodable {
    let tipId: String
    let orderId: String
    let amount: Int
    let currency: String
    let razorpayKeyId: String
    let providerName: String?
    let jarName: String?

    var amountPaise: Int { amount }
    var title: String { providerName ?? jarName ?? "Fliq payment" }
    var subtitle: String? { jarName }
    var isMockOrder: Bool { orderId.hasPrefix("mock_order_") }
}

struct NativeEkycInitiation: Decodable {
    let sessionToken: String
    let maskedPhone: String
}

struct NativeEkycProfile: Decodable {
    let name: String
    let dob: String
    let gender: String
    let address: String
}

struct NativeEkycVerifyResponse: Decodable {
    let success: Bool
    let profile: NativeEkycProfile
}

struct NativeEkycStatus: Decodable {
    let kycVerified: Bool
    let kycMethod: String?
    let kycCompletedAt: String?
    let kycStatus: String
}

struct NativeTipResponse: Decodable, Identifiable {
    let id: String
    let type: String
    let emoji: String?
    let mediaUrl: String?
    let createdAt: String?
}

final class ParityCompletionClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func createRecurringTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        frequency: NativeRecurringFrequency
    ) async throws -> NativeRecurringAuthorization {
        try await request(
            path: "/recurring-tips",
            queryItems: [],
            method: "POST",
            body: [
                "providerId": providerId,
                "amountPaise": amountPaise,
                "frequency": frequency.rawValue
            ],
            accessToken: accessToken
        )
    }

    func getMyRecurringTips(accessToken: String) async throws -> [NativeRecurringTip] {
        try await request(
            path: "/recurring-tips",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func pauseRecurringTip(accessToken: String, recurringTipId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/recurring-tips/\(recurringTipId)/pause",
            queryItems: [],
            method: "PATCH",
            body: nil,
            accessToken: accessToken
        )
    }

    func resumeRecurringTip(accessToken: String, recurringTipId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/recurring-tips/\(recurringTipId)/resume",
            queryItems: [],
            method: "PATCH",
            body: nil,
            accessToken: accessToken
        )
    }

    func cancelRecurringTip(accessToken: String, recurringTipId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/recurring-tips/\(recurringTipId)",
            queryItems: [],
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func createDeferredTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        message: String?,
        rating: Int?
    ) async throws -> NativeDeferredTip {
        var body: [String: Any] = [
            "providerId": providerId,
            "amountPaise": amountPaise
        ]
        if let message, !message.isEmpty { body["message"] = message }
        if let rating { body["rating"] = rating }
        return try await request(
            path: "/tip-later",
            queryItems: [],
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    func getMyDeferredTips(accessToken: String) async throws -> [NativeDeferredTip] {
        try await request(
            path: "/tip-later/my",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func payDeferredTip(accessToken: String, deferredTipId: String) async throws -> NativePaymentOrder {
        try await request(
            path: "/tip-later/\(deferredTipId)/pay",
            queryItems: [],
            method: "POST",
            body: nil,
            accessToken: accessToken
        )
    }

    func cancelDeferredTip(accessToken: String, deferredTipId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/tip-later/\(deferredTipId)",
            queryItems: [],
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func getBadges(accessToken: String) async throws -> [NativeBadge] {
        try await request(
            path: "/gamification/badges",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func getStreak(accessToken: String) async throws -> NativeStreak {
        try await request(
            path: "/gamification/streak",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func getLeaderboard(path: String, period: String = "week") async throws -> [NativeLeaderboardEntry] {
        try await request(
            path: path,
            queryItems: [URLQueryItem(name: "period", value: period)],
            method: "GET",
            body: nil,
            accessToken: nil
        )
    }

    func saveBankDetails(
        accessToken: String,
        upiVpa: String?,
        bankAccountNumber: String?,
        ifscCode: String?,
        pan: String?
    ) async throws {
        var body: [String: Any] = [:]
        if let upiVpa, !upiVpa.isEmpty { body["upiVpa"] = upiVpa }
        if let bankAccountNumber, !bankAccountNumber.isEmpty { body["bankAccountNumber"] = bankAccountNumber }
        if let ifscCode, !ifscCode.isEmpty { body["ifscCode"] = ifscCode }
        if let pan, !pan.isEmpty { body["pan"] = pan }
        let _: ProviderSelfProfile = try await request(
            path: "/providers/profile",
            queryItems: [],
            method: "PATCH",
            body: body,
            accessToken: accessToken
        )
    }

    func initiateEkyc(accessToken: String, aadhaarOrVid: String) async throws -> NativeEkycInitiation {
        try await request(
            path: "/ekyc/initiate",
            queryItems: [],
            method: "POST",
            body: ["aadhaarOrVid": aadhaarOrVid],
            accessToken: accessToken
        )
    }

    func verifyEkycOtp(
        accessToken: String,
        sessionToken: String,
        otp: String
    ) async throws -> NativeEkycProfile {
        let response: NativeEkycVerifyResponse = try await request(
            path: "/ekyc/verify-otp",
            queryItems: [],
            method: "POST",
            body: [
                "sessionToken": sessionToken,
                "otp": otp
            ],
            accessToken: accessToken
        )
        return response.profile
    }

    func getEkycStatus(accessToken: String) async throws -> NativeEkycStatus {
        try await request(
            path: "/ekyc/status",
            queryItems: [],
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
    }

    func createEmojiResponse(accessToken: String, tipId: String, emoji: String) async throws -> NativeTipResponse {
        try await request(
            path: "/responses",
            queryItems: [],
            method: "POST",
            body: [
                "tipId": tipId,
                "type": "emoji",
                "emoji": emoji
            ],
            accessToken: accessToken
        )
    }

    func getTipResponse(tipId: String) async throws -> NativeTipResponse? {
        do {
            let response: NativeTipResponse = try await request(
                path: "/responses/tip/\(tipId)",
                queryItems: [],
                method: "GET",
                body: nil,
                accessToken: nil
            )
            return response
        } catch let error as CustomerClientError where error.statusCode == 404 {
            return nil
        }
    }

    func exportBusinessCsv(accessToken: String, businessId: String) async throws -> String {
        guard let url = URL(string: baseURL + "/business/\(businessId)/export") else {
            throw CustomerClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CustomerClientError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = (try? decoder.decode(APIMessageResponse.self, from: data).message) ?? "Request failed with \(httpResponse.statusCode)"
            throw CustomerClientError.requestFailed(message: message, statusCode: httpResponse.statusCode)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: [String: Any]?,
        accessToken: String?
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
}
