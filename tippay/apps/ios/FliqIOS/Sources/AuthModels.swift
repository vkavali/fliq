import Foundation

enum NativeRole: String, CaseIterable, Identifiable {
    case customer = "CUSTOMER"
    case provider = "PROVIDER"
    case business = "BUSINESS"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customer: return "Customer"
        case .provider: return "Provider"
        case .business: return "Business"
        }
    }

    var credentialLabel: String {
        switch self {
        case .business: return "Email"
        case .customer, .provider: return "Phone"
        }
    }

    var usesEmail: Bool { self == .business }
}

struct AuthUser: Codable {
    let id: String
    let phone: String?
    let email: String?
    let name: String?
    let type: String
    let kycStatus: String?
    let languagePreference: String?
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct SendCodeResult: Decodable {
    let message: String
    let otp: String?
}

struct VerifyCodeResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct APIMessageResponse: Decodable {
    let message: String?
}
