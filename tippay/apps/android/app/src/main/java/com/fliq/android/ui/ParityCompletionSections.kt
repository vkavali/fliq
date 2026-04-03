package com.fliq.android.ui

import android.content.Intent

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fliq.android.data.AuthException
import com.fliq.android.data.AuthSession
import com.fliq.android.data.CustomerRepository
import com.fliq.android.data.NativeBadge
import com.fliq.android.data.NativeDeferredTip
import com.fliq.android.data.NativeEkycInitiation
import com.fliq.android.data.NativeEkycProfile
import com.fliq.android.data.NativeEkycStatus
import com.fliq.android.data.NativeLeaderboardEntry
import com.fliq.android.data.NativePaymentOrder
import com.fliq.android.data.NativeRecurringAuthorization
import com.fliq.android.data.NativeRecurringFrequency
import com.fliq.android.data.NativeRecurringTip
import com.fliq.android.data.NativeStreak
import com.fliq.android.data.ParityCompletionRepository
import com.fliq.android.data.ProviderProfile
import com.fliq.android.data.ProviderTipItem
import com.fliq.android.data.TipImpactSnapshot
import com.fliq.android.data.TipStatusSnapshot
import com.fliq.android.payments.NativeCheckoutCallbacks
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.payments.NativeCheckoutRequest
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch
import org.json.JSONObject

