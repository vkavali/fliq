import SwiftUI

struct CustomerRetentionView: View {
    let session: AuthSession
    let selectedProvider: ProviderProfile?
    let amountRupees: String
    let message: String
    let rating: Int

    @State private var badges: [NativeBadge] = []
    @State private var streak: NativeStreak?
    @State private var tipperLeaderboard: [NativeLeaderboardEntry] = []
    @State private var providerLeaderboard: [NativeLeaderboardEntry] = []
    @State private var recurringTips: [NativeRecurringTip] = []
    @State private var deferredTips: [NativeDeferredTip] = []
    @State private var recurringAuthorization: NativeRecurringAuthorization?
    @State private var paymentOrder: NativePaymentOrder?
    @State private var paymentStatus: TipStatusSnapshot?
    @State private var paymentImpact: TipImpactSnapshot?
    @State private var statusMessage = "Recurring tips, tip later, and gamification are now loading natively."
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isCreatingRecurring = false
    @State private var isCreatingDeferred = false
    @State private var isUpdatingRecurring = false
    @State private var isPayingDeferred = false
    @State private var isLaunchingCheckout = false
    @State private var isVerifyingPayment = false

    private let parityClient = ParityCompletionClient()
    private let customerClient = CustomerClient()
    private let checkoutCoordinator = NativeCheckoutCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Retention and promises")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let streak {
                ParitySectionCard(title: "Streak") {
                    DetailLine(label: "Current streak", value: "\(streak.currentStreak) days")
                    DetailLine(label: "Longest streak", value: "\(streak.longestStreak) days")
                    if let lastTipDate = streak.lastTipDate {
                        DetailLine(label: "Last tip", value: parityDateText(lastTipDate) ?? lastTipDate)
                    }
                }
            }

            ParitySectionCard(title: "Badges") {
                let earned = badges.filter(\.earned)
                if earned.isEmpty {
                    Text("No earned badges yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(earned.prefix(4))) { badge in
                        ParityListCard {
                            Text(badge.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            DetailLine(label: "Category", value: badge.category)
                            DetailLine(label: "Description", value: badge.description)
                        }
                    }
                }
            }

            ParitySectionCard(title: "Leaderboards") {
                Text("Top tippers")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if tipperLeaderboard.isEmpty {
                    Text("No leaderboard data yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(tipperLeaderboard.prefix(3))) { entry in
                        DetailLine(label: "#\(entry.rank) \(entry.name)", value: "\(entry.tipCount) tips")
                    }
                }

                Text("Top providers")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if providerLeaderboard.isEmpty {
                    Text("No provider leaderboard data yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(providerLeaderboard.prefix(3))) { entry in
                        DetailLine(label: "#\(entry.rank) \(entry.name)", value: parityAmountText(entry.displayAmountPaise))
                    }
                }
            }

            ParitySectionCard(title: "Recurring tips") {
                if let selectedProvider {
                    Text("Create a recurring tip for \(selectedProvider.displayName).")
                        .foregroundStyle(Color.fliqMuted)
                    HStack(spacing: 12) {
                        Button(action: {
                            Task { await createRecurringTip(frequency: .weekly, providerId: selectedProvider.id) }
                        }) {
                            Text("Weekly")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                        .disabled(isCreatingRecurring)

                        Button(action: {
                            Task { await createRecurringTip(frequency: .monthly, providerId: selectedProvider.id) }
                        }) {
                            Text("Monthly")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                        .disabled(isCreatingRecurring)
                    }
                } else {
                    Text("Select a provider above to create a recurring tip.")
                        .foregroundStyle(Color.fliqMuted)
                }

                if let recurringAuthorization {
                    ParityListCard {
                        Text("Mandate ready for \(recurringAuthorization.providerName)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Subscription", value: recurringAuthorization.subscriptionId)
                        DetailLine(label: "Authorization URL", value: recurringAuthorization.authorizationUrl)
                        Link(destination: URL(string: recurringAuthorization.authorizationUrl)!) {
                            Text("Open authorization link")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(NothingGhostButtonStyle())
                    }
                }

                if recurringTips.isEmpty {
                    Text("No recurring tips yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(recurringTips) { recurring in
                        ParityListCard {
                            Text("\(parityAmountText(recurring.amountPaise)) / \(recurring.frequency.lowercased())")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if let providerName = recurring.providerName {
                                DetailLine(label: "Provider", value: providerName)
                            }
                            if let providerCategory = recurring.providerCategory {
                                DetailLine(label: "Category", value: providerCategory)
                            }
                            DetailLine(label: "Status", value: recurring.status)
                            if let nextChargeDate = recurring.nextChargeDate {
                                DetailLine(label: "Next charge", value: parityDateText(nextChargeDate) ?? nextChargeDate)
                            }
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await toggleRecurring(recurring) }
                                }) {
                                    Text(recurring.status == "PAUSED" ? "Resume" : "Pause")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(isUpdatingRecurring || (recurring.status != "ACTIVE" && recurring.status != "PAUSED"))

                                Button(action: {
                                    Task { await cancelRecurring(recurring.id) }
                                }) {
                                    Text("Cancel")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(isUpdatingRecurring)
                            }
                        }
                    }
                }
            }

            ParitySectionCard(title: "Tip later") {
                if let selectedProvider {
                    Button(action: {
                        Task { await createDeferredTip(providerId: selectedProvider.id) }
                    }) {
                        Text(isCreatingDeferred ? "Saving promise..." : "Promise this tip for later")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
                    .disabled(isCreatingDeferred)
                } else {
                    Text("Select a provider above to save a tip promise.")
                        .foregroundStyle(Color.fliqMuted)
                }

                if deferredTips.isEmpty {
                    Text("No promised tips yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(deferredTips) { deferred in
                        ParityListCard {
                            Text("\(parityAmountText(deferred.amountPaise)) to \(deferred.providerName ?? "Provider")")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            DetailLine(label: "Status", value: deferred.status)
                            if let dueAt = deferred.dueAt {
                                DetailLine(label: "Due", value: parityDateText(dueAt) ?? dueAt)
                            }
                            if let message = deferred.message {
                                DetailLine(label: "Message", value: message)
                            }
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await payDeferredTip(deferred.id) }
                                }) {
                                    Text("Pay now")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                                .disabled(isPayingDeferred || deferred.status != "PROMISED")

                                Button(action: {
                                    Task { await cancelDeferredTip(deferred.id) }
                                }) {
                                    Text("Cancel")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(deferred.status != "PROMISED")
                            }
                        }
                    }
                }

                if let paymentOrder {
                    ParityListCard {
                        Text("Deferred payment order")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Title", value: paymentOrder.title)
                        if let subtitle = paymentOrder.subtitle {
                            DetailLine(label: "Context", value: subtitle)
                        }
                        DetailLine(label: "Amount", value: parityAmountText(paymentOrder.amountPaise))
                        DetailLine(label: "Order ID", value: paymentOrder.orderId)
                        if let paymentStatus {
                            DetailLine(label: "Status", value: paymentStatus.status)
                        }
                        if let paymentImpact {
                            Text(paymentImpact.message)
                                .foregroundStyle(.white)
                        }
                        HStack(spacing: 12) {
                            if paymentOrder.isMockOrder {
                                Button(action: {
                                    Task { await completeMockPayment(paymentOrder) }
                                }) {
                                    Text("Complete mock payment")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                                .disabled(isVerifyingPayment)
                            } else {
                                Button(action: {
                                    openDeferredCheckout(paymentOrder)
                                }) {
                                    Text(isVerifyingPayment ? "Verifying..." : (isLaunchingCheckout ? "Opening..." : "Open checkout"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                                .disabled(isLaunchingCheckout || isVerifyingPayment)
                            }
                            Button(action: {
                                Task { await refreshPaymentState(paymentOrder) }
                            }) {
                                Text("Refresh status")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(NothingGhostButtonStyle())
                        }
                    }
                }
            }
        }
        .task(id: session.user.id) {
            await loadRetentionData()
        }
    }

    @MainActor
    private func loadRetentionData() async {
        isLoading = true
        do {
            badges = try await parityClient.getBadges(accessToken: session.accessToken)
            streak = try await parityClient.getStreak(accessToken: session.accessToken)
            tipperLeaderboard = try await parityClient.getLeaderboard(path: "/gamification/leaderboard")
            providerLeaderboard = try await parityClient.getLeaderboard(path: "/gamification/leaderboard/providers")
            recurringTips = try await parityClient.getMyRecurringTips(accessToken: session.accessToken)
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Recurring support, tip promises, badges, streaks, and leaderboards are live natively."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load retention data right now."
        }
        isLoading = false
    }

    @MainActor
    private func createRecurringTip(frequency: NativeRecurringFrequency, providerId: String) async {
        guard let amount = Int(amountRupees), amount >= 10 else {
            errorMessage = "Recurring tip minimum is Rs 10."
            return
        }

        isCreatingRecurring = true
        do {
            recurringAuthorization = try await parityClient.createRecurringTip(
                accessToken: session.accessToken,
                providerId: providerId,
                amountPaise: amount * 100,
                frequency: frequency
            )
            recurringTips = try await parityClient.getMyRecurringTips(accessToken: session.accessToken)
            statusMessage = "\(frequency.label) recurring tip created. Open the authorization link to finish the mandate."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create a recurring tip right now."
        }
        isCreatingRecurring = false
    }

    @MainActor
    private func toggleRecurring(_ recurring: NativeRecurringTip) async {
        guard recurring.status == "ACTIVE" || recurring.status == "PAUSED" else { return }

        isUpdatingRecurring = true
        do {
            if recurring.status == "ACTIVE" {
                try await parityClient.pauseRecurringTip(accessToken: session.accessToken, recurringTipId: recurring.id)
                statusMessage = "Recurring tip paused."
            } else {
                try await parityClient.resumeRecurringTip(accessToken: session.accessToken, recurringTipId: recurring.id)
                statusMessage = "Recurring tip resumed."
            }
            recurringTips = try await parityClient.getMyRecurringTips(accessToken: session.accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update the recurring tip right now."
        }
        isUpdatingRecurring = false
    }

    @MainActor
    private func cancelRecurring(_ recurringTipId: String) async {
        isUpdatingRecurring = true
        do {
            try await parityClient.cancelRecurringTip(accessToken: session.accessToken, recurringTipId: recurringTipId)
            recurringTips = try await parityClient.getMyRecurringTips(accessToken: session.accessToken)
            statusMessage = "Recurring tip cancelled."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to cancel the recurring tip right now."
        }
        isUpdatingRecurring = false
    }

    @MainActor
    private func createDeferredTip(providerId: String) async {
        guard let amount = Int(amountRupees), amount >= 10 else {
            errorMessage = "Tip later minimum is Rs 10."
            return
        }

        isCreatingDeferred = true
        do {
            _ = try await parityClient.createDeferredTip(
                accessToken: session.accessToken,
                providerId: providerId,
                amountPaise: amount * 100,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: rating
            )
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Tip promise saved."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create a tip promise right now."
        }
        isCreatingDeferred = false
    }

    @MainActor
    private func payDeferredTip(_ deferredTipId: String) async {
        isPayingDeferred = true
        do {
            paymentOrder = try await parityClient.payDeferredTip(accessToken: session.accessToken, deferredTipId: deferredTipId)
            paymentStatus = nil
            paymentImpact = nil
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Deferred tip converted into a payment order."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to pay the deferred tip right now."
        }
        isPayingDeferred = false
    }

    @MainActor
    private func cancelDeferredTip(_ deferredTipId: String) async {
        do {
            try await parityClient.cancelDeferredTip(accessToken: session.accessToken, deferredTipId: deferredTipId)
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Tip promise cancelled."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to cancel the tip promise right now."
        }
    }

    private func openDeferredCheckout(_ order: NativePaymentOrder) {
        isLaunchingCheckout = true
        errorMessage = nil

        do {
            try checkoutCoordinator.open(
                order: order,
                contact: session.user.phone,
                email: session.user.email,
                onSuccess: { result in
                    Task { await handleCheckoutSuccess(result, order: order) }
                },
                onError: { message in
                    Task { @MainActor in
                        isLaunchingCheckout = false
                        errorMessage = message
                    }
                }
            )
        } catch {
            isLaunchingCheckout = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to open checkout right now."
        }
    }

    @MainActor
    private func handleCheckoutSuccess(_ result: NativeCheckoutSuccess, order: NativePaymentOrder) async {
        isLaunchingCheckout = false
        isVerifyingPayment = true

        do {
            let payload = try parseCheckoutPayload(
                response: result.response,
                fallbackPaymentId: result.paymentId
            )
            _ = try await customerClient.verifyPayment(
                tipId: order.tipId,
                orderId: payload.orderId ?? order.orderId,
                paymentId: payload.paymentId,
                signature: payload.signature
            )
            await refreshPaymentState(order)
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Deferred payment verified."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Checkout returned, but verification failed."
        }

        isVerifyingPayment = false
    }

    @MainActor
    private func completeMockPayment(_ order: NativePaymentOrder) async {
        isVerifyingPayment = true
        do {
            _ = try await customerClient.verifyMockPayment(tipId: order.tipId, orderId: order.orderId)
            await refreshPaymentState(order)
            deferredTips = try await parityClient.getMyDeferredTips(accessToken: session.accessToken)
            statusMessage = "Mock payment verified."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to complete mock verification right now."
        }
        isVerifyingPayment = false
    }

    @MainActor
    private func refreshPaymentState(_ order: NativePaymentOrder) async {
        do {
            paymentStatus = try await customerClient.getTipStatus(tipId: order.tipId)
            paymentImpact = try? await customerClient.getTipImpact(tipId: order.tipId)
            statusMessage = "Deferred payment status refreshed."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to refresh payment status right now."
        }
    }

    private func parseCheckoutPayload(
        response: [AnyHashable: Any]?,
        fallbackPaymentId: String
    ) throws -> ParsedDeferredCheckoutPayload {
        let orderId = response?["razorpay_order_id"] as? String
        let paymentId = (response?["razorpay_payment_id"] as? String) ?? fallbackPaymentId
        guard !paymentId.isEmpty else {
            throw CustomerClientError.invalidResponse
        }
        guard let signature = response?["razorpay_signature"] as? String, !signature.isEmpty else {
            throw CustomerClientError.invalidResponse
        }
        return ParsedDeferredCheckoutPayload(orderId: orderId, paymentId: paymentId, signature: signature)
    }
}

struct ProviderCompletionView: View {
    let session: AuthSession
    let latestTips: [ProviderTipItem]
    let onRefreshRequested: () -> Void

    @State private var responseState: [String: String] = [:]
    @State private var responseSubmittingTipId: String?
    @State private var errorMessage: String?

    private let parityClient = ParityCompletionClient()

    var body: some View {
        let paidTips = Array(latestTips.filter { ["PAID", "SETTLED"].contains($0.status.uppercased()) }.prefix(5))

        Group {
            if !paidTips.isEmpty {
                FliqCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(Color.dsError)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Say Thank You")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.dsPrimary)
                                Text("Send a \u{1F64F} to your recent tippers")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            Spacer()
                        }

                        if let errorMessage {
                            FliqErrorBanner(message: errorMessage)
                        }

                        ForEach(Array(paidTips.enumerated()), id: \.element.id) { index, tip in
                            HStack(spacing: DS.Spacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(Color.dsSuccessTint)
                                        .frame(width: 36, height: 36)
                                    Text(String((tip.customerName ?? "A").prefix(1)).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.dsSuccess)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tip.customerName ?? "Anonymous")
                                        .font(DS.Typography.bodyMedium)
                                        .foregroundStyle(Color.dsPrimary)
                                    Text(parityAmountText(tip.amountPaise))
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsSecondary)
                                }
                                Spacer()
                                if let existingResponse = responseState[tip.id] {
                                    Text(existingResponse)
                                        .font(.system(size: 22))
                                } else {
                                    Button(action: {
                                        Task { await sendResponse(for: tip.id, status: tip.status) }
                                    }) {
                                        HStack(spacing: 4) {
                                            if responseSubmittingTipId == tip.id {
                                                ProgressView().scaleEffect(0.7).tint(Color.dsAccent)
                                            } else {
                                                Text("\u{1F64F}")
                                            }
                                            Text("Thank")
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(Color.dsAccent)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.dsAccentTint)
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(responseSubmittingTipId == tip.id)
                                }
                            }
                            if index < paidTips.count - 1 {
                                FliqDivider()
                            }
                        }
                    }
                }
            }
        }
        .task(id: session.user.id) {
            await loadProviderCompletionData()
        }
    }

    @MainActor
    private func loadProviderCompletionData() async {
        for tip in latestTips.prefix(5) {
            if let response = try? await parityClient.getTipResponse(tipId: tip.id), let emoji = response.emoji {
                responseState[tip.id] = emoji
            }
        }
    }

    @MainActor
    private func sendResponse(for tipId: String, status: String) async {
        guard ["PAID", "SETTLED"].contains(status.uppercased()) else { return }
        responseSubmittingTipId = tipId
        errorMessage = nil
        do {
            let response = try await parityClient.createEmojiResponse(
                accessToken: session.accessToken,
                tipId: tipId,
                emoji: "🙏"
            )
            responseState[tipId] = response.emoji ?? "🙏"
        } catch {
            errorMessage = "Couldn't send your thank-you. Please try again."
        }
        responseSubmittingTipId = nil
    }
}

