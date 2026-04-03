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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fliq.android.data.AuthSession
import com.fliq.android.data.AuthUser
import com.fliq.android.data.CreatedTipOrder
import com.fliq.android.data.CustomerTipHistoryItem
import com.fliq.android.data.NativeRole
import com.fliq.android.data.PendingTipDraft
import com.fliq.android.data.ProviderProfile
import com.fliq.android.data.ProviderSearchResult
import com.fliq.android.data.TipEntryContext
import com.fliq.android.data.TipImpactSnapshot
import com.fliq.android.data.TipIntentOption
import com.fliq.android.data.TipStatusSnapshot
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.scanning.NativeQrScannerLauncher

// ═══════════════════════════════════════════════════════════════════════
// Data classes used by UI components
// ═══════════════════════════════════════════════════════════════════════

data class RoleCard(
    val role: NativeRole,
    val title: String,
    val subtitle: String,
    val accent: Color,
    val actionLabel: String,
)

private val roles = listOf(
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

private fun roleMeta(role: NativeRole): RoleCard = roles.first { it.role == role }

private fun requiresNotificationPermission(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
    return ContextCompat.checkSelfPermission(
        context, Manifest.permission.POST_NOTIFICATIONS,
    ) != PackageManager.PERMISSION_GRANTED
}

// ═══════════════════════════════════════════════════════════════════════
// Root composable — thin shell delegating to FliqViewModel
// ═══════════════════════════════════════════════════════════════════════

@Composable
fun FliqAndroidApp() {
    val context = LocalContext.current
    val vm: FliqViewModel = viewModel {
        FliqViewModel(context.applicationContext)
    }
    val checkoutLauncher = remember(context) { context as? NativeCheckoutLauncher }
    val scannerLauncher = remember(context) { context as? NativeQrScannerLauncher }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (!granted) {
            vm.statusMessage = "Notifications stay off until Android notification permission is granted."
            return@rememberLauncherForActivityResult
        }
        vm.syncPushTokenIfPossible()
    }

    // Restore session on first launch
    LaunchedEffect(Unit) { vm.restoreSession() }

    // Request notification permission and sync token when session changes
    LaunchedEffect(vm.session?.accessToken) {
        vm.session?.let {
            if (requiresNotificationPermission(context)) {
                if (!vm.hasRequestedNotificationPermission) {
                    vm.hasRequestedNotificationPermission = true
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
                return@let
            }
            vm.syncPushTokenIfPossible()
        }
    }

    // Auto-load customer data when reaching home
    LaunchedEffect(vm.session?.user?.id, vm.stage) {
        vm.loadCustomerHomeDataIfNeeded()
    }

    // ── UI ───────────────────────────────────────────────────────────
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
                vm.isLoading && vm.stage == AuthStage.ROLE_PICKER -> {
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

                        when (vm.stage) {
                            AuthStage.ROLE_PICKER -> {
                                roles.forEach { role ->
                                    RoleEntryCard(role = role) { vm.selectRole(role.role) }
                                }
                            }
                            AuthStage.CREDENTIAL -> {
                                val role = vm.selectedRole ?: NativeRole.CUSTOMER
                                CredentialCard(
                                    role = roleMeta(role),
                                    credential = vm.credential,
                                    onCredentialChange = { vm.credential = it },
                                    onBack = { vm.backToRolePicker() },
                                    onSubmit = { vm.sendCode() },
                                )
                            }
                            AuthStage.OTP -> {
                                val role = vm.selectedRole ?: NativeRole.CUSTOMER
                                OtpCard(
                                    role = roleMeta(role),
                                    credential = vm.credential,
                                    code = vm.code,
                                    onCodeChange = { vm.code = it.take(6) },
                                    onBack = { vm.backToCredential() },
                                    onResend = { vm.resendCode() },
                                    onVerify = { vm.verifyCode() },
                                )
                            }
                            AuthStage.HOME -> {
                                vm.session?.let {
                                    when (vm.homeRole(it)) {
                                        NativeRole.CUSTOMER -> CustomerHomeCard(
                                            session = it,
                                            providerQuery = vm.providerQuery,
                                            onProviderQueryChange = { vm.providerQuery = it },
                                            providerResults = vm.providerResults,
                                            selectedProvider = vm.selectedProvider,
                                            selectedEntryContext = vm.selectedEntryContext,
                                            resolutionInput = vm.resolutionInput,
                                            onResolutionInputChange = { vm.resolutionInput = it },
                                            amountRupees = vm.amountRupees,
                                            onAmountRupeesChange = { vm.amountRupees = it.filter(Char::isDigit) },
                                            selectedIntent = vm.selectedIntent,
                                            onIntentSelected = { vm.selectedIntent = it },
                                            tipMessage = vm.tipMessage,
                                            onTipMessageChange = { vm.tipMessage = it },
                                            selectedRating = vm.selectedRating,
                                            onRatingSelected = { vm.selectedRating = it },
                                            createdTipOrder = vm.createdTipOrder,
                                            tipStatus = vm.tipStatus,
                                            tipImpact = vm.tipImpact,
                                            customerProfile = vm.currentUserProfile ?: vm.session?.user,
                                            customerHistory = vm.customerHistory,
                                            pendingTipDrafts = vm.pendingTipDrafts,
                                            profileName = vm.profileName,
                                            onProfileNameChange = { vm.profileName = it },
                                            profileEmail = vm.profileEmail,
                                            onProfileEmailChange = { vm.profileEmail = it },
                                            profilePhone = vm.profilePhone,
                                            onProfilePhoneChange = { vm.profilePhone = it },
                                            profileLanguage = vm.profileLanguage,
                                            onProfileLanguageChange = { vm.profileLanguage = it },
                                            isSearchingProviders = vm.isSearchingProviders,
                                            isLoadingProvider = vm.isLoadingProvider,
                                            isSubmittingTip = vm.isSubmittingTip,
                                            isResolvingQr = vm.isResolvingQr,
                                            isResolvingPaymentLink = vm.isResolvingPaymentLink,
                                            isRefreshingTipStatus = vm.isRefreshingTipStatus,
                                            isCompletingMockPayment = vm.isCompletingMockPayment,
                                            isLaunchingCheckout = vm.isLaunchingCheckout,
                                            isVerifyingCheckout = vm.isVerifyingCheckout,
                                            isLoadingCustomerProfile = vm.isLoadingCustomerProfile,
                                            isLoadingCustomerHistory = vm.isLoadingCustomerHistory,
                                            isSavingCustomerProfile = vm.isSavingCustomerProfile,
                                            isLoadingTipImpact = vm.isLoadingTipImpact,
                                            isSyncingPendingTips = vm.isSyncingPendingTips,
                                            isLaunchingScanner = vm.isLaunchingScanner,
                                            onSearchProviders = { vm.searchProviders() },
                                            onSelectProvider = { vm.selectProvider(it) },
                                            onScanQr = { vm.scanQr(scannerLauncher) },
                                            onResolveQr = { vm.resolveQr() },
                                            onResolvePaymentLink = { vm.resolvePaymentLink() },
                                            onCreateTip = { vm.createTip() },
                                            onRefreshTipStatus = { vm.refreshTipStatus() },
                                            onCompleteMockPayment = { vm.completeMockPayment() },
                                            onOpenCheckout = { vm.openCheckout(checkoutLauncher) },
                                            onRefreshCustomerProfile = { vm.refreshCustomerProfile() },
                                            onRefreshCustomerHistory = { vm.refreshCustomerHistory() },
                                            onRefreshTipImpact = { vm.refreshTipImpact() },
                                            onSyncPendingTips = { vm.syncPendingTips() },
                                            onDiscardPendingTip = { vm.discardPendingTip(it) },
                                            onSaveCustomerProfile = { vm.saveCustomerProfile() },
                                            onUsePresetAmount = { vm.usePresetAmount(it) },
                                            onLogout = { vm.logout() },
                                        )
                                        NativeRole.BUSINESS -> BusinessHomeCard(
                                            session = it,
                                            onLogout = { vm.logout() },
                                        )
                                        NativeRole.PROVIDER -> ProviderHomeCard(
                                            session = it,
                                            onLogout = { vm.logout() },
                                        )
                                    }
                                }
                            }
                        }

                        StatusCard(
                            statusMessage = vm.statusMessage,
                            errorMessage = vm.errorMessage,
                        )
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared UI components
// ═══════════════════════════════════════════════════════════════════════

@Composable
private fun HeaderSection() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Fliq",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Digital tipping & appreciation for everyone.",
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
                    Text(role.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(role.subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("${role.title} sign in", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                RoleBadge(accent = role.accent)
            }
            Text(
                text = if (isBusiness) "Enter the business email used for dashboard access."
                else "Enter the phone number used for ${role.title.lowercase()} access.",
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
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(onClick = onBack) { Text("Back") }
                Button(onClick = onSubmit, enabled = credential.isNotBlank(), modifier = Modifier.weight(1f)) {
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
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("Verify ${role.title.lowercase()} code", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("We sent a one-time code to $credential.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(
                value = code,
                onValueChange = onCodeChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("6-digit OTP") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(onClick = onBack) { Text("Back") }
                TextButton(onClick = onResend) { Text("Resend") }
                Button(onClick = onVerify, enabled = code.length >= 4, modifier = Modifier.weight(1f)) {
                    Text("Verify")
                }
            }
        }
    }
}

@Composable
fun CustomerHomeCard(
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
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text("Customer home", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
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

            Text("Resolve QR or link", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            OutlinedTextField(
                value = resolutionInput,
                onValueChange = onResolutionInputChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Paste /qr/... or /tip/... or raw ID") },
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(
                    onClick = onScanQr,
                    enabled = !isLaunchingScanner && !isResolvingQr && !isResolvingPaymentLink,
                    modifier = Modifier.weight(1f),
                ) { Text(if (isLaunchingScanner) "Scanning..." else "Scan QR") }
                OutlinedButton(
                    onClick = onResolveQr,
                    enabled = resolutionInput.isNotBlank() && !isResolvingQr && !isLaunchingScanner,
                    modifier = Modifier.weight(1f),
                ) { Text(if (isResolvingQr) "Resolving..." else "Resolve QR") }
                OutlinedButton(
                    onClick = onResolvePaymentLink,
                    enabled = resolutionInput.isNotBlank() && !isResolvingPaymentLink && !isLaunchingScanner,
                    modifier = Modifier.weight(1f),
                ) { Text(if (isResolvingPaymentLink) "Resolving..." else "Resolve link") }
            }

            OutlinedTextField(
                value = providerQuery,
                onValueChange = onProviderQueryChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Search providers by name or phone") },
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = onSearchProviders,
                    enabled = providerQuery.trim().length >= 2 && !isSearchingProviders,
                    modifier = Modifier.weight(1f),
                ) { Text(if (isSearchingProviders) "Searching..." else "Search providers") }
                TextButton(onClick = onLogout) { Text("Log out") }
            }

            selectedEntryContext?.let { entry ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(20.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Selected entry context", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        DetailLine("Source", entry.source.label)
                        DetailLine("Provider", entry.providerName)
                        entry.category?.let { DetailLine("Category", it) }
                        entry.entryDetail?.let { DetailLine("Context", it) }
                        entry.suggestedAmountPaise?.let { DetailLine("Suggested amount", "Rs ${it / 100}") }
                        DetailLine("Custom amount", if (entry.allowCustomAmount) "Allowed" else "Locked to suggested amount")
                    }
                }
            }

            if (providerResults.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Search results", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    providerResults.forEach { provider ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            shape = RoundedCornerShape(20.dp),
                        ) {
                            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(provider.name, fontWeight = FontWeight.Bold)
                                provider.category?.let { DetailLine("Category", it) }
                                provider.phone?.let { DetailLine("Phone", it) }
                                DetailLine("Rating", FliqViewModel.formatScore(provider.ratingAverage))
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
                    Text("Selected provider", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    DetailLine("Name", provider.displayName)
                    provider.category?.let { DetailLine("Category", it) }
                    provider.bio?.let { DetailLine("Bio", it) }
                    DetailLine("Rating", FliqViewModel.formatScore(provider.ratingAverage))
                    DetailLine("Tips today", provider.stats.tipsToday.toString())
                    DetailLine("Recent appreciations", provider.stats.recentAppreciations.toString())
                    provider.reputation?.let { DetailLine("Reputation score", FliqViewModel.formatScore(it.score)) }
                    provider.dream?.let { DetailLine("Dream", "${it.title} (${it.percentage}% funded)") }
                    selectedEntryContext?.let { DetailLine("Entry source", it.source.label) }

                    Text("Tip amount", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(50, 100, 200).forEach { preset ->
                            OutlinedButton(
                                onClick = { onUsePresetAmount(preset) },
                                modifier = Modifier.weight(1f),
                                enabled = !isCustomAmountLocked,
                            ) { Text("Rs $preset") }
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
                        Text("This payment link locks the amount to the suggested value from the backend.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }

                    Text("Intent", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    TipIntentOption.values().forEach { intent ->
                        OutlinedButton(onClick = { onIntentSelected(intent) }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (intent == selectedIntent) "${intent.label} selected" else "${intent.label}: ${intent.summary}")
                        }
                    }

                    OutlinedTextField(
                        value = tipMessage,
                        onValueChange = onTipMessageChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Message") },
                        minLines = 3,
                    )

                    Text("Rating", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        (1..5).forEach { rating ->
                            OutlinedButton(
                                onClick = { onRatingSelected(rating) },
                                modifier = Modifier.weight(1f),
                            ) { Text(if (rating == selectedRating) "$rating*" else rating.toString()) }
                        }
                    }

                    Button(onClick = onCreateTip, enabled = !isSubmittingTip, modifier = Modifier.fillMaxWidth()) {
                        Text(if (isSubmittingTip) "Creating order..." else "Create tip order")
                    }
                }
            }

            createdTipOrder?.let { tipOrder ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(20.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Tip order created", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
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
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedButton(
                                onClick = onRefreshTipStatus,
                                enabled = !isRefreshingTipStatus && !isVerifyingCheckout,
                                modifier = Modifier.weight(1f),
                            ) { Text(if (isRefreshingTipStatus) "Refreshing..." else "Refresh status") }
                            if (tipOrder.isMockOrder) {
                                Button(
                                    onClick = onCompleteMockPayment,
                                    enabled = !isCompletingMockPayment,
                                    modifier = Modifier.weight(1f),
                                ) { Text(if (isCompletingMockPayment) "Completing..." else "Complete mock payment") }
                            } else {
                                Button(
                                    onClick = onOpenCheckout,
                                    enabled = !isLaunchingCheckout && !isVerifyingCheckout,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(when {
                                        isVerifyingCheckout -> "Verifying..."
                                        isLaunchingCheckout -> "Opening..."
                                        else -> "Open checkout"
                                    })
                                }
                            }
                        }
                        Text(
                            text = if (tipOrder.isMockOrder) "Dev-bypass order. Complete verification here without a real checkout SDK."
                            else "Native Razorpay checkout wired. Opens the SDK and verifies the callback.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            CustomerTipSuccessCard(tipImpact = tipImpact, isLoadingTipImpact = isLoadingTipImpact, onRefreshTipImpact = onRefreshTipImpact)
            CustomerTipHistoryCard(customerHistory = customerHistory, isLoadingCustomerHistory = isLoadingCustomerHistory, onRefreshCustomerHistory = onRefreshCustomerHistory)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Small reusable components
// ═══════════════════════════════════════════════════════════════════════

@Composable
private fun CustomerProfileCard(
    customerProfile: AuthUser,
    profileName: String, onProfileNameChange: (String) -> Unit,
    profileEmail: String, onProfileEmailChange: (String) -> Unit,
    profilePhone: String, onProfilePhoneChange: (String) -> Unit,
    profileLanguage: String, onProfileLanguageChange: (String) -> Unit,
    isLoadingCustomerProfile: Boolean, isSavingCustomerProfile: Boolean,
    onRefreshCustomerProfile: () -> Unit, onSaveCustomerProfile: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Profile", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            DetailLine("Customer ID", customerProfile.id)
            OutlinedTextField(value = profileName, onValueChange = onProfileNameChange, modifier = Modifier.fillMaxWidth(), singleLine = true, label = { Text("Name") })
            OutlinedTextField(value = profileEmail, onValueChange = onProfileEmailChange, modifier = Modifier.fillMaxWidth(), singleLine = true, label = { Text("Email") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email))
            OutlinedTextField(value = profilePhone, onValueChange = onProfilePhoneChange, modifier = Modifier.fillMaxWidth(), singleLine = true, label = { Text("Phone") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone))
            OutlinedTextField(value = profileLanguage, onValueChange = onProfileLanguageChange, modifier = Modifier.fillMaxWidth(), singleLine = true, label = { Text("Language code (en, hi, ta, te, kn, mr)") })
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = onRefreshCustomerProfile, enabled = !isLoadingCustomerProfile && !isSavingCustomerProfile, modifier = Modifier.weight(1f)) {
                    Text(if (isLoadingCustomerProfile) "Refreshing..." else "Refresh profile")
                }
                Button(onClick = onSaveCustomerProfile, enabled = !isLoadingCustomerProfile && !isSavingCustomerProfile, modifier = Modifier.weight(1f)) {
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
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Offline queue", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                OutlinedButton(onClick = onSyncPendingTips, enabled = pendingTipDrafts.isNotEmpty() && !isSyncingPendingTips) {
                    Text(if (isSyncingPendingTips) "Syncing..." else "Sync now")
                }
            }
            if (pendingTipDrafts.isEmpty()) {
                Text("Offline-created customer tips will queue here if the backend cannot be reached.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                pendingTipDrafts.forEach { draft ->
                    Card(colors = CardDefaults.cardColors(containerColor = Color.White), shape = RoundedCornerShape(18.dp)) {
                        Column(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("${FliqViewModel.formatTipAmount(draft.amountPaise)} to ${draft.providerName}", fontWeight = FontWeight.Bold)
                            draft.providerCategory?.let { DetailLine("Category", it) }
                            DetailLine("Source", draft.source.label)
                            DetailLine("Intent", draft.intent.label)
                            draft.message?.let { DetailLine("Message", it) }
                            FliqViewModel.formatHistoryDate(draft.createdAt)?.let { DetailLine("Queued", it) }
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Button(onClick = onSyncPendingTips, enabled = !isSyncingPendingTips, modifier = Modifier.weight(1f)) { Text("Retry sync") }
                                OutlinedButton(onClick = { onDiscardPendingTip(draft.id) }, enabled = !isSyncingPendingTips, modifier = Modifier.weight(1f)) { Text("Discard") }
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
    if (!isLoadingTipImpact && tipImpact == null) return

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Payment success", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                if (tipImpact != null) {
                    TextButton(onClick = onRefreshTipImpact, enabled = !isLoadingTipImpact) { Text(if (isLoadingTipImpact) "Refreshing..." else "Refresh") }
                }
            }
            when {
                isLoadingTipImpact && tipImpact == null -> {
                    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                }
                tipImpact != null -> {
                    DetailLine("Worker", tipImpact.workerName)
                    DetailLine("Amount", FliqViewModel.formatTipAmount(tipImpact.amountPaise))
                    FliqViewModel.formatIntentLabel(tipImpact.intent)?.let { DetailLine("Intent", it) }
                    Text(tipImpact.message, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
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
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Recent tips", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                TextButton(onClick = onRefreshCustomerHistory, enabled = !isLoadingCustomerHistory) { Text(if (isLoadingCustomerHistory) "Refreshing..." else "Refresh") }
            }
            when {
                isLoadingCustomerHistory && customerHistory.isEmpty() -> {
                    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                }
                customerHistory.isEmpty() -> {
                    Text("No customer tips yet. Recent authenticated tips will appear here.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                else -> {
                    customerHistory.forEach { tip ->
                        Card(colors = CardDefaults.cardColors(containerColor = Color.White), shape = RoundedCornerShape(18.dp)) {
                            Column(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("${FliqViewModel.formatTipAmount(tip.amountPaise)} to ${tip.providerName}", fontWeight = FontWeight.Bold)
                                tip.providerCategory?.let { DetailLine("Category", it) }
                                DetailLine("Status", tip.status)
                                FliqViewModel.formatIntentLabel(tip.intent)?.let { DetailLine("Intent", it) }
                                tip.message?.let { DetailLine("Message", it) }
                                FliqViewModel.formatHistoryDate(tip.createdAt)?.let { DetailLine("Created", it) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StatusCard(statusMessage: String, errorMessage: String?) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = if (errorMessage == null) "Current status" else "Error",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = errorMessage ?: statusMessage,
                style = MaterialTheme.typography.bodyMedium,
                color = if (errorMessage == null) MaterialTheme.colorScheme.onSurfaceVariant else Color(0xFFB42318),
            )
        }
    }
}

@Composable
fun DetailLine(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun RoleBadge(accent: Color) {
    Box(
        modifier = Modifier
            .background(color = accent.copy(alpha = 0.14f), shape = RoundedCornerShape(999.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text("Native", color = accent, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
    }
}
