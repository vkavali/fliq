import SwiftUI

private let providerCategories: [String] = [
    "DELIVERY",
    "SALON",
    "HOUSEHOLD",
    "RESTAURANT",
    "HOTEL",
    "TRANSPORT",
    "HEALTHCARE",
    "EDUCATION",
    "FITNESS",
    "OTHER"
]

private let dreamCategories: [String] = [
    "EDUCATION",
    "HEALTH",
    "FAMILY",
    "SKILL",
    "EMERGENCY",
    "TRAVEL",
    "OTHER"
]

private let businessTypes: [String] = [
    "HOTEL",
    "SALON",
    "RESTAURANT",
    "SPA",
    "CAFE",
    "RETAIL",
    "OTHER"
]

private let businessRoles: [String] = ["ADMIN", "MANAGER", "STAFF"]

struct ProviderHomeView: View {
    let session: AuthSession
    let onLogout: () -> Void

    @State private var profile: ProviderSelfProfile?
    @State private var tips: [ProviderTipItem] = []
    @State private var qrCodes: [ProviderQrCode] = []
    @State private var paymentLinks: [ProviderPaymentLink] = []
    @State private var payouts: [ProviderPayoutItem] = []
    @State private var dream: ProviderDreamData?
    @State private var recurringTips: [ProviderRecurringTip] = []
    @State private var invitations: [BusinessInvitationData] = []
    @State private var affiliations: [BusinessAffiliation] = []
    @State private var isLoading = true
    @State private var isSavingProfile = false
    @State private var isCreatingQR = false
    @State private var isCreatingLink = false
    @State private var isRequestingPayout = false
    @State private var isSavingDream = false
    @State private var statusMessage = ""
    @State private var errorMessage: String?

    @State private var displayName = ""
    @State private var category = providerCategories.first ?? "OTHER"
    @State private var bio = ""
    @State private var upiVpa = ""
    @State private var qrLocationLabel = ""
    @State private var linkRole = ""
    @State private var linkWorkplace = ""
    @State private var linkDescription = ""
    @State private var linkSuggestedAmount = ""
    @State private var linkAllowCustomAmount = true
    @State private var payoutAmountRupees = ""
    @State private var dreamTitle = ""
    @State private var dreamDescription = ""
    @State private var dreamCategory = dreamCategories.first ?? "OTHER"
    @State private var dreamGoalAmount = ""

    private let providerClient = ProviderClient()

    private var paidTipsCount: Int {
        tips.filter { ["PAID", "SETTLED"].contains($0.status.uppercased()) }.count
    }

    private var allTimeTipsAmount: Int {
        tips.filter { ["PAID", "SETTLED"].contains($0.status.uppercased()) }
            .reduce(0) { $0 + $1.amountPaise }
    }

    private var todayTipsAmount: Int {
        let calendar = Calendar.current
        return tips.filter { tip in
            guard let str = tip.createdAt,
                  let date = ISO8601DateFormatter().date(from: str) else { return false }
            return calendar.isDateInToday(date) && ["PAID", "SETTLED"].contains(tip.status.uppercased())
        }.reduce(0) { $0 + $1.amountPaise }
    }

