package com.fliq.android.ui

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fliq.android.data.AuthException
import com.fliq.android.data.AuthRepository
import com.fliq.android.data.AuthSession
import com.fliq.android.data.AuthUser
import com.fliq.android.data.CreatedTipOrder
import com.fliq.android.data.CustomerTipHistoryItem
import com.fliq.android.data.CustomerRepository
import com.fliq.android.data.NativeRole
import com.fliq.android.data.PendingTipDraft
import com.fliq.android.data.PendingTipQueueStore
import com.fliq.android.data.ProviderProfile
import com.fliq.android.data.ProviderSearchResult
import com.fliq.android.data.TipEntryContext
import com.fliq.android.data.TipImpactSnapshot
import com.fliq.android.data.TipIntentOption
import com.fliq.android.data.TipSourceOption
import com.fliq.android.data.TipStatusSnapshot
import com.fliq.android.payments.NativeCheckoutCallbacks
import com.fliq.android.payments.NativeCheckoutError
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.payments.NativeCheckoutRequest
import com.fliq.android.payments.NativeCheckoutSuccess
import com.fliq.android.push.NativePushManager
import com.fliq.android.scanning.NativeQrScannerCallbacks
import com.fliq.android.scanning.NativeQrScannerError
import com.fliq.android.scanning.NativeQrScannerLauncher
import com.fliq.android.scanning.NativeQrScannerResult
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.IOException
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/**
 * Central ViewModel for the Fliq Android app.
 * Extracted from the monolithic FliqAndroidApp composable to enable proper
 * state management with Jetpack Navigation Compose.
 */
