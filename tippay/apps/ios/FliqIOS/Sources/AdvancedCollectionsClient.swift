import Foundation

struct NativeTipJarMember: Decodable, Identifiable {
    let id: String
    let providerId: String
    let roleLabel: String?
    let splitPercentage: Double
    let isActive: Bool
    let provider: TipOrderProvider?

    var providerName: String? { provider?.name }
}

struct NativeTipJarCount: Decodable {
    let contributions: Int?
}

struct NativeTipJar: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let eventType: String
    let shortCode: String
    let isActive: Bool
    let expiresAt: String?
    let totalCollected: Int?
    let targetAmount: Int?
    let members: [NativeTipJarMember]
    let count: NativeTipJarCount?
    let shareableUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case eventType
        case shortCode
        case isActive
        case expiresAt
        case totalCollected
        case targetAmount
        case members
        case count = "_count"
        case shareableUrl
    }

    var totalCollectedPaise: Int { totalCollected ?? 0 }
    var targetAmountPaise: Int? { targetAmount }
    var contributionCount: Int { count?.contributions ?? 0 }
}

struct NativeTipJarCollection: Decodable {
    let owned: [NativeTipJar]
    let memberOf: [NativeTipJar]
}

struct NativeTipJarStatsMember: Decodable, Identifiable {
    let memberId: String
    let providerId: String
    let providerName: String?
    let splitPercentage: Double
    let earnedPaise: Int?
    let amountPaise: Int?

    var id: String { memberId }
    var displayAmountPaise: Int { earnedPaise ?? amountPaise ?? 0 }
}

struct NativeTipJarStats: Decodable {
    let jarId: String
    let jarName: String
    let totalCollectedPaise: Int
    let contributionCount: Int
    let memberBreakdown: [NativeTipJarStatsMember]?
    let members: [NativeTipJarStatsMember]?

    var breakdown: [NativeTipJarStatsMember] { memberBreakdown ?? members ?? [] }
}

struct NativeTipPoolMember: Decodable, Identifiable {
    let id: String
    let userId: String
    let role: String?
    let splitPercentage: Double?
    let isActive: Bool
    let user: TipPoolUser?

    var userName: String? { user?.name }
    var userPhone: String? { user?.phone }
}

struct TipPoolUser: Decodable {
    let name: String?
    let phone: String?
}

struct NativeTipPoolCount: Decodable {
    let tips: Int?
}

struct NativeTipPool: Decodable, Identifiable {
    let id: String
    let name: String
    let ownerId: String
    let description: String?
    let splitMethod: String
    let isActive: Bool
    let members: [NativeTipPoolMember]
    let count: NativeTipPoolCount?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId
        case description
        case splitMethod
        case isActive
        case members
        case count = "_count"
    }

    var tipCount: Int { count?.tips ?? 0 }
}

struct NativeTipPoolCollection: Decodable {
    let owned: [NativeTipPool]
    let memberOf: [NativeTipPool]
}

struct NativeTipPoolEarningMember: Decodable, Identifiable {
    let memberId: String
    let userId: String
    let userName: String?
    let role: String?
    let splitPercentage: Double
    let amountPaise: Int

    var id: String { memberId }
}

struct NativeTipPoolEarnings: Decodable {
    let poolId: String
    let poolName: String
    let splitMethod: String
    let totalEarningsPaise: Int
    let tipCount: Int
    let members: [NativeTipPoolEarningMember]
}

final class AdvancedCollectionsClient {
    private let baseURL = "https://www.fliq.co.in"
    private let decoder = JSONDecoder()

    func createTipJar(
        accessToken: String,
        name: String,
        eventType: String,
        description: String?,
        targetAmountPaise: Int?
    ) async throws -> NativeTipJar {
        var body: [String: Any] = [
            "name": name,
            "eventType": eventType
        ]
        if let description, !description.isEmpty { body["description"] = description }
        if let targetAmountPaise, targetAmountPaise > 0 { body["targetAmountPaise"] = targetAmountPaise }
        return try await request(path: "/tip-jars", method: "POST", body: body, accessToken: accessToken)
    }

    func getMyTipJars(accessToken: String) async throws -> NativeTipJarCollection {
        try await request(path: "/tip-jars/my", method: "GET", body: nil, accessToken: accessToken)
    }

    func getTipJar(accessToken: String, jarId: String) async throws -> NativeTipJar {
        try await request(path: "/tip-jars/\(jarId)", method: "GET", body: nil, accessToken: accessToken)
    }

