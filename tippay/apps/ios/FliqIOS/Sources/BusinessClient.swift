import Foundation

final class BusinessClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func getMyBusiness(accessToken: String) async throws -> BusinessSummary {
        try await request(path: "/business/mine", method: "GET", body: nil, accessToken: accessToken)
    }

    func getMyMemberships(accessToken: String) async throws -> [BusinessAffiliation] {
        try await request(path: "/business/memberships/mine", method: "GET", body: nil, accessToken: accessToken)
    }

    func registerBusiness(
        accessToken: String,
        name: String,
        type: String,
        address: String?,
        contactPhone: String?,
        contactEmail: String?,
        gstin: String?
    ) async throws -> BusinessSummary {
        var body: [String: Any] = [
            "name": name,
            "type": type
        ]
        if let address, !address.isEmpty { body["address"] = address }
        if let contactPhone, !contactPhone.isEmpty { body["contactPhone"] = contactPhone }
        if let contactEmail, !contactEmail.isEmpty { body["contactEmail"] = contactEmail }
        if let gstin, !gstin.isEmpty { body["gstin"] = gstin }
        return try await request(path: "/business/register", method: "POST", body: body, accessToken: accessToken)
    }

    func updateBusiness(
        accessToken: String,
        businessId: String,
        name: String?,
        type: String?,
        address: String?,
        contactPhone: String?,
        contactEmail: String?,
        gstin: String?
    ) async throws -> BusinessSummary {
        var body: [String: Any] = [:]
        if let name, !name.isEmpty { body["name"] = name }
        if let type, !type.isEmpty { body["type"] = type }
        if let address, !address.isEmpty { body["address"] = address }
        if let contactPhone, !contactPhone.isEmpty { body["contactPhone"] = contactPhone }
        if let contactEmail, !contactEmail.isEmpty { body["contactEmail"] = contactEmail }
        if let gstin, !gstin.isEmpty { body["gstin"] = gstin }
        let _: BusinessSummary = try await request(path: "/business/\(businessId)", method: "PATCH", body: body, accessToken: accessToken)
        return try await getMyBusiness(accessToken: accessToken)
    }

    func getDashboard(accessToken: String, businessId: String) async throws -> BusinessDashboardSnapshot {
        try await request(path: "/business/\(businessId)/dashboard", method: "GET", body: nil, accessToken: accessToken)
    }

    func getStaff(accessToken: String, businessId: String) async throws -> [BusinessStaffMember] {
        try await request(path: "/business/\(businessId)/staff", method: "GET", body: nil, accessToken: accessToken)
    }

    func inviteMember(accessToken: String, businessId: String, phone: String, role: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/business/\(businessId)/invite",
            method: "POST",
            body: ["phone": phone, "role": role],
            accessToken: accessToken
        )
    }

    func removeMember(accessToken: String, businessId: String, memberId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/business/\(businessId)/members/\(memberId)",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func getSatisfaction(accessToken: String, businessId: String) async throws -> BusinessSatisfactionSnapshot {
        try await request(path: "/business/\(businessId)/satisfaction", method: "GET", body: nil, accessToken: accessToken)
    }

    func getQrCodes(accessToken: String, businessId: String) async throws -> [BusinessQrStaffGroup] {
        try await request(path: "/business/\(businessId)/qrcodes", method: "GET", body: nil, accessToken: accessToken)
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
