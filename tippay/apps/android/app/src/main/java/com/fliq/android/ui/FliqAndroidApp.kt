package com.fliq.android.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
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
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.payments.NativeCheckoutRequest
import com.fliq.android.push.NativePushManager
import com.fliq.android.scanning.NativeQrScannerCallbacks
import com.fliq.android.scanning.NativeQrScannerLauncher
import java.io.IOException
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.launch
import org.json.JSONObject

private enum class AuthStage {
    ROLE_PICKER,
    CREDENTIAL,
    OTP,
    HOME,
}

private data class RoleCard(
    val role: NativeRole,
    val title: String,
    val subtitle: String,
    val accent: Color,
    val actionLabel: String,
)

private val supportedLanguageCodes = setOf("en", "hi", "ta", "te", "kn", "mr")

private fun requiresNotificationPermission(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return false
    }
    return ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.POST_NOTIFICATIONS,
    ) != PackageManager.PERMISSION_GRANTED
}

@Composable
fun FliqAndroidApp() {
    val context = LocalContext.current
    val repository = remember(context) { AuthRepository(context) }
    val customerRepository = remember { CustomerRepository() }
    val pendingTipQueueStore = remember(context) { PendingTipQueueStore(context) }
    val pushManager = remember(context) { NativePushManager(context.applicationContext) }
    val checkoutLauncher = remember(context) { context as? NativeCheckoutLauncher }
    val scannerLauncher = remember(context) { context as? NativeQrScannerLauncher }
    val coroutineScope = rememberCoroutineScope()

    val roles = remember {
        listOf(
            RoleCard(
                role = NativeRole.CUSTOMER,
                title = "Customer",
                subtitle = "Scan QR codes, tip instantly, and manage history.",
                accent = Color(0xFF2267F2),
                actionLabel = "Continue as customer",
            ),
            RoleCard(
                role = NativeRole.PROVIDER,
                title = "Provider",
                subtitle = "Receive tips, manage QR links, and track payouts.",
                accent = Color(0xFF159570),
                actionLabel = "Continue as provider",
            ),
            RoleCard(
                role = NativeRole.BUSINESS,
                title = "Business",
                subtitle = "Manage staff, invitations, satisfaction, and QR exports.",
                accent = Color(0xFFF08A24),
                actionLabel = "Continue as business",
            ),
        )
    }

    var stage by remember { mutableStateOf(AuthStage.ROLE_PICKER) }
    var selectedRole by remember { mutableStateOf<NativeRole?>(null) }
    var credential by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var session by remember { mutableStateOf<AuthSession?>(null) }
    var statusMessage by remember {
        mutableStateOf("Native Android foundation is live. OTP auth and session restore are now wired into this app shell.")
    }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var providerQuery by remember { mutableStateOf("") }
    var providerResults by remember { mutableStateOf(emptyList<ProviderSearchResult>()) }
    var selectedProvider by remember { mutableStateOf<ProviderProfile?>(null) }
    var selectedEntryContext by remember { mutableStateOf<TipEntryContext?>(null) }
    var resolutionInput by remember { mutableStateOf("") }
    var amountRupees by remember { mutableStateOf("100") }
    var selectedIntent by remember { mutableStateOf(TipIntentOption.KINDNESS) }
    var tipMessage by remember { mutableStateOf("") }
    var selectedRating by remember { mutableStateOf(5) }
    var createdTipOrder by remember { mutableStateOf<CreatedTipOrder?>(null) }
    var tipStatus by remember { mutableStateOf<TipStatusSnapshot?>(null) }
    var tipImpact by remember { mutableStateOf<TipImpactSnapshot?>(null) }
    var currentUserProfile by remember { mutableStateOf<AuthUser?>(null) }
    var customerHistory by remember { mutableStateOf(emptyList<CustomerTipHistoryItem>()) }
    var pendingTipDrafts by remember { mutableStateOf(emptyList<PendingTipDraft>()) }
    var profileName by remember { mutableStateOf("") }
    var profileEmail by remember { mutableStateOf("") }
    var profilePhone by remember { mutableStateOf("") }
    var profileLanguage by remember { mutableStateOf("") }
    var isSearchingProviders by remember { mutableStateOf(false) }
    var isLoadingProvider by remember { mutableStateOf(false) }
    var isSubmittingTip by remember { mutableStateOf(false) }
    var isResolvingQr by remember { mutableStateOf(false) }
    var isResolvingPaymentLink by remember { mutableStateOf(false) }
    var isRefreshingTipStatus by remember { mutableStateOf(false) }
    var isCompletingMockPayment by remember { mutableStateOf(false) }
    var isLaunchingCheckout by remember { mutableStateOf(false) }
    var isVerifyingCheckout by remember { mutableStateOf(false) }
    var isLoadingCustomerProfile by remember { mutableStateOf(false) }
    var isLoadingCustomerHistory by remember { mutableStateOf(false) }
    var isSavingCustomerProfile by remember { mutableStateOf(false) }
    var isLoadingTipImpact by remember { mutableStateOf(false) }
    var isSyncingPendingTips by remember { mutableStateOf(false) }
    var isLaunchingScanner by remember { mutableStateOf(false) }
    var hasLoadedCustomerHomeData by remember { mutableStateOf(false) }
    var hasRequestedNotificationPermission by remember { mutableStateOf(false) }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (!granted) {
            statusMessage = "Notifications stay off until Android notification permission is granted."
            return@rememberLauncherForActivityResult
        }

        val activeSession = session ?: return@rememberLauncherForActivityResult
        coroutineScope.launch {
            runCatching { pushManager.syncTokenIfPossible(activeSession) }
        }
    }

    fun applyCustomerProfile(profile: AuthUser) {
        currentUserProfile = profile
        profileName = profile.name.orEmpty()
        profileEmail = profile.email.orEmpty()
        profilePhone = profile.phone.orEmpty()
        profileLanguage = profile.languagePreference.orEmpty()

        session?.let { activeSession ->
            val updatedSession = activeSession.copy(user = profile)
            session = updatedSession
            repository.persistSession(updatedSession)
        }
    }

    fun loadPendingTipDrafts(userId: String) {
        pendingTipDrafts = pendingTipQueueStore.loadDrafts(userId)
    }

    suspend fun syncPendingTipDrafts(
        activeSession: AuthSession,
        showStatusMessage: Boolean,
        surfaceErrors: Boolean,
    ) {
        loadPendingTipDrafts(activeSession.user.id)
        if (pendingTipDrafts.isEmpty()) {
            if (showStatusMessage) {
                statusMessage = "There are no pending offline tips to sync."
            }
            return
        }

        isSyncingPendingTips = true
        if (surfaceErrors) {
            errorMessage = null
        }

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
            } catch (error: AuthException) {
                syncError = error.message
                break
            } catch (error: IOException) {
                syncError = error.localizedMessage ?: "Unable to reach the backend right now."
                break
            } catch (_: Exception) {
                syncError = "Unable to sync pending tips right now."
                break
            }
        }

        loadPendingTipDrafts(activeSession.user.id)

        latestOrder?.let { order ->
            createdTipOrder = order
            tipStatus = TipStatusSnapshot(
                tipId = order.tipId,
                status = "INITIATED",
                updatedAt = null,
            )
            tipImpact = null
            runCatching {
                customerHistory = customerRepository.getCustomerTipHistory(activeSession.accessToken).tips
            }
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

    suspend fun refreshCustomerProfile(
        activeSession: AuthSession,
        showStatusMessage: Boolean,
        surfaceErrors: Boolean,
    ) {
        isLoadingCustomerProfile = true
        if (surfaceErrors) {
            errorMessage = null
        }

        try {
            val profile = customerRepository.getCurrentUserProfile(activeSession.accessToken)
            applyCustomerProfile(profile)
            if (showStatusMessage) {
                statusMessage = "Loaded customer profile from the shared backend."
            }
        } catch (error: AuthException) {
            if (surfaceErrors) {
                errorMessage = error.message
            }
        } catch (_: Exception) {
            if (surfaceErrors) {
                errorMessage = "Unable to load the customer profile right now."
            }
        } finally {
            isLoadingCustomerProfile = false
        }
    }

    suspend fun refreshCustomerHistory(
        activeSession: AuthSession,
        showStatusMessage: Boolean,
        surfaceErrors: Boolean,
    ) {
        isLoadingCustomerHistory = true
        if (surfaceErrors) {
            errorMessage = null
        }

        try {
            val historyPage = customerRepository.getCustomerTipHistory(activeSession.accessToken)
            customerHistory = historyPage.tips
            if (showStatusMessage) {
                statusMessage = if (historyPage.tips.isEmpty()) {
                    "Customer history is live, but no tips have been sent yet."
                } else {
                    "Loaded ${historyPage.tips.size} recent tips from the shared backend."
                }
            }
        } catch (error: AuthException) {
            if (surfaceErrors) {
                errorMessage = error.message
            }
        } catch (_: Exception) {
            if (surfaceErrors) {
                errorMessage = "Unable to load tip history right now."
            }
        } finally {
            isLoadingCustomerHistory = false
        }
    }

    suspend fun refreshTipImpact(
        tipId: String,
        showStatusMessage: Boolean,
        surfaceErrors: Boolean,
    ) {
        isLoadingTipImpact = true
        if (surfaceErrors) {
            errorMessage = null
        }

        try {
            val impact = customerRepository.getTipImpact(tipId)
            tipImpact = impact
            if (showStatusMessage) {
                statusMessage = impact.message
            }
        } catch (error: AuthException) {
            if (surfaceErrors) {
                errorMessage = error.message
            }
        } catch (_: Exception) {
            if (surfaceErrors) {
                errorMessage = "Unable to load payment impact right now."
            }
        } finally {
            isLoadingTipImpact = false
        }
    }

    suspend fun applyResolvedEntry(entry: TipEntryContext) {
        selectedEntryContext = entry
        selectedProvider = customerRepository.getPublicProfile(entry.providerId)
        entry.suggestedAmountPaise?.let { amountRupees = (it / 100).toString() }
    }

    suspend fun resolveScannedCode(rawInput: String) {
        val trimmedInput = rawInput.trim()
        resolutionInput = trimmedInput
        createdTipOrder = null
        tipStatus = null
        tipImpact = null
        errorMessage = null

        val preferPaymentLink = looksLikePaymentLink(trimmedInput)
        var lastErrorMessage: String? = null

        val primaryResolution = runCatching {
            if (preferPaymentLink) {
                customerRepository.resolvePaymentLink(trimmedInput)
            } else {
                customerRepository.resolveQrCode(trimmedInput)
            }
        }

        val entry = if (primaryResolution.isSuccess) {
            primaryResolution.getOrThrow()
        } else {
            val primaryError = primaryResolution.exceptionOrNull()
            lastErrorMessage = (primaryError as? AuthException)?.message ?: primaryError?.message

            val fallbackResolution = runCatching {
                if (preferPaymentLink) {
                    customerRepository.resolveQrCode(trimmedInput)
                } else {
                    customerRepository.resolvePaymentLink(trimmedInput)
                }
            }

            if (fallbackResolution.isSuccess) {
                fallbackResolution.getOrThrow()
            } else {
                val fallbackError = fallbackResolution.exceptionOrNull()
                throw (fallbackError ?: primaryError ?: IllegalStateException("Unable to resolve scanned QR code."))
            }
        }

        applyResolvedEntry(entry)
        statusMessage = when (entry.source) {
            TipSourceOption.PAYMENT_LINK -> "Resolved payment link for ${selectedProvider?.displayName ?: entry.providerName}."
            TipSourceOption.QR_CODE -> "Resolved QR entry for ${selectedProvider?.displayName ?: entry.providerName}."
            TipSourceOption.IN_APP -> "Loaded ${selectedProvider?.displayName ?: entry.providerName} details for tipping."
        }
        if (selectedProvider == null && lastErrorMessage != null) {
            errorMessage = lastErrorMessage
        }
    }

    LaunchedEffect(repository) {
        val restored = repository.restoreSession()
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

    LaunchedEffect(session?.accessToken) {
        session?.let { activeSession ->
            if (requiresNotificationPermission(context)) {
                if (!hasRequestedNotificationPermission) {
                    hasRequestedNotificationPermission = true
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
                return@let
            }
            runCatching { pushManager.syncTokenIfPossible(activeSession) }
        }
    }

    fun homeRole(activeSession: AuthSession): NativeRole {
        return when {
            activeSession.user.type.startsWith("BUSINESS") -> NativeRole.BUSINESS
            activeSession.user.type == NativeRole.PROVIDER.name -> NativeRole.PROVIDER
            activeSession.user.type == NativeRole.CUSTOMER.name && selectedRole == NativeRole.PROVIDER -> NativeRole.PROVIDER
            else -> NativeRole.CUSTOMER
        }
    }

    LaunchedEffect(session?.user?.id, stage) {
        val activeSession = session
        if (
            activeSession != null &&
            stage == AuthStage.HOME &&
            homeRole(activeSession) == NativeRole.CUSTOMER &&
            !hasLoadedCustomerHomeData
        ) {
            hasLoadedCustomerHomeData = true
            loadPendingTipDrafts(activeSession.user.id)
            refreshCustomerProfile(
                activeSession = activeSession,
                showStatusMessage = false,
                surfaceErrors = false,
            )
            refreshCustomerHistory(
                activeSession = activeSession,
                showStatusMessage = false,
                surfaceErrors = false,
            )
            if (pendingTipDrafts.isNotEmpty()) {
                syncPendingTipDrafts(
                    activeSession = activeSession,
                    showStatusMessage = false,
                    surfaceErrors = false,
                )
            }
        }
    }

    fun roleMeta(role: NativeRole): RoleCard = roles.first { it.role == role }

    fun resetCustomerFlow() {
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

    suspend fun clearSessionAndPushToken() {
        val previousAccessToken = session?.accessToken
        runCatching { pushManager.removeTokenIfPossible(previousAccessToken) }
        repository.logout()
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

    fun goToRole(role: NativeRole) {
        selectedRole = role
        credential = ""
        code = ""
        resetCustomerFlow()
        errorMessage = null
        statusMessage = if (role == NativeRole.BUSINESS) {
            "Business login uses email OTP from the shared backend."
        } else {
            "${roleMeta(role).title} login uses phone OTP from the shared backend."
        }
        stage = AuthStage.CREDENTIAL
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(Color(0xFFF5F8FF), Color.White),
                    ),
                ),
        ) {
            when {
                isLoading -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }

                else -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(horizontal = 20.dp, vertical = 28.dp),
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) {
                        HeaderSection()

                        when (stage) {
                            AuthStage.ROLE_PICKER -> {
                                roles.forEach { role ->
                                    RoleEntryCard(role = role) { goToRole(role.role) }
                                }
                            }

                            AuthStage.CREDENTIAL -> {
                                val role = selectedRole ?: NativeRole.CUSTOMER
                                CredentialCard(
                                    role = roleMeta(role),
                                    credential = credential,
                                    onCredentialChange = { credential = it },
                                    onBack = {
                                        errorMessage = null
                                        stage = AuthStage.ROLE_PICKER
                                    },
                                    onSubmit = {
                                        coroutineScope.launch {
                                            isLoading = true
                                            errorMessage = null
                                            try {
                                                val result = repository.sendCode(role, credential.trim())
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
                                    },
                                )
                            }

                            AuthStage.OTP -> {
                                val role = selectedRole ?: NativeRole.CUSTOMER
                                OtpCard(
                                    role = roleMeta(role),
                                    credential = credential,
                                    code = code,
                                    onCodeChange = { code = it.take(6) },
                                    onBack = {
                                        errorMessage = null
                                        stage = AuthStage.CREDENTIAL
                                    },
                                    onResend = {
                                        coroutineScope.launch {
                                            isLoading = true
                                            errorMessage = null
                                            try {
                                                val result = repository.sendCode(role, credential.trim())
                                                statusMessage = result.message
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to resend the code right now."
                                            } finally {
                                                isLoading = false
                                            }
                                        }
                                    },
                                    onVerify = {
                                        coroutineScope.launch {
                                            isLoading = true
                                            errorMessage = null
                                            try {
                                                val verified = repository.verifyCode(role, credential.trim(), code.trim())
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
                                    },
                                )
                            }

                            AuthStage.HOME -> {
                                session?.let {
                                    when (homeRole(it)) {
                                        NativeRole.CUSTOMER -> CustomerHomeCard(
                                            session = it,
                                            providerQuery = providerQuery,
                                            onProviderQueryChange = { providerQuery = it },
                                            providerResults = providerResults,
                                            selectedProvider = selectedProvider,
                                            selectedEntryContext = selectedEntryContext,
                                            resolutionInput = resolutionInput,
                                            onResolutionInputChange = { resolutionInput = it },
                                            amountRupees = amountRupees,
                                            onAmountRupeesChange = { amountRupees = it.filter(Char::isDigit) },
                                            selectedIntent = selectedIntent,
                                            onIntentSelected = { selectedIntent = it },
                                            tipMessage = tipMessage,
                                            onTipMessageChange = { tipMessage = it },
                                            selectedRating = selectedRating,
                                            onRatingSelected = { selectedRating = it },
                                            createdTipOrder = createdTipOrder,
                                            tipStatus = tipStatus,
                                            tipImpact = tipImpact,
                                            customerProfile = currentUserProfile ?: session?.user,
                                            customerHistory = customerHistory,
                                            pendingTipDrafts = pendingTipDrafts,
                                            profileName = profileName,
                                            onProfileNameChange = { profileName = it },
                                            profileEmail = profileEmail,
                                            onProfileEmailChange = { profileEmail = it },
                                            profilePhone = profilePhone,
                                            onProfilePhoneChange = { profilePhone = it },
                                            profileLanguage = profileLanguage,
                                            onProfileLanguageChange = { profileLanguage = it },
                                            isSearchingProviders = isSearchingProviders,
                                            isLoadingProvider = isLoadingProvider,
                                            isSubmittingTip = isSubmittingTip,
                                            isResolvingQr = isResolvingQr,
                                            isResolvingPaymentLink = isResolvingPaymentLink,
                                            isRefreshingTipStatus = isRefreshingTipStatus,
                                            isCompletingMockPayment = isCompletingMockPayment,
                                            isLaunchingCheckout = isLaunchingCheckout,
                                            isVerifyingCheckout = isVerifyingCheckout,
                                            isLoadingCustomerProfile = isLoadingCustomerProfile,
                                            isLoadingCustomerHistory = isLoadingCustomerHistory,
                                            isSavingCustomerProfile = isSavingCustomerProfile,
                                            isLoadingTipImpact = isLoadingTipImpact,
                                            isSyncingPendingTips = isSyncingPendingTips,
                                            isLaunchingScanner = isLaunchingScanner,
                                            onSearchProviders = {
                                                if (providerQuery.trim().length < 2) {
                                                    errorMessage = "Search query must be at least 2 characters."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    isSearchingProviders = true
                                                    errorMessage = null
                                                    createdTipOrder = null
                                                    tipStatus = null
                                                    tipImpact = null
                                                    try {
                                                        providerResults = customerRepository.searchProviders(providerQuery.trim())
                                                        statusMessage = if (providerResults.isEmpty()) {
                                                            "No providers matched that search."
                                                        } else {
                                                            "Loaded ${providerResults.size} provider matches."
                                                        }
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to search providers right now."
                                                    } finally {
                                                        isSearchingProviders = false
                                                    }
                                                }
                                            },
                                            onSelectProvider = { providerId ->
                                                coroutineScope.launch {
                                                    isLoadingProvider = true
                                                    errorMessage = null
                                                    createdTipOrder = null
                                                    tipStatus = null
                                                    tipImpact = null
                                                    try {
                                                        selectedProvider = customerRepository.getPublicProfile(providerId)
                                                        selectedEntryContext = selectedProvider?.let {
                                                            TipEntryContext.inApp(
                                                                providerId = it.id,
                                                                providerName = it.displayName,
                                                                category = it.category,
                                                            )
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
                                            },
                                            onCreateTip = {
                                                val activeSession = session
                                                val provider = selectedProvider
                                                val amount = amountRupees.toIntOrNull()
                                                val source = selectedEntryContext?.source

                                                when {
                                                    activeSession == null -> errorMessage = "Sign in again to continue."
                                                    provider == null -> errorMessage = "Choose a provider first."
                                                    amount == null -> errorMessage = "Enter a valid amount in rupees."
                                                    amount < 10 -> errorMessage = "Minimum tip amount is Rs 10."
                                                    else -> {
                                                        coroutineScope.launch {
                                                            isSubmittingTip = true
                                                            errorMessage = null
                                                            val trimmedMessage = tipMessage.trim().takeIf { it.isNotBlank() }
                                                            try {
                                                                createdTipOrder = customerRepository.createAuthenticatedTip(
                                                                    accessToken = activeSession.accessToken,
                                                                    providerId = provider.id,
                                                                    amountPaise = amount * 100,
                                                                    source = source ?: TipEntryContext.inApp(
                                                                        providerId = provider.id,
                                                                        providerName = provider.displayName,
                                                                        category = provider.category,
                                                                    ).source,
                                                                    intent = selectedIntent,
                                                                    message = trimmedMessage,
                                                                    rating = selectedRating,
                                                                )
                                                                tipStatus = createdTipOrder?.let {
                                                                    TipStatusSnapshot(
                                                                        tipId = it.tipId,
                                                                        status = "INITIATED",
                                                                        updatedAt = null,
                                                                    )
                                                                }
                                                                tipImpact = null
                                                                statusMessage = if (createdTipOrder?.isMockOrder == true) {
                                                                    "Mock tip order created for ${provider.displayName}. You can complete dev-bypass verification from this screen."
                                                                } else {
                                                                    "Tip order created for ${provider.displayName}. Open native Razorpay checkout to continue."
                                                                }
                                                                refreshCustomerHistory(
                                                                    activeSession = activeSession,
                                                                    showStatusMessage = false,
                                                                    surfaceErrors = false,
                                                                )
                                                            } catch (error: AuthException) {
                                                                errorMessage = error.message
                                                            } catch (error: IOException) {
                                                                val draft = PendingTipDraft(
                                                                    id = UUID.randomUUID().toString(),
                                                                    providerId = provider.id,
                                                                    providerName = provider.displayName,
                                                                    providerCategory = provider.category,
                                                                    amountPaise = amount * 100,
                                                                    source = source ?: TipEntryContext.inApp(
                                                                        providerId = provider.id,
                                                                        providerName = provider.displayName,
                                                                        category = provider.category,
                                                                    ).source,
                                                                    intent = selectedIntent,
                                                                    message = trimmedMessage,
                                                                    rating = selectedRating,
                                                                    idempotencyKey = UUID.randomUUID().toString(),
                                                                    createdAt = Instant.now().toString(),
                                                                )
                                                                pendingTipQueueStore.enqueue(activeSession.user.id, draft)
                                                                loadPendingTipDrafts(activeSession.user.id)
                                                                statusMessage = "You appear to be offline. This tip was saved locally and can be synced later without losing its idempotency key."
                                                            } catch (_: Exception) {
                                                                errorMessage = "Unable to create the tip order right now."
                                                            } finally {
                                                                isSubmittingTip = false
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onResolveQr = {
                                                if (resolutionInput.trim().isBlank()) {
                                                    errorMessage = "Paste a QR URL or QR code ID first."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    isResolvingQr = true
                                                    errorMessage = null
                                                    createdTipOrder = null
                                                    tipStatus = null
                                                    tipImpact = null
                                                    try {
                                                        val entry = customerRepository.resolveQrCode(resolutionInput.trim())
                                                        applyResolvedEntry(entry)
                                                        statusMessage = "Resolved QR entry for ${selectedProvider?.displayName ?: entry.providerName}."
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to resolve that QR code right now."
                                                    } finally {
                                                        isResolvingQr = false
                                                    }
                                                }
                                            },
                                            onResolvePaymentLink = {
                                                if (resolutionInput.trim().isBlank()) {
                                                    errorMessage = "Paste a payment link URL or short code first."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    isResolvingPaymentLink = true
                                                    errorMessage = null
                                                    createdTipOrder = null
                                                    tipStatus = null
                                                    tipImpact = null
                                                    try {
                                                        val entry = customerRepository.resolvePaymentLink(resolutionInput.trim())
                                                        applyResolvedEntry(entry)
                                                        statusMessage = "Resolved payment link for ${selectedProvider?.displayName ?: entry.providerName}."
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to resolve that payment link right now."
                                                    } finally {
                                                        isResolvingPaymentLink = false
                                                    }
                                                }
                                            },
                                            onRefreshTipStatus = {
                                                val tipId = createdTipOrder?.tipId
                                                if (tipId.isNullOrBlank()) {
                                                    errorMessage = "Create a tip order first."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    isRefreshingTipStatus = true
                                                    errorMessage = null
                                                    try {
                                                        tipStatus = customerRepository.getTipStatus(tipId)
                                                        if (shouldLoadImpact(tipStatus?.status)) {
                                                            refreshTipImpact(
                                                                tipId = tipId,
                                                                showStatusMessage = true,
                                                                surfaceErrors = false,
                                                            )
                                                        } else {
                                                            statusMessage = "Fetched backend status for tip $tipId."
                                                        }
                                                        session?.let { activeSession ->
                                                            refreshCustomerHistory(
                                                                activeSession = activeSession,
                                                                showStatusMessage = false,
                                                                surfaceErrors = false,
                                                            )
                                                        }
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to fetch tip status right now."
                                                    } finally {
                                                        isRefreshingTipStatus = false
                                                    }
                                                }
                                            },
                                            onCompleteMockPayment = {
                                                val order = createdTipOrder
                                                if (order == null || !order.isMockOrder) {
                                                    errorMessage = "Mock payment completion is only available for dev-bypass orders."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    isCompletingMockPayment = true
                                                    errorMessage = null
                                                    try {
                                                        customerRepository.verifyMockPayment(
                                                            tipId = order.tipId,
                                                            orderId = order.orderId,
                                                        )
                                                        tipStatus = customerRepository.getTipStatus(order.tipId)
                                                        refreshTipImpact(
                                                            tipId = order.tipId,
                                                            showStatusMessage = true,
                                                            surfaceErrors = false,
                                                        )
                                                        session?.let { activeSession ->
                                                            refreshCustomerHistory(
                                                                activeSession = activeSession,
                                                                showStatusMessage = false,
                                                                surfaceErrors = false,
                                                            )
                                                        }
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to complete mock payment verification right now."
                                                    } finally {
                                                        isCompletingMockPayment = false
                                                    }
                                                }
                                            },
                                            onOpenCheckout = {
                                                val order = createdTipOrder
                                                val provider = selectedProvider
                                                val launcher = checkoutLauncher
                                                val activeSession = session

                                                when {
                                                    order == null -> errorMessage = "Create a tip order first."
                                                    order.isMockOrder -> errorMessage = "Use mock completion for dev-bypass orders."
                                                    launcher == null -> errorMessage = "Native checkout is not available in this host."
                                                    provider == null -> errorMessage = "Provider details are missing."
                                                    activeSession == null -> errorMessage = "Sign in again to continue."
                                                    order.razorpayKeyId.isBlank() -> errorMessage = "Razorpay key is missing from the backend response."
                                                    else -> {
                                                        errorMessage = null
                                                        isLaunchingCheckout = true

                                                        val opened = launcher.launchCheckout(
                                                            request = NativeCheckoutRequest(
                                                                keyId = order.razorpayKeyId,
                                                                orderId = order.orderId,
                                                                amountPaise = order.amountPaise,
                                                                currency = order.currency,
                                                                title = "Fliq",
                                                                description = "Tip for ${provider.displayName}",
                                                                contact = activeSession.user.phone,
                                                                email = activeSession.user.email,
                                                            ),
                                                            callbacks = NativeCheckoutCallbacks(
                                                                onSuccess = { result ->
                                                                    coroutineScope.launch {
                                                                        isLaunchingCheckout = false
                                                                        isVerifyingCheckout = true
                                                                        errorMessage = null
                                                                        try {
                                                                            val payload = parseCheckoutPayload(
                                                                                responseJson = result.responseJson,
                                                                                fallbackPaymentId = result.paymentId,
                                                                            )
                                                                            customerRepository.verifyPayment(
                                                                                tipId = order.tipId,
                                                                                orderId = payload.orderId ?: order.orderId,
                                                                                paymentId = payload.paymentId,
                                                                                signature = payload.signature,
                                                                            )
                                                                            tipStatus = customerRepository.getTipStatus(order.tipId)
                                                                            refreshTipImpact(
                                                                                tipId = order.tipId,
                                                                                showStatusMessage = true,
                                                                                surfaceErrors = false,
                                                                            )
                                                                            session?.let { activeSession ->
                                                                                refreshCustomerHistory(
                                                                                    activeSession = activeSession,
                                                                                    showStatusMessage = false,
                                                                                    surfaceErrors = false,
                                                                                )
                                                                            }
                                                                        } catch (error: AuthException) {
                                                                            errorMessage = error.message
                                                                        } catch (_: Exception) {
                                                                            errorMessage = "Checkout returned, but verification failed on this device."
                                                                        } finally {
                                                                            isVerifyingCheckout = false
                                                                        }
                                                                    }
                                                                },
                                                                onError = { result ->
                                                                    isLaunchingCheckout = false
                                                                    errorMessage = "Checkout failed (${result.code}): ${result.description ?: "Unknown error"}"
                                                                },
                                                                onExternalWallet = { walletName, _ ->
                                                                    isLaunchingCheckout = false
                                                                    statusMessage = "External wallet selected${walletName?.let { ": $it" } ?: ""}. Refresh the tip status after payment completes."
                                                                },
                                                            ),
                                                        )

                                                        if (!opened) {
                                                            isLaunchingCheckout = false
                                                        }
                                                    }
                                                }
                                            },
                                            onRefreshCustomerProfile = {
                                                val activeSession = session
                                                if (activeSession == null) {
                                                    errorMessage = "Sign in again to continue."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    refreshCustomerProfile(
                                                        activeSession = activeSession,
                                                        showStatusMessage = true,
                                                        surfaceErrors = true,
                                                    )
                                                }
                                            },
                                            onRefreshCustomerHistory = {
                                                val activeSession = session
                                                if (activeSession == null) {
                                                    errorMessage = "Sign in again to continue."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    refreshCustomerHistory(
                                                        activeSession = activeSession,
                                                        showStatusMessage = true,
                                                        surfaceErrors = true,
                                                    )
                                                }
                                            },
                                            onRefreshTipImpact = {
                                                val order = createdTipOrder
                                                if (order == null) {
                                                    errorMessage = "Create and verify a tip order first."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    refreshTipImpact(
                                                        tipId = order.tipId,
                                                        showStatusMessage = true,
                                                        surfaceErrors = true,
                                                    )
                                                }
                                            },
                                            onSyncPendingTips = {
                                                val activeSession = session
                                                if (activeSession == null) {
                                                    errorMessage = "Sign in again to continue."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
                                                    syncPendingTipDrafts(
                                                        activeSession = activeSession,
                                                        showStatusMessage = true,
                                                        surfaceErrors = true,
                                                    )
                                                }
                                            },
                                            onDiscardPendingTip = { draftId ->
                                                val activeSession = session
                                                if (activeSession == null) {
                                                    errorMessage = "Sign in again to continue."
                                                    return@CustomerHomeCard
                                                }

                                                pendingTipQueueStore.remove(activeSession.user.id, draftId)
                                                loadPendingTipDrafts(activeSession.user.id)
                                                statusMessage = if (pendingTipDrafts.isEmpty()) {
                                                    "Removed the pending offline tip. The queue is now clear."
                                                } else {
                                                    "Removed the pending offline tip from this device queue."
                                                }
                                            },
                                            onScanQr = {
                                                val launcher = scannerLauncher
                                                if (launcher == null) {
                                                    errorMessage = "Native QR scanning is not available in this host."
                                                    return@CustomerHomeCard
                                                }

                                                errorMessage = null
                                                isLaunchingScanner = true
                                                val started = launcher.launchQrScanner(
                                                    callbacks = NativeQrScannerCallbacks(
                                                        onSuccess = { result ->
                                                            coroutineScope.launch {
                                                                try {
                                                                    resolveScannedCode(result.rawValue)
                                                                } catch (error: AuthException) {
                                                                    errorMessage = error.message
                                                                } catch (_: Exception) {
                                                                    errorMessage = "Unable to resolve that scanned code right now."
                                                                } finally {
                                                                    isLaunchingScanner = false
                                                                }
                                                            }
                                                        },
                                                        onCancelled = {
                                                            isLaunchingScanner = false
                                                            statusMessage = "QR scan cancelled."
                                                        },
                                                        onError = { result ->
                                                            isLaunchingScanner = false
                                                            errorMessage = result.message
                                                        },
                                                    ),
                                                )

                                                if (!started) {
                                                    isLaunchingScanner = false
                                                }
                                            },
                                            onSaveCustomerProfile = {
                                                val activeSession = session
                                                if (activeSession == null) {
                                                    errorMessage = "Sign in again to continue."
                                                    return@CustomerHomeCard
                                                }

                                                val normalizedLanguage = profileLanguage.trim().lowercase()
                                                if (
                                                    normalizedLanguage.isNotBlank() &&
                                                    normalizedLanguage !in supportedLanguageCodes
                                                ) {
                                                    errorMessage = "Language must be one of: en, hi, ta, te, kn, mr."
                                                    return@CustomerHomeCard
                                                }

                                                coroutineScope.launch {
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
                                                    } catch (error: AuthException) {
                                                        errorMessage = error.message
                                                    } catch (_: Exception) {
                                                        errorMessage = "Unable to save the customer profile right now."
                                                    } finally {
                                                        isSavingCustomerProfile = false
                                                    }
                                                }
                                            },
                                            onUsePresetAmount = { amountRupees = it.toString() },
                                            onLogout = {
                                                coroutineScope.launch {
                                                    clearSessionAndPushToken()
                                                }
                                            },
                                        )
                                        NativeRole.BUSINESS -> BusinessHomeCard(
                                            session = it,
                                            onLogout = {
                                                coroutineScope.launch {
                                                    clearSessionAndPushToken()
                                                }
                                            },
                                        )
                                        NativeRole.PROVIDER -> ProviderHomeCard(
                                            session = it,
                                            onLogout = {
                                                coroutineScope.launch {
                                                    clearSessionAndPushToken()
                                                }
                                            },
                                        )
                                    }
                                }
                            }
                        }

                        StatusCard(
                            statusMessage = statusMessage,
                            errorMessage = errorMessage,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderSection() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Fliq Android",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Native auth and session foundation on the shared Fliq backend. Customer, provider, and business roles all route through this native codebase.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RoleEntryCard(
    role: RoleCard,
    onClick: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = role.title,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = role.subtitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                RoleBadge(accent = role.accent)
            }

            Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
                Text(role.actionLabel)
            }
        }
    }
}

@Composable
private fun CredentialCard(
    role: RoleCard,
    credential: String,
    onCredentialChange: (String) -> Unit,
    onBack: () -> Unit,
    onSubmit: () -> Unit,
) {
    val isBusiness = role.role == NativeRole.BUSINESS
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "${role.title} sign in",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                RoleBadge(accent = role.accent)
            }

            Text(
                text = if (isBusiness) {
                    "Enter the business email used for dashboard access."
                } else {
                    "Enter the phone number used for ${role.title.lowercase()} access."
                },
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            OutlinedTextField(
                value = credential,
                onValueChange = onCredentialChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text(if (isBusiness) "Email" else "Phone number") },
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (isBusiness) KeyboardType.Email else KeyboardType.Phone,
                ),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(onClick = onBack) {
                    Text("Back")
                }
                Button(
                    onClick = onSubmit,
                    enabled = credential.isNotBlank(),
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Send OTP")
                }
            }
        }
    }
}

@Composable
private fun OtpCard(
    role: RoleCard,
    credential: String,
    code: String,
    onCodeChange: (String) -> Unit,
    onBack: () -> Unit,
    onResend: () -> Unit,
    onVerify: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Verify ${role.title.lowercase()} code",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "We sent a one-time code to $credential.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedTextField(
                value = code,
                onValueChange = onCodeChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("6-digit OTP") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(onClick = onBack) { Text("Back") }
                TextButton(onClick = onResend) { Text("Resend") }
                Button(
                    onClick = onVerify,
                    enabled = code.length >= 4,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Verify")
                }
            }
        }
    }
}

@Composable
private fun HomeCard(
    session: AuthSession,
    onLogout: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Signed in",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            DetailLine("User type", session.user.type)
            session.user.name?.let { DetailLine("Name", it) }
            session.user.phone?.let { DetailLine("Phone", it) }
            session.user.email?.let { DetailLine("Email", it) }
            session.user.kycStatus?.let { DetailLine("KYC", it) }
            DetailLine("User ID", session.user.id)

            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "Next parity slice from here: native customer home, provider resolve, and tip flow screens.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) {
                Text("Log out")
            }
        }
    }
}

@Composable
private fun CustomerHomeCard(
    session: AuthSession,
    providerQuery: String,
    onProviderQueryChange: (String) -> Unit,
    providerResults: List<ProviderSearchResult>,
    selectedProvider: ProviderProfile?,
    selectedEntryContext: TipEntryContext?,
    resolutionInput: String,
    onResolutionInputChange: (String) -> Unit,
    amountRupees: String,
    onAmountRupeesChange: (String) -> Unit,
    selectedIntent: TipIntentOption,
    onIntentSelected: (TipIntentOption) -> Unit,
    tipMessage: String,
    onTipMessageChange: (String) -> Unit,
    selectedRating: Int,
    onRatingSelected: (Int) -> Unit,
    createdTipOrder: CreatedTipOrder?,
    tipStatus: TipStatusSnapshot?,
    tipImpact: TipImpactSnapshot?,
    customerProfile: AuthUser?,
    customerHistory: List<CustomerTipHistoryItem>,
    pendingTipDrafts: List<PendingTipDraft>,
    profileName: String,
    onProfileNameChange: (String) -> Unit,
    profileEmail: String,
    onProfileEmailChange: (String) -> Unit,
    profilePhone: String,
    onProfilePhoneChange: (String) -> Unit,
    profileLanguage: String,
    onProfileLanguageChange: (String) -> Unit,
    isSearchingProviders: Boolean,
    isLoadingProvider: Boolean,
    isSubmittingTip: Boolean,
    isResolvingQr: Boolean,
    isResolvingPaymentLink: Boolean,
    isRefreshingTipStatus: Boolean,
    isCompletingMockPayment: Boolean,
    isLaunchingCheckout: Boolean,
    isVerifyingCheckout: Boolean,
    isLoadingCustomerProfile: Boolean,
    isLoadingCustomerHistory: Boolean,
    isSavingCustomerProfile: Boolean,
    isLoadingTipImpact: Boolean,
    isSyncingPendingTips: Boolean,
    isLaunchingScanner: Boolean,
    onSearchProviders: () -> Unit,
    onSelectProvider: (String) -> Unit,
    onScanQr: () -> Unit,
    onResolveQr: () -> Unit,
    onResolvePaymentLink: () -> Unit,
    onCreateTip: () -> Unit,
    onRefreshTipStatus: () -> Unit,
    onCompleteMockPayment: () -> Unit,
    onOpenCheckout: () -> Unit,
    onRefreshCustomerProfile: () -> Unit,
    onRefreshCustomerHistory: () -> Unit,
    onRefreshTipImpact: () -> Unit,
    onSyncPendingTips: () -> Unit,
    onDiscardPendingTip: (String) -> Unit,
    onSaveCustomerProfile: () -> Unit,
    onUsePresetAmount: (Int) -> Unit,
    onLogout: () -> Unit,
) {
    val isCustomAmountLocked = selectedEntryContext?.allowCustomAmount == false &&
        selectedEntryContext.suggestedAmountPaise != null

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text(
                text = "Customer home",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            session.user.name?.let { DetailLine("Signed in as", it) }
            DetailLine("Journey", "Provider search, QR or payment-link resolve, and backend tip status")

            CustomerProfileCard(
                customerProfile = customerProfile ?: session.user,
                profileName = profileName,
                onProfileNameChange = onProfileNameChange,
                profileEmail = profileEmail,
                onProfileEmailChange = onProfileEmailChange,
                profilePhone = profilePhone,
                onProfilePhoneChange = onProfilePhoneChange,
                profileLanguage = profileLanguage,
                onProfileLanguageChange = onProfileLanguageChange,
                isLoadingCustomerProfile = isLoadingCustomerProfile,
                isSavingCustomerProfile = isSavingCustomerProfile,
                onRefreshCustomerProfile = onRefreshCustomerProfile,
                onSaveCustomerProfile = onSaveCustomerProfile,
            )

            CustomerPendingTipsCard(
                pendingTipDrafts = pendingTipDrafts,
                isSyncingPendingTips = isSyncingPendingTips,
                onSyncPendingTips = onSyncPendingTips,
                onDiscardPendingTip = onDiscardPendingTip,
            )

            CustomerRetentionSection(
                session = session,
                selectedProvider = selectedProvider,
                amountRupees = amountRupees,
                message = tipMessage,
                rating = selectedRating,
            )
            CustomerJarSection(session = session)

            Text(
                text = "Resolve QR or link",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            OutlinedTextField(
                value = resolutionInput,
                onValueChange = onResolutionInputChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Paste /qr/... or /tip/... or raw ID") },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = onScanQr,
                    enabled = !isLaunchingScanner && !isResolvingQr && !isResolvingPaymentLink,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isLaunchingScanner) "Scanning..." else "Scan QR")
                }
                OutlinedButton(
                    onClick = onResolveQr,
                    enabled = resolutionInput.isNotBlank() && !isResolvingQr && !isLaunchingScanner,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isResolvingQr) "Resolving..." else "Resolve QR")
                }
                OutlinedButton(
                    onClick = onResolvePaymentLink,
                    enabled = resolutionInput.isNotBlank() && !isResolvingPaymentLink && !isLaunchingScanner,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isResolvingPaymentLink) "Resolving..." else "Resolve link")
                }
            }

            OutlinedTextField(
                value = providerQuery,
                onValueChange = onProviderQueryChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Search providers by name or phone") },
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    onClick = onSearchProviders,
                    enabled = providerQuery.trim().length >= 2 && !isSearchingProviders,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isSearchingProviders) "Searching..." else "Search providers")
                }
                TextButton(onClick = onLogout) {
                    Text("Log out")
                }
            }

            selectedEntryContext?.let { entry ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(20.dp),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "Selected entry context",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                        DetailLine("Source", entry.source.label)
                        DetailLine("Provider", entry.providerName)
                        entry.category?.let { DetailLine("Category", it) }
                        entry.entryDetail?.let { DetailLine("Context", it) }
                        entry.suggestedAmountPaise?.let { DetailLine("Suggested amount", "Rs ${it / 100}") }
                        DetailLine(
                            "Custom amount",
                            if (entry.allowCustomAmount) "Allowed" else "Locked to suggested amount",
                        )
                    }
                }
            }

            if (providerResults.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Search results",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    providerResults.forEach { provider ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            shape = RoundedCornerShape(20.dp),
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Text(provider.name, fontWeight = FontWeight.Bold)
                                provider.category?.let { DetailLine("Category", it) }
                                provider.phone?.let { DetailLine("Phone", it) }
                                DetailLine("Rating", formatScore(provider.ratingAverage))
                                DetailLine("Total tips", provider.totalTipsReceived.toString())
                                OutlinedButton(
                                    onClick = { onSelectProvider(provider.id) },
                                    modifier = Modifier.fillMaxWidth(),
                                    enabled = !isLoadingProvider,
                                ) {
                                    Text(if (isLoadingProvider && selectedProvider?.id == provider.id) "Loading..." else "Open provider")
                                }
                            }
                        }
                    }
                }
            }

            selectedProvider?.let { provider ->
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Selected provider",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    DetailLine("Name", provider.displayName)
                    provider.category?.let { DetailLine("Category", it) }
                    provider.bio?.let { DetailLine("Bio", it) }
                    DetailLine("Rating", formatScore(provider.ratingAverage))
                    DetailLine("Tips today", provider.stats.tipsToday.toString())
                    DetailLine("Recent appreciations", provider.stats.recentAppreciations.toString())
                    provider.reputation?.let {
                        DetailLine("Reputation score", formatScore(it.score))
                    }
                    provider.dream?.let {
                        DetailLine("Dream", "${it.title} (${it.percentage}% funded)")
                    }
                    selectedEntryContext?.let {
                        DetailLine("Entry source", it.source.label)
                    }

                    Text(
                        text = "Tip amount",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        listOf(50, 100, 200).forEach { preset ->
                            OutlinedButton(
                                onClick = { onUsePresetAmount(preset) },
                                modifier = Modifier.weight(1f),
                                enabled = !isCustomAmountLocked,
                            ) {
                                Text("Rs $preset")
                            }
                        }
                    }
                    OutlinedTextField(
                        value = amountRupees,
                        onValueChange = onAmountRupeesChange,
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Custom amount in rupees") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        enabled = !isCustomAmountLocked,
                    )
                    if (isCustomAmountLocked) {
                        Text(
                            text = "This payment link locks the amount to the suggested value from the backend.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    Text(
                        text = "Intent",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    TipIntentOption.values().forEach { intent ->
                        OutlinedButton(
                            onClick = { onIntentSelected(intent) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                text = if (intent == selectedIntent) {
                                    "${intent.label} selected"
                                } else {
                                    "${intent.label}: ${intent.summary}"
                                },
                            )
                        }
                    }

                    OutlinedTextField(
                        value = tipMessage,
                        onValueChange = onTipMessageChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Message") },
                        minLines = 3,
                    )

                    Text(
                        text = "Rating",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        (1..5).forEach { rating ->
                            OutlinedButton(
                                onClick = { onRatingSelected(rating) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text(if (rating == selectedRating) "$rating*" else rating.toString())
                            }
                        }
                    }

                    Button(
                        onClick = onCreateTip,
                        enabled = !isSubmittingTip,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (isSubmittingTip) "Creating order..." else "Create tip order")
                    }
                }
            }

            createdTipOrder?.let { tipOrder ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(20.dp),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "Tip order created",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                        DetailLine("Provider", tipOrder.providerName)
                        tipOrder.providerCategory?.let { DetailLine("Category", it) }
                        DetailLine("Amount", "Rs ${tipOrder.amountPaise / 100}")
                        DetailLine("Currency", tipOrder.currency)
                        DetailLine("Tip ID", tipOrder.tipId)
                        DetailLine("Order ID", tipOrder.orderId)
                        DetailLine("Razorpay key", tipOrder.razorpayKeyId)
                        tipStatus?.let {
                            DetailLine("Backend status", it.status)
                            it.updatedAt?.let { timestamp -> DetailLine("Updated at", timestamp) }
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            OutlinedButton(
                                onClick = onRefreshTipStatus,
                                enabled = !isRefreshingTipStatus && !isVerifyingCheckout,
                                modifier = Modifier.weight(1f),
                            ) {
                                Text(if (isRefreshingTipStatus) "Refreshing..." else "Refresh status")
                            }
                            if (tipOrder.isMockOrder) {
                                Button(
                                    onClick = onCompleteMockPayment,
                                    enabled = !isCompletingMockPayment,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (isCompletingMockPayment) "Completing..." else "Complete mock payment")
                                }
                            } else {
                                Button(
                                    onClick = onOpenCheckout,
                                    enabled = !isLaunchingCheckout && !isVerifyingCheckout,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(
                                        when {
                                            isVerifyingCheckout -> "Verifying..."
                                            isLaunchingCheckout -> "Opening..."
                                            else -> "Open checkout"
                                        },
                                    )
                                }
                            }
                        }
                        Text(
                            text = if (tipOrder.isMockOrder) {
                                "The backend is returning a dev-bypass Razorpay order. You can complete verification here without a real checkout SDK."
                            } else {
                                "Native Razorpay checkout is now wired. This button opens the SDK and verifies the callback back through the shared backend."
                            },
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            CustomerTipSuccessCard(
                tipImpact = tipImpact,
                isLoadingTipImpact = isLoadingTipImpact,
                onRefreshTipImpact = onRefreshTipImpact,
            )

            CustomerTipHistoryCard(
                customerHistory = customerHistory,
                isLoadingCustomerHistory = isLoadingCustomerHistory,
                onRefreshCustomerHistory = onRefreshCustomerHistory,
            )
        }
    }
}

