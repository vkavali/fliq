import Foundation

final class ProviderClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func getOwnProfile(accessToken: String) async throws -> ProviderSelfProfile {
        try await request(path: "/providers/profile", method: "GET", body: nil, accessToken: accessToken)
    }

    func createProfile(
        accessToken: String,
        displayName: String,
        category: String,
        bio: String?,
        upiVpa: String?
    ) async throws -> ProviderSelfProfile {
        var body: [String: Any] = [
            "displayName": displayName,
            "category": category
        ]
        if let bio, !bio.isEmpty { body["bio"] = bio }
        if let upiVpa, !upiVpa.isEmpty { body["upiVpa"] = upiVpa }
        let _: ProviderSelfProfile = try await request(path: "/providers/profile", method: "POST", body: body, accessToken: accessToken)
        return try await getOwnProfile(accessToken: accessToken)
    }

    func updateProfile(
        accessToken: String,
        displayName: String?,
        category: String?,
        bio: String?,
        upiVpa: String?
    ) async throws -> ProviderSelfProfile {
        var body: [String: Any] = [:]
        if let displayName, !displayName.isEmpty { body["displayName"] = displayName }
        if let category, !category.isEmpty { body["category"] = category }
        if let bio, !bio.isEmpty { body["bio"] = bio }
        if let upiVpa, !upiVpa.isEmpty { body["upiVpa"] = upiVpa }
        let _: ProviderSelfProfile = try await request(path: "/providers/profile", method: "PATCH", body: body, accessToken: accessToken)
        return try await getOwnProfile(accessToken: accessToken)
    }

    func uploadAvatar(
        accessToken: String,
        imageData: Data,
        mimeType: String = "image/jpeg"
    ) async throws -> String? {
        guard let url = URL(string: baseURL + "/providers/profile/avatar") else {
            throw AuthClientError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthClientError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = (try? decoder.decode(APIMessageResponse.self, from: data).message) ?? "Request failed with \(httpResponse.statusCode)"
            throw AuthClientError.requestFailed(message: message, statusCode: httpResponse.statusCode)
        }

        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return payload?["avatarUrl"] as? String
    }

    func getReceivedTips(accessToken: String) async throws -> [ProviderTipItem] {
        let response: ProviderTipsResponse = try await request(path: "/tips/provider", method: "GET", body: nil, accessToken: accessToken)
        return response.tips
    }

    func getQrCodes(accessToken: String) async throws -> [ProviderQrCode] {
        try await request(path: "/qrcodes/my", method: "GET", body: nil, accessToken: accessToken)
    }

    func createQrCode(accessToken: String, locationLabel: String?) async throws -> ProviderQrCode {
        var body: [String: Any] = [:]
        if let locationLabel, !locationLabel.isEmpty { body["locationLabel"] = locationLabel }
        return try await request(path: "/qrcodes", method: "POST", body: body, accessToken: accessToken)
    }

    func getPaymentLinks(accessToken: String) async throws -> [ProviderPaymentLink] {
        try await request(path: "/payment-links/my", method: "GET", body: nil, accessToken: accessToken)
    }

    func createPaymentLink(
        accessToken: String,
        role: String?,
        workplace: String?,
        description: String?,
        suggestedAmountPaise: Int?,
        allowCustomAmount: Bool
    ) async throws -> ProviderPaymentLink {
        var body: [String: Any] = ["allowCustomAmount": allowCustomAmount]
        if let role, !role.isEmpty { body["role"] = role }
        if let workplace, !workplace.isEmpty { body["workplace"] = workplace }
        if let description, !description.isEmpty { body["description"] = description }
        if let suggestedAmountPaise, suggestedAmountPaise > 0 { body["suggestedAmountPaise"] = suggestedAmountPaise }
        return try await request(path: "/payment-links", method: "POST", body: body, accessToken: accessToken)
    }

    func getPayoutHistory(accessToken: String) async throws -> [ProviderPayoutItem] {
        let response: ProviderPayoutHistoryResponse = try await request(path: "/payouts/history", method: "GET", body: nil, accessToken: accessToken)
        return response.payouts
    }

    func requestPayout(accessToken: String, amountPaise: Int, mode: String = "IMPS") async throws {
        let _: APIMessageResponse = try await request(
            path: "/payouts/request",
            method: "POST",
            body: ["amountPaise": amountPaise, "mode": mode],
            accessToken: accessToken
        )
    }

    func getActiveDream(accessToken: String) async throws -> ProviderDreamData? {
        try await request(path: "/dreams/active", method: "GET", body: nil, accessToken: accessToken)
    }

    func saveDream(
        accessToken: String,
        existingDreamId: String?,
        title: String,
        description: String,
        category: String,
        goalAmountPaise: Int
    ) async throws -> ProviderDreamData {
        if let existingDreamId, !existingDreamId.isEmpty {
            return try await request(
                path: "/dreams/\(existingDreamId)",
                method: "PUT",
                body: [
                    "title": title,
                    "description": description,
                    "goalAmount": goalAmountPaise
                ],
                accessToken: accessToken
            )
        }

        return try await request(
            path: "/dreams",
            method: "POST",
            body: [
                "title": title,
                "description": description,
                "category": category,
                "goalAmount": goalAmountPaise
            ],
            accessToken: accessToken
        )
    }

    func getRecurringTips(accessToken: String) async throws -> [ProviderRecurringTip] {
        try await request(path: "/recurring-tips/provider", method: "GET", body: nil, accessToken: accessToken)
    }

    func getBusinessInvitations(accessToken: String) async throws -> [BusinessInvitationData] {
        try await request(path: "/business/invitations/mine", method: "GET", body: nil, accessToken: accessToken)
    }

    func getBusinessAffiliations(accessToken: String) async throws -> [BusinessAffiliation] {
        try await request(path: "/business/memberships/mine", method: "GET", body: nil, accessToken: accessToken)
    }

    func respondToInvitation(accessToken: String, invitationId: String, response: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/business/invitations/\(invitationId)/respond",
            method: "POST",
            body: ["response": response],
            accessToken: accessToken
        )
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

private extension Data {
    mutating func appendString(_ string: String) {
        append(string.data(using: .utf8) ?? Data())
    }
}
