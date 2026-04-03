package com.fliq.android.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fliq.android.data.AdvancedCollectionsRepository
import com.fliq.android.data.AuthException
import com.fliq.android.data.AuthSession
import com.fliq.android.data.CustomerRepository
import com.fliq.android.data.NativePaymentOrder
import com.fliq.android.data.NativeTipJar
import com.fliq.android.data.NativeTipJarStats
import com.fliq.android.data.NativeTipPool
import com.fliq.android.data.NativeTipPoolEarnings
import com.fliq.android.data.ProviderRepository
import com.fliq.android.payments.NativeCheckoutCallbacks
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.payments.NativeCheckoutRequest
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlinx.coroutines.launch
import org.json.JSONObject

private val nativeJarEvents = listOf("WEDDING", "RESTAURANT", "SALON", "EVENT", "CUSTOM")
private val nativePoolSplitMethods = listOf("EQUAL", "PERCENTAGE", "ROLE_BASED")

@Composable
fun CustomerJarSection(
    session: AuthSession,
) {
    val repository = remember { AdvancedCollectionsRepository() }
    val customerRepository = remember { CustomerRepository() }
    val checkoutLauncher = LocalContext.current as? NativeCheckoutLauncher
    val coroutineScope = rememberCoroutineScope()

    var shortCode by remember { mutableStateOf("") }
    var amountRupees by remember { mutableStateOf("100") }
    var message by remember { mutableStateOf("") }
    var rating by remember { mutableStateOf("5") }
    var resolvedJar by remember { mutableStateOf<NativeTipJar?>(null) }
    var paymentOrder by remember { mutableStateOf<NativePaymentOrder?>(null) }
    var paymentStatus by remember { mutableStateOf<com.fliq.android.data.TipStatusSnapshot?>(null) }
    var paymentImpact by remember { mutableStateOf<com.fliq.android.data.TipImpactSnapshot?>(null) }
    var statusMessage by remember { mutableStateOf("Tip jars can now be resolved and paid natively from Android.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isResolving by remember { mutableStateOf(false) }
    var isCreatingTip by remember { mutableStateOf(false) }
    var isLaunchingCheckout by remember { mutableStateOf(false) }
    var isVerifyingPayment by remember { mutableStateOf(false) }
    var isRefreshingStatus by remember { mutableStateOf(false) }

    suspend fun refreshPayment(order: NativePaymentOrder) {
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

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Tip jars",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            AdvancedSectionCard(title = "Resolve a jar") {
                OutlinedTextField(
                    value = shortCode,
                    onValueChange = { shortCode = it.trim() },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Jar short code") },
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                if (shortCode.isBlank()) {
                                    errorMessage = "Enter a tip jar short code first."
                                    return@launch
                                }
                                isResolving = true
                                try {
                                    resolvedJar = repository.resolveTipJar(shortCode)
                                    paymentOrder = null
                                    paymentStatus = null
                                    paymentImpact = null
                                    statusMessage = "Resolved tip jar ${resolvedJar?.name ?: shortCode}."
                                    errorMessage = null
                                } catch (error: AuthException) {
                                    errorMessage = error.message
                                } catch (_: Exception) {
                                    errorMessage = "Unable to resolve that tip jar right now."
                                } finally {
                                    isResolving = false
                                }
                            }
                        },
                        enabled = !isResolving,
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(if (isResolving) "Resolving..." else "Resolve")
                    }
                    OutlinedButton(
                        onClick = {
                            resolvedJar = null
                            paymentOrder = null
                            paymentStatus = null
                            paymentImpact = null
                            shortCode = ""
                            statusMessage = "Tip jar state cleared on this device."
                            errorMessage = null
                        },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text("Clear")
                    }
                }

                resolvedJar?.let { jar ->
                    AdvancedListCard {
                        Text(jar.name, fontWeight = FontWeight.Bold)
                        AdvancedLine("Event", jar.eventType.replace('_', ' '))
                        AdvancedLine("Members", jar.members.size.toString())
                        AdvancedLine("Collected", advancedAmountText(jar.totalCollectedPaise))
                        jar.targetAmountPaise?.let { AdvancedLine("Target", advancedAmountText(it)) }
                        jar.shareableUrl?.let { AdvancedLine("Shareable URL", it) }
                    }
                }
            }

            AdvancedSectionCard(title = "Contribute to jar") {
                OutlinedTextField(
                    value = amountRupees,
                    onValueChange = { amountRupees = it.filter(Char::isDigit) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Amount in rupees") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = message,
                    onValueChange = { message = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Message") },
                    minLines = 2,
                )
                OutlinedTextField(
                    value = rating,
                    onValueChange = { rating = it.filter(Char::isDigit).take(1) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Rating 1-5") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            val jar = resolvedJar
                            val amount = amountRupees.toIntOrNull()
                            if (jar == null) {
                                errorMessage = "Resolve a tip jar first."
                                return@launch
                            }
                            if (amount == null || amount < 10) {
                                errorMessage = "Minimum tip jar amount is Rs 10."
                                return@launch
                            }
                            isCreatingTip = true
                            try {
                                paymentOrder = repository.createAuthenticatedJarTip(
                                    accessToken = session.accessToken,
                                    shortCode = jar.shortCode,
                                    amountPaise = amount * 100,
                                    message = message.trim().takeIf { it.isNotBlank() },
                                    rating = rating.toIntOrNull()?.coerceIn(1, 5),
                                )
                                paymentStatus = paymentOrder?.let {
                                    com.fliq.android.data.TipStatusSnapshot(
                                        tipId = it.tipId,
                                        status = "INITIATED",
                                        updatedAt = null,
                                    )
                                }
                                paymentImpact = null
                                statusMessage = if (paymentOrder?.isMockOrder == true) {
                                    "Tip jar order created. Complete the mock payment from this screen."
                                } else {
                                    "Tip jar order created. Open native checkout to continue."
                                }
                                errorMessage = null
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to create the tip jar payment right now."
                            } finally {
                                isCreatingTip = false
                            }
                        }
                    },
                    enabled = !isCreatingTip,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (isCreatingTip) "Creating..." else "Create jar payment")
                }

                paymentOrder?.let { order ->
                    AdvancedListCard {
                        Text(order.title, fontWeight = FontWeight.Bold)
                        AdvancedLine("Order ID", order.orderId)
                        AdvancedLine("Amount", advancedAmountText(order.amountPaise))
                        paymentStatus?.let { AdvancedLine("Status", it.status) }
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
                                                customerRepository.verifyMockPayment(
                                                    tipId = order.tipId,
                                                    orderId = order.orderId,
                                                )
                                                refreshPayment(order)
                                                statusMessage = "Mock tip jar payment completed."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to verify the mock tip jar payment right now."
                                            } finally {
                                                isVerifyingPayment = false
                                            }
                                        }
                                    },
                                    enabled = !isVerifyingPayment,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (isVerifyingPayment) "Verifying..." else "Complete mock payment")
                                }
                            } else {
                                Button(
                                    onClick = {
                                        val launcher = checkoutLauncher
                                        if (launcher == null) {
                                            errorMessage = "Native checkout is not available in this host."
                                            return@Button
                                        }
                                        if (order.razorpayKeyId.isBlank()) {
                                            errorMessage = "Razorpay key is missing from the backend response."
                                            return@Button
                                        }
                                        errorMessage = null
                                        isLaunchingCheckout = true
                                        launcher.launchCheckout(
                                            request = NativeCheckoutRequest(
                                                keyId = order.razorpayKeyId,
                                                orderId = order.orderId,
                                                amountPaise = order.amountPaise,
                                                currency = order.currency,
                                                title = "Fliq",
                                                description = "Contribution to ${order.title}",
                                                contact = session.user.phone,
                                                email = session.user.email,
                                            ),
                                            callbacks = NativeCheckoutCallbacks(
                                                onSuccess = { result ->
                                                    coroutineScope.launch {
                                                        isLaunchingCheckout = false
                                                        isVerifyingPayment = true
                                                        try {
                                                            val payload = parsePaymentPayload(result.responseJson)
                                                            if (payload == null) {
                                                                errorMessage = "Checkout returned without a complete payment payload."
                                                            } else {
                                                                customerRepository.verifyPayment(
                                                                    tipId = order.tipId,
                                                                    orderId = payload.first ?: order.orderId,
                                                                    paymentId = payload.second,
                                                                    signature = payload.third,
                                                                )
                                                                refreshPayment(order)
                                                                statusMessage = "Tip jar payment verified on the shared backend."
                                                                errorMessage = null
                                                            }
                                                        } catch (error: AuthException) {
                                                            errorMessage = error.message
                                                        } catch (_: Exception) {
                                                            errorMessage = "Checkout returned, but verification failed on this device."
                                                        } finally {
                                                            isVerifyingPayment = false
                                                        }
                                                    }
                                                },
                                                onError = { result ->
                                                    isLaunchingCheckout = false
                                                    errorMessage = "Checkout failed (${result.code}): ${result.description ?: "Unknown error"}"
                                                },
                                                onExternalWallet = { walletName, _ ->
                                                    isLaunchingCheckout = false
                                                    statusMessage = "External wallet selected${walletName?.let { ": $it" } ?: ""}. Refresh status after payment completes."
                                                },
                                            ),
                                        )
                                    },
                                    enabled = !isLaunchingCheckout && !isVerifyingPayment,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(if (isLaunchingCheckout) "Opening..." else "Open checkout")
                                }
                            }
                            OutlinedButton(
                                onClick = {
                                    coroutineScope.launch {
                                        isRefreshingStatus = true
                                        try {
                                            refreshPayment(order)
                                            statusMessage = "Fetched the latest tip jar payment status."
                                            errorMessage = null
                                        } catch (error: AuthException) {
                                            errorMessage = error.message
                                        } catch (_: Exception) {
                                            errorMessage = "Unable to refresh the tip jar payment right now."
                                        } finally {
                                            isRefreshingStatus = false
                                        }
                                    }
                                },
                                enabled = !isRefreshingStatus,
                                modifier = Modifier.weight(1f),
                            ) {
                                Text(if (isRefreshingStatus) "Refreshing..." else "Refresh")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ProviderAvatarSection(
    session: AuthSession,
    currentAvatarUrl: String?,
    onRefreshRequested: () -> Unit,
) {
    val repository = remember { ProviderRepository() }
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var statusMessage by remember { mutableStateOf("Native provider avatar upload is now available on Android.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isUploading by remember { mutableStateOf(false) }

    val pickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) {
            return@rememberLauncherForActivityResult
        }
        coroutineScope.launch {
            isUploading = true
            try {
                val compressed = compressAvatarForUpload(context, uri)
                if (compressed == null) {
                    errorMessage = "Unable to prepare that image for upload."
                } else {
                    repository.uploadAvatar(
                        accessToken = session.accessToken,
                        imageBytes = compressed,
                    )
                    statusMessage = "Provider avatar uploaded to the shared backend."
                    errorMessage = null
                    onRefreshRequested()
                }
            } catch (error: AuthException) {
                errorMessage = error.message
            } catch (_: Exception) {
                errorMessage = "Unable to upload the provider avatar right now."
            } finally {
                isUploading = false
            }
        }
    }

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Avatar",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            currentAvatarUrl?.let {
                AdvancedLine("Current avatar", if (it.length > 48) "${it.take(48)}..." else it)
            } ?: Text("No provider avatar uploaded yet.")

            Text("The backend accepts a compact image, so the app compresses uploads automatically.")

            Button(
                onClick = { pickerLauncher.launch("image/*") },
                enabled = !isUploading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isUploading) "Uploading..." else "Choose avatar image")
            }
        }
    }
}

