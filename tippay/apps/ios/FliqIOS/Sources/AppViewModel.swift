import Foundation

private let supportedLanguageCodes: Set<String> = ["en", "hi", "ta", "te", "kn", "mr"]

@MainActor
final class AppViewModel: ObservableObject {
    enum Stage {
        case rolePicker
        case credential
        case otp
        case home
    }

    @Published var stage: Stage = .rolePicker
    @Published var selectedRole: NativeRole?
    @Published var credential = ""
    @Published var code = ""
    @Published var session: AuthSession?
    @Published var statusMessage = "Native iOS foundation is live. OTP auth and session restore are now wired into this app shell."
    @Published var errorMessage: String?
    @Published var isLoading = true
    @Published var providerQuery = ""
    @Published var providerResults: [ProviderSearchResult] = []
    @Published var selectedProvider: ProviderProfile?
    @Published var selectedEntryContext: TipEntryContext?
    @Published var resolutionInput = ""
    @Published var amountRupees = "100"
    @Published var selectedIntent: TipIntentOption = .kindness
    @Published var tipMessage = ""
    @Published var selectedRating = 5
    @Published var createdTipOrder: CreatedTipOrder?
    @Published var tipStatus: TipStatusSnapshot?
    @Published var tipImpact: TipImpactSnapshot?
    @Published var isSearchingProviders = false
    @Published var isLoadingProvider = false
    @Published var isSubmittingTip = false
    @Published var isResolvingQr = false
    @Published var isResolvingPaymentLink = false
    @Published var isRefreshingTipStatus = false
    @Published var isCompletingMockPayment = false
    @Published var isLaunchingCheckout = false
    @Published var isVerifyingCheckout = false
    @Published var customerProfile: AuthUser?
    @Published var customerTipHistory: [CustomerTipHistoryItem] = []
    @Published var pendingTipDrafts: [PendingTipDraft] = []
    @Published var profileName = ""
    @Published var profileEmail = ""
    @Published var profilePhone = ""
    @Published var profileLanguage = ""
    @Published var isLoadingCustomerProfile = false
    @Published var isLoadingCustomerHistory = false
    @Published var isSavingCustomerProfile = false
    @Published var isLoadingTipImpact = false
    @Published var isSyncingPendingTips = false
    @Published var isScannerPresented = false
    @Published var isResolvingScannedCode = false
    @Published var customerHistoryCurrentPage = 1
    @Published var customerHistoryHasMore = false