@Composable
private fun CustomerProfileCard(
    customerProfile: AuthUser,
    profileName: String,
    onProfileNameChange: (String) -> Unit,
    profileEmail: String,
    onProfileEmailChange: (String) -> Unit,
    profilePhone: String,
    onProfilePhoneChange: (String) -> Unit,
    profileLanguage: String,
    onProfileLanguageChange: (String) -> Unit,
    isLoadingCustomerProfile: Boolean,
    isSavingCustomerProfile: Boolean,
    onRefreshCustomerProfile: () -> Unit,
    onSaveCustomerProfile: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "Profile",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            DetailLine("Customer ID", customerProfile.id)
            OutlinedTextField(
                value = profileName,
                onValueChange = onProfileNameChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Name") },
            )
            OutlinedTextField(
                value = profileEmail,
                onValueChange = onProfileEmailChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Email") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            )
            OutlinedTextField(
                value = profilePhone,
                onValueChange = onProfilePhoneChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Phone") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            )
            OutlinedTextField(
                value = profileLanguage,
                onValueChange = onProfileLanguageChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Language code (en, hi, ta, te, kn, mr)") },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = onRefreshCustomerProfile,
                    enabled = !isLoadingCustomerProfile && !isSavingCustomerProfile,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isLoadingCustomerProfile) "Refreshing..." else "Refresh profile")
                }
                Button(
                    onClick = onSaveCustomerProfile,
                    enabled = !isLoadingCustomerProfile && !isSavingCustomerProfile,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (isSavingCustomerProfile) "Saving..." else "Save profile")
                }
            }
        }
    }
}

