import Foundation

enum TipIntentOption: String, CaseIterable, Identifiable, Codable {
    case kindness = "KINDNESS"
    case speed = "SPEED"
    case experience = "EXPERIENCE"
    case support = "SUPPORT"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kindness: return "Kindness"
        case .speed: return "Speed"
        case .experience: return "Experience"
        case .support: return "Support"
        }
    }

    var summary: String {
        switch self {
        case .kindness: return "Warm, thoughtful service"
        case .speed: return "Fast help when it mattered"
        case .experience: return "Memorable hospitality"
        case .support: return "Reliable support throughout"
        }
    }
}

enum TipSourceOption: String, Codable {
    case qrCode = "QR_CODE"
    case paymentLink = "PAYMENT_LINK"
    case inApp = "IN_APP"

    var label: String {
        switch self {
        case .qrCode: return "QR code"
        case .paymentLink: return "Payment link"
        case .inApp: return "In-app search"
        }
    }
}

struct ProviderSearchResponse: Decodable {
    let providers: [ProviderSearchResult]
}

struct ProviderSearchResult: Decodable, Identifiable {
    let id: String
    let name: String
    let phone: String?
    let category: String?
    let ratingAverage: Double?
    let totalTipsReceived: Int
}

struct ProviderStats: Decodable {
    let tipsToday: Int
    let recentAppreciations: Int
}

struct ProviderDream: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let goalAmount: Double
    let currentAmount: Double
    let percentage: Int
    let verified: Bool
}

struct ProviderReputation: Decodable {
    let score: Double
    let consistency: Double
    let uniqueTippers: Int
}

struct ProviderProfile: Decodable, Identifiable {
    let id: String
    let name: String
    let displayName: String
    let bio: String?
    let avatarUrl: String?
    let category: String?
    let ratingAverage: Double?
    let totalTipsReceived: Int
    let upiVpa: String?
    let stats: ProviderStats
    let dream: ProviderDream?
    let reputation: ProviderReputation?
}

struct TipOrderProvider: Decodable {
    let name: String
    let category: String?
}

struct CreatedTipOrder: Decodable {
    let tipId: String
    let orderId: String
    let amount: Int
    let currency: String
    let razorpayKeyId: String
    let provider: TipOrderProvider

    var isMockOrder: Bool { orderId.hasPrefix("mock_order_") }
}

struct TipEntryContext {
    let providerId: String
    let providerName: String
    let category: String?
    let source: TipSourceOption
    let entryLabel: String
    let entryDetail: String?
    let suggestedAmountPaise: Int?
    let allowCustomAmount: Bool

    static func inApp(providerId: String, providerName: String, category: String?) -> TipEntryContext {
        TipEntryContext(
            providerId: providerId,
            providerName: providerName,
            category: category,
            source: .inApp,
            entryLabel: "In-app search",
            entryDetail: nil,
            suggestedAmountPaise: nil,
            allowCustomAmount: true
        )
    }
}

struct ResolvedQrCodeResponse: Decodable {
    let providerId: String
    let providerName: String
    let category: String?
    let locationLabel: String?
}

struct ResolvedPaymentLinkResponse: Decodable {
    let providerId: String
    let providerName: String
    let category: String?
    let role: String?
    let workplace: String?
    let description: String?
    let shortCode: String?
    let suggestedAmountPaise: Int?
    let allowCustomAmount: Bool
}

struct VerifiedTipResult: Decodable {
    let status: String
    let tipId: String
    let bypass: Bool?
}

struct TipStatusSnapshot: Decodable {
    let tipId: String
    let status: String
    let updatedAt: String?
}

struct CustomerTipHistoryResponse: Decodable {
    let tips: [CustomerTipHistoryItem]
    let total: Int
    let page: Int
    let limit: Int
}

struct CustomerTipProviderProfile: Decodable {
    let category: String?
}

struct CustomerTipProvider: Decodable {
    let name: String
    let providerProfile: CustomerTipProviderProfile?
}

struct CustomerTipHistoryItem: Decodable, Identifiable {
    let id: String
    let amountPaise: Int
    let netAmountPaise: Int
    let status: String
    let intent: String?
    let message: String?
    let createdAt: String?
    let provider: CustomerTipProvider

    var providerName: String { provider.name }
    var providerCategory: String? { provider.providerProfile?.category }
}

struct TipImpactDream: Decodable {
    let title: String
    let previousProgress: Int
    let newProgress: Int
    let goalAmount: Double
    let currentAmount: Double
}

struct TipImpactSnapshot: Decodable {
    let tipId: String
    let workerName: String
    let amount: Int
    let intent: String?
    let dream: TipImpactDream?
    let message: String

    var amountPaise: Int { amount }
}