@Composable
fun CustomerRetentionSection(
    session: AuthSession,
    selectedProvider: ProviderProfile?,
    amountRupees: String,
    message: String?,
    rating: Int,
) {
    val repository = remember { ParityCompletionRepository() }
    val customerRepository = remember { CustomerRepository() }
    val coroutineScope = rememberCoroutineScope()
    val checkoutLauncher = LocalContext.current as? NativeCheckoutLauncher
    val uriHandler = LocalUriHandler.current

    var badges by remember { mutableStateOf(emptyList<NativeBadge>()) }
    var streak by remember { mutableStateOf<NativeStreak?>(null) }
    var tipperLeaderboard by remember { mutableStateOf(emptyList<NativeLeaderboardEntry>()) }
    var providerLeaderboard by remember { mutableStateOf(emptyList<NativeLeaderboardEntry>()) }
    var recurringTips by remember { mutableStateOf(emptyList<NativeRecurringTip>()) }
    var deferredTips by remember { mutableStateOf(emptyList<NativeDeferredTip>()) }
    var recurringAuthorization by remember { mutableStateOf<NativeRecurringAuthorization?>(null) }
    var paymentOrder by remember { mutableStateOf<NativePaymentOrder?>(null) }
    var paymentStatus by remember { mutableStateOf<TipStatusSnapshot?>(null) }
    var paymentImpact by remember { mutableStateOf<TipImpactSnapshot?>(null) }
    var statusMessage by remember { mutableStateOf("Recurring tips, tip later, and gamification are now loading natively.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var isCreatingRecurring by remember { mutableStateOf(false) }
    var isCreatingDeferred by remember { mutableStateOf(false) }
    var isUpdatingRecurring by remember { mutableStateOf(false) }
    var isPayingDeferred by remember { mutableStateOf(false) }
    var isLaunchingCheckout by remember { mutableStateOf(false) }
    var isVerifyingPayment by remember { mutableStateOf(false) }

    suspend fun loadRetentionData() {
        isLoading = true
        try {
            badges = repository.getBadges(session.accessToken)
            streak = repository.getStreak(session.accessToken)
            tipperLeaderboard = repository.getLeaderboard("/gamification/leaderboard")
            providerLeaderboard = repository.getLeaderboard("/gamification/leaderboard/providers")
            recurringTips = repository.getMyRecurringTips(session.accessToken)
            deferredTips = repository.getMyDeferredTips(session.accessToken)
            statusMessage = "Recurring support, tip promises, badges, streaks, and leaderboards are live natively."
            errorMessage = null
        } catch (error: AuthException) {
            errorMessage = error.message
        } catch (_: Exception) {
            errorMessage = "Unable to load retention data right now."
        } finally {
            isLoading = false
        }
    }

    suspend fun refreshPaymentState(order: NativePaymentOrder) {
        paymentStatus = customerRepository.getTipStatus(order.tipId)
        paymentImpact = runCatching { customerRepository.getTipImpact(order.tipId) }.getOrNull()
    }

    fun parsePaymentPayload(responseJson: String?): Triple<String?, String, String>? {
        val response = responseJson?.takeIf { it.isNotBlank() }?.let(::JSONObject) ?: return null
        val orderId = response.optString("razorpay_order_id").takeIf { it.isNotBlank() }
        val paymentId = response.optString("razorpay_payment_id").takeIf { it.isNotBlank() } ?: return null
        val signature = response.optString("razorpay_signature").takeIf { it.isNotBlank() } ?: return null
        return Triple(orderId, paymentId, signature)
    }

    LaunchedEffect(session.user.id) {
        loadRetentionData()
    }

    Card(
        shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Retention and promises",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(text = it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(text = statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            if (isLoading) {
                Text("Loading badges, streaks, recurring tips, and promised tips...")
            }

            streak?.let {
                CompletionSectionCard(title = "Streak") {
                    CompletionLine("Current streak", "${it.currentStreak} days")
                    CompletionLine("Longest streak", "${it.longestStreak} days")
                    it.lastTipDate?.let { lastTip -> CompletionLine("Last tip", formatCompletionDate(lastTip) ?: lastTip) }
                }
            }

            CompletionSectionCard(title = "Badges") {
                val earnedBadges = badges.filter { it.earned }
                if (earnedBadges.isEmpty()) {
                    Text("No earned badges yet.")
                } else {
                    earnedBadges.take(4).forEach { badge ->
                        CompletionListCard {
                            Text(badge.name, fontWeight = FontWeight.Bold)
                            CompletionLine("Category", badge.category)
                            CompletionLine("Description", badge.description)
                        }
                    }
                }
            }

            CompletionSectionCard(title = "Leaderboards") {
                Text("Top tippers", fontWeight = FontWeight.Bold)
                if (tipperLeaderboard.isEmpty()) {
                    Text("No leaderboard data yet.")
                } else {
                    tipperLeaderboard.take(3).forEach { entry ->
                        CompletionLine("#${entry.rank} ${entry.name}", "${entry.tipCount} tips")
                    }
                }
                Text("Top providers", fontWeight = FontWeight.Bold)
                if (providerLeaderboard.isEmpty()) {
                    Text("No provider leaderboard data yet.")
                } else {
                    providerLeaderboard.take(3).forEach { entry ->
                        CompletionLine("#${entry.rank} ${entry.name}", formatCompletionAmount(entry.totalAmountPaise))
                    }
                }
            }

            CompletionSectionCard(title = "Recurring tips") {
                val currentAmountPaise = amountRupees.toIntOrNull()?.times(100)
                selectedProvider?.let { provider ->
                    Text("Create a recurring tip for ${provider.displayName}.")
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    val amount = currentAmountPaise
                                    if (amount == null || amount < 1000) {
                                        errorMessage = "Recurring tip minimum is Rs 10."
                                        return@launch
                                    }
                                    isCreatingRecurring = true
                                    try {
                                        recurringAuthorization = repository.createRecurringTip(
                                            accessToken = session.accessToken,
                                            providerId = provider.id,
                                            amountPaise = amount,
                                            frequency = NativeRecurringFrequency.WEEKLY,
                                        )
                                        recurringTips = repository.getMyRecurringTips(session.accessToken)
                                        statusMessage = "Weekly recurring tip created. Open the authorization link to finish the mandate."
                                        errorMessage = null
                                    } catch (error: AuthException) {
                                        errorMessage = error.message
                                    } catch (_: Exception) {
                                        errorMessage = "Unable to create a recurring tip right now."
                                    } finally {
                                        isCreatingRecurring = false
                                    }
                                }
                            },
                            enabled = !isCreatingRecurring,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Weekly")
                        }
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    val amount = currentAmountPaise
                                    if (amount == null || amount < 1000) {
                                        errorMessage = "Recurring tip minimum is Rs 10."
                                        return@launch
                                    }
                                    isCreatingRecurring = true
                                    try {
                                        recurringAuthorization = repository.createRecurringTip(
                                            accessToken = session.accessToken,
                                            providerId = provider.id,
                                            amountPaise = amount,
                                            frequency = NativeRecurringFrequency.MONTHLY,
                                        )
                                        recurringTips = repository.getMyRecurringTips(session.accessToken)
                                        statusMessage = "Monthly recurring tip created. Open the authorization link to finish the mandate."
                                        errorMessage = null
                                    } catch (error: AuthException) {
                                        errorMessage = error.message
                                    } catch (_: Exception) {
                                        errorMessage = "Unable to create a recurring tip right now."
                                    } finally {
                                        isCreatingRecurring = false
                                    }
                                }
                            },
                            enabled = !isCreatingRecurring,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Monthly")
                        }
                    }
                } ?: Text("Select a provider above to create a recurring tip.")

                recurringAuthorization?.let { auth ->
                    CompletionListCard {
                        Text("Mandate ready for ${auth.providerName}", fontWeight = FontWeight.Bold)
                        CompletionLine("Subscription", auth.subscriptionId)
                        CompletionLine("Authorization URL", auth.authorizationUrl)
                        OutlinedButton(onClick = { uriHandler.openUri(auth.authorizationUrl) }) {
                            Text("Open authorization link")
                        }
                    }
                }

                if (recurringTips.isEmpty()) {
                    Text("No recurring tips yet.")
                } else {
                    recurringTips.forEach { recurring ->
                        CompletionListCard {
                            Text(
                                text = "${formatCompletionAmount(recurring.amountPaise)} / ${recurring.frequency.lowercase(Locale.US)}",
                                fontWeight = FontWeight.Bold,
                            )
                            recurring.providerName?.let { CompletionLine("Provider", it) }
                            recurring.providerCategory?.let { CompletionLine("Category", it) }
                            CompletionLine("Status", recurring.status)
                            recurring.nextChargeDate?.let { CompletionLine("Next charge", formatCompletionDate(it) ?: it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            isUpdatingRecurring = true
                                            try {
                                                if (recurring.status == "ACTIVE") {
                                                    repository.pauseRecurringTip(session.accessToken, recurring.id)
                                                    statusMessage = "Recurring tip paused."
                                                } else if (recurring.status == "PAUSED") {
                                                    repository.resumeRecurringTip(session.accessToken, recurring.id)
                                                    statusMessage = "Recurring tip resumed."
                                                }
                                                recurringTips = repository.getMyRecurringTips(session.accessToken)
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to update the recurring tip right now."
                                            } finally {
                                                isUpdatingRecurring = false
                                            }
                                        }
                                    },
                                    enabled = !isUpdatingRecurring && (recurring.status == "ACTIVE" || recurring.status == "PAUSED"),
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (recurring.status == "PAUSED") "Resume" else "Pause")
                                }
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            isUpdatingRecurring = true
                                            try {
                                                repository.cancelRecurringTip(session.accessToken, recurring.id)
                                                recurringTips = repository.getMyRecurringTips(session.accessToken)
                                                statusMessage = "Recurring tip cancelled."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to cancel the recurring tip right now."
                                            } finally {
                                                isUpdatingRecurring = false
                                            }
                                        }
                                    },
                                    enabled = !isUpdatingRecurring,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Cancel")
                                }
                            }
                        }
                    }
                }
            }

            CompletionSectionCard(title = "Tip later") {
                val currentAmountPaise = amountRupees.toIntOrNull()?.times(100)
                selectedProvider?.let { provider ->
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                val amount = currentAmountPaise
                                if (amount == null || amount < 1000) {
                                    errorMessage = "Tip later minimum is Rs 10."
                                    return@launch
                                }
                                isCreatingDeferred = true
                                try {
                                    repository.createDeferredTip(
                                        accessToken = session.accessToken,
                                        providerId = provider.id,
                                        amountPaise = amount,
                                        message = message?.trim()?.takeIf { it.isNotBlank() },
                                        rating = rating,
                                    )
                                    deferredTips = repository.getMyDeferredTips(session.accessToken)
                                    statusMessage = "Tip promise saved for ${provider.displayName}."
                                    errorMessage = null
                                } catch (error: AuthException) {
                                    errorMessage = error.message
                                } catch (_: Exception) {
                                    errorMessage = "Unable to create a tip promise right now."
                                } finally {
                                    isCreatingDeferred = false
                                }
                            }
                        },
                        enabled = !isCreatingDeferred,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (isCreatingDeferred) "Saving promise..." else "Promise this tip for later")
                    }
                } ?: Text("Select a provider above to save a tip promise.")

                if (deferredTips.isEmpty()) {
                    Text("No promised tips yet.")
                } else {
                    deferredTips.forEach { deferred ->
                        CompletionListCard {
                            Text(
                                text = "${formatCompletionAmount(deferred.amountPaise)} to ${deferred.providerName ?: "Provider"}",
                                fontWeight = FontWeight.Bold,
                            )
                            CompletionLine("Status", deferred.status)
                            deferred.dueAt?.let { CompletionLine("Due", formatCompletionDate(it) ?: it) }
                            deferred.message?.let { CompletionLine("Message", it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            isPayingDeferred = true
                                            try {
                                                paymentOrder = repository.payDeferredTip(session.accessToken, deferred.id)
                                                paymentStatus = null
                                                paymentImpact = null
                                                deferredTips = repository.getMyDeferredTips(session.accessToken)
                                                statusMessage = "Deferred tip converted into a payment order."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to pay the deferred tip right now."
                                            } finally {
                                                isPayingDeferred = false
                                            }
                                        }
                                    },
                                    enabled = !isPayingDeferred && deferred.status == "PROMISED",
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Pay now")
                                }
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            try {
                                                repository.cancelDeferredTip(session.accessToken, deferred.id)
                                                deferredTips = repository.getMyDeferredTips(session.accessToken)
                                                statusMessage = "Tip promise cancelled."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to cancel the tip promise right now."
                                            }
                                        }
                                    },
                                    enabled = deferred.status == "PROMISED",
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Cancel")
                                }
                            }
                        }
                    }
                }

                paymentOrder?.let { order ->
                    CompletionListCard {
                        Text("Deferred payment order", fontWeight = FontWeight.Bold)
                        CompletionLine("Title", order.title)
                        order.subtitle?.let { CompletionLine("Context", it) }
                        CompletionLine("Amount", formatCompletionAmount(order.amountPaise))
                        CompletionLine("Order ID", order.orderId)
                        paymentStatus?.let { CompletionLine("Status", it.status) }
                        paymentImpact?.let { Text(it.message) }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            if (order.isMockOrder) {
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            isVerifyingPayment = true
                                            try {
                                                customerRepository.verifyMockPayment(order.tipId, order.orderId)
                                                refreshPaymentState(order)
                                                deferredTips = repository.getMyDeferredTips(session.accessToken)
                                                statusMessage = "Mock payment verified."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to complete mock verification right now."
                                            } finally {
                                                isVerifyingPayment = false
                                            }
                                        }
                                    },
                                    enabled = !isVerifyingPayment,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Complete mock payment")
                                }
                            } else {
                                Button(
                                    onClick = {
                                        val launcher = checkoutLauncher
                                        if (launcher == null) {
                                            errorMessage = "This device cannot launch native checkout right now."
                                            return@Button
                                        }
                                        isLaunchingCheckout = true
                                        errorMessage = null
                                        launcher.launchCheckout(
                                            request = NativeCheckoutRequest(
                                                keyId = order.razorpayKeyId,
                                                orderId = order.orderId,
                                                amountPaise = order.amountPaise,
                                                currency = order.currency,
                                                title = "Fliq",
                                                description = order.title,
                                                contact = session.user.phone,
                                                email = session.user.email,
                                            ),
                                            callbacks = NativeCheckoutCallbacks(
                                                onSuccess = { success ->
                                                    coroutineScope.launch {
                                                        isLaunchingCheckout = false
                                                        isVerifyingPayment = true
                                                        try {
                                                            val payload = parsePaymentPayload(success.responseJson)
                                                            if (payload == null) {
                                                                errorMessage = "Checkout returned without a valid verification payload."
                                                            } else {
                                                                customerRepository.verifyPayment(
                                                                    tipId = order.tipId,
                                                                    orderId = payload.first ?: order.orderId,
                                                                    paymentId = payload.second,
                                                                    signature = payload.third,
                                                                )
                                                                refreshPaymentState(order)
                                                                deferredTips = repository.getMyDeferredTips(session.accessToken)
                                                                statusMessage = "Deferred payment verified."
                                                                errorMessage = null
                                                            }
                                                        } catch (error: AuthException) {
                                                            errorMessage = error.message
                                                        } catch (_: Exception) {
                                                            errorMessage = "Checkout returned, but verification failed."
                                                        } finally {
                                                            isVerifyingPayment = false
                                                        }
                                                    }
                                                },
                                                onError = { error ->
                                                    isLaunchingCheckout = false
                                                    errorMessage = error.description ?: "Unable to open checkout."
                                                },
                                                onExternalWallet = { _, _ ->
                                                    isLaunchingCheckout = false
                                                    statusMessage = "External wallet selected. Refresh the order status after payment completes."
                                                },
                                            ),
                                        )
                                    },
                                    enabled = !isLaunchingCheckout && !isVerifyingPayment,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (isVerifyingPayment) "Verifying..." else if (isLaunchingCheckout) "Opening..." else "Open checkout")
                                }
                            }
                            OutlinedButton(
                                onClick = {
                                    coroutineScope.launch {
                                        try {
                                            refreshPaymentState(order)
                                            statusMessage = "Deferred payment status refreshed."
                                            errorMessage = null
                                        } catch (error: AuthException) {
                                            errorMessage = error.message
                                        } catch (_: Exception) {
                                            errorMessage = "Unable to refresh payment status right now."
                                        }
                                    }
                                },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Refresh status")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ProviderCompletionSection(
    session: AuthSession,
    currentUpiVpa: String?,
    latestTips: List<ProviderTipItem>,
    onRefreshRequested: () -> Unit,
) {
    val repository = remember { ParityCompletionRepository() }
    val coroutineScope = rememberCoroutineScope()

    var bankUpiVpa by remember(currentUpiVpa) { mutableStateOf(currentUpiVpa.orEmpty()) }
    var bankAccountNumber by remember { mutableStateOf("") }
    var bankIfscCode by remember { mutableStateOf("") }
    var bankPan by remember { mutableStateOf("") }
    var aadhaarOrVid by remember { mutableStateOf("") }
    var ekycOtp by remember { mutableStateOf("") }
    var ekycInitiation by remember { mutableStateOf<NativeEkycInitiation?>(null) }
    var ekycProfile by remember { mutableStateOf<NativeEkycProfile?>(null) }
    var ekycStatus by remember { mutableStateOf<NativeEkycStatus?>(null) }
    var responseEmoji by remember { mutableStateOf("🙏") }
    var isSavingBank by remember { mutableStateOf(false) }
    var isInitiatingEkyc by remember { mutableStateOf(false) }
    var isVerifyingEkyc by remember { mutableStateOf(false) }
    var responseSubmittingTipId by remember { mutableStateOf<String?>(null) }
    var responseState by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var statusMessage by remember { mutableStateOf("Bank details, Aadhaar eKYC, and thank-you responses are now wired natively.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    suspend fun loadProviderCompletionData() {
        try {
            ekycStatus = repository.getEkycStatus(session.accessToken)
            latestTips.take(5).forEach { tip ->
                if (tip.status != "INITIATED" && tip.status != "FAILED") {
                    repository.getTipResponse(tip.id)?.emoji?.let { emoji ->
                        responseState = responseState + (tip.id to emoji)
                    }
                }
            }
        } catch (_: Exception) {
            // Keep provider tools usable even if completion hydration fails.
        }
    }

    LaunchedEffect(session.user.id, latestTips.map { it.id }.joinToString(",")) {
        loadProviderCompletionData()
    }

    Card(
        shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Provider completion",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(text = it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(text = statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            CompletionSectionCard(title = "Bank details") {
                OutlinedTextField(
                    value = bankUpiVpa,
                    onValueChange = { bankUpiVpa = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("UPI VPA") },
                )
                OutlinedTextField(
                    value = bankAccountNumber,
                    onValueChange = { bankAccountNumber = it.filter(Char::isDigit) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Bank account number") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = bankIfscCode,
                    onValueChange = { bankIfscCode = it.uppercase(Locale.US) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("IFSC code") },
                )
                OutlinedTextField(
                    value = bankPan,
                    onValueChange = { bankPan = it.uppercase(Locale.US) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("PAN") },
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            isSavingBank = true
                            try {
                                repository.saveBankDetails(
                                    accessToken = session.accessToken,
                                    upiVpa = bankUpiVpa.trim().takeIf { it.isNotBlank() },
                                    bankAccountNumber = bankAccountNumber.trim().takeIf { it.isNotBlank() },
                                    ifscCode = bankIfscCode.trim().takeIf { it.isNotBlank() },
                                    pan = bankPan.trim().takeIf { it.isNotBlank() },
                                )
                                statusMessage = "Bank details saved to the shared backend."
                                errorMessage = null
                                onRefreshRequested()
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to save bank details right now."
                            } finally {
                                isSavingBank = false
                            }
                        }
                    },
                    enabled = !isSavingBank,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (isSavingBank) "Saving..." else "Save bank details")
                }
            }

            CompletionSectionCard(title = "Aadhaar eKYC") {
                ekycStatus?.let {
                    CompletionLine("KYC status", it.kycStatus)
                    CompletionLine("Verified", if (it.kycVerified) "Yes" else "No")
                    it.kycMethod?.let { method -> CompletionLine("Method", method) }
                    it.kycCompletedAt?.let { date -> CompletionLine("Completed", formatCompletionDate(date) ?: date) }
                }
                OutlinedTextField(
                    value = aadhaarOrVid,
                    onValueChange = { aadhaarOrVid = it.filter(Char::isDigit).take(16) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Aadhaar or VID") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            if (aadhaarOrVid.trim().length < 12) {
                                errorMessage = "Enter a valid Aadhaar or VID."
                                return@launch
                            }
                            isInitiatingEkyc = true
                            try {
                                ekycInitiation = repository.initiateEkyc(session.accessToken, aadhaarOrVid.trim())
                                statusMessage = "OTP sent to ${ekycInitiation?.maskedPhone ?: "the Aadhaar-linked mobile"}."
                                errorMessage = null
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to initiate eKYC right now."
                            } finally {
                                isInitiatingEkyc = false
                            }
                        }
                    },
                    enabled = !isInitiatingEkyc,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (isInitiatingEkyc) "Sending OTP..." else "Initiate eKYC")
                }

                ekycInitiation?.let { initiation ->
                    CompletionLine("Session token", initiation.sessionToken)
                    CompletionLine("Masked phone", initiation.maskedPhone)
                    OutlinedTextField(
                        value = ekycOtp,
                        onValueChange = { ekycOtp = it.filter(Char::isDigit).take(6) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("OTP") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    )
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                if (ekycOtp.trim().length < 4) {
                                    errorMessage = "Enter the OTP received on the Aadhaar-linked mobile."
                                    return@launch
                                }
                                isVerifyingEkyc = true
                                try {
                                    ekycProfile = repository.verifyEkycOtp(
                                        accessToken = session.accessToken,
                                        sessionToken = initiation.sessionToken,
                                        otp = ekycOtp.trim(),
                                    )
                                    ekycStatus = repository.getEkycStatus(session.accessToken)
                                    statusMessage = "Aadhaar eKYC completed."
                                    errorMessage = null
                                    onRefreshRequested()
                                } catch (error: AuthException) {
                                    errorMessage = error.message
                                } catch (_: Exception) {
                                    errorMessage = "Unable to verify the eKYC OTP right now."
                                } finally {
                                    isVerifyingEkyc = false
                                }
                            }
                        },
                        enabled = !isVerifyingEkyc,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (isVerifyingEkyc) "Verifying..." else "Verify eKYC OTP")
                    }
                }

                ekycProfile?.let { profile ->
                    CompletionListCard {
                        Text("Verified profile", fontWeight = FontWeight.Bold)
                        CompletionLine("Name", profile.name)
                        CompletionLine("DOB", profile.dob)
                        CompletionLine("Gender", profile.gender)
                        CompletionLine("Address", profile.address)
                    }
                }
            }

            CompletionSectionCard(title = "Thank-you responses") {
                if (latestTips.isEmpty()) {
                    Text("Paid tips will appear here for emoji responses.")
                } else {
                    latestTips.take(5).forEach { tip ->
                        CompletionListCard {
                            Text(
                                text = "${formatCompletionAmount(tip.amountPaise)}${tip.customerName?.let { " from $it" } ?: ""}",
                                fontWeight = FontWeight.Bold,
                            )
                            CompletionLine("Status", tip.status)
                            responseState[tip.id]?.let { CompletionLine("Existing response", it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                OutlinedTextField(
                                    value = responseEmoji,
                                    onValueChange = { responseEmoji = it.take(2) },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true,
                                    label = { Text("Emoji") },
                                )
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            responseSubmittingTipId = tip.id
                                            try {
                                                val response = repository.createEmojiResponse(
                                                    accessToken = session.accessToken,
                                                    tipId = tip.id,
                                                    emoji = responseEmoji.ifBlank { "🙏" },
                                                )
                                                responseState = responseState + (tip.id to (response.emoji ?: "🙏"))
                                                statusMessage = "Thank-you response sent."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to send the thank-you response right now."
                                            } finally {
                                                responseSubmittingTipId = null
                                            }
                                        }
                                    },
                                    enabled = responseSubmittingTipId != tip.id && tip.status != "INITIATED" && tip.status != "FAILED" && responseState[tip.id] == null,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (responseSubmittingTipId == tip.id) "Sending..." else "Send")
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
fun BusinessExportSection(
    session: AuthSession,
    businessId: String?,
) {
    val repository = remember { ParityCompletionRepository() }
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    var csvPreview by remember { mutableStateOf<String?>(null) }
    var csvContent by remember { mutableStateOf<String?>(null) }
    var statusMessage by remember { mutableStateOf("Native business export is now available from this app.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isExporting by remember { mutableStateOf(false) }

    Card(
        shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Business export",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(text = it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(text = statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            Button(
                onClick = {
                    val currentBusinessId = businessId
                    if (currentBusinessId.isNullOrBlank()) {
                        errorMessage = "Register or load a business first."
                        return@Button
                    }
                    coroutineScope.launch {
                        isExporting = true
                        try {
                            val csv = repository.exportBusinessCsv(session.accessToken, currentBusinessId)
                            csvContent = csv
                            csvPreview = csv
                                .lineSequence()
                                .take(12)
                                .joinToString("\n")
                            statusMessage = "Loaded CSV export preview from the shared backend."
                            errorMessage = null
                        } catch (error: AuthException) {
                            errorMessage = error.message
                        } catch (_: Exception) {
                            errorMessage = "Unable to export business CSV right now."
                        } finally {
                            isExporting = false
                        }
                    }
                },
                enabled = !isExporting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isExporting) "Exporting..." else "Load CSV preview")
            }

            csvContent?.let { exportBody ->
                OutlinedButton(
                    onClick = {
                        context.startActivity(
                            Intent.createChooser(
                                Intent(Intent.ACTION_SEND).apply {
                                    type = "text/csv"
                                    putExtra(Intent.EXTRA_SUBJECT, "Fliq business export")
                                    putExtra(Intent.EXTRA_TEXT, exportBody)
                                },
                                "Share CSV export",
                            ),
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Share CSV export")
                }
            }

            csvPreview?.let {
                CompletionSectionCard(title = "Preview") {
                    Text(it, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun CompletionSectionCard(
    title: String,
    content: @Composable () -> Unit,
) {
    Card(
        shape = androidx.compose.foundation.shape.RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color(0xFFF8FAFD)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(text = title, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
private fun CompletionListCard(content: @Composable () -> Unit) {
    Card(
        shape = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun CompletionLine(
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, fontWeight = FontWeight.Medium)
    }
}

private fun formatCompletionAmount(amountPaise: Int): String {
    return "Rs ${amountPaise / 100}"
}

private fun formatCompletionDate(raw: String): String? {
    return runCatching {
        OffsetDateTime.parse(raw)
            .atZoneSameInstant(ZoneId.systemDefault())
            .format(DateTimeFormatter.ofPattern("dd MMM yyyy, hh:mm a"))
    }.getOrNull()
}