@Composable
private fun CustomerPendingTipsCard(
    pendingTipDrafts: List<PendingTipDraft>,
    isSyncingPendingTips: Boolean,
    onSyncPendingTips: () -> Unit,
    onDiscardPendingTip: (String) -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Offline queue",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                OutlinedButton(
                    onClick = onSyncPendingTips,
                    enabled = pendingTipDrafts.isNotEmpty() && !isSyncingPendingTips,
                ) {
                    Text(if (isSyncingPendingTips) "Syncing..." else "Sync now")
                }
            }

            if (pendingTipDrafts.isEmpty()) {
                Text(
                    text = "Offline-created customer tips will queue here if the backend cannot be reached.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                pendingTipDrafts.forEach { draft ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        shape = RoundedCornerShape(18.dp),
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                text = "${formatTipAmount(draft.amountPaise)} to ${draft.providerName}",
                                fontWeight = FontWeight.Bold,
                            )
                            draft.providerCategory?.let { DetailLine("Category", it) }
                            DetailLine("Source", draft.source.label)
                            DetailLine("Intent", draft.intent.label)
                            draft.message?.let { DetailLine("Message", it) }
                            formatHistoryDate(draft.createdAt)?.let { DetailLine("Queued", it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Button(
                                    onClick = onSyncPendingTips,
                                    enabled = !isSyncingPendingTips,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Retry sync")
                                }
                                OutlinedButton(
                                    onClick = { onDiscardPendingTip(draft.id) },
                                    enabled = !isSyncingPendingTips,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Discard")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CustomerTipSuccessCard(
    tipImpact: TipImpactSnapshot?,
    isLoadingTipImpact: Boolean,
    onRefreshTipImpact: () -> Unit,
) {
    if (!isLoadingTipImpact && tipImpact == null) {
        return
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Payment success",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                if (tipImpact != null) {
                    TextButton(onClick = onRefreshTipImpact, enabled = !isLoadingTipImpact) {
                        Text(if (isLoadingTipImpact) "Refreshing..." else "Refresh")
                    }
                }
            }

            when {
                isLoadingTipImpact && tipImpact == null -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 20.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator()
                    }
                }

                tipImpact != null -> {
                    DetailLine("Worker", tipImpact.workerName)
                    DetailLine("Amount", formatTipAmount(tipImpact.amountPaise))
                    formatIntentLabel(tipImpact.intent)?.let { DetailLine("Intent", it) }
                    Text(
                        text = tipImpact.message,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    tipImpact.dream?.let { dream ->
                        DetailLine("Dream", dream.title)
                        DetailLine("Progress", "${dream.previousProgress}% to ${dream.newProgress}%")
                    }
                }
            }
        }
    }
}

