import Foundation

struct ProviderSelfUser: Decodable {
    let name: String?
    let phone: String?
    let kycStatus: String?
}

struct ProviderSelfProfile: Decodable {
    let id: String
    let displayName: String
    let bio: String?
    let avatarUrl: String?
    let category: String?
    let upiVpa: String?
    let totalTipsReceived: Int
    let ratingAverage: Double?
    let user: ProviderSelfUser?
}

struct ProviderTipsResponse: Decodable {
    let tips: [ProviderTipItem]
}

struct ProviderTipCustomer: Decodable {
    let name: String?
}

struct ProviderTipItem: Decodable, Identifiable {
    let id: String
    let amountPaise: Int
    let status: String
    let rating: Int?
    let message: String?
    let intent: String?
    let createdAt: String?
    let customer: ProviderTipCustomer?

    var customerName: String? { customer?.name }
}

struct ProviderQrCode: Decodable, Identifiable {
    let id: String
    let locationLabel: String?
    let qrImageUrl: String?
    let upiUrl: String?
    let scanCount: Int?
}

struct ProviderPaymentLink: Decodable, Identifiable {
    let id: String
    let shortCode: String
    let role: String?
    let workplace: String?
    let description: String?
    let suggestedAmountPaise: Int?
    let allowCustomAmount: Bool
    let clickCount: Int?
    let shareableUrl: String?
}

struct ProviderPayoutHistoryResponse: Decodable {
    let payouts: [ProviderPayoutItem]
}

struct ProviderPayoutItem: Decodable, Identifiable {
    let id: String
    let amountPaise: Int
    let status: String
    let mode: String?
    let createdAt: String?
}

struct ProviderDreamData: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let category: String?
    let goalAmount: Int
    let currentAmount: Int
    let percentage: Int
    let isActive: Bool
}

struct ProviderRecurringTipCustomer: Decodable {
    let name: String?
}

struct ProviderRecurringTip: Decodable, Identifiable {
    let id: String
    let amountPaise: Int
    let frequency: String
    let status: String
    let createdAt: String?
    let customer: ProviderRecurringTipCustomer?

    var customerName: String? { customer?.name }
}

struct BusinessInvitationBusiness: Decodable {
    let id: String?
    let name: String?
    let type: String?
}

struct BusinessInvitationSender: Decodable {
    let name: String?
}

struct BusinessInvitationData: Decodable, Identifiable {
    let id: String
    let role: String
    let expiresAt: String?
    let business: BusinessInvitationBusiness?
    let sender: BusinessInvitationSender?

    var businessName: String? { business?.name }
    var businessType: String? { business?.type }
    var senderName: String? { sender?.name }
}