struct BusinessExportView: View {
    let session: AuthSession
    let businessId: String?

    @State private var csvPreview: String?
    @State private var csvBody: String?
    @State private var statusMessage = "Native business export is now available from this app."
    @State private var errorMessage: String?
    @State private var isExporting = false

    private let parityClient = ParityCompletionClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business export")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            Button(action: {
                Task { await loadExportPreview() }
            }) {
                Text(isExporting ? "Exporting..." : "Load CSV preview")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
            .disabled(isExporting)

            if let csvBody {
                ShareLink(item: csvBody, preview: SharePreview("Fliq business export")) {
                    Text("Share CSV export")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(NothingGhostButtonStyle())
            }

            if let csvPreview {
                ParitySectionCard(title: "Preview") {
                    Text(csvPreview)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @MainActor
    private func loadExportPreview() async {
        guard let businessId, !businessId.isEmpty else {
            errorMessage = "Register or load a business first."
            return
        }

        isExporting = true
        do {
            let csv = try await parityClient.exportBusinessCsv(accessToken: session.accessToken, businessId: businessId)
            csvBody = csv
            csvPreview = csv
                .split(separator: "\n")
                .prefix(12)
                .joined(separator: "\n")
            statusMessage = "Loaded CSV export preview from the shared backend."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to export business CSV right now."
        }
        isExporting = false
    }
}

private struct ParitySectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

private struct ParityListCard<Content: View>: View {
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

private let parityFieldBackground =
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(hex: "F3F4F6"))
        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)

private struct ParsedDeferredCheckoutPayload {
    let orderId: String?
    let paymentId: String
    let signature: String
}

private func parityAmountText(_ amountPaise: Int) -> String {
    "Rs \(amountPaise / 100)"
}

private func parityDateText(_ raw: String) -> String? {
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: raw) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    return nil
}