    private let client = AuthClient()
    private let customerClient = CustomerClient()
    private let checkoutCoordinator = NativeCheckoutCoordinator()
    private let pendingTipQueueStore = PendingTipQueueStore()
    private let pushCoordinator = NativePushCoordinator.shared
    private var hasLoadedCustomerHomeData = false

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedRole"),
           let role = NativeRole(rawValue: saved) {
            selectedRole = role
        }
        Task { await restoreSession() }
    }

    func restoreSession() async {
        let restored = await client.restoreSession()
        session = restored
        stage = restored == nil ? .rolePicker : .home
        if let restored {
            if restored.user.type == NativeRole.customer.rawValue {
                applyCustomerProfile(restored.user)
            }
            statusMessage = "Session restored for \(restored.user.type)."
            await pushCoordinator.syncTokenIfPossible(session: restored)
        }
        isLoading = false
    }

    func selectRole(_ role: NativeRole) {
        selectedRole = role
        UserDefaults.standard.set(role.rawValue, forKey: "selectedRole")
        credential = ""
        code = ""
        resetCustomerFlow()
        errorMessage = nil
        statusMessage = role.usesEmail
            ? "Business login uses email OTP from the shared backend."
            : "\(role.title) login uses phone OTP from the shared backend."
        stage = .credential
    }

    func sendCode() async {
        guard let selectedRole else { return }
        isLoading = true
        errorMessage = nil

        do {
            let result = try await client.sendCode(role: selectedRole, credential: credential.trimmingCharacters(in: .whitespacesAndNewlines))
            statusMessage = result.message + (result.otp.map { " Use \($0) if dev bypass is enabled." } ?? "")
            stage = .otp
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to contact the backend right now."
        }

        isLoading = false
    }

    func resendCode() async {
        await sendCode()
    }

    func verifyCode() async {
        guard let selectedRole else { return }
        isLoading = true
        errorMessage = nil

        do {
            let verified = try await client.verifyCode(
                role: selectedRole,
                credential: credential.trimmingCharacters(in: .whitespacesAndNewlines),
                code: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            session = verified
            if verified.user.type == NativeRole.customer.rawValue {
                applyCustomerProfile(verified.user)
            }
            statusMessage = "Signed in as \(verified.user.type)."
            stage = .home
            await pushCoordinator.syncTokenIfPossible(session: verified)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to verify the code right now."
        }

        isLoading = false
    }

    func logout() {
        let previousAccessToken = session?.accessToken
        client.logout()
        session = nil
        selectedRole = nil
        UserDefaults.standard.removeObject(forKey: "selectedRole")
        credential = ""
        code = ""
        resetCustomerFlow()
        errorMessage = nil
        statusMessage = "Session cleared on this device."
        stage = .rolePicker
        Task {
            await pushCoordinator.removeTokenIfPossible(accessToken: previousAccessToken)
        }
    }

    func backToRolePicker() {
        errorMessage = nil
        stage = .rolePicker
    }

    func backToCredential() {
        errorMessage = nil
        stage = .credential
    }

    func searchProviders() async {
        let trimmedQuery = providerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            errorMessage = "Search query must be at least 2 characters."
            return
        }

        isSearchingProviders = true
        errorMessage = nil
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil

        do {
            providerResults = try await customerClient.searchProviders(query: trimmedQuery)
            statusMessage = providerResults.isEmpty
                ? "No providers matched that search."
                : "Loaded \(providerResults.count) provider matches."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to search providers right now."
        }

        isSearchingProviders = false
    }

    func loadProvider(_ providerId: String) async {
        isLoadingProvider = true
        errorMessage = nil
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil

        do {
            selectedProvider = try await customerClient.loadProvider(providerId: providerId)
            if let selectedProvider {
                selectedEntryContext = .inApp(
                    providerId: selectedProvider.id,
                    providerName: selectedProvider.displayName,
                    category: selectedProvider.category
                )
            }
            statusMessage = "Loaded \(selectedProvider?.displayName ?? "provider") details for tipping."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load provider details right now."
        }

        isLoadingProvider = false
    }

    func usePresetAmount(_ amount: Int) {
        amountRupees = String(amount)
    }

    func createTip() async {
        guard let session else {
            errorMessage = "Sign in again to continue."
            return
        }

        guard let selectedProvider else {
            errorMessage = "Choose a provider first."
            return
        }

        guard let amount = Int(amountRupees), amount >= 10 else {
            errorMessage = "Minimum tip amount is Rs 10."
            return
        }

        isSubmittingTip = true
        errorMessage = nil
        let trimmedMessage = tipMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let source = selectedEntryContext?.source ?? .inApp
            let order = try await customerClient.createTip(
                accessToken: session.accessToken,
                providerId: selectedProvider.id,
                amountPaise: amount * 100,
                source: source,
                intent: selectedIntent,
                message: trimmedMessage.isEmpty ? nil : trimmedMessage,
                rating: selectedRating
            )
            createdTipOrder = order
            tipStatus = TipStatusSnapshot(tipId: order.tipId, status: "INITIATED", updatedAt: nil)
            tipImpact = nil
            statusMessage = order.isMockOrder
                ? "Mock tip order created for \(selectedProvider.displayName). You can complete dev-bypass verification from this screen."
                : "Tip order created for \(selectedProvider.displayName). Open native Razorpay checkout to continue."
            await refreshCustomerHistorySilently()
        } catch let error as CustomerClientError {
            errorMessage = error.errorDescription ?? "Unable to create the tip order right now."
        } catch {
            let draft = PendingTipDraft(
                id: UUID().uuidString,
                providerId: selectedProvider.id,
                providerName: selectedProvider.displayName,
                providerCategory: selectedProvider.category,
                amountPaise: amount * 100,
                source: selectedEntryContext?.source ?? .inApp,
                intent: selectedIntent,
                message: trimmedMessage.isEmpty ? nil : trimmedMessage,
                rating: selectedRating,
                idempotencyKey: UUID().uuidString,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            pendingTipQueueStore.enqueue(draft, userId: session.user.id)
            pendingTipDrafts = pendingTipQueueStore.load(userId: session.user.id)
            statusMessage = "You appear to be offline. This tip was saved locally and can be synced later without losing its idempotency key."
        }

        isSubmittingTip = false
    }

    func resolveQr() async {
        let trimmedInput = resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Paste a QR URL or QR code ID first."
            return
        }

        isResolvingQr = true
        errorMessage = nil
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil

        do {
            let entry = try await customerClient.resolveQrCode(rawInput: trimmedInput)
            try await loadResolvedEntry(entry)
            statusMessage = "Resolved QR entry for \(selectedProvider?.displayName ?? entry.providerName)."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to resolve that QR code right now."
        }

        isResolvingQr = false
    }

    func resolvePaymentLink() async {
        let trimmedInput = resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Paste a payment link URL or short code first."
            return
        }

        isResolvingPaymentLink = true
        errorMessage = nil
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil

        do {
            let entry = try await customerClient.resolvePaymentLink(rawInput: trimmedInput)
            try await loadResolvedEntry(entry)
            if let suggestedAmountPaise = entry.suggestedAmountPaise {
                amountRupees = String(suggestedAmountPaise / 100)
            }
            statusMessage = "Resolved payment link for \(selectedProvider?.displayName ?? entry.providerName)."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to resolve that payment link right now."
        }

        isResolvingPaymentLink = false
    }

    func openScanner() {
        errorMessage = nil
        isScannerPresented = true
    }

    func dismissScanner() {
        isScannerPresented = false
    }

    func handleScannedCode(_ rawInput: String) async {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "The scanned QR code did not contain a readable value."
            return
        }

        isScannerPresented = false
        isResolvingScannedCode = true
        errorMessage = nil
        resolutionInput = trimmedInput
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil

        do {
            let entry = try await resolveScannedEntry(rawInput: trimmedInput)
            try await loadResolvedEntry(entry)
            if let suggestedAmountPaise = entry.suggestedAmountPaise {
                amountRupees = String(suggestedAmountPaise / 100)
            }
            statusMessage = entry.source == .paymentLink
                ? "Resolved payment link for \(selectedProvider?.displayName ?? entry.providerName)."
                : "Resolved QR entry for \(selectedProvider?.displayName ?? entry.providerName)."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to resolve that scanned code right now."
        }

        isResolvingScannedCode = false
    }

    func refreshTipStatus() async {
        guard let createdTipOrder else {
            errorMessage = "Create a tip order first."
            return
        }

        isRefreshingTipStatus = true
        errorMessage = nil

        do {
            tipStatus = try await customerClient.getTipStatus(tipId: createdTipOrder.tipId)
            if shouldLoadImpact(for: tipStatus?.status) {
                await refreshTipImpact(
                    tipId: createdTipOrder.tipId,
                    showStatusMessage: true,
                    surfaceErrors: false
                )
            } else {
                statusMessage = "Fetched backend status for tip \(createdTipOrder.tipId)."
            }
            await refreshCustomerHistorySilently()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to fetch tip status right now."
        }

        isRefreshingTipStatus = false
    }

    func completeMockPayment() async {
        guard let createdTipOrder, createdTipOrder.isMockOrder else {
            errorMessage = "Mock payment completion is only available for dev-bypass orders."
            return
        }

        isCompletingMockPayment = true
        errorMessage = nil

        do {
            _ = try await customerClient.verifyMockPayment(
                tipId: createdTipOrder.tipId,
                orderId: createdTipOrder.orderId
            )
            tipStatus = try await customerClient.getTipStatus(tipId: createdTipOrder.tipId)
            await refreshTipImpact(
                tipId: createdTipOrder.tipId,
                showStatusMessage: true,
                surfaceErrors: false
            )
            await refreshCustomerHistorySilently()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to complete mock payment verification right now."
        }

        isCompletingMockPayment = false
    }

    func openCheckout() {
        guard let createdTipOrder else {
            errorMessage = "Create a tip order first."
            return
        }

        guard !createdTipOrder.isMockOrder else {
            errorMessage = "Use mock completion for dev-bypass orders."
            return
        }

        guard let selectedProvider else {
            errorMessage = "Provider details are missing."
            return
        }

        guard let session else {
            errorMessage = "Sign in again to continue."
            return
        }

        isLaunchingCheckout = true
        errorMessage = nil

        do {
            try checkoutCoordinator.open(
                order: createdTipOrder,
                providerName: selectedProvider.displayName,
                contact: session.user.phone,
                email: session.user.email,
                onSuccess: { [weak self] result in
                    Task { await self?.handleCheckoutSuccess(result, order: createdTipOrder) }
                },
                onError: { [weak self] message in
                    Task { @MainActor in
                        self?.isLaunchingCheckout = false
                        self?.errorMessage = message
                    }
                }
            )
        } catch {
            isLaunchingCheckout = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to open Razorpay checkout right now."
        }
    }

    func loadCustomerHomeDataIfNeeded() async {
        guard session?.user.type == NativeRole.customer.rawValue else { return }
        guard !hasLoadedCustomerHomeData else { return }

        hasLoadedCustomerHomeData = true
        loadPendingTipDrafts()
        await refreshCustomerProfileSilently()
        await refreshCustomerHistorySilently()
        if !pendingTipDrafts.isEmpty {
            await syncPendingTipDrafts(silent: true)
        }
    }

    func syncPendingTipDrafts() async {
        await syncPendingTipDrafts(silent: false)
    }

    func discardPendingTipDraft(_ draftId: String) {
        guard let session else { return }
        pendingTipQueueStore.remove(draftId: draftId, userId: session.user.id)
        pendingTipDrafts = pendingTipQueueStore.load(userId: session.user.id)
        statusMessage = pendingTipDrafts.isEmpty
            ? "Removed the pending offline tip. The queue is now clear."
            : "Removed the pending offline tip from this device queue."
    }

    func refreshCustomerProfile() async {
        guard let session else {
            errorMessage = "Sign in again to continue."
            return
        }

        isLoadingCustomerProfile = true
        errorMessage = nil

        do {
            let profile = try await customerClient.getCurrentUserProfile(accessToken: session.accessToken)
            applyCustomerProfile(profile)
            statusMessage = "Loaded customer profile from the shared backend."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load the customer profile right now."
        }

        isLoadingCustomerProfile = false
    }

    func refreshCustomerHistory() async {
        guard let session else {
            errorMessage = "Sign in again to continue."
            return
        }

        isLoadingCustomerHistory = true
        errorMessage = nil

        do {
            let response = try await customerClient.getCustomerTipHistory(accessToken: session.accessToken)
            customerTipHistory = response.tips
            customerHistoryCurrentPage = 1
            customerHistoryHasMore = response.tips.count >= response.limit
            statusMessage = response.tips.isEmpty
                ? "Customer history is live, but no tips have been sent yet."
                : "Loaded \(response.tips.count) recent tips from the shared backend."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load tip history right now."
        }

        isLoadingCustomerHistory = false
    }

    func loadMoreCustomerHistory() async {
        guard !isLoadingCustomerHistory, customerHistoryHasMore, let session else { return }
        let nextPage = customerHistoryCurrentPage + 1
        isLoadingCustomerHistory = true
        do {
            let response = try await customerClient.getCustomerTipHistory(
                accessToken: session.accessToken,
                page: nextPage
            )
            customerTipHistory.append(contentsOf: response.tips)
            customerHistoryCurrentPage = nextPage
            customerHistoryHasMore = response.tips.count >= response.limit
        } catch {
            // Non-blocking — existing history stays visible
        }
        isLoadingCustomerHistory = false
    }

    func handleDeepLink(url: URL) async {
        guard stage == .home else { return }
        let path = url.path
        resolutionInput = url.absoluteString
        errorMessage = nil
        if path.contains("/qr/") {
            await resolveQr()
        } else if path.contains("/tip/") || path.contains("/p/") {
            await resolvePaymentLink()
        }
    }

    func refreshTipImpact() async {
        guard let createdTipOrder else {
            errorMessage = "Create and verify a tip order first."
            return
        }

        await refreshTipImpact(
            tipId: createdTipOrder.tipId,
            showStatusMessage: true,
            surfaceErrors: true
        )
    }

    func saveCustomerProfile() async {
        guard let session else {
            errorMessage = "Sign in again to continue."
            return
        }

        let trimmedLanguage = profileLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedLanguage.isEmpty, !supportedLanguageCodes.contains(trimmedLanguage) {
            errorMessage = "Language must be one of: en, hi, ta, te, kn, mr."
            return
        }

        isSavingCustomerProfile = true
        errorMessage = nil

        do {
            let profile = try await customerClient.updateCurrentUserProfile(
                accessToken: session.accessToken,
                name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: profileEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: profilePhone.trimmingCharacters(in: .whitespacesAndNewlines),
                languagePreference: trimmedLanguage.isEmpty ? nil : trimmedLanguage
            )
            applyCustomerProfile(profile)
            statusMessage = "Saved customer profile to the shared backend."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save the customer profile right now."
        }

        isSavingCustomerProfile = false
    }

    private func resetCustomerFlow() {
        providerQuery = ""
        providerResults = []
        selectedProvider = nil
        selectedEntryContext = nil
        resolutionInput = ""
        amountRupees = "100"
        selectedIntent = .kindness
        tipMessage = ""
        selectedRating = 5
        createdTipOrder = nil
        tipStatus = nil
        tipImpact = nil
        isSearchingProviders = false
        isLoadingProvider = false
        isSubmittingTip = false
        isResolvingQr = false
        isResolvingPaymentLink = false
        isRefreshingTipStatus = false
        isCompletingMockPayment = false
        isLaunchingCheckout = false
        isVerifyingCheckout = false
        customerProfile = nil
        customerTipHistory = []
        pendingTipDrafts = []
        profileName = ""
        profileEmail = ""
        profilePhone = ""
        profileLanguage = ""
        isLoadingCustomerProfile = false
        isLoadingCustomerHistory = false
        isSavingCustomerProfile = false
        isLoadingTipImpact = false
        isSyncingPendingTips = false
        isScannerPresented = false
        isResolvingScannedCode = false
        customerHistoryCurrentPage = 1
        customerHistoryHasMore = false
        hasLoadedCustomerHomeData = false
    }

    private func loadResolvedEntry(_ entry: TipEntryContext) async throws {
        selectedEntryContext = entry
        selectedProvider = try await customerClient.loadProvider(providerId: entry.providerId)
    }

    private func handleCheckoutSuccess(_ result: NativeCheckoutSuccess, order: CreatedTipOrder) async {
        isLaunchingCheckout = false
        isVerifyingCheckout = true
        errorMessage = nil

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
            tipStatus = try await customerClient.getTipStatus(tipId: order.tipId)
            await refreshTipImpact(
                tipId: order.tipId,
                showStatusMessage: true,
                surfaceErrors: false
            )
            await refreshCustomerHistorySilently()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Checkout returned, but verification failed on this device."
        }

        isVerifyingCheckout = false
    }

    private func parseCheckoutPayload(
        response: [AnyHashable: Any]?,
        fallbackPaymentId: String
    ) throws -> ParsedCheckoutPayload {
        let orderId = response?["razorpay_order_id"] as? String
        let paymentId = (response?["razorpay_payment_id"] as? String) ?? fallbackPaymentId
        guard !paymentId.isEmpty else {
            throw CustomerClientError.invalidResponse
        }
        guard let signature = response?["razorpay_signature"] as? String, !signature.isEmpty else {
            throw CustomerClientError.invalidResponse
        }
        return ParsedCheckoutPayload(
            orderId: orderId,
            paymentId: paymentId,
            signature: signature
        )
    }

    private func refreshCustomerProfileSilently() async {
        guard let session else { return }
        isLoadingCustomerProfile = true

        do {
            let profile = try await customerClient.getCurrentUserProfile(accessToken: session.accessToken)
            applyCustomerProfile(profile)
        } catch {
            // Keep the signed-in session usable even if profile hydration fails.
        }

        isLoadingCustomerProfile = false
    }

    private func refreshCustomerHistorySilently() async {
        guard let session else { return }
        isLoadingCustomerHistory = true

        do {
            let response = try await customerClient.getCustomerTipHistory(accessToken: session.accessToken)
            customerTipHistory = response.tips
            customerHistoryCurrentPage = 1
            customerHistoryHasMore = response.tips.count >= response.limit
        } catch {
            // History is non-blocking for the rest of the customer flow.
        }

        isLoadingCustomerHistory = false
    }

    private func refreshTipImpact(
        tipId: String,
        showStatusMessage: Bool,
        surfaceErrors: Bool
    ) async {
        isLoadingTipImpact = true
        if surfaceErrors {
            errorMessage = nil
        }

        do {
            let impact = try await customerClient.getTipImpact(tipId: tipId)
            tipImpact = impact
            if showStatusMessage {
                statusMessage = impact.message
            }
        } catch {
            if surfaceErrors {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load payment impact right now."
            }
        }

        isLoadingTipImpact = false
    }

    private func resolveScannedEntry(rawInput: String) async throws -> TipEntryContext {
        if looksLikePaymentLink(rawInput) {
            do {
                return try await customerClient.resolvePaymentLink(rawInput: rawInput)
            } catch {
                return try await customerClient.resolveQrCode(rawInput: rawInput)
            }
        } else {
            do {
                return try await customerClient.resolveQrCode(rawInput: rawInput)
            } catch {
                return try await customerClient.resolvePaymentLink(rawInput: rawInput)
            }
        }
    }

    private func applyCustomerProfile(_ profile: AuthUser) {
        customerProfile = profile
        profileName = profile.name ?? ""
        profileEmail = profile.email ?? ""
        profilePhone = profile.phone ?? ""
        profileLanguage = profile.languagePreference ?? ""

        if let session {
            let updatedSession = AuthSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                user: profile
            )
            self.session = updatedSession
            client.persistSession(updatedSession)
        }
    }

    private func shouldLoadImpact(for status: String?) -> Bool {
        switch status {
        case "PAID", "SETTLED":
            return true
        default:
            return false
        }
    }

    private func looksLikePaymentLink(_ rawInput: String) -> Bool {
        let normalized = rawInput.lowercased()
        return normalized.contains("/tip/") || normalized.contains("payment-link")
    }

    private func loadPendingTipDrafts() {
        guard let session else {
            pendingTipDrafts = []
            return
        }
        pendingTipDrafts = pendingTipQueueStore.load(userId: session.user.id)
    }

    private func syncPendingTipDrafts(silent: Bool) async {
        guard let session else {
            if !silent {
                errorMessage = "Sign in again to continue."
            }
            return
        }

        guard !pendingTipDrafts.isEmpty else {
            if !silent {
                statusMessage = "There are no pending offline tips to sync."
            }
            return
        }

        isSyncingPendingTips = true
        if !silent {
            errorMessage = nil
        }

        var syncedCount = 0
        var latestOrder: CreatedTipOrder?
        var syncError: String?

        for draft in pendingTipDrafts {
            do {
                let order = try await customerClient.createTip(
                    accessToken: session.accessToken,
                    providerId: draft.providerId,
                    amountPaise: draft.amountPaise,
                    source: draft.source,
                    intent: draft.intent,
                    message: draft.message,
                    rating: draft.rating,
                    idempotencyKey: draft.idempotencyKey
                )
                pendingTipQueueStore.remove(draftId: draft.id, userId: session.user.id)
                syncedCount += 1
                latestOrder = order
            } catch let error as CustomerClientError {
                syncError = error.errorDescription ?? "Unable to sync pending tips right now."
                break
            } catch {
                syncError = error.localizedDescription
                break
            }
        }

        pendingTipDrafts = pendingTipQueueStore.load(userId: session.user.id)

        if let latestOrder {
            createdTipOrder = latestOrder
            tipStatus = TipStatusSnapshot(tipId: latestOrder.tipId, status: "INITIATED", updatedAt: nil)
            tipImpact = nil
            await refreshCustomerHistorySilently()
        }

        if syncedCount > 0 {
            statusMessage = pendingTipDrafts.isEmpty
                ? "Synced \(syncedCount) pending offline tip\(syncedCount == 1 ? "" : "s") to the shared backend."
                : "Synced \(syncedCount) pending offline tip\(syncedCount == 1 ? "" : "s"). \(pendingTipDrafts.count) still queued on this device."
        } else if let syncError, !silent {
            errorMessage = syncError
        }

        isSyncingPendingTips = false
    }
}

private struct ParsedCheckoutPayload {
    let orderId: String?
    let paymentId: String
    let signature: String
}
