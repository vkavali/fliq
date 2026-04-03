import Foundation

struct BusinessSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let ownerId: String?
    let address: String?
    let contactPhone: String?
    let contactEmail: String?
    let gstin: String?
}

struct BusinessTrendPoint: Decodable, Identifiable {
    struct TrendSum: Decodable {
        let amountPaise: Int?
    }

    struct TrendCount: Decodable {
        let id: Int?
    }

    let createdAt: String?
    let sum: TrendSum?
    let count: TrendCount?

    enum CodingKeys: String, CodingKey {
        case createdAt
        case sum = "_sum"
        case count = "_count"
    }

    var id: String { createdAt ?? UUID().uuidString }
    var totalAmountPaise: Int { sum?.amountPaise ?? 0 }
    var tipCount: Int { count?.id ?? 0 }
}

struct BusinessDashboardSnapshot: Decodable {
    let totalTipsCount: Int
    let totalAmountPaise: Int
    let totalNetAmountPaise: Int?
    let averageRating: Double?
    let staffCount: Int
    let totalRatingsCount: Int?
    let recentTipTrend: [BusinessTrendPoint]
}

struct BusinessAffiliationBusiness: Decodable {
    let id: String
    let name: String
    let type: String
    let ownerId: String?
    let address: String?
    let contactPhone: String?
    let contactEmail: String?
}

struct BusinessAffiliation: Decodable, Identifiable {
    let businessId: String
    let business: BusinessAffiliationBusiness
    let role: String
    let joinedAt: String?
    let isOwner: Bool

    var id: String { businessId }
    var businessName: String { business.name }
    var businessType: String { business.type }
    var contactPhone: String? { business.contactPhone }
    var contactEmail: String? { business.contactEmail }
}

struct BusinessStaffProviderProfile: Decodable {
    let displayName: String?
    let category: String?
}

struct BusinessStaffProvider: Decodable {
    let id: String
    let name: String?
    let phone: String?
    let email: String?
    let providerProfile: BusinessStaffProviderProfile?
}

struct BusinessStaffTips: Decodable {
    let count: Int
    let totalAmountPaise: Int
    let averageRating: Double?
}

struct BusinessStaffMember: Decodable, Identifiable {
    let memberId: String
    let role: String
    let joinedAt: String?
    let provider: BusinessStaffProvider
    let tips: BusinessStaffTips

    var id: String { memberId }
    var displayName: String { provider.providerProfile?.displayName ?? provider.name ?? "Staff Member" }
    var contact: String? { provider.phone ?? provider.email }
    var category: String? { provider.providerProfile?.category }
}

struct RatingDistributionItem: Decodable, Identifiable {
    let star: Int
    let count: Int

    var id: Int { star }
}

struct BusinessReviewProviderProfile: Decodable {
    let displayName: String?
}

struct BusinessReviewProvider: Decodable {
    let name: String?
    let providerProfile: BusinessReviewProviderProfile?
}

struct BusinessReviewItem: Decodable, Identifiable {
    let id: String
    let rating: Int?
    let message: String?
    let amountPaise: Int
    let createdAt: String?
    let provider: BusinessReviewProvider?

    var providerName: String { provider?.providerProfile?.displayName ?? provider?.name ?? "Staff" }
}

struct BusinessSatisfactionSnapshot: Decodable {
    let ratingDistribution: [RatingDistributionItem]
    let tips: [BusinessReviewItem]
}

struct BusinessQrStaffGroup: Decodable, Identifiable {
    let memberId: String
    let providerId: String
    let displayName: String
    let qrCodes: [ProviderQrCode]

    var id: String { memberId }
}