class FliqViewModel(
    private val appContext: Context,
) : ViewModel() {

    private val authRepository = AuthRepository(appContext)
    private val customerRepository = CustomerRepository()
    private val pendingTipQueueStore = PendingTipQueueStore(appContext)
    val pushManager = NativePushManager(appContext)

    // ── Auth state ──────────────────────────────────────────────────────
    var stage by mutableStateOf(AuthStage.ROLE_PICKER)
        private set
    var selectedRole by mutableStateOf<NativeRole?>(null)
        private set
    var credential by mutableStateOf("")
    var code by mutableStateOf("")
    var session by mutableStateOf<AuthSession?>(null)
        private set

    // ── Status / error ──────────────────────────────────────────────────
    var statusMessage by mutableStateOf("Native Android foundation is live.")
    var errorMessage by mutableStateOf<String?>(null)
    var isLoading by mutableStateOf(true)
        private set

    // ── Customer tip flow ───────────────────────────────────────────────
    var providerQuery by mutableStateOf("")
    var providerResults by mutableStateOf(emptyList<ProviderSearchResult>())
        private set
    var selectedProvider by mutableStateOf<ProviderProfile?>(null)
        private set
    var selectedEntryContext by mutableStateOf<TipEntryContext?>(null)
        private set
    var resolutionInput by mutableStateOf("")
    var amountRupees by mutableStateOf("100")
    var selectedIntent by mutableStateOf(TipIntentOption.KINDNESS)
    var tipMessage by mutableStateOf("")
    var selectedRating by mutableStateOf(5)
    var createdTipOrder by mutableStateOf<CreatedTipOrder?>(null)
        private set
    var tipStatus by mutableStateOf<TipStatusSnapshot?>(null)
        private set
    var tipImpact by mutableStateOf<TipImpactSnapshot?>(null)
        private set

    // ── Customer profile ────────────────────────────────────────────────
    var currentUserProfile by mutableStateOf<AuthUser?>(null)
        private set
    var customerHistory by mutableStateOf(emptyList<CustomerTipHistoryItem>())
        private set
    var pendingTipDrafts by mutableStateOf(emptyList<PendingTipDraft>())
        private set
    var profileName by mutableStateOf("")
    var profileEmail by mutableStateOf("")
    var profilePhone by mutableStateOf("")
    var profileLanguage by mutableStateOf("")

    // ── Loading flags ───────────────────────────────────────────────────
    var isSearchingProviders by mutableStateOf(false); private set
    var isLoadingProvider by mutableStateOf(false); private set
    var isSubmittingTip by mutableStateOf(false); private set
    var isResolvingQr by mutableStateOf(false); private set
    var isResolvingPaymentLink by mutableStateOf(false); private set
    var isRefreshingTipStatus by mutableStateOf(false); private set
    var isCompletingMockPayment by mutableStateOf(false); private set
    var isLaunchingCheckout by mutableStateOf(false); private set
    var isVerifyingCheckout by mutableStateOf(false); private set
    var isLoadingCustomerProfile by mutableStateOf(false); private set
    var isLoadingCustomerHistory by mutableStateOf(false); private set
    var isSavingCustomerProfile by mutableStateOf(false); private set
    var isLoadingTipImpact by mutableStateOf(false); private set
    var isSyncingPendingTips by mutableStateOf(false); private set
    var isLaunchingScanner by mutableStateOf(false); private set
    var hasLoadedCustomerHomeData by mutableStateOf(false); private set
    var hasRequestedNotificationPermission by mutableStateOf(false)

    // ── Auth actions ────────────────────────────────────────────────────

    fun restoreSession() {
        viewModelScope.launch {
            val restored = authRepository.restoreSession()
            session = restored
            stage = if (restored != null) AuthStage.HOME else AuthStage.ROLE_PICKER
            if (restored != null) {
                if (restored.user.type == NativeRole.CUSTOMER.name) {
                    applyCustomerProfile(restored.user)
                }
                statusMessage = "Session restored for ${restored.user.type}."
            }
            isLoading = false
        }
    }

    fun selectRole(role: NativeRole) {
        selectedRole = role
        credential = ""
        code = ""
        resetCustomerFlow()
        errorMessage = null
        statusMessage = if (role == NativeRole.BUSINESS) {
            "Business login uses email OTP from the shared backend."
        } else {
            "${role.name.lowercase().replaceFirstChar(Char::uppercase)} login uses phone OTP from the shared backend."
        }
        stage = AuthStage.CREDENTIAL
    }

    fun backToRolePicker() {
        errorMessage = null
        stage = AuthStage.ROLE_PICKER
    }

    fun backToCredential() {
        errorMessage = null
        stage = AuthStage.CREDENTIAL
    }

    fun sendCode() {
        val role = selectedRole ?: return
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                val result = authRepository.sendCode(role, credential.trim())
                statusMessage = buildString {
                    append(result.message)
                    result.otpHint?.let { append(" Use $it if dev bypass is enabled.") }
                }
                stage = AuthStage.OTP
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to contact the backend right now."
            } finally {
                isLoading = false
            }
        }
    }

    fun resendCode() {
        val role = selectedRole ?: return
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                val result = authRepository.sendCode(role, credential.trim())
                statusMessage = result.message
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to resend the code right now."
            } finally {
                isLoading = false
            }
        }
    }

    fun verifyCode() {
        val role = selectedRole ?: return
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                val verified = authRepository.verifyCode(role, credential.trim(), code.trim())
                session = verified
                if (verified.user.type == NativeRole.CUSTOMER.name) {
                    applyCustomerProfile(verified.user)
                }
                statusMessage = "Signed in as ${verified.user.type}."
                stage = AuthStage.HOME
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to verify the code right now."
            } finally {
                isLoading = false
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            val previousAccessToken = session?.accessToken
            runCatching { pushManager.removeTokenIfPossible(previousAccessToken) }
            authRepository.logout()
            session = null
            selectedRole = null
            credential = ""
            code = ""
            resetCustomerFlow()
            hasRequestedNotificationPermission = false
            errorMessage = null
            statusMessage = "Session cleared on this device."
            stage = AuthStage.ROLE_PICKER
        }
    }

    fun syncPushTokenIfPossible() {
        viewModelScope.launch {
            session?.let { activeSession ->
                runCatching { pushManager.syncTokenIfPossible(activeSession) }
            }
        }
    }

    // ── Customer flow helpers ───────────────────────────────────────────

    fun homeRole(activeSession: AuthSession): NativeRole {
        return when {
            activeSession.user.type.startsWith("BUSINESS") -> NativeRole.BUSINESS
            activeSession.user.type == NativeRole.PROVIDER.name -> NativeRole.PROVIDER
            activeSession.user.type == NativeRole.CUSTOMER.name && selectedRole == NativeRole.PROVIDER -> NativeRole.PROVIDER
            else -> NativeRole.CUSTOMER
        }
    }

    private fun applyCustomerProfile(profile: AuthUser) {
        currentUserProfile = profile
        profileName = profile.name.orEmpty()
        profileEmail = profile.email.orEmpty()
        profilePhone = profile.phone.orEmpty()
        profileLanguage = profile.languagePreference.orEmpty()

        session?.let { activeSession ->
            val updatedSession = activeSession.copy(user = profile)
            session = updatedSession
            authRepository.persistSession(updatedSession)
        }
    }

    private fun resetCustomerFlow() {
        providerQuery = ""
        providerResults = emptyList()
        selectedProvider = null
        selectedEntryContext = null
        resolutionInput = ""
        amountRupees = "100"
        selectedIntent = TipIntentOption.KINDNESS
        tipMessage = ""
        selectedRating = 5
        createdTipOrder = null
        tipStatus = null
        currentUserProfile = null
        customerHistory = emptyList()
        pendingTipDrafts = emptyList()
        tipImpact = null
        profileName = ""
        profileEmail = ""
        profilePhone = ""
        profileLanguage = ""
        isSearchingProviders = false
        isLoadingProvider = false
        isSubmittingTip = false
        isResolvingQr = false
        isResolvingPaymentLink = false
        isRefreshingTipStatus = false
        isCompletingMockPayment = false
        isLaunchingCheckout = false
        isVerifyingCheckout = false
        isLoadingCustomerProfile = false
        isLoadingCustomerHistory = false
        isSavingCustomerProfile = false
        isLoadingTipImpact = false
        isSyncingPendingTips = false
        isLaunchingScanner = false
        hasLoadedCustomerHomeData = false
    }

    fun loadCustomerHomeDataIfNeeded() {
        session?.let { activeSession ->
            if (stage == AuthStage.HOME && homeRole(activeSession) == NativeRole.CUSTOMER && !hasLoadedCustomerHomeData) {
                hasLoadedCustomerHomeData = true
                viewModelScope.launch {
                    loadPendingTipDrafts(activeSession.user.id)
                    refreshCustomerProfile(activeSession, false, false)
                    refreshCustomerHistory(activeSession, false, false)
                    if (pendingTipDrafts.isNotEmpty()) {
                        syncPendingTipDrafts(activeSession, false, false)
                    }
                }
            }
        }
    }

    // ── Customer API actions ────────────────────────────────────────────

    fun searchProviders() {
        if (providerQuery.trim().length < 2) {
            errorMessage = "Search query must be at least 2 characters."
            return
        }
        viewModelScope.launch {
            isSearchingProviders = true
            errorMessage = null
            createdTipOrder = null
            tipStatus = null
            tipImpact = null
            try {
                providerResults = customerRepository.searchProviders(providerQuery.trim())
                statusMessage = if (providerResults.isEmpty()) "No providers matched that search." else "Loaded ${providerResults.size} provider matches."
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to search providers right now."
            } finally {
                isSearchingProviders = false
            }
        }
    }

    fun selectProvider(providerId: String) {
        viewModelScope.launch {
            isLoadingProvider = true
            errorMessage = null
            createdTipOrder = null
            tipStatus = null
            tipImpact = null
            try {
                selectedProvider = customerRepository.getPublicProfile(providerId)
                selectedEntryContext = selectedProvider?.let {
                    TipEntryContext.inApp(providerId = it.id, providerName = it.displayName, category = it.category)
                }
                statusMessage = "Loaded ${selectedProvider?.displayName ?: "provider"} details for tipping."
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to load provider details right now."
            } finally {
                isLoadingProvider = false
            }
        }
    }

    fun resolveQr() {
        if (resolutionInput.trim().isBlank()) {
            errorMessage = "Paste a QR URL or QR code ID first."
            return
        }
        viewModelScope.launch {
            isResolvingQr = true
            errorMessage = null
            createdTipOrder = null; tipStatus = null; tipImpact = null
            try {
                val entry = customerRepository.resolveQrCode(resolutionInput.trim())
                applyResolvedEntry(entry)
                statusMessage = "Resolved QR entry for ${selectedProvider?.displayName ?: entry.providerName}."
            } catch (error: AuthException) { errorMessage = error.message
            } catch (_: Exception) { errorMessage = "Unable to resolve that QR code right now."
            } finally { isResolvingQr = false }
        }
    }

    fun resolvePaymentLink() {
        if (resolutionInput.trim().isBlank()) {
            errorMessage = "Paste a payment link URL or short code first."
            return
        }
        viewModelScope.launch {
            isResolvingPaymentLink = true
            errorMessage = null
            createdTipOrder = null; tipStatus = null; tipImpact = null
            try {
                val entry = customerRepository.resolvePaymentLink(resolutionInput.trim())
                applyResolvedEntry(entry)
                statusMessage = "Resolved payment link for ${selectedProvider?.displayName ?: entry.providerName}."
            } catch (error: AuthException) { errorMessage = error.message
            } catch (_: Exception) { errorMessage = "Unable to resolve that payment link right now."
            } finally { isResolvingPaymentLink = false }
        }
    }

    fun createTip() {
        val activeSession = session
        val provider = selectedProvider
        val amount = amountRupees.toIntOrNull()
        val source = selectedEntryContext?.source

        when {
            activeSession == null -> { errorMessage = "Sign in again to continue."; return }
            provider == null -> { errorMessage = "Choose a provider first."; return }
            amount == null -> { errorMessage = "Enter a valid amount in rupees."; return }
            amount < 10 -> { errorMessage = "Minimum tip amount is Rs 10."; return }
        }

        viewModelScope.launch {
            isSubmittingTip = true
            errorMessage = null
            val trimmedMessage = tipMessage.trim().takeIf { it.isNotBlank() }
            try {
                createdTipOrder = customerRepository.createAuthenticatedTip(
                    accessToken = activeSession!!.accessToken,
                    providerId = provider!!.id,
                    amountPaise = amount!! * 100,
                    source = source ?: TipEntryContext.inApp(
                        providerId = provider.id, providerName = provider.displayName, category = provider.category,
                    ).source,
                    intent = selectedIntent,
                    message = trimmedMessage,
                    rating = selectedRating,
                )
                tipStatus = createdTipOrder?.let { TipStatusSnapshot(tipId = it.tipId, status = "INITIATED", updatedAt = null) }
                tipImpact = null
                statusMessage = if (createdTipOrder?.isMockOrder == true) {
                    "Mock tip order created for ${provider.displayName}."
                } else {
                    "Tip order created for ${provider.displayName}. Open native Razorpay checkout to continue."
                }
                refreshCustomerHistory(activeSession, false, false)
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (error: IOException) {
                val draft = PendingTipDraft(
                    id = UUID.randomUUID().toString(),
                    providerId = provider!!.id,
                    providerName = provider.displayName,
                    providerCategory = provider.category,
                    amountPaise = amount!! * 100,
                    source = source ?: TipEntryContext.inApp(
                        providerId = provider.id, providerName = provider.displayName, category = provider.category,
                    ).source,
                    intent = selectedIntent,
                    message = trimmedMessage,
                    rating = selectedRating,
                    idempotencyKey = UUID.randomUUID().toString(),
                    createdAt = Instant.now().toString(),
                )
                pendingTipQueueStore.enqueue(activeSession!!.user.id, draft)
                loadPendingTipDrafts(activeSession.user.id)
                statusMessage = "You appear to be offline. This tip was saved locally."
            } catch (_: Exception) {
                errorMessage = "Unable to create the tip order right now."
            } finally {
                isSubmittingTip = false
            }
        }
    }

    fun refreshTipStatus() {
        val tipId = createdTipOrder?.tipId
        if (tipId.isNullOrBlank()) { errorMessage = "Create a tip order first."; return }
        viewModelScope.launch {
            isRefreshingTipStatus = true
            errorMessage = null
            try {
                tipStatus = customerRepository.getTipStatus(tipId)
                if (shouldLoadImpact(tipStatus?.status)) {
                    refreshTipImpact(tipId, true, false)
                } else {
                    statusMessage = "Fetched backend status for tip $tipId."
                }
                session?.let { refreshCustomerHistory(it, false, false) }
            } catch (error: AuthException) { errorMessage = error.message
            } catch (_: Exception) { errorMessage = "Unable to fetch tip status right now."
            } finally { isRefreshingTipStatus = false }
        }
    }

    fun completeMockPayment() {
        val order = createdTipOrder
        if (order == null || !order.isMockOrder) { errorMessage = "Mock payment is only available for dev-bypass orders."; return }
        viewModelScope.launch {
            isCompletingMockPayment = true
            errorMessage = null
            try {
                customerRepository.verifyMockPayment(tipId = order.tipId, orderId = order.orderId)
                tipStatus = customerRepository.getTipStatus(order.tipId)
                refreshTipImpact(order.tipId, true, false)
                session?.let { refreshCustomerHistory(it, false, false) }
            } catch (error: AuthException) { errorMessage = error.message
            } catch (_: Exception) { errorMessage = "Unable to complete mock payment verification right now."
            } finally { isCompletingMockPayment = false }
        }
    }

    fun openCheckout(launcher: NativeCheckoutLauncher?) {
        val order = createdTipOrder
        val provider = selectedProvider
        val activeSession = session

        when {
            order == null -> { errorMessage = "Create a tip order first."; return }
            order.isMockOrder -> { errorMessage = "Use mock completion for dev-bypass orders."; return }
            launcher == null -> { errorMessage = "Native checkout is not available in this host."; return }
            provider == null -> { errorMessage = "Provider details are missing."; return }
            activeSession == null -> { errorMessage = "Sign in again to continue."; return }
            order.razorpayKeyId.isBlank() -> { errorMessage = "Razorpay key is missing from the backend response."; return }
        }

        errorMessage = null
        isLaunchingCheckout = true

        val opened = launcher!!.launchCheckout(
            request = NativeCheckoutRequest(
                keyId = order!!.razorpayKeyId,
                orderId = order.orderId,
                amountPaise = order.amountPaise,
                currency = order.currency,
                title = "Fliq",
                description = "Tip for ${provider!!.displayName}",
                contact = activeSession!!.user.phone,
                email = activeSession.user.email,
            ),
            callbacks = NativeCheckoutCallbacks(
                onSuccess = { result ->
                    viewModelScope.launch {
                        isLaunchingCheckout = false
                        isVerifyingCheckout = true
                        errorMessage = null
                        try {
                            val payload = parseCheckoutPayload(result.responseJson, result.paymentId)
                            customerRepository.verifyPayment(
                                tipId = order.tipId,
                                orderId = payload.orderId ?: order.orderId,
                                paymentId = payload.paymentId,
                                signature = payload.signature,
                            )
                            tipStatus = customerRepository.getTipStatus(order.tipId)
                            refreshTipImpact(order.tipId, true, false)
                            session?.let { refreshCustomerHistory(it, false, false) }
                        } catch (error: AuthException) { errorMessage = error.message
                        } catch (_: Exception) { errorMessage = "Checkout returned, but verification failed on this device."
                        } finally { isVerifyingCheckout = false }
                    }
                },
                onError = { result ->
                    isLaunchingCheckout = false
                    errorMessage = "Checkout failed (${result.code}): ${result.description ?: "Unknown error"}"
                },
                onExternalWallet = { walletName, _ ->
                    isLaunchingCheckout = false
                    statusMessage = "External wallet selected${walletName?.let { ": $it" } ?: ""}."
                },
            ),
        )
        if (!opened) isLaunchingCheckout = false
    }

    fun scanQr(launcher: NativeQrScannerLauncher?) {
        if (launcher == null) { errorMessage = "Native QR scanning is not available in this host."; return }
        errorMessage = null
        isLaunchingScanner = true
        val started = launcher.launchQrScanner(
            callbacks = NativeQrScannerCallbacks(
                onSuccess = { result ->
                    viewModelScope.launch {
                        try { resolveScannedCode(result.rawValue)
                        } catch (error: AuthException) { errorMessage = error.message
                        } catch (_: Exception) { errorMessage = "Unable to resolve that scanned code right now."
                        } finally { isLaunchingScanner = false }
                    }
                },
                onCancelled = { isLaunchingScanner = false; statusMessage = "QR scan cancelled." },
                onError = { result -> isLaunchingScanner = false; errorMessage = result.message },
            ),
        )
        if (!started) isLaunchingScanner = false
    }

    fun refreshCustomerProfile() {
        val activeSession = session ?: run { errorMessage = "Sign in again to continue."; return }
        viewModelScope.launch { refreshCustomerProfile(activeSession, true, true) }
    }

    fun refreshCustomerHistory() {
        val activeSession = session ?: run { errorMessage = "Sign in again to continue."; return }
        viewModelScope.launch { refreshCustomerHistory(activeSession, true, true) }
    }

    fun refreshTipImpact() {
        val order = createdTipOrder ?: run { errorMessage = "Create and verify a tip order first."; return }
        viewModelScope.launch { refreshTipImpact(order.tipId, true, true) }
    }

    fun syncPendingTips() {
        val activeSession = session ?: run { errorMessage = "Sign in again to continue."; return }
        viewModelScope.launch { syncPendingTipDrafts(activeSession, true, true) }
    }

    fun discardPendingTip(draftId: String) {
        val activeSession = session ?: run { errorMessage = "Sign in again to continue."; return }
        pendingTipQueueStore.remove(activeSession.user.id, draftId)
        loadPendingTipDrafts(activeSession.user.id)
        statusMessage = if (pendingTipDrafts.isEmpty()) "Removed the pending offline tip. The queue is now clear." else "Removed the pending offline tip from this device queue."
    }

    fun saveCustomerProfile() {
        val activeSession = session ?: run { errorMessage = "Sign in again to continue."; return }
        val normalizedLanguage = profileLanguage.trim().lowercase()
        if (normalizedLanguage.isNotBlank() && normalizedLanguage !in supportedLanguageCodes) {
            errorMessage = "Language must be one of: en, hi, ta, te, kn, mr."
            return
        }
        viewModelScope.launch {
            isSavingCustomerProfile = true
            errorMessage = null
            try {
                val updatedProfile = customerRepository.updateCurrentUserProfile(
                    accessToken = activeSession.accessToken,
                    name = profileName.trim(),
                    email = profileEmail.trim(),
                    phone = profilePhone.trim(),
                    languagePreference = normalizedLanguage.ifBlank { null },
                )
                applyCustomerProfile(updatedProfile)
                statusMessage = "Saved customer profile to the shared backend."
            } catch (error: AuthException) { errorMessage = error.message
            } catch (_: Exception) { errorMessage = "Unable to save the customer profile right now."
            } finally { isSavingCustomerProfile = false }
        }
    }

    fun usePresetAmount(amount: Int) { amountRupees = amount.toString() }

    // ── Internal helpers ────────────────────────────────────────────────

    private suspend fun applyResolvedEntry(entry: TipEntryContext) {
        selectedEntryContext = entry
        selectedProvider = customerRepository.getPublicProfile(entry.providerId)
        entry.suggestedAmountPaise?.let { amountRupees = (it / 100).toString() }
    }

    private suspend fun resolveScannedCode(rawInput: String) {
        val trimmedInput = rawInput.trim()
        resolutionInput = trimmedInput
        createdTipOrder = null; tipStatus = null; tipImpact = null; errorMessage = null

        val preferPaymentLink = looksLikePaymentLink(trimmedInput)
        val primaryResolution = runCatching {
            if (preferPaymentLink) customerRepository.resolvePaymentLink(trimmedInput)
            else customerRepository.resolveQrCode(trimmedInput)
        }
        val entry = if (primaryResolution.isSuccess) {
            primaryResolution.getOrThrow()
        } else {
            val fallbackResolution = runCatching {
                if (preferPaymentLink) customerRepository.resolveQrCode(trimmedInput)
                else customerRepository.resolvePaymentLink(trimmedInput)
            }
            if (fallbackResolution.isSuccess) fallbackResolution.getOrThrow()
            else throw (fallbackResolution.exceptionOrNull() ?: primaryResolution.exceptionOrNull()!!)
        }
        applyResolvedEntry(entry)
        statusMessage = when (entry.source) {
            TipSourceOption.PAYMENT_LINK -> "Resolved payment link for ${selectedProvider?.displayName ?: entry.providerName}."
            TipSourceOption.QR_CODE -> "Resolved QR entry for ${selectedProvider?.displayName ?: entry.providerName}."
            TipSourceOption.IN_APP -> "Loaded ${selectedProvider?.displayName ?: entry.providerName} details for tipping."
        }
    }

    private fun loadPendingTipDrafts(userId: String) {
        pendingTipDrafts = pendingTipQueueStore.loadDrafts(userId)
    }

    private suspend fun syncPendingTipDrafts(activeSession: AuthSession, showStatusMessage: Boolean, surfaceErrors: Boolean) {
        loadPendingTipDrafts(activeSession.user.id)
        if (pendingTipDrafts.isEmpty()) {
            if (showStatusMessage) statusMessage = "There are no pending offline tips to sync."
            return
        }
        isSyncingPendingTips = true
        if (surfaceErrors) errorMessage = null

        var syncedCount = 0
        var latestOrder: CreatedTipOrder? = null
        var syncError: String? = null

        for (draft in pendingTipDrafts) {
            try {
                val order = customerRepository.createAuthenticatedTip(
                    accessToken = activeSession.accessToken,
                    providerId = draft.providerId,
                    amountPaise = draft.amountPaise,
                    source = draft.source,
                    intent = draft.intent,
                    message = draft.message,
                    rating = draft.rating,
                    idempotencyKey = draft.idempotencyKey,
                )
                pendingTipQueueStore.remove(activeSession.user.id, draft.id)
                syncedCount += 1
                latestOrder = order
            } catch (error: AuthException) { syncError = error.message; break
            } catch (error: IOException) { syncError = error.localizedMessage ?: "Unable to reach the backend right now."; break
            } catch (_: Exception) { syncError = "Unable to sync pending tips right now."; break }
        }

        loadPendingTipDrafts(activeSession.user.id)
        latestOrder?.let { order ->
            createdTipOrder = order
            tipStatus = TipStatusSnapshot(tipId = order.tipId, status = "INITIATED", updatedAt = null)
            tipImpact = null
            runCatching { customerHistory = customerRepository.getCustomerTipHistory(activeSession.accessToken).tips }
        }

        if (syncedCount > 0 && showStatusMessage) {
            statusMessage = if (pendingTipDrafts.isEmpty()) {
                "Synced $syncedCount pending offline tip${if (syncedCount == 1) "" else "s"} to the shared backend."
            } else {
                "Synced $syncedCount pending offline tip${if (syncedCount == 1) "" else "s"}. ${pendingTipDrafts.size} still queued on this device."
            }
        } else if (surfaceErrors && syncError != null) {
            errorMessage = syncError
        }
        isSyncingPendingTips = false
    }

    private suspend fun refreshCustomerProfile(activeSession: AuthSession, showStatusMessage: Boolean, surfaceErrors: Boolean) {
        isLoadingCustomerProfile = true
        if (surfaceErrors) errorMessage = null
        try {
            val profile = customerRepository.getCurrentUserProfile(activeSession.accessToken)
            applyCustomerProfile(profile)
            if (showStatusMessage) statusMessage = "Loaded customer profile from the shared backend."
        } catch (error: AuthException) { if (surfaceErrors) errorMessage = error.message
        } catch (_: Exception) { if (surfaceErrors) errorMessage = "Unable to load the customer profile right now."
        } finally { isLoadingCustomerProfile = false }
    }

    private suspend fun refreshCustomerHistory(activeSession: AuthSession, showStatusMessage: Boolean, surfaceErrors: Boolean) {
        isLoadingCustomerHistory = true
        if (surfaceErrors) errorMessage = null
        try {
            val historyPage = customerRepository.getCustomerTipHistory(activeSession.accessToken)
            customerHistory = historyPage.tips
            if (showStatusMessage) {
                statusMessage = if (historyPage.tips.isEmpty()) "Customer history is live, but no tips have been sent yet."
                else "Loaded ${historyPage.tips.size} recent tips from the shared backend."
            }
        } catch (error: AuthException) { if (surfaceErrors) errorMessage = error.message
        } catch (_: Exception) { if (surfaceErrors) errorMessage = "Unable to load tip history right now."
        } finally { isLoadingCustomerHistory = false }
    }

    private suspend fun refreshTipImpact(tipId: String, showStatusMessage: Boolean, surfaceErrors: Boolean) {
        isLoadingTipImpact = true
        if (surfaceErrors) errorMessage = null
        try {
            val impact = customerRepository.getTipImpact(tipId)
            tipImpact = impact
            if (showStatusMessage) statusMessage = impact.message
        } catch (error: AuthException) { if (surfaceErrors) errorMessage = error.message
        } catch (_: Exception) { if (surfaceErrors) errorMessage = "Unable to load payment impact right now."
        } finally { isLoadingTipImpact = false }
    }

    companion object {
        private val supportedLanguageCodes = setOf("en", "hi", "ta", "te", "kn", "mr")

        fun looksLikePaymentLink(rawValue: String): Boolean {
            val normalized = rawValue.lowercase(Locale.US)
            return normalized.contains("/tip/") || normalized.contains("payment-link")
        }

        fun shouldLoadImpact(status: String?): Boolean = status == "PAID" || status == "SETTLED"

        fun formatScore(value: Double): String = if (value == 0.0) "0.0" else String.format("%.1f", value)
        fun formatTipAmount(amountPaise: Int): String = "Rs ${amountPaise / 100}"

        fun formatIntentLabel(intent: String?): String? = when (intent) {
            "KINDNESS" -> "Kindness"; "SPEED" -> "Speed"; "EXPERIENCE" -> "Experience"; "SUPPORT" -> "Support"
            null -> null; else -> intent
        }

        fun formatHistoryDate(value: String?): String? {
            if (value.isNullOrBlank()) return null
            val formatter = DateTimeFormatter.ofPattern("d MMM yyyy, h:mm a", Locale.US)
            return runCatching {
                OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.systemDefault()).format(formatter)
            }.recoverCatching {
                Instant.parse(value).atZone(ZoneId.systemDefault()).format(formatter)
            }.getOrElse { value }
        }

        fun parseCheckoutPayload(responseJson: String?, fallbackPaymentId: String?): ParsedCheckoutPayload {
            val json = responseJson?.takeIf { it.isNotBlank() }?.let(::JSONObject) ?: JSONObject()
            val paymentId = json.optString("razorpay_payment_id").takeIf { it.isNotBlank() }
                ?: fallbackPaymentId?.takeIf { it.isNotBlank() }
                ?: error("Missing payment id from Razorpay callback.")
            val signature = json.optString("razorpay_signature").takeIf { it.isNotBlank() }
                ?: error("Missing payment signature from Razorpay callback.")
            val orderId = json.optString("razorpay_order_id").takeIf { it.isNotBlank() }
            return ParsedCheckoutPayload(orderId = orderId, paymentId = paymentId, signature = signature)
        }
    }
}

enum class AuthStage { ROLE_PICKER, CREDENTIAL, OTP, HOME }

data class ParsedCheckoutPayload(val orderId: String?, val paymentId: String, val signature: String)