@Composable
fun ProviderCollectionsSection(
    session: AuthSession,
) {
    val repository = remember { AdvancedCollectionsRepository() }
    val coroutineScope = rememberCoroutineScope()

    var jars by remember { mutableStateOf(emptyList<NativeTipJar>()) }
    var pools by remember { mutableStateOf(emptyList<NativeTipPool>()) }
    var selectedJar by remember { mutableStateOf<NativeTipJar?>(null) }
    var selectedPool by remember { mutableStateOf<NativeTipPool?>(null) }
    var jarStats by remember { mutableStateOf<NativeTipJarStats?>(null) }
    var poolEarnings by remember { mutableStateOf<NativeTipPoolEarnings?>(null) }
    var statusMessage by remember { mutableStateOf("Tip jars and tip pools are now available natively on Android.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var isSavingJar by remember { mutableStateOf(false) }
    var isSavingPool by remember { mutableStateOf(false) }

    var jarName by remember { mutableStateOf("") }
    var jarDescription by remember { mutableStateOf("") }
    var jarEventType by remember { mutableStateOf(nativeJarEvents.last()) }
    var jarTargetRupees by remember { mutableStateOf("") }
    var jarMemberProviderId by remember { mutableStateOf("") }
    var jarMemberSplit by remember { mutableStateOf("25") }
    var jarMemberRole by remember { mutableStateOf("") }

    var poolName by remember { mutableStateOf("") }
    var poolDescription by remember { mutableStateOf("") }
    var poolSplitMethod by remember { mutableStateOf(nativePoolSplitMethods.first()) }
    var poolMemberPhone by remember { mutableStateOf("") }
    var poolMemberRole by remember { mutableStateOf("waiter") }
    var poolMemberSplit by remember { mutableStateOf("25") }

    suspend fun refreshCollections() {
        isLoading = true
        try {
            val jarCollection = repository.getMyTipJars(session.accessToken)
            val poolCollection = repository.getMyTipPools(session.accessToken)
            jars = jarCollection.owned + jarCollection.memberOf
            pools = poolCollection.owned + poolCollection.memberOf
            selectedJar = selectedJar?.id?.let { selectedId -> jars.firstOrNull { it.id == selectedId } }
            selectedPool = selectedPool?.id?.let { selectedId -> pools.firstOrNull { it.id == selectedId } }
            statusMessage = "Loaded native tip jars and tip pools from the shared backend."
            errorMessage = null
        } catch (error: AuthException) {
            errorMessage = error.message
        } catch (_: Exception) {
            errorMessage = "Unable to load tip jars or tip pools right now."
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(session.user.id) {
        refreshCollections()
    }

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = "Shared collections",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )

            errorMessage?.let { Text(it, color = androidx.compose.ui.graphics.Color(0xFFB42318)) }
                ?: Text(statusMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)

            OutlinedButton(
                onClick = { coroutineScope.launch { refreshCollections() } },
                enabled = !isLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isLoading) "Refreshing..." else "Refresh tip jars and pools")
            }

            AdvancedSectionCard(title = "Create a tip jar") {
                OutlinedTextField(
                    value = jarName,
                    onValueChange = { jarName = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Jar name") },
                )
                ChoiceRow(
                    label = "Event type",
                    options = nativeJarEvents,
                    selected = jarEventType,
                    onSelected = { jarEventType = it },
                )
                OutlinedTextField(
                    value = jarDescription,
                    onValueChange = { jarDescription = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Description") },
                    minLines = 2,
                )
                OutlinedTextField(
                    value = jarTargetRupees,
                    onValueChange = { jarTargetRupees = it.filter(Char::isDigit) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Target amount in rupees") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            if (jarName.isBlank()) {
                                errorMessage = "Tip jar name is required."
                                return@launch
                            }
                            isSavingJar = true
                            try {
                                val created = repository.createTipJar(
                                    accessToken = session.accessToken,
                                    name = jarName.trim(),
                                    eventType = jarEventType,
                                    description = jarDescription.trim().takeIf { it.isNotBlank() },
                                    targetAmountPaise = jarTargetRupees.toIntOrNull()?.takeIf { it > 0 }?.times(100),
                                )
                                jarName = ""
                                jarDescription = ""
                                jarTargetRupees = ""
                                selectedJar = created
                                refreshCollections()
                                statusMessage = "Tip jar created natively."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to create the tip jar right now."
                            } finally {
                                isSavingJar = false
                            }
                        }
                    },
                    enabled = !isSavingJar,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (isSavingJar) "Creating..." else "Create tip jar")
                }

                if (jars.isEmpty()) {
                    Text("No tip jars yet.")
                } else {
                    jars.take(6).forEach { jar ->
                        AdvancedListCard {
                            Text(jar.name, fontWeight = FontWeight.Bold)
                            AdvancedLine("Short code", jar.shortCode)
                            AdvancedLine("Members", jar.members.size.toString())
                            AdvancedLine("Contributions", jar.contributionCount.toString())
                            jar.shareableUrl?.let { AdvancedLine("Shareable URL", it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            try {
                                                selectedJar = repository.getTipJar(session.accessToken, jar.id)
                                                jarStats = repository.getTipJarStats(session.accessToken, jar.id)
                                                statusMessage = "Loaded tip jar details for ${jar.name}."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to load that tip jar right now."
                                            }
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Open")
                                }
                                if (jar.isActive) {
                                    OutlinedButton(
                                        onClick = {
                                            coroutineScope.launch {
                                                try {
                                                    repository.closeTipJar(session.accessToken, jar.id)
                                                    refreshCollections()
                                                    statusMessage = "Tip jar closed."
                                                    errorMessage = null
                                                } catch (error: AuthException) {
                                                    errorMessage = error.message
                                                } catch (_: Exception) {
                                                    errorMessage = "Unable to close that tip jar right now."
                                                }
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                    ) {
                                        Text("Close")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            selectedJar?.let { jar ->
                AdvancedSectionCard(title = "Manage tip jar") {
                    AdvancedLine("Selected jar", jar.name)
                    jarStats?.let {
                        AdvancedLine("Collected", advancedAmountText(it.totalCollectedPaise))
                        AdvancedLine("Contribution count", it.contributionCount.toString())
                    }
                    OutlinedTextField(
                        value = jarMemberProviderId,
                        onValueChange = { jarMemberProviderId = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Member provider ID") },
                    )
                    OutlinedTextField(
                        value = jarMemberSplit,
                        onValueChange = { jarMemberSplit = it.filter { ch -> ch.isDigit() || ch == '.' } },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Split percentage") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    )
                    OutlinedTextField(
                        value = jarMemberRole,
                        onValueChange = { jarMemberRole = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Role label") },
                    )
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                val split = jarMemberSplit.toDoubleOrNull()
                                if (jarMemberProviderId.isBlank() || split == null) {
                                    errorMessage = "Member provider ID and split percentage are required."
                                    return@launch
                                }
                                try {
                                    repository.addTipJarMember(
                                        accessToken = session.accessToken,
                                        jarId = jar.id,
                                        providerId = jarMemberProviderId.trim(),
                                        splitPercentage = split,
                                        roleLabel = jarMemberRole.trim().takeIf { it.isNotBlank() },
                                    )
                                    selectedJar = repository.getTipJar(session.accessToken, jar.id)
                                    jarStats = repository.getTipJarStats(session.accessToken, jar.id)
                                    refreshCollections()
                                    jarMemberProviderId = ""
                                    jarMemberSplit = "25"
                                    jarMemberRole = ""
                                    statusMessage = "Tip jar member added."
                                    errorMessage = null
                                } catch (error: AuthException) {
                                    errorMessage = error.message
                                } catch (_: Exception) {
                                    errorMessage = "Unable to add that tip jar member right now."
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Add tip jar member")
                    }
                    if (jar.members.isEmpty()) {
                        Text("No active members yet.")
                    } else {
                        jar.members.forEach { member ->
                            AdvancedListCard {
                                Text(member.providerName ?: member.providerId, fontWeight = FontWeight.Bold)
                                member.roleLabel?.let { AdvancedLine("Role", it) }
                                AdvancedLine("Split", "${member.splitPercentage}%")
                                if (member.providerId != session.user.id && jar.isActive) {
                                    OutlinedButton(
                                        onClick = {
                                            coroutineScope.launch {
                                                try {
                                                    repository.removeTipJarMember(session.accessToken, jar.id, member.id)
                                                    selectedJar = repository.getTipJar(session.accessToken, jar.id)
                                                    jarStats = repository.getTipJarStats(session.accessToken, jar.id)
                                                    refreshCollections()
                                                    statusMessage = "Tip jar member removed."
                                                    errorMessage = null
                                                } catch (error: AuthException) {
                                                    errorMessage = error.message
                                                } catch (_: Exception) {
                                                    errorMessage = "Unable to remove that tip jar member right now."
                                                }
                                            }
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Text("Remove member")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            AdvancedSectionCard(title = "Create a tip pool") {
                OutlinedTextField(
                    value = poolName,
                    onValueChange = { poolName = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Pool name") },
                )
                ChoiceRow(
                    label = "Split method",
                    options = nativePoolSplitMethods,
                    selected = poolSplitMethod,
                    onSelected = { poolSplitMethod = it },
                )
                OutlinedTextField(
                    value = poolDescription,
                    onValueChange = { poolDescription = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Description") },
                    minLines = 2,
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            if (poolName.isBlank()) {
                                errorMessage = "Tip pool name is required."
                                return@launch
                            }
                            isSavingPool = true
                            try {
                                val created = repository.createTipPool(
                                    accessToken = session.accessToken,
                                    name = poolName.trim(),
                                    splitMethod = poolSplitMethod,
                                    description = poolDescription.trim().takeIf { it.isNotBlank() },
                                )
                                poolName = ""
                                poolDescription = ""
                                selectedPool = created
                                refreshCollections()
                                statusMessage = "Tip pool created natively."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to create the tip pool right now."
                            } finally {
                                isSavingPool = false
                            }
                        }
                    },
                    enabled = !isSavingPool,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (isSavingPool) "Creating..." else "Create tip pool")
                }

                if (pools.isEmpty()) {
                    Text("No tip pools yet.")
                } else {
                    pools.take(6).forEach { pool ->
                        AdvancedListCard {
                            Text(pool.name, fontWeight = FontWeight.Bold)
                            AdvancedLine("Split method", pool.splitMethod)
                            AdvancedLine("Members", pool.members.size.toString())
                            AdvancedLine("Tips", pool.tipCount.toString())
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            try {
                                                selectedPool = repository.getTipPool(session.accessToken, pool.id)
                                                poolEarnings = repository.getTipPoolEarnings(session.accessToken, pool.id)
                                                statusMessage = "Loaded tip pool details for ${pool.name}."
                                                errorMessage = null
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to load that tip pool right now."
                                            }
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Open")
                                }
                                if (pool.isActive) {
                                    OutlinedButton(
                                        onClick = {
                                            coroutineScope.launch {
                                                try {
                                                    repository.deactivateTipPool(session.accessToken, pool.id)
                                                    refreshCollections()
                                                    statusMessage = "Tip pool deactivated."
                                                    errorMessage = null
                                                } catch (error: AuthException) {
                                                    errorMessage = error.message
                                                } catch (_: Exception) {
                                                    errorMessage = "Unable to deactivate that tip pool right now."
                                                }
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                    ) {
                                        Text("Deactivate")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            selectedPool?.let { pool ->
                AdvancedSectionCard(title = "Manage tip pool") {
                    AdvancedLine("Selected pool", pool.name)
                    poolEarnings?.let {
                        AdvancedLine("Total earnings", advancedAmountText(it.totalEarningsPaise))
                        AdvancedLine("Tip count", it.tipCount.toString())
                    }
                    OutlinedTextField(
                        value = poolMemberPhone,
                        onValueChange = { poolMemberPhone = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Member phone") },
                    )
                    OutlinedTextField(
                        value = poolMemberRole,
                        onValueChange = { poolMemberRole = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Role") },
                    )
                    OutlinedTextField(
                        value = poolMemberSplit,
                        onValueChange = { poolMemberSplit = it.filter { ch -> ch.isDigit() || ch == '.' } },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Split percentage") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    )
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                try {
                                    repository.addTipPoolMember(
                                        accessToken = session.accessToken,
                                        poolId = pool.id,
                                        phone = poolMemberPhone.trim(),
                                        role = poolMemberRole.trim().takeIf { it.isNotBlank() },
                                        splitPercentage = poolMemberSplit.toDoubleOrNull(),
                                    )
                                    selectedPool = repository.getTipPool(session.accessToken, pool.id)
                                    poolEarnings = repository.getTipPoolEarnings(session.accessToken, pool.id)
                                    refreshCollections()
                                    poolMemberPhone = ""
                                    poolMemberRole = "waiter"
                                    poolMemberSplit = "25"
                                    statusMessage = "Tip pool member added."
                                    errorMessage = null
                                } catch (error: AuthException) {
                                    errorMessage = error.message
                                } catch (_: Exception) {
                                    errorMessage = "Unable to add that tip pool member right now."
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Add tip pool member")
                    }
                    if (pool.members.isEmpty()) {
                        Text("No active pool members yet.")
                    } else {
                        pool.members.forEach { member ->
                            AdvancedListCard {
                                Text(member.userName ?: member.userPhone ?: member.userId, fontWeight = FontWeight.Bold)
                                member.role?.let { AdvancedLine("Role", it) }
                                member.splitPercentage?.let { AdvancedLine("Split", "$it%") }
                                if (member.userId != session.user.id && pool.isActive) {
                                    OutlinedButton(
                                        onClick = {
                                            coroutineScope.launch {
                                                try {
                                                    repository.removeTipPoolMember(session.accessToken, pool.id, member.id)
                                                    selectedPool = repository.getTipPool(session.accessToken, pool.id)
                                                    poolEarnings = repository.getTipPoolEarnings(session.accessToken, pool.id)
                                                    refreshCollections()
                                                    statusMessage = "Tip pool member removed."
                                                    errorMessage = null
                                                } catch (error: AuthException) {
                                                    errorMessage = error.message
                                                } catch (_: Exception) {
                                                    errorMessage = "Unable to remove that tip pool member right now."
                                                }
                                            }
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Text("Remove member")
                                    }
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
private fun AdvancedSectionCard(
    title: String,
    content: @Composable () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color(0xFFF8FAFD)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
private fun AdvancedListCard(content: @Composable () -> Unit) {
    Card(
        shape = RoundedCornerShape(18.dp),
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
private fun AdvancedLine(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun ChoiceRow(
    label: String,
    options: List<String>,
    selected: String,
    onSelected: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        options.chunked(3).forEach { rowOptions ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowOptions.forEach { option ->
                    val isSelected = option == selected
                    val buttonModifier = Modifier.weight(1f)
                    if (isSelected) {
                        Button(
                            onClick = { onSelected(option) },
                            modifier = buttonModifier,
                        ) {
                            Text(option.replace('_', ' '))
                        }
                    } else {
                        OutlinedButton(
                            onClick = { onSelected(option) },
                            modifier = buttonModifier,
                        ) {
                            Text(option.replace('_', ' '))
                        }
                    }
                }
            }
        }
    }
}

private fun advancedAmountText(amountPaise: Int): String = "Rs ${amountPaise / 100}"

private fun compressAvatarForUpload(
    context: Context,
    uri: Uri,
): ByteArray? {
    val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.contentResolver.openInputStream(uri)?.use { input ->
        BitmapFactory.decodeStream(input, null, boundsOptions)
    } ?: return null

    val maxDimension = 256
    var sampleSize = 1
    while (boundsOptions.outWidth / sampleSize > maxDimension || boundsOptions.outHeight / sampleSize > maxDimension) {
        sampleSize *= 2
    }

    val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize.coerceAtLeast(1) }
    val bitmap = context.contentResolver.openInputStream(uri)?.use { input ->
        BitmapFactory.decodeStream(input, null, decodeOptions)
    } ?: return null

    return bitmap.toCompressedAvatarBytes()
}

private fun Bitmap.toCompressedAvatarBytes(): ByteArray? {
    val qualitySteps = listOf(82, 72, 62, 52, 42, 32)
    val variants = listOf(256, 192, 160, 128)

    for (dimension in variants) {
        val scaled = Bitmap.createScaledBitmap(
            this,
            if (width >= height) dimension else (dimension * width / height).coerceAtLeast(1),
            if (height > width) dimension else (dimension * height / width).coerceAtLeast(1),
            true,
        )
        for (quality in qualitySteps) {
            val output = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, output)
            if (output.size() <= 72_000) {
                return output.toByteArray()
            }
        }
    }

    val fallback = ByteArrayOutputStream()
    compress(Bitmap.CompressFormat.JPEG, 24, fallback)
    return fallback.toByteArray().takeIf { it.size <= 72_000 }
}
