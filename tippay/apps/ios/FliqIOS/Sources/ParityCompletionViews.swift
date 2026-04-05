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
    let currentUpiVpa: String?
    let latestTips: [ProviderTipItem]
    let onRefreshRequested: () -> Void

    @State private var bankUpiVpa = ""
    @State private var bankAccountNumber = ""
    @State private var bankIfscCode = ""
    @State private var bankPan = ""
    @State private var aadhaarOrVid = ""
    @State private var ekycOtp = ""
    @State private var ekycInitiation: NativeEkycInitiation?
    @State private var ekycProfile: NativeEkycProfile?
    @State private var ekycStatus: NativeEkycStatus?
    @State private var responseEmoji = "🙏"
    @State private var responseState: [String: String] = [:]
    @State private var isSavingBank = false
    @State private var isInitiatingEkyc = false
    @State private var isVerifyingEkyc = false
    @State private var responseSubmittingTipId: String?
    @State private var statusMessage = "Bank details, Aadhaar eKYC, and thank-you responses are now wired natively."
    @State private var errorMessage: String?

    private let parityClient = ParityCompletionClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider completion")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            ParitySectionCard(title: "Bank details") {
                TextField("UPI VPA", text: $bankUpiVpa)
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(parityFieldBackground)
                TextField("Bank account number", text: $bankAccountNumber)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(parityFieldBackground)
                TextField("IFSC code", text: $bankIfscCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(parityFieldBackground)
                TextField("PAN", text: $bankPan)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(parityFieldBackground)

                Button(action: {
                    Task { await saveBankDetails() }
                }) {
                    Text(isSavingBank ? "Saving..." : "Save bank details")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                .disabled(isSavingBank)
            }

            ParitySectionCard(title: "Aadhaar eKYC") {
                if let ekycStatus {
                    DetailLine(label: "KYC status", value: ekycStatus.kycStatus)
                    DetailLine(label: "Verified", value: ekycStatus.kycVerified ? "Yes" : "No")
                    if let kycMethod = ekycStatus.kycMethod {
                        DetailLine(label: "Method", value: kycMethod)
                    }
                    if let kycCompletedAt = ekycStatus.kycCompletedAt {
                        DetailLine(label: "Completed", value: parityDateText(kycCompletedAt) ?? kycCompletedAt)
                    }
                }

                TextField("Aadhaar or VID", text: $aadhaarOrVid)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(parityFieldBackground)

                Button(action: {
                    Task { await initiateEkyc() }
                }) {
                    Text(isInitiatingEkyc ? "Sending OTP..." : "Initiate eKYC")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                .disabled(isInitiatingEkyc)

                if let ekycInitiation {
                    DetailLine(label: "Session token", value: ekycInitiation.sessionToken)
                    DetailLine(label: "Masked phone", value: ekycInitiation.maskedPhone)

                    TextField("OTP", text: $ekycOtp)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .foregroundStyle(.white)
                    .background(parityFieldBackground)

                    Button(action: {
                        Task { await verifyEkyc() }
                    }) {
                        Text(isVerifyingEkyc ? "Verifying..." : "Verify eKYC OTP")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
                    .disabled(isVerifyingEkyc)
                }

                if let ekycProfile {
                    ParityListCard {
                        Text("Verified profile")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DetailLine(label: "Name", value: ekycProfile.name)
                        DetailLine(label: "DOB", value: ekycProfile.dob)
                        DetailLine(label: "Gender", value: ekycProfile.gender)
                        DetailLine(label: "Address", value: ekycProfile.address)
                    }
                }
            }

            ParitySectionCard(title: "Thank-you responses") {
                if latestTips.isEmpty {
                    Text("Paid tips will appear here for emoji responses.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(latestTips.prefix(5))) { tip in
                        ParityListCard {
                            Text("\(parityAmountText(tip.amountPaise))\(tip.customerName.map { " from \($0)" } ?? "")")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            DetailLine(label: "Status", value: tip.status)
                            if let existingResponse = responseState[tip.id] {
                                DetailLine(label: "Existing response", value: existingResponse)
                            }
                            HStack(spacing: 12) {
                                TextField("Emoji", text: $responseEmoji)
                                    .padding(14)
                                    .foregroundStyle(.white)
                    .background(parityFieldBackground)

                                Button(action: {
                                    Task { await sendResponse(for: tip.id, status: tip.status) }
                                }) {
                                    Text(responseSubmittingTipId == tip.id ? "Sending..." : "Send")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                                .disabled(responseSubmittingTipId == tip.id || tip.status == "INITIATED" || tip.status == "FAILED" || responseState[tip.id] != nil)
                            }
                        }
                    }
                }
            }
        }
        .task(id: session.user.id) {
            bankUpiVpa = currentUpiVpa ?? ""
            await loadProviderCompletionData()
        }
    }

    @MainActor
    private func loadProviderCompletionData() async {
        do {
            ekycStatus = try await parityClient.getEkycStatus(accessToken: session.accessToken)
            for tip in latestTips.prefix(5) {
                if let response = try? await parityClient.getTipResponse(tipId: tip.id), let emoji = response.emoji {
                    responseState[tip.id] = emoji
                }
            }
        } catch {
            // Completion hydration is non-blocking.
        }
    }

    @MainActor
    private func saveBankDetails() async {
        isSavingBank = true
        do {
            try await parityClient.saveBankDetails(
                accessToken: session.accessToken,
                upiVpa: bankUpiVpa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankUpiVpa.trimmingCharacters(in: .whitespacesAndNewlines),
                bankAccountNumber: bankAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                ifscCode: bankIfscCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankIfscCode.trimmingCharacters(in: .whitespacesAndNewlines),
                pan: bankPan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankPan.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            statusMessage = "Bank details saved to the shared backend."
            errorMessage = nil
            onRefreshRequested()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save bank details right now."
        }
        isSavingBank = false
    }

    @MainActor
    private func initiateEkyc() async {
        guard aadhaarOrVid.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else {
            errorMessage = "Enter a valid Aadhaar or VID."
            return
        }

        isInitiatingEkyc = true
        do {
            ekycInitiation = try await parityClient.initiateEkyc(
                accessToken: session.accessToken,
                aadhaarOrVid: aadhaarOrVid.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            statusMessage = "OTP sent to \(ekycInitiation?.maskedPhone ?? "the Aadhaar-linked mobile")."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to initiate eKYC right now."
        }
        isInitiatingEkyc = false
    }

    @MainActor
    private func verifyEkyc() async {
        guard let ekycInitiation else { return }
        guard ekycOtp.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 else {
            errorMessage = "Enter the OTP received on the Aadhaar-linked mobile."
            return
        }

        isVerifyingEkyc = true
        do {
            ekycProfile = try await parityClient.verifyEkycOtp(
                accessToken: session.accessToken,
                sessionToken: ekycInitiation.sessionToken,
                otp: ekycOtp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            ekycStatus = try await parityClient.getEkycStatus(accessToken: session.accessToken)
            statusMessage = "Aadhaar eKYC completed."
            errorMessage = nil
            onRefreshRequested()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to verify the eKYC OTP right now."
        }
        isVerifyingEkyc = false
    }

    @MainActor
    private func sendResponse(for tipId: String, status: String) async {
        guard status != "INITIATED", status != "FAILED" else { return }

        responseSubmittingTipId = tipId
        do {
            let response = try await parityClient.createEmojiResponse(
                accessToken: session.accessToken,
                tipId: tipId,
                emoji: responseEmoji.isEmpty ? "🙏" : responseEmoji
            )
            responseState[tipId] = response.emoji ?? "🙏"
            statusMessage = "Thank-you response sent."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to send the thank-you response right now."
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
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.06))
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct ParityListCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private let parityFieldBackground =
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.white.opacity(0.1))
        .stroke(Color.white.opacity(0.2), lineWidth: 1)

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