@Composable
private fun CustomerTipHistoryCard(
    customerHistory: List<CustomerTipHistoryItem>,
    isLoadingCustomerHistory: Boolean,
    onRefreshCustomerHistory: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Recent tips",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                TextButton(onClick = onRefreshCustomerHistory, enabled = !isLoadingCustomerHistory) {
                    Text(if (isLoadingCustomerHistory) "Refreshing..." else "Refresh")
                }
            }

            when {
                isLoadingCustomerHistory && customerHistory.isEmpty() -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 20.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator()
                    }
                }

                customerHistory.isEmpty() -> {
                    Text(
                        text = "No customer tips yet. Recent authenticated tips will appear here.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                else -> {
                    customerHistory.forEach { tip ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            shape = RoundedCornerShape(18.dp),
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(14.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    text = "${formatTipAmount(tip.amountPaise)} to ${tip.providerName}",
                                    fontWeight = FontWeight.Bold,
                                )
                                tip.providerCategory?.let { DetailLine("Category", it) }
                                DetailLine("Status", tip.status)
                                formatIntentLabel(tip.intent)?.let { DetailLine("Intent", it) }
                                tip.message?.let { DetailLine("Message", it) }
                                formatHistoryDate(tip.createdAt)?.let { DetailLine("Created", it) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RoleHomeCard(
    session: AuthSession,
    onLogout: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "${session.user.type.lowercase().replaceFirstChar(Char::uppercase)} home",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            session.user.name?.let { DetailLine("Name", it) }
            session.user.phone?.let { DetailLine("Phone", it) }
            session.user.email?.let { DetailLine("Email", it) }
            Text(
                text = "Auth and session parity are live here. Provider and business feature screens stay separate and will be expanded in their own slices instead of being mixed into customer tipping work.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) {
                Text("Log out")
            }
        }
    }
}

@Composable
private fun DetailLine(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun StatusCard(
    statusMessage: String,
    errorMessage: String?,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = if (errorMessage == null) "Current status" else "Error",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = errorMessage ?: statusMessage,
                style = MaterialTheme.typography.bodyMedium,
                color = if (errorMessage == null) {
                    MaterialTheme.colorScheme.onSurfaceVariant
                } else {
                    Color(0xFFB42318)
                },
            )
        }
    }
}