    @ViewBuilder
    private func providerInitialsCircle(name: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: size, height: size)
            Text(String(name.prefix(2)).uppercased())
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func providerStatView(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(title)
                .font(DS.Typography.micro)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        TabView {
            // ── Tab 1: Home ──────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                            // Error banner
                            if let error = errorMessage {
                                FliqErrorBanner(message: error)
                            }

                            if isLoading && profile == nil {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(.white)
                                    Spacer()
                                }
                                .padding(.vertical, DS.Spacing.xl)
                            } else if let profile = profile {

                                // Provider header on gradient
                                HStack(spacing: DS.Spacing.md) {
                                    if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                                    .frame(width: 56, height: 56)
                                                    .clipShape(Circle())
                                            default:
                                                providerInitialsCircle(name: profile.displayName, size: 56)
                                            }
                                        }
                                    } else {
                                        providerInitialsCircle(name: profile.displayName, size: 56)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.displayName)
                                            .font(DS.Typography.title2)
                                            .foregroundStyle(.white)
                                        if let cat = profile.category {
                                            Text(cat.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(.white.opacity(0.75))
                                        }
                                    }
                                    Spacer()
                                }

                                // Earnings stats card
                                HStack(spacing: 0) {
                                    providerStatView(title: "Today", value: roleAmountText(todayTipsAmount))
                                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                                    providerStatView(title: "All-time", value: roleAmountText(allTimeTipsAmount))
                                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                                    providerStatView(title: "Tips", value: "\(paidTipsCount)")
                                }
                                .padding(DS.Spacing.md)
                                .background(.white.opacity(0.15))
                                .cornerRadius(DS.CornerRadius.md)

                                // Share tip link / QR button
                                if let shareUrl = paymentLinks.first?.shareableUrl {
                                    ShareLink(item: shareUrl) {
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 15, weight: .semibold))
                                            Text("Share My Tip Link")
                                                .font(DS.Typography.headline)
                                        }
                                        .foregroundStyle(Color.dsAccent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(.white)
                                        .cornerRadius(DS.CornerRadius.sm)
                                    }
                                } else if let qrCode = qrCodes.first, let upiUrl = qrCode.upiUrl {
                                    ShareLink(item: upiUrl) {
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: "qrcode")
                                                .font(.system(size: 15, weight: .semibold))
                                            Text("Share QR Code")
                                                .font(DS.Typography.headline)
                                        }
                                        .foregroundStyle(Color.dsAccent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(.white)
                                        .cornerRadius(DS.CornerRadius.sm)
                                    }
                                }

                                // Subscribers card
                                let activeSubscriberCount = recurringTips.filter { $0.status == "ACTIVE" }.count
                                FliqCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Subscribers")
                                                .font(DS.Typography.headline)
                                                .foregroundStyle(Color.dsPrimary)
                                            if activeSubscriberCount == 0 {
                                                Text("No subscribers yet")
                                                    .font(DS.Typography.caption)
                                                    .foregroundStyle(Color.dsSecondary)
                                                Text("Share your tip link to get recurring support")
                                                    .font(DS.Typography.caption)
                                                    .foregroundStyle(Color.dsTertiary)
                                            } else {
                                                Text("\(activeSubscriberCount) active subscriber\(activeSubscriberCount == 1 ? "" : "s")")
                                                    .font(DS.Typography.caption)
                                                    .foregroundStyle(Color.dsSuccess)
                                            }
                                        }
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(activeSubscriberCount > 0 ? Color.dsSuccessTint : Color.dsAccentTint)
                                                .frame(width: 44, height: 44)
                                            Text("\(activeSubscriberCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(activeSubscriberCount > 0 ? Color.dsSuccess : Color.dsAccent)
                                        }
                                    }
                                }

                                // Recent tips
                                if tips.isEmpty {
                                    FliqCard {
                                        VStack(spacing: DS.Spacing.md) {
                                            Image(systemName: "banknote")
                                                .font(.system(size: 36))
                                                .foregroundStyle(Color.dsTertiary)
                                            Text("No tips yet")
                                                .font(DS.Typography.bodyMedium)
                                                .foregroundStyle(Color.dsSecondary)
                                            Text("Share your QR code or payment link to start receiving tips")
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(Color.dsTertiary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DS.Spacing.lg)
                                    }
                                } else {
                                    Text("Recent tips")
                                        .font(DS.Typography.title2)
                                        .foregroundStyle(.white)
                                    ForEach(tips.prefix(5)) { tip in
                                        ProviderTipCard(tip: tip)
                                    }
                                }

                                // Business invitations
                                if !invitations.isEmpty {
                                    Text("Business invitations")
                                        .font(DS.Typography.title2)
                                        .foregroundStyle(.white)
                                    ForEach(invitations) { invitation in
                                        FliqCard {
                                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                                Text(invitation.businessName ?? "Business")
                                                    .font(DS.Typography.headline)
                                                    .foregroundStyle(Color.dsPrimary)
                                                FliqDetailRow(label: "Role", value: invitation.role)
                                                if let expiresAt = invitation.expiresAt {
                                                    FliqDetailRow(label: "Expires", value: roleHistoryDateText(expiresAt) ?? expiresAt)
                                                }
                                                HStack(spacing: DS.Spacing.sm) {
                                                    Button(action: {
                                                        Task { await respondToInvitation(invitationId: invitation.id, response: "ACCEPT") }
                                                    }) {
                                                        Text("Accept")
                                                            .font(DS.Typography.bodyMedium)
                                                            .foregroundStyle(.white)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .background(Color.dsAccent)
                                                            .cornerRadius(DS.CornerRadius.sm)
                                                    }
                                                    .buttonStyle(.plain)
                                                    Button(action: {
                                                        Task { await respondToInvitation(invitationId: invitation.id, response: "DECLINE") }
                                                    }) {
                                                        Text("Decline")
                                                            .font(DS.Typography.bodyMedium)
                                                            .foregroundStyle(Color.dsSecondary)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .overlay(RoundedRectangle(cornerRadius: DS.CornerRadius.sm).strokeBorder(Color.dsBorder))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: DS.Spacing.xxl)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { Task { await loadProviderHome() } }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.white)
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            // ── Tab 2: Tips ───────────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            if profile != nil {
                                ProviderTipsSection(tips: tips)
                                ProviderRecurringSupportSection(recurringTips: recurringTips)
                                ProviderCompletionView(
                                    session: session,
                                    currentUpiVpa: upiVpa,
                                    latestTips: tips,
                                    onRefreshRequested: { Task { await loadProviderHome() } }
                                )
                            } else {
                                FliqCard {
                                    Text("Complete your profile in the Home tab to start receiving tips.")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(Color.dsSecondary)
                                        .padding(.vertical, DS.Spacing.sm)
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                }
                .navigationTitle("Tips")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Tips", systemImage: "banknote.fill") }

            // ── Tab 3: Collect ────────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            if profile != nil {
                                ProviderAvatarView(
                                    session: session,
                                    currentAvatarUrl: profile?.avatarUrl,
                                    onRefreshRequested: { Task { await loadProviderHome() } }
                                )
                                ProviderQrSection(
                                    qrCodes: qrCodes,
                                    qrLocationLabel: $qrLocationLabel,
                                    isCreatingQR: isCreatingQR,
                                    onCreate: { Task { await createQRCode() } }
                                )
                                ProviderPaymentLinkSection(
                                    paymentLinks: paymentLinks,
                                    linkRole: $linkRole,
                                    linkWorkplace: $linkWorkplace,
                                    linkDescription: $linkDescription,
                                    linkSuggestedAmount: $linkSuggestedAmount,
                                    linkAllowCustomAmount: $linkAllowCustomAmount,
                                    isCreatingLink: isCreatingLink,
                                    onCreate: { Task { await createPaymentLink() } }
                                )
                                ProviderCollectionsView(session: session)
                            } else {
                                FliqCard {
                                    Text("Complete your profile in the Home tab to manage QR codes and payment links.")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(Color.dsSecondary)
                                        .padding(.vertical, DS.Spacing.sm)
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                }
                .navigationTitle("Collect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Collect", systemImage: "qrcode") }

            // ── Tab 4: Profile ────────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            if profile != nil {
                                // Account status card
                                FliqCard {
                                    VStack(spacing: 0) {
                                        HStack {
                                            Image(systemName: "checkmark.shield")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.dsAccent)
                                                .frame(width: 22)
                                            Text("KYC Status")
                                                .font(DS.Typography.body)
                                                .foregroundStyle(Color.dsPrimary)
                                            Spacer()
                                            let kycStatus = profile?.user?.kycStatus ?? ""
                                            Text(kycStatus.isEmpty ? "Not verified" : kycStatus.capitalized)
                                                .font(DS.Typography.footnote)
                                                .foregroundStyle(kycStatus.uppercased() == "VERIFIED" ? Color.dsSuccess : Color.dsSecondary)
                                        }
                                        .padding(.vertical, DS.Spacing.sm + 2)
                                        FliqDivider()
                                        HStack {
                                            Image(systemName: "indianrupeesign.circle")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.dsAccent)
                                                .frame(width: 22)
                                            Text("UPI / Bank")
                                                .font(DS.Typography.body)
                                                .foregroundStyle(Color.dsPrimary)
                                            Spacer()
                                            Text(upiVpa.isEmpty ? "Not linked" : upiVpa)
                                                .font(DS.Typography.footnote)
                                                .foregroundStyle(upiVpa.isEmpty ? Color.dsSecondary : Color.dsPrimary)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, DS.Spacing.sm + 2)
                                    }
                                }

                                ProviderDreamSection(
                                    dream: dream,
                                    dreamTitle: $dreamTitle,
                                    dreamDescription: $dreamDescription,
                                    dreamCategory: $dreamCategory,
                                    dreamGoalAmount: $dreamGoalAmount,
                                    isSavingDream: isSavingDream,
                                    onSave: { Task { await saveDream() } }
                                )
                                ProviderPayoutSection(
                                    payouts: payouts,
                                    payoutAmountRupees: $payoutAmountRupees,
                                    isRequestingPayout: isRequestingPayout,
                                    onRequest: { Task { await requestPayout() } }
                                )
                            }
                            Button("Sign Out", action: onLogout)
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.dsError)
                        }
                        .padding(DS.Spacing.md)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Color.dsAccent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .task(id: session.user.id) {
            await loadProviderHome()
        }
    }

    @MainActor
    private func loadProviderHome() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedProfile = try? await providerClient.getOwnProfile(accessToken: session.accessToken)
            profile = loadedProfile
            invitations = try await providerClient.getBusinessInvitations(accessToken: session.accessToken)
            affiliations = try await providerClient.getBusinessAffiliations(accessToken: session.accessToken)

            if let loadedProfile {
                displayName = loadedProfile.displayName
                category = loadedProfile.category ?? category
                bio = loadedProfile.bio ?? ""
                upiVpa = loadedProfile.upiVpa ?? ""
                tips = try await providerClient.getReceivedTips(accessToken: session.accessToken)
                qrCodes = try await providerClient.getQrCodes(accessToken: session.accessToken)
                paymentLinks = try await providerClient.getPaymentLinks(accessToken: session.accessToken)
                payouts = try await providerClient.getPayoutHistory(accessToken: session.accessToken)
                dream = try await providerClient.getActiveDream(accessToken: session.accessToken)
                recurringTips = try await providerClient.getRecurringTips(accessToken: session.accessToken)
                if let dream {
                    dreamTitle = dream.title
                    dreamDescription = dream.description ?? ""
                    dreamCategory = dream.category ?? dreamCategory
                    dreamGoalAmount = String(dream.goalAmount / 100)
                }
                statusMessage = ""
            } else {
                tips = []
                qrCodes = []
                paymentLinks = []
                payouts = []
                dream = nil
                recurringTips = []
                statusMessage = ""
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load the provider home right now."
        }

        isLoading = false
    }

    @MainActor
    private func saveProviderProfile() async {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Display name is required."
            return
        }

        isSavingProfile = true
        errorMessage = nil

        do {
            let isCreating = profile == nil
            if profile != nil {
                profile = try await providerClient.updateProfile(
                    accessToken: session.accessToken,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    upiVpa: upiVpa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : upiVpa.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                profile = try await providerClient.createProfile(
                    accessToken: session.accessToken,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    upiVpa: upiVpa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : upiVpa.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            statusMessage = isCreating ? "Provider profile created." : "Provider profile saved."
            await loadProviderHome()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save the provider profile right now."
        }

        isSavingProfile = false
    }

    @MainActor
    private func createQRCode() async {
        isCreatingQR = true
        errorMessage = nil

        do {
            _ = try await providerClient.createQrCode(
                accessToken: session.accessToken,
                locationLabel: qrLocationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : qrLocationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            qrCodes = try await providerClient.getQrCodes(accessToken: session.accessToken)
            qrLocationLabel = ""
            statusMessage = "New QR code created."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create a QR code right now."
        }

        isCreatingQR = false
    }

    @MainActor
    private func createPaymentLink() async {
        isCreatingLink = true
        errorMessage = nil

        do {
            _ = try await providerClient.createPaymentLink(
                accessToken: session.accessToken,
                role: linkRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkRole.trimmingCharacters(in: .whitespacesAndNewlines),
                workplace: linkWorkplace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkWorkplace.trimmingCharacters(in: .whitespacesAndNewlines),
                description: linkDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedAmountPaise: linkSuggestedAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : (Int(linkSuggestedAmount) ?? 0) * 100,
                allowCustomAmount: linkAllowCustomAmount
            )
            paymentLinks = try await providerClient.getPaymentLinks(accessToken: session.accessToken)
            linkRole = ""
            linkWorkplace = ""
            linkDescription = ""
            linkSuggestedAmount = ""
            linkAllowCustomAmount = true
            statusMessage = "New payment link created."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create a payment link right now."
        }

        isCreatingLink = false
    }

    @MainActor
    private func saveDream() async {
        guard !dreamTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !dreamDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let goalAmount = Int(dreamGoalAmount),
              goalAmount > 0 else {
            errorMessage = "Dream title, description, and goal amount are required."
            return
        }

        isSavingDream = true
        errorMessage = nil

        do {
            dream = try await providerClient.saveDream(
                accessToken: session.accessToken,
                existingDreamId: dream?.id,
                title: dreamTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: dreamDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                category: dreamCategory,
                goalAmountPaise: goalAmount * 100
            )
            statusMessage = "Dream saved."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save the dream right now."
        }

        isSavingDream = false
    }

    @MainActor
    private func requestPayout() async {
        guard let amount = Int(payoutAmountRupees), amount >= 100 else {
            errorMessage = "Minimum payout is Rs 100."
            return
        }

        isRequestingPayout = true
        errorMessage = nil

        do {
            try await providerClient.requestPayout(accessToken: session.accessToken, amountPaise: amount * 100)
            payouts = try await providerClient.getPayoutHistory(accessToken: session.accessToken)
            payoutAmountRupees = ""
            statusMessage = "Payout request submitted."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to request a payout right now."
        }

        isRequestingPayout = false
    }

    @MainActor
    private func respondToInvitation(invitationId: String, response: String) async {
        errorMessage = nil

        do {
            try await providerClient.respondToInvitation(
                accessToken: session.accessToken,
                invitationId: invitationId,
                response: response
            )
            invitations.removeAll { $0.id == invitationId }
            statusMessage = response == "ACCEPT" ? "Invitation accepted." : "Invitation declined."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to respond to the invitation right now."
        }
    }
}

// MARK: - Provider Tip Card (used in Home dashboard)

private struct ProviderTipCard: View {
    let tip: ProviderTipItem

    private var statusColor: Color {
        switch tip.status.uppercased() {
        case "PAID", "SETTLED": return .dsSuccess
        case "INITIATED", "PENDING": return .dsWarning
        case "FAILED": return .dsError
        default: return .dsSecondary
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: tip.status.uppercased() == "PAID" || tip.status.uppercased() == "SETTLED"
                      ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.customerName ?? "Anonymous")
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.dsPrimary)
                HStack(spacing: DS.Spacing.xs) {
                    if let intent = tip.intent {
                        Text(intent.capitalized)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)
                        Text("·")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsTertiary)
                    }
                    if let date = roleHistoryDateText(tip.createdAt) {
                        Text(date)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(roleAmountText(tip.amountPaise))
                    .font(DS.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsPrimary)
                FliqStatusBadge(status: tip.status)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct ProviderAnalyticsView: View {
    let tips: [ProviderTipItem]
    let payouts: [ProviderPayoutItem]
    let recurringTips: [ProviderRecurringTip]

    private var paidTips: [ProviderTipItem] {
        tips.filter { $0.status == "PAID" || $0.status == "SETTLED" }
    }

    private var totalTipAmount: Int {
        paidTips.reduce(0) { $0 + $1.amountPaise }
    }

    private var averageTipAmount: Int {
        guard !paidTips.isEmpty else { return 0 }
        return totalTipAmount / paidTips.count
    }

    private var recentTipAmount: Int {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return paidTips
            .filter { tip in
                guard let createdAt = tip.createdAt,
                      let date = ISO8601DateFormatter().date(from: createdAt) else { return false }
                return date >= cutoff
            }
            .reduce(0) { $0 + $1.amountPaise }
    }

    private var successfulPayoutAmount: Int {
        payouts
            .filter { ["PROCESSED", "SUCCESS", "COMPLETED"].contains($0.status) }
            .reduce(0) { $0 + $1.amountPaise }
    }

    var body: some View {
        RoleSectionContainer(title: "Performance") {
            DetailLine(label: "Paid tips", value: String(paidTips.count))
            DetailLine(label: "Average tip", value: roleAmountText(averageTipAmount))
            DetailLine(label: "Last 30 days", value: roleAmountText(recentTipAmount))
            DetailLine(label: "Recurring supporters", value: String(recurringTips.filter { ["ACTIVE", "PAUSED"].contains($0.status) }.count))
            DetailLine(label: "Payouts processed", value: roleAmountText(successfulPayoutAmount))
        }
    }
}

private struct ProviderAffiliationsView: View {
    let affiliations: [BusinessAffiliation]

    var body: some View {
        RoleSectionContainer(title: "Business affiliations") {
            if affiliations.isEmpty {
                Text("No active business memberships yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(affiliations) { affiliation in
                    RoleItemCard {
                        Text(affiliation.businessName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Role", value: affiliation.isOwner ? "\(affiliation.role) (Owner)" : affiliation.role)
                        DetailLine(label: "Type", value: affiliation.businessType)
                        if let joinedAt = affiliation.joinedAt {
                            DetailLine(label: "Joined", value: roleHistoryDateText(joinedAt) ?? joinedAt)
                        }
                        if let phone = affiliation.contactPhone {
                            DetailLine(label: "Phone", value: phone)
                        }
                        if let email = affiliation.contactEmail {
                            DetailLine(label: "Email", value: email)
                        }
                    }
                }
            }
        }
    }
}

private struct BusinessReportingView: View {
    let dashboard: BusinessDashboardSnapshot
    let staff: [BusinessStaffMember]

    private var topStaff: [BusinessStaffMember] {
        staff.sorted { $0.tips.totalAmountPaise > $1.tips.totalAmountPaise }.prefix(3).map { $0 }
    }

    var body: some View {
        RoleSectionContainer(title: "Reporting") {
            DetailLine(label: "Gross tipped", value: roleAmountText(dashboard.totalAmountPaise))
            DetailLine(label: "Net after commissions", value: roleAmountText(dashboard.totalNetAmountPaise ?? 0))
            DetailLine(label: "Ratings captured", value: String(dashboard.totalRatingsCount ?? 0))
            if dashboard.recentTipTrend.isEmpty {
                Text("No 30-day trend data yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(Array(dashboard.recentTipTrend.suffix(5))) { point in
                    DetailLine(
                        label: roleHistoryDateText(point.createdAt ?? "") ?? "Trend point",
                        value: "\(roleAmountText(point.totalAmountPaise)) from \(point.tipCount) tips"
                    )
                }
            }

            if !topStaff.isEmpty {
                Text("Top staff")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                ForEach(topStaff) { member in
                    DetailLine(label: member.displayName, value: roleAmountText(member.tips.totalAmountPaise))
                }
            }
        }
    }
}

struct BusinessHomeView: View {
    let session: AuthSession
    let onLogout: () -> Void

    @State private var business: BusinessSummary?
    @State private var dashboard: BusinessDashboardSnapshot?
    @State private var staff: [BusinessStaffMember] = []
    @State private var satisfaction: BusinessSatisfactionSnapshot?
    @State private var qrGroups: [BusinessQrStaffGroup] = []
    @State private var isLoading = true
    @State private var isSavingBusiness = false
    @State private var isInvitingMember = false
    @State private var statusMessage = "Business parity is loading from the shared backend."
    @State private var errorMessage: String?

    @State private var businessName = ""
    @State private var businessType = businessTypes.first ?? "OTHER"
    @State private var businessAddress = ""
    @State private var businessContactPhone = ""
    @State private var businessContactEmail = ""
    @State private var businessGstin = ""
    @State private var invitePhone = ""
    @State private var inviteRole = "STAFF"

    private let businessClient = BusinessClient()

    var body: some View {
        TabView {
            // ── Tab 1: Dashboard ──────────────────────────────────────────
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        StatusCard(
                            title: errorMessage == nil ? "Current status" : "Error",
                            message: errorMessage ?? statusMessage,
                            isError: errorMessage != nil
                        )
                        if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                        BusinessEditorSection(
                            isRegistered: business != nil,
                            businessName: $businessName,
                            businessType: $businessType,
                            businessAddress: $businessAddress,
                            businessContactPhone: $businessContactPhone,
                            businessContactEmail: $businessContactEmail,
                            businessGstin: $businessGstin,
                            isSavingBusiness: isSavingBusiness,
                            onSave: { Task { await saveBusiness() } }
                        )
                        if business != nil, let dashboard {
                            RoleSectionContainer(title: "Dashboard") {
                                DetailLine(label: "Total tips", value: roleAmountText(dashboard.totalAmountPaise))
                                DetailLine(label: "Transactions", value: String(dashboard.totalTipsCount))
                                DetailLine(label: "Average rating", value: roleScoreText(dashboard.averageRating))
                                DetailLine(label: "Staff count", value: String(dashboard.staffCount))
                            }
                            BusinessReportingView(dashboard: dashboard, staff: staff)
                        }
                    }
                    .padding(16)
                }
                .background(Color.clear)
                .navigationTitle("Dashboard")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.dsSurface, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { Task { await loadBusinessHome() } }) {
                            Text(isLoading ? "Refreshing..." : "Refresh")
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

            // ── Tab 2: Staff ──────────────────────────────────────────────
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if business != nil {
                            BusinessInviteSection(
                                invitePhone: $invitePhone,
                                inviteRole: $inviteRole,
                                isInvitingMember: isInvitingMember,
                                onInvite: { Task { await inviteMember() } }
                            )
                            RoleSectionContainer(title: "Staff") {
                                if staff.isEmpty {
                                    Text("No staff members yet.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.fliqMuted)
                                } else {
                                    ForEach(staff) { member in
                                        RoleItemCard {
                                            Text(member.displayName)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            DetailLine(label: "Role", value: member.role)
                                            if let contact = member.contact {
                                                DetailLine(label: "Contact", value: contact)
                                            }
                                            if let category = member.category {
                                                DetailLine(label: "Category", value: category)
                                            }
                                            DetailLine(label: "Tips", value: String(member.tips.count))
                                            DetailLine(label: "Total tipped", value: roleAmountText(member.tips.totalAmountPaise))
                                            if let rating = member.tips.averageRating {
                                                DetailLine(label: "Average rating", value: roleScoreText(rating))
                                            }
                                            Button(action: { Task { await removeMember(member.id) } }) {
                                                Text("Remove member").frame(maxWidth: .infinity).padding(.vertical, 12)
                                            }
                                            .buttonStyle(NothingGhostButtonStyle())
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("Register your business in the Dashboard tab first.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.fliqMuted).padding()
                        }
                    }
                    .padding(16)
                }
                .background(Color.clear)
                .navigationTitle("Staff")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.dsSurface, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
            }
            .tabItem { Label("Staff", systemImage: "person.2.fill") }

            // ── Tab 3: Analytics ──────────────────────────────────────────
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RoleSectionContainer(title: "Satisfaction") {
                            if let satisfaction, !satisfaction.tips.isEmpty {
                                ForEach(Array(satisfaction.tips.prefix(20))) { review in
                                    RoleItemCard {
                                        Text(review.providerName)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        if let rating = review.rating { DetailLine(label: "Rating", value: "\(rating)/5") }
                                        if let message = review.message { DetailLine(label: "Message", value: message) }
                                        DetailLine(label: "Amount", value: roleAmountText(review.amountPaise))
                                        if let createdAt = review.createdAt {
                                            DetailLine(label: "Created", value: roleHistoryDateText(createdAt) ?? createdAt)
                                        }
                                    }
                                }
                            } else {
                                Text("No review data yet.")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.fliqMuted)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color.clear)
                .navigationTitle("Analytics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.dsSurface, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
            }
            .tabItem { Label("Analytics", systemImage: "chart.pie.fill") }

            // ── Tab 4: Settings ───────────────────────────────────────────
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if business != nil {
                            RoleSectionContainer(title: "Staff QR groups") {
                                if qrGroups.isEmpty {
                                    Text("No staff QR codes yet.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.fliqMuted)
                                } else {
                                    ForEach(qrGroups) { group in
                                        RoleItemCard {
                                            Text(group.displayName)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            DetailLine(label: "QR codes", value: String(group.qrCodes.count))
                                            ForEach(group.qrCodes) { qrCode in
                                                DetailLine(label: "QR", value: qrCode.locationLabel ?? qrCode.id)
                                            }
                                        }
                                    }
                                }
                            }
                            BusinessExportView(session: session, businessId: business?.id)
                        }
                        Button("Log Out", action: onLogout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .buttonStyle(.borderless)
                            .foregroundStyle(Color.fliqMuted)
                    }
                    .padding(16)
                }
                .background(Color.clear)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.dsSurface, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(Color.fliqLilac)
        .toolbarBackground(Color.dsSurface, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .task(id: session.user.id) {
            await loadBusinessHome()
        }
    }

    @MainActor
    private func loadBusinessHome() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedBusiness = try? await businessClient.getMyBusiness(accessToken: session.accessToken)
            business = loadedBusiness
            if let loadedBusiness {
                businessName = loadedBusiness.name
                businessType = loadedBusiness.type
                businessAddress = loadedBusiness.address ?? ""
                businessContactPhone = loadedBusiness.contactPhone ?? ""
                businessContactEmail = loadedBusiness.contactEmail ?? ""
                businessGstin = loadedBusiness.gstin ?? ""
                dashboard = try await businessClient.getDashboard(accessToken: session.accessToken, businessId: loadedBusiness.id)
                staff = try await businessClient.getStaff(accessToken: session.accessToken, businessId: loadedBusiness.id)
                satisfaction = try await businessClient.getSatisfaction(accessToken: session.accessToken, businessId: loadedBusiness.id)
                qrGroups = try await businessClient.getQrCodes(accessToken: session.accessToken, businessId: loadedBusiness.id)
                statusMessage = "Business dashboard, staff, satisfaction, and QR groups are loading natively."
            } else {
                dashboard = nil
                staff = []
                satisfaction = nil
                qrGroups = []
                statusMessage = "No business is registered for this account yet. Complete the native registration form to continue."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load the business home right now."
        }

        isLoading = false
    }

    @MainActor
    private func saveBusiness() async {
        guard !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Business name is required."
            return
        }

        isSavingBusiness = true
        errorMessage = nil

        do {
            let isRegistering = business == nil
            if let business {
                self.business = try await businessClient.updateBusiness(
                    accessToken: session.accessToken,
                    businessId: business.id,
                    name: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: businessType,
                    address: businessAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    contactPhone: businessContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessContactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                    contactEmail: businessContactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessContactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    gstin: businessGstin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessGstin.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                self.business = try await businessClient.registerBusiness(
                    accessToken: session.accessToken,
                    name: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: businessType,
                    address: businessAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    contactPhone: businessContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessContactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                    contactEmail: businessContactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessContactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    gstin: businessGstin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : businessGstin.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            statusMessage = isRegistering ? "Business registered." : "Business settings saved."
            await loadBusinessHome()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save the business right now."
        }

        isSavingBusiness = false
    }

    @MainActor
    private func inviteMember() async {
        guard let business, !invitePhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Staff phone number is required."
            return
        }

        isInvitingMember = true
        errorMessage = nil

        do {
            try await businessClient.inviteMember(
                accessToken: session.accessToken,
                businessId: business.id,
                phone: invitePhone.trimmingCharacters(in: .whitespacesAndNewlines),
                role: inviteRole
            )
            staff = try await businessClient.getStaff(accessToken: session.accessToken, businessId: business.id)
            invitePhone = ""
            statusMessage = "Staff invitation sent."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to invite that staff member right now."
        }

        isInvitingMember = false
    }

    @MainActor
    private func removeMember(_ memberId: String) async {
        guard let business else { return }
        errorMessage = nil

        do {
            try await businessClient.removeMember(
                accessToken: session.accessToken,
                businessId: business.id,
                memberId: memberId
            )
            staff = try await businessClient.getStaff(accessToken: session.accessToken, businessId: business.id)
            dashboard = try await businessClient.getDashboard(accessToken: session.accessToken, businessId: business.id)
            statusMessage = "Staff member removed."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to remove that staff member right now."
        }
    }
}

private struct ProviderProfileSection: View {
    let hasProfile: Bool
    @Binding var displayName: String
    @Binding var category: String
    @Binding var bio: String
    @Binding var upiVpa: String
    let isSavingProfile: Bool
    let profile: ProviderSelfProfile?
    let onSave: () -> Void

    var body: some View {
        RoleSectionContainer(title: hasProfile ? "Profile" : "Provider onboarding") {
            if let profile {
                DetailLine(label: "Provider ID", value: String(profile.id.prefix(8)).uppercased())
                DetailLine(label: "KYC", value: profile.user?.kycStatus ?? "PENDING")
                DetailLine(label: "Rating", value: roleScoreText(profile.ratingAverage))
                DetailLine(label: "Tips received", value: String(profile.totalTipsReceived))
            }

            TextField("Display name", text: $displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            RoleChoiceSection(label: "Category", options: providerCategories, selected: $category)

            TextField("Bio", text: $bio, axis: .vertical)
                .lineLimit(3...5)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("UPI VPA", text: $upiVpa)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onSave) {
                Text(isSavingProfile ? "Saving..." : (hasProfile ? "Save profile" : "Create profile"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isSavingProfile)
        }
    }
}

private struct ProviderQrSection: View {
    let qrCodes: [ProviderQrCode]
    @Binding var qrLocationLabel: String
    let isCreatingQR: Bool
    let onCreate: () -> Void

    var body: some View {
        RoleSectionContainer(title: "QR codes") {
            TextField("Location label", text: $qrLocationLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onCreate) {
                Text(isCreatingQR ? "Creating..." : "Create QR code")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isCreatingQR)

            if qrCodes.isEmpty {
                Text("No QR codes yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(qrCodes) { qrCode in
                    RoleItemCard {
                        if let qrImageUrl = qrCode.qrImageUrl, let imageUrl = URL(string: qrImageUrl) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                case .failure:
                                    Label("QR image unavailable", systemImage: "qrcode")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.fliqMuted)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                case .empty:
                                    ProgressView()
                                        .tint(Color.fliqMint)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        DetailLine(label: "Label", value: qrCode.locationLabel ?? "QR code")
                        DetailLine(label: "Scans", value: String(qrCode.scanCount ?? 0))
                        if let upiUrl = qrCode.upiUrl {
                            DetailLine(label: "UPI URL", value: upiUrl)
                        }
                    }
                }
            }
        }
    }
}

private struct ProviderPaymentLinkSection: View {
    let paymentLinks: [ProviderPaymentLink]
    @Binding var linkRole: String
    @Binding var linkWorkplace: String
    @Binding var linkDescription: String
    @Binding var linkSuggestedAmount: String
    @Binding var linkAllowCustomAmount: Bool
    let isCreatingLink: Bool
    let onCreate: () -> Void

    var body: some View {
        RoleSectionContainer(title: "Payment links") {
            TextField("Role", text: $linkRole)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Workplace", text: $linkWorkplace)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Description", text: $linkDescription, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Suggested amount in rupees", text: $linkSuggestedAmount)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: {
                linkAllowCustomAmount.toggle()
            }) {
                Text(linkAllowCustomAmount ? "Custom amount allowed" : "Amount locked to suggested value")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(NothingGhostButtonStyle())

            Button(action: onCreate) {
                Text(isCreatingLink ? "Creating..." : "Create payment link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isCreatingLink)

            if paymentLinks.isEmpty {
                Text("No payment links yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(paymentLinks) { link in
                    RoleItemCard {
                        DetailLine(label: "Short code", value: link.shortCode)
                        if let role = link.role {
                            DetailLine(label: "Role", value: role)
                        }
                        if let workplace = link.workplace {
                            DetailLine(label: "Workplace", value: workplace)
                        }
                        if let shareableUrl = link.shareableUrl {
                            DetailLine(label: "Shareable URL", value: shareableUrl)
                        }
                        DetailLine(label: "Clicks", value: String(link.clickCount ?? 0))
                    }
                }
            }
        }
    }
}

private struct ProviderTipsSection: View {
    let tips: [ProviderTipItem]

    var body: some View {
        RoleSectionContainer(title: "Recent tips") {
            if tips.isEmpty {
                Text("No tips received yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(Array(tips.prefix(10))) { tip in
                    RoleItemCard {
                        Text("\(roleAmountText(tip.amountPaise))\(tip.customerName.map { " from \($0)" } ?? "")")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Status", value: tip.status)
                        if let rating = tip.rating {
                            DetailLine(label: "Rating", value: "\(rating)/5")
                        }
                        if let intent = tip.intent {
                            DetailLine(label: "Intent", value: intent)
                        }
                        if let message = tip.message {
                            DetailLine(label: "Message", value: message)
                        }
                        if let createdAt = tip.createdAt {
                            DetailLine(label: "Created", value: roleHistoryDateText(createdAt) ?? createdAt)
                        }
                    }
                }
            }
        }
    }
}

private struct ProviderDreamSection: View {
    let dream: ProviderDreamData?
    @Binding var dreamTitle: String
    @Binding var dreamDescription: String
    @Binding var dreamCategory: String
    @Binding var dreamGoalAmount: String
    let isSavingDream: Bool
    let onSave: () -> Void

    var body: some View {
        RoleSectionContainer(title: "Dream") {
            if let dream {
                DetailLine(label: "Current dream", value: dream.title)
                DetailLine(label: "Progress", value: "\(dream.percentage)% funded")
            }

            TextField("Dream title", text: $dreamTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Dream description", text: $dreamDescription, axis: .vertical)
                .lineLimit(3...5)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            RoleChoiceSection(label: "Dream category", options: dreamCategories, selected: $dreamCategory)

            TextField("Goal amount in rupees", text: $dreamGoalAmount)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onSave) {
                Text(isSavingDream ? "Saving..." : "Save dream")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isSavingDream)
        }
    }
}

private struct ProviderRecurringSupportSection: View {
    let recurringTips: [ProviderRecurringTip]

    var body: some View {
        RoleSectionContainer(title: "Recurring support") {
            if recurringTips.isEmpty {
                Text("No active recurring supporters yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(recurringTips) { recurring in
                    RoleItemCard {
                        Text("\(roleAmountText(recurring.amountPaise)) / \(recurring.frequency.lowercased())")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Status", value: recurring.status)
                        if let customerName = recurring.customerName {
                            DetailLine(label: "Customer", value: customerName)
                        }
                        if let createdAt = recurring.createdAt {
                            DetailLine(label: "Created", value: roleHistoryDateText(createdAt) ?? createdAt)
                        }
                    }
                }
            }
        }
    }
}

private struct ProviderPayoutSection: View {
    let payouts: [ProviderPayoutItem]
    @Binding var payoutAmountRupees: String
    let isRequestingPayout: Bool
    let onRequest: () -> Void

    var body: some View {
        RoleSectionContainer(title: "Payouts") {
            TextField("Payout amount in rupees", text: $payoutAmountRupees)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onRequest) {
                Text(isRequestingPayout ? "Requesting..." : "Request payout")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isRequestingPayout)

            if payouts.isEmpty {
                Text("No payout history yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(payouts) { payout in
                    RoleItemCard {
                        Text(roleAmountText(payout.amountPaise))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Status", value: payout.status)
                        if let mode = payout.mode {
                            DetailLine(label: "Mode", value: mode)
                        }
                        if let createdAt = payout.createdAt {
                            DetailLine(label: "Created", value: roleHistoryDateText(createdAt) ?? createdAt)
                        }
                    }
                }
            }
        }
    }
}

private struct BusinessEditorSection: View {
    let isRegistered: Bool
    @Binding var businessName: String
    @Binding var businessType: String
    @Binding var businessAddress: String
    @Binding var businessContactPhone: String
    @Binding var businessContactEmail: String
    @Binding var businessGstin: String
    let isSavingBusiness: Bool
    let onSave: () -> Void

    var body: some View {
        RoleSectionContainer(title: isRegistered ? "Business settings" : "Business registration") {
            TextField("Business name", text: $businessName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            RoleChoiceSection(label: "Business type", options: businessTypes, selected: $businessType)

            TextField("Address", text: $businessAddress, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Contact phone", text: $businessContactPhone)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("Contact email", text: $businessContactEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            TextField("GSTIN", text: $businessGstin)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onSave) {
                Text(isSavingBusiness ? "Saving..." : (isRegistered ? "Save business" : "Register business"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
            .disabled(isSavingBusiness)
        }
    }
}

private struct BusinessInviteSection: View {
    @Binding var invitePhone: String
    @Binding var inviteRole: String
    let isInvitingMember: Bool
    let onInvite: () -> Void

    var body: some View {
        RoleSectionContainer(title: "Invite staff") {
            TextField("Staff phone number", text: $invitePhone)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(13)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            RoleChoiceSection(label: "Role", options: businessRoles, selected: $inviteRole)

            Button(action: onInvite) {
                Text(isInvitingMember ? "Inviting..." : "Send invitation")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
            .disabled(isInvitingMember)
        }
    }
}

private struct RoleSectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(DS.Typography.title2)
                .foregroundStyle(Color.dsPrimary)
            content
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private struct RoleItemCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsBorderLight)
        .cornerRadius(DS.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md, style: .continuous)
                .strokeBorder(Color.dsBorder, lineWidth: 1)
        )
    }
}

private struct RoleChoiceSection: View {
    let label: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.dsSecondary)

            ForEach(Array(options.chunked(into: 3).enumerated()), id: \.offset) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk.element, id: \.self) { option in
                        let isSelected = selected == option
                        Button(action: { selected = option }) {
                            Text(isSelected ? "✓ \(option)" : option)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? Color.dsAccent : Color.dsSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(isSelected ? Color.dsAccentTint : Color.dsBorderLight)
                                .cornerRadius(DS.CornerRadius.sm)
                                .overlay(RoundedRectangle(cornerRadius: DS.CornerRadius.sm).strokeBorder(
                                    isSelected ? Color.dsAccent.opacity(0.5) : Color.clear,
                                    lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

private func roleAmountText(_ amountPaise: Int) -> String {
    let amount = Double(amountPaise) / 100.0
    return String(format: "Rs %.0f", amount)
}

private func roleHistoryDateText(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: value) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    return value
}

private func roleScoreText(_ value: Double?) -> String {
    guard let value else { return "0.0" }
    return String(format: "%.1f", value)
}