    func addTipJarMember(
        accessToken: String,
        jarId: String,
        providerId: String,
        splitPercentage: Double,
        roleLabel: String?
    ) async throws {
        var body: [String: Any] = [
            "providerId": providerId,
            "splitPercentage": splitPercentage
        ]
        if let roleLabel, !roleLabel.isEmpty { body["roleLabel"] = roleLabel }
        let _: APIMessageResponse = try await request(
            path: "/tip-jars/\(jarId)/members",
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    func removeTipJarMember(accessToken: String, jarId: String, memberId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/tip-jars/\(jarId)/members/\(memberId)",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func closeTipJar(accessToken: String, jarId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/tip-jars/\(jarId)",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func getTipJarStats(accessToken: String, jarId: String) async throws -> NativeTipJarStats {
        try await request(path: "/tip-jars/\(jarId)/stats", method: "GET", body: nil, accessToken: accessToken)
    }

    func resolveTipJar(shortCode: String) async throws -> NativeTipJar {
        try await request(path: "/tip-jars/resolve/\(shortCode)", method: "GET", body: nil, accessToken: nil)
    }

    func createAuthenticatedJarTip(
        accessToken: String,
        shortCode: String,
        amountPaise: Int,
        message: String?,
        rating: Int?
    ) async throws -> NativePaymentOrder {
        var body: [String: Any] = ["amountPaise": amountPaise]
        if let message, !message.isEmpty { body["message"] = message }
        if let rating { body["rating"] = rating }
        return try await request(
            path: "/tip-jars/\(shortCode)/tip/authenticated",
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    func createTipPool(
        accessToken: String,
        name: String,
        splitMethod: String,
        description: String?
    ) async throws -> NativeTipPool {
        var body: [String: Any] = [
            "name": name,
            "splitMethod": splitMethod
        ]
        if let description, !description.isEmpty { body["description"] = description }
        return try await request(path: "/tip-pools", method: "POST", body: body, accessToken: accessToken)
    }

    func getMyTipPools(accessToken: String) async throws -> NativeTipPoolCollection {
        try await request(path: "/tip-pools/my", method: "GET", body: nil, accessToken: accessToken)
    }

    func getTipPool(accessToken: String, poolId: String) async throws -> NativeTipPool {
        try await request(path: "/tip-pools/\(poolId)", method: "GET", body: nil, accessToken: accessToken)
    }

    func addTipPoolMember(
        accessToken: String,
        poolId: String,
        phone: String,
        role: String?,
        splitPercentage: Double?
    ) async throws {
        var body: [String: Any] = ["phone": phone]
        if let role, !role.isEmpty { body["role"] = role }
        if let splitPercentage { body["splitPercentage"] = splitPercentage }
        let _: APIMessageResponse = try await request(
            path: "/tip-pools/\(poolId)/members",
            method: "POST",
            body: body,
            accessToken: accessToken
        )
    }

    func removeTipPoolMember(accessToken: String, poolId: String, memberId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/tip-pools/\(poolId)/members/\(memberId)",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func updateTipPool(
        accessToken: String,
        poolId: String,
        name: String?,
        description: String?,
        splitMethod: String?
    ) async throws {
        var body: [String: Any] = [:]
        if let name, !name.isEmpty { body["name"] = name }
        if let description, !description.isEmpty { body["description"] = description }
        if let splitMethod, !splitMethod.isEmpty { body["splitMethod"] = splitMethod }
        let _: APIMessageResponse = try await request(
            path: "/tip-pools/\(poolId)",
            method: "PATCH",
            body: body,
            accessToken: accessToken
        )
    }

    func deactivateTipPool(accessToken: String, poolId: String) async throws {
        let _: APIMessageResponse = try await request(
            path: "/tip-pools/\(poolId)",
            method: "DELETE",
            body: nil,
            accessToken: accessToken
        )
    }

    func getTipPoolEarnings(accessToken: String, poolId: String) async throws -> NativeTipPoolEarnings {
        try await request(path: "/tip-pools/\(poolId)/earnings", method: "GET", body: nil, accessToken: accessToken)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        accessToken: String?
    ) async throws -> Response {
        guard let url = URL(string: baseURL + path) else {
            throw CustomerClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

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

        if Response.self == APIMessageResponse.self, data.isEmpty {
            return APIMessageResponse(message: "OK") as! Response
        }

        return try decoder.decode(Response.self, from: data.isEmpty ? Data("{\"message\":\"OK\"}".utf8) : data)
    }
}