private fun formatScore(value: Double): String {
    return if (value == 0.0) "0.0" else String.format("%.1f", value)
}

private fun formatTipAmount(amountPaise: Int): String {
    return "Rs ${amountPaise / 100}"
}

private fun formatIntentLabel(intent: String?): String? {
    return when (intent) {
        "KINDNESS" -> "Kindness"
        "SPEED" -> "Speed"
        "EXPERIENCE" -> "Experience"
        "SUPPORT" -> "Support"
        null -> null
        else -> intent
    }
}

private fun formatHistoryDate(value: String?): String? {
    if (value.isNullOrBlank()) {
        return null
    }

    val formatter = DateTimeFormatter.ofPattern("d MMM yyyy, h:mm a", Locale.US)
    return runCatching {
        OffsetDateTime.parse(value)
            .atZoneSameInstant(ZoneId.systemDefault())
            .format(formatter)
    }.recoverCatching {
        Instant.parse(value)
            .atZone(ZoneId.systemDefault())
            .format(formatter)
    }.getOrElse {
        value
    }
}

private fun looksLikePaymentLink(rawValue: String): Boolean {
    val normalized = rawValue.lowercase(Locale.US)
    return normalized.contains("/tip/") || normalized.contains("payment-link")
}

private fun shouldLoadImpact(status: String?): Boolean {
    return status == "PAID" || status == "SETTLED"
}

private data class ParsedCheckoutPayload(
    val orderId: String?,
    val paymentId: String,
    val signature: String,
)

private fun parseCheckoutPayload(
    responseJson: String?,
    fallbackPaymentId: String?,
): ParsedCheckoutPayload {
    val json = responseJson?.takeIf { it.isNotBlank() }?.let(::JSONObject) ?: JSONObject()
    val paymentId = json.optString("razorpay_payment_id").takeIf { it.isNotBlank() }
        ?: fallbackPaymentId?.takeIf { it.isNotBlank() }
        ?: error("Missing payment id from Razorpay callback.")
    val signature = json.optString("razorpay_signature").takeIf { it.isNotBlank() }
        ?: error("Missing payment signature from Razorpay callback.")
    val orderId = json.optString("razorpay_order_id").takeIf { it.isNotBlank() }
    return ParsedCheckoutPayload(
        orderId = orderId,
        paymentId = paymentId,
        signature = signature,
    )
}

@Composable
private fun RoleBadge(accent: Color) {
    Box(
        modifier = Modifier
            .background(
                color = accent.copy(alpha = 0.14f),
                shape = RoundedCornerShape(999.dp),
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(
            text = "Native",
            color = accent,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
        )
    }
}
