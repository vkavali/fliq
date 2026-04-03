package com.fliq.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fliq.android.data.AuthException
import com.fliq.android.data.AuthSession
import com.fliq.android.data.BusinessAffiliation
import com.fliq.android.data.BusinessDashboardSnapshot
import com.fliq.android.data.BusinessInvitationData
import com.fliq.android.data.BusinessQrStaffGroup
import com.fliq.android.data.BusinessRepository
import com.fliq.android.data.BusinessReviewItem
import com.fliq.android.data.BusinessSatisfactionSnapshot
import com.fliq.android.data.BusinessStaffMember
import com.fliq.android.data.BusinessSummary
import com.fliq.android.data.ProviderDreamData
import com.fliq.android.data.ProviderPaymentLink
import com.fliq.android.data.ProviderPayoutItem
import com.fliq.android.data.ProviderQrCode
import com.fliq.android.data.ProviderRecurringTip
import com.fliq.android.data.ProviderRepository
import com.fliq.android.data.ProviderSelfProfile
import com.fliq.android.data.ProviderTipItem
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

private val providerCategories = listOf(
    "DELIVERY",
    "SALON",
    "HOUSEHOLD",
    "RESTAURANT",
    "HOTEL",
    "TRANSPORT",
    "HEALTHCARE",
    "EDUCATION",
    "FITNESS",
    "OTHER",
)

private val dreamCategories = listOf(
    "EDUCATION",
    "HEALTH",
    "FAMILY",
    "SKILL",
    "EMERGENCY",
    "TRAVEL",
    "OTHER",
)

private val businessTypes = listOf(
    "HOTEL",
    "SALON",
    "RESTAURANT",
    "SPA",
    "CAFE",
    "RETAIL",
    "OTHER",
)

private val businessRoles = listOf("ADMIN", "MANAGER", "STAFF")

@Composable
fun ProviderHomeCard(
    session: AuthSession,
    onLogout: () -> Unit,
) {
    val repository = remember { ProviderRepository() }
    val coroutineScope = rememberCoroutineScope()

    var profile by remember { mutableStateOf<ProviderSelfProfile?>(null) }
    var tips by remember { mutableStateOf(emptyList<ProviderTipItem>()) }
    var qrCodes by remember { mutableStateOf(emptyList<ProviderQrCode>()) }
    var paymentLinks by remember { mutableStateOf(emptyList<ProviderPaymentLink>()) }
    var payouts by remember { mutableStateOf(emptyList<ProviderPayoutItem>()) }
    var dream by remember { mutableStateOf<ProviderDreamData?>(null) }
    var recurringTips by remember { mutableStateOf(emptyList<ProviderRecurringTip>()) }
    var invitations by remember { mutableStateOf(emptyList<BusinessInvitationData>()) }
    var affiliations by remember { mutableStateOf(emptyList<BusinessAffiliation>()) }
    var isLoading by remember { mutableStateOf(true) }
    var isSavingProfile by remember { mutableStateOf(false) }
    var isCreatingQr by remember { mutableStateOf(false) }
    var isCreatingLink by remember { mutableStateOf(false) }
    var isRequestingPayout by remember { mutableStateOf(false) }
    var isSavingDream by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf("Provider parity is loading from the shared backend.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var displayName by remember { mutableStateOf(session.user.name.orEmpty()) }
    var category by remember { mutableStateOf(providerCategories.first()) }
    var bio by remember { mutableStateOf("") }
    var upiVpa by remember { mutableStateOf("") }
    var qrLocationLabel by remember { mutableStateOf("") }
    var linkRole by remember { mutableStateOf("") }
    var linkWorkplace by remember { mutableStateOf("") }
    var linkDescription by remember { mutableStateOf("") }
    var linkSuggestedAmount by remember { mutableStateOf("") }
    var linkAllowCustomAmount by remember { mutableStateOf(true) }
    var payoutAmountRupees by remember { mutableStateOf("") }
    var dreamTitle by remember { mutableStateOf("") }
    var dreamDescription by remember { mutableStateOf("") }
    var dreamCategory by remember { mutableStateOf(dreamCategories.first()) }
    var dreamGoalAmount by remember { mutableStateOf("") }

    suspend fun loadProviderHome() {
        isLoading = true
        errorMessage = null

        try {
            val ownProfile = runCatching { repository.getOwnProfile(session.accessToken) }.getOrNull()
            profile = ownProfile
            if (ownProfile != null) {
                displayName = ownProfile.displayName
                category = ownProfile.category ?: category
                bio = ownProfile.bio.orEmpty()
                upiVpa = ownProfile.upiVpa.orEmpty()
                tips = repository.getReceivedTips(session.accessToken)
                qrCodes = repository.getQrCodes(session.accessToken)
                paymentLinks = repository.getPaymentLinks(session.accessToken)
                payouts = repository.getPayoutHistory(session.accessToken)
                dream = repository.getActiveDream(session.accessToken)
                recurringTips = repository.getRecurringTips(session.accessToken)
                affiliations = repository.getBusinessAffiliations(session.accessToken)
                dream?.let {
                    dreamTitle = it.title
                    dreamDescription = it.description.orEmpty()
                    dreamCategory = it.category ?: dreamCategory
                    dreamGoalAmount = (it.goalAmount / 100).toString()
                }
            } else {
                tips = emptyList()
                qrCodes = emptyList()
                paymentLinks = emptyList()
                payouts = emptyList()
                dream = null
                recurringTips = emptyList()
                affiliations = repository.getBusinessAffiliations(session.accessToken)
            }
            invitations = repository.getBusinessInvitations(session.accessToken)
            statusMessage = if (ownProfile == null) {
                "No provider profile exists yet. Complete onboarding to unlock native provider tools."
            } else {
                "Provider profile, payouts, QR codes, links, tips, dream, affiliations, and invitations are loading natively."
            }
        } catch (error: AuthException) {
            errorMessage = error.message
        } catch (_: Exception) {
            errorMessage = "Unable to load the provider home right now."
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(session.user.id) {
        loadProviderHome()
    }

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
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
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Provider home",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { coroutineScope.launch { loadProviderHome() } }, enabled = !isLoading) {
                        Text(if (isLoading) "Refreshing..." else "Refresh")
                    }
                    TextButton(onClick = onLogout) {
                        Text("Log out")
                    }
                }
            }

            errorMessage?.let {
                Text(text = it, color = androidx.compose.ui.graphics.Color(0xFFB42318))
            } ?: Text(
                text = statusMessage,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (isLoading) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }

            profile?.let { currentProfile ->
                DetailLine("Provider ID", currentProfile.id)
                DetailLine("KYC", currentProfile.kycStatus ?: "PENDING")
                DetailLine("Rating", providerScoreText(currentProfile.ratingAverage))
                DetailLine("Tips received", currentProfile.totalTipsReceived.toString())
            }

            ProviderProfileEditorCard(
                hasProfile = profile != null,
                displayName = displayName,
                onDisplayNameChange = { displayName = it },
                category = category,
                onCategoryChange = { category = it },
                bio = bio,
                onBioChange = { bio = it },
                upiVpa = upiVpa,
                onUpiVpaChange = { upiVpa = it },
                isSavingProfile = isSavingProfile,
                onSaveProfile = {
                    coroutineScope.launch {
                        if (displayName.isBlank()) {
                            errorMessage = "Display name is required."
                            return@launch
                        }
                        isSavingProfile = true
                        errorMessage = null
                        try {
                            val isCreatingProfile = profile == null
                            profile = if (profile == null) {
                                repository.createProfile(
                                    accessToken = session.accessToken,
                                    displayName = displayName.trim(),
                                    category = category,
                                    bio = bio.trim().takeIf { it.isNotBlank() },
                                    upiVpa = upiVpa.trim().takeIf { it.isNotBlank() },
                                )
                            } else {
                                repository.updateProfile(
                                    accessToken = session.accessToken,
                                    displayName = displayName.trim(),
                                    category = category,
                                    bio = bio.trim().takeIf { it.isNotBlank() },
                                    upiVpa = upiVpa.trim().takeIf { it.isNotBlank() },
                                )
                            }
                            statusMessage = if (isCreatingProfile) {
                                "Provider profile created."
                            } else {
                                "Provider profile saved."
                            }
                            loadProviderHome()
                        } catch (error: AuthException) {
                            errorMessage = error.message
                        } catch (_: Exception) {
                            errorMessage = "Unable to save the provider profile right now."
                        } finally {
                            isSavingProfile = false
                        }
                    }
                },
            )

            if (invitations.isNotEmpty()) {
                RoleSectionCard(title = "Business invitations") {
                    invitations.forEach { invitation ->
                        RoleListCard {
                            DetailLine("Business", invitation.businessName ?: "Business")
                            DetailLine("Role", invitation.role)
                            invitation.expiresAt?.let { DetailLine("Expires", roleDateText(it) ?: it) }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            try {
                                                repository.respondToInvitation(
                                                    accessToken = session.accessToken,
                                                    invitationId = invitation.id,
                                                    response = "ACCEPT",
                                                )
                                                statusMessage = "Invitation accepted."
                                                invitations = invitations.filterNot { it.id == invitation.id }
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to respond to the invitation right now."
                                            }
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Accept")
                                }
                                OutlinedButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            try {
                                                repository.respondToInvitation(
                                                    accessToken = session.accessToken,
                                                    invitationId = invitation.id,
                                                    response = "DECLINE",
                                                )
                                                statusMessage = "Invitation declined."
                                                invitations = invitations.filterNot { it.id == invitation.id }
                                            } catch (error: AuthException) {
                                                errorMessage = error.message
                                            } catch (_: Exception) {
                                                errorMessage = "Unable to respond to the invitation right now."
                                            }
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("Decline")
                                }
                            }
                        }
                    }
                }
            }

            if (profile != null) {
                ProviderAnalyticsSection(
                    tips = tips,
                    payouts = payouts,
                    recurringTips = recurringTips,
                )

                ProviderAffiliationsSection(affiliations = affiliations)

                ProviderAvatarSection(
                    session = session,
                    currentAvatarUrl = profile?.avatarUrl,
                    onRefreshRequested = {
                        coroutineScope.launch { loadProviderHome() }
                    },
                )

                ProviderQrSection(
                    qrCodes = qrCodes,
                    qrLocationLabel = qrLocationLabel,
                    onQrLocationLabelChange = { qrLocationLabel = it },
                    isCreatingQr = isCreatingQr,
                    onCreateQr = {
                        coroutineScope.launch {
                            isCreatingQr = true
                            errorMessage = null
                            try {
                                repository.createQrCode(
                                    accessToken = session.accessToken,
                                    locationLabel = qrLocationLabel.trim().takeIf { it.isNotBlank() },
                                )
                                qrLocationLabel = ""
                                qrCodes = repository.getQrCodes(session.accessToken)
                                statusMessage = "New QR code created."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to create a QR code right now."
                            } finally {
                                isCreatingQr = false
                            }
                        }
                    },
                )

                ProviderPaymentLinkSection(
                    paymentLinks = paymentLinks,
                    role = linkRole,
                    onRoleChange = { linkRole = it },
                    workplace = linkWorkplace,
                    onWorkplaceChange = { linkWorkplace = it },
                    description = linkDescription,
                    onDescriptionChange = { linkDescription = it },
                    suggestedAmount = linkSuggestedAmount,
                    onSuggestedAmountChange = { linkSuggestedAmount = it.filter(Char::isDigit) },
                    allowCustomAmount = linkAllowCustomAmount,
                    onToggleAllowCustomAmount = { linkAllowCustomAmount = !linkAllowCustomAmount },
                    isCreatingLink = isCreatingLink,
                    onCreateLink = {
                        coroutineScope.launch {
                            isCreatingLink = true
                            errorMessage = null
                            try {
                                repository.createPaymentLink(
                                    accessToken = session.accessToken,
                                    role = linkRole.trim().takeIf { it.isNotBlank() },
                                    workplace = linkWorkplace.trim().takeIf { it.isNotBlank() },
                                    description = linkDescription.trim().takeIf { it.isNotBlank() },
                                    suggestedAmountPaise = linkSuggestedAmount.toIntOrNull()?.times(100),
                                    allowCustomAmount = linkAllowCustomAmount,
                                )
                                paymentLinks = repository.getPaymentLinks(session.accessToken)
                                linkRole = ""
                                linkWorkplace = ""
                                linkDescription = ""
                                linkSuggestedAmount = ""
                                linkAllowCustomAmount = true
                                statusMessage = "New payment link created."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to create a payment link right now."
                            } finally {
                                isCreatingLink = false
                            }
                        }
                    },
                )

                ProviderTipsSection(tips = tips)
                ProviderDreamSection(
                    dream = dream,
                    dreamTitle = dreamTitle,
                    onDreamTitleChange = { dreamTitle = it },
                    dreamDescription = dreamDescription,
                    onDreamDescriptionChange = { dreamDescription = it },
                    dreamCategory = dreamCategory,
                    onDreamCategoryChange = { dreamCategory = it },
                    dreamGoalAmount = dreamGoalAmount,
                    onDreamGoalAmountChange = { dreamGoalAmount = it.filter(Char::isDigit) },
                    isSavingDream = isSavingDream,
                    onSaveDream = {
                        coroutineScope.launch {
                            val goalAmount = dreamGoalAmount.toIntOrNull()
                            if (dreamTitle.isBlank() || dreamDescription.isBlank() || goalAmount == null || goalAmount < 1) {
                                errorMessage = "Dream title, description, and goal amount are required."
                                return@launch
                            }
                            isSavingDream = true
                            errorMessage = null
                            try {
                                dream = repository.saveDream(
                                    accessToken = session.accessToken,
                                    existingDreamId = dream?.id,
                                    title = dreamTitle.trim(),
                                    description = dreamDescription.trim(),
                                    category = dreamCategory,
                                    goalAmountPaise = goalAmount * 100,
                                )
                                statusMessage = "Dream saved."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to save the dream right now."
                            } finally {
                                isSavingDream = false
                            }
                        }
                    },
                )
                ProviderRecurringSection(recurringTips = recurringTips)
                ProviderPayoutSection(
                    payouts = payouts,
                    payoutAmountRupees = payoutAmountRupees,
                    onPayoutAmountChange = { payoutAmountRupees = it.filter(Char::isDigit) },
                    isRequestingPayout = isRequestingPayout,
                    onRequestPayout = {
                        coroutineScope.launch {
                            val amount = payoutAmountRupees.toIntOrNull()
                            if (amount == null || amount < 100) {
                                errorMessage = "Minimum payout is Rs 100."
                                return@launch
                            }
                            isRequestingPayout = true
                            errorMessage = null
                            try {
                                repository.requestPayout(
                                    accessToken = session.accessToken,
                                    amountPaise = amount * 100,
                                )
                                payoutAmountRupees = ""
                                payouts = repository.getPayoutHistory(session.accessToken)
                                statusMessage = "Payout request submitted."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to request a payout right now."
                            } finally {
                                isRequestingPayout = false
                            }
                        }
                    },
                )

                ProviderCompletionSection(
                    session = session,
                    currentUpiVpa = upiVpa,
                    latestTips = tips,
                    onRefreshRequested = {
                        coroutineScope.launch { loadProviderHome() }
                    },
                )

                ProviderCollectionsSection(session = session)
            }
        }
    }
}

@Composable
fun BusinessHomeCard(
    session: AuthSession,
    onLogout: () -> Unit,
) {
    val repository = remember { BusinessRepository() }
    val coroutineScope = rememberCoroutineScope()

    var business by remember { mutableStateOf<BusinessSummary?>(null) }
    var dashboard by remember { mutableStateOf<BusinessDashboardSnapshot?>(null) }
    var staff by remember { mutableStateOf(emptyList<BusinessStaffMember>()) }
    var satisfaction by remember { mutableStateOf<BusinessSatisfactionSnapshot?>(null) }
    var qrGroups by remember { mutableStateOf(emptyList<BusinessQrStaffGroup>()) }
    var isLoading by remember { mutableStateOf(true) }
    var isSavingBusiness by remember { mutableStateOf(false) }
    var isInvitingMember by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf("Business parity is loading from the shared backend.") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var businessName by remember { mutableStateOf("") }
    var businessType by remember { mutableStateOf(businessTypes.first()) }
    var businessAddress by remember { mutableStateOf("") }
    var businessContactPhone by remember { mutableStateOf("") }
    var businessContactEmail by remember { mutableStateOf(session.user.email.orEmpty()) }
    var businessGstin by remember { mutableStateOf("") }
    var invitePhone by remember { mutableStateOf("") }
    var inviteRole by remember { mutableStateOf("STAFF") }

    suspend fun loadBusinessHome() {
        isLoading = true
        errorMessage = null

        try {
            val currentBusiness = runCatching { repository.getMyBusiness(session.accessToken) }.getOrNull()
            business = currentBusiness
            if (currentBusiness == null) {
                statusMessage = "No business is registered for this account yet. Complete the native registration form to continue."
                dashboard = null
                staff = emptyList()
                satisfaction = null
                qrGroups = emptyList()
            } else {
                businessName = currentBusiness.name
                businessType = currentBusiness.type
                businessAddress = currentBusiness.address.orEmpty()
                businessContactPhone = currentBusiness.contactPhone.orEmpty()
                businessContactEmail = currentBusiness.contactEmail.orEmpty()
                businessGstin = currentBusiness.gstin.orEmpty()
                dashboard = repository.getDashboard(session.accessToken, currentBusiness.id)
                staff = repository.getStaff(session.accessToken, currentBusiness.id)
                satisfaction = repository.getSatisfaction(session.accessToken, currentBusiness.id)
                qrGroups = repository.getQrCodes(session.accessToken, currentBusiness.id)
                statusMessage = "Business dashboard, staff, satisfaction, and QR groups are loading natively."
            }
        } catch (error: AuthException) {
            errorMessage = error.message
        } catch (_: Exception) {
            errorMessage = "Unable to load the business home right now."
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(session.user.id) {
        loadBusinessHome()
    }

    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
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
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Business home",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { coroutineScope.launch { loadBusinessHome() } }, enabled = !isLoading) {
                        Text(if (isLoading) "Refreshing..." else "Refresh")
                    }
                    TextButton(onClick = onLogout) {
                        Text("Log out")
                    }
                }
            }

            errorMessage?.let {
                Text(text = it, color = androidx.compose.ui.graphics.Color(0xFFB42318))
            } ?: Text(
                text = statusMessage,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (isLoading) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }

            BusinessEditorCard(
                isRegistered = business != null,
                businessName = businessName,
                onBusinessNameChange = { businessName = it },
                businessType = businessType,
                onBusinessTypeChange = { businessType = it },
                businessAddress = businessAddress,
                onBusinessAddressChange = { businessAddress = it },
                businessContactPhone = businessContactPhone,
                onBusinessContactPhoneChange = { businessContactPhone = it },
                businessContactEmail = businessContactEmail,
                onBusinessContactEmailChange = { businessContactEmail = it },
                businessGstin = businessGstin,
                onBusinessGstinChange = { businessGstin = it.uppercase(Locale.US) },
                isSavingBusiness = isSavingBusiness,
                onSaveBusiness = {
                    coroutineScope.launch {
                        if (businessName.isBlank()) {
                            errorMessage = "Business name is required."
                            return@launch
                        }
                        isSavingBusiness = true
                        errorMessage = null
                        try {
                            val isRegisteringBusiness = business == null
                            business = if (business == null) {
                                repository.registerBusiness(
                                    accessToken = session.accessToken,
                                    name = businessName.trim(),
                                    type = businessType,
                                    address = businessAddress.trim().takeIf { it.isNotBlank() },
                                    contactPhone = businessContactPhone.trim().takeIf { it.isNotBlank() },
                                    contactEmail = businessContactEmail.trim().takeIf { it.isNotBlank() },
                                    gstin = businessGstin.trim().takeIf { it.isNotBlank() },
                                )
                            } else {
                                repository.updateBusiness(
                                    accessToken = session.accessToken,
                                    businessId = business!!.id,
                                    name = businessName.trim(),
                                    type = businessType,
                                    address = businessAddress.trim().takeIf { it.isNotBlank() },
                                    contactPhone = businessContactPhone.trim().takeIf { it.isNotBlank() },
                                    contactEmail = businessContactEmail.trim().takeIf { it.isNotBlank() },
                                    gstin = businessGstin.trim().takeIf { it.isNotBlank() },
                                )
                            }
                            statusMessage = if (isRegisteringBusiness) {
                                "Business registered."
                            } else {
                                "Business settings saved."
                            }
                            loadBusinessHome()
                        } catch (error: AuthException) {
                            errorMessage = error.message
                        } catch (_: Exception) {
                            errorMessage = "Unable to save the business right now."
                        } finally {
                            isSavingBusiness = false
                        }
                    }
                },
            )

            business?.let { currentBusiness ->
                dashboard?.let { BusinessDashboardSection(it) }
                dashboard?.let {
                    BusinessReportingSection(
                        dashboard = it,
                        staff = staff,
                    )
                }

                BusinessInviteSection(
                    invitePhone = invitePhone,
                    onInvitePhoneChange = { invitePhone = it },
                    inviteRole = inviteRole,
                    onInviteRoleChange = { inviteRole = it },
                    isInvitingMember = isInvitingMember,
                    onInviteMember = {
                        coroutineScope.launch {
                            if (invitePhone.isBlank()) {
                                errorMessage = "Invite phone number is required."
                                return@launch
                            }
                            isInvitingMember = true
                            errorMessage = null
                            try {
                                repository.inviteMember(
                                    accessToken = session.accessToken,
                                    businessId = currentBusiness.id,
                                    phone = invitePhone.trim(),
                                    role = inviteRole,
                                )
                                invitePhone = ""
                                staff = repository.getStaff(session.accessToken, currentBusiness.id)
                                statusMessage = "Staff invitation sent."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to invite that staff member right now."
                            } finally {
                                isInvitingMember = false
                            }
                        }
                    },
                )

                BusinessStaffSection(
                    staff = staff,
                    onRemoveMember = { memberId ->
                        coroutineScope.launch {
                            try {
                                repository.removeMember(
                                    accessToken = session.accessToken,
                                    businessId = currentBusiness.id,
                                    memberId = memberId,
                                )
                                staff = repository.getStaff(session.accessToken, currentBusiness.id)
                                dashboard = repository.getDashboard(session.accessToken, currentBusiness.id)
                                statusMessage = "Staff member removed."
                            } catch (error: AuthException) {
                                errorMessage = error.message
                            } catch (_: Exception) {
                                errorMessage = "Unable to remove that staff member right now."
                            }
                        }
                    },
                )

                satisfaction?.let { BusinessSatisfactionSection(it.reviews) }
                BusinessQrSection(qrGroups = qrGroups)
                BusinessExportSection(
                    session = session,
                    businessId = currentBusiness.id,
                )
            }
        }
    }
}

@Composable
private fun ProviderAnalyticsSection(
    tips: List<ProviderTipItem>,
    payouts: List<ProviderPayoutItem>,
    recurringTips: List<ProviderRecurringTip>,
) {
    val paidTips = tips.filter { it.status == "PAID" || it.status == "SETTLED" }
    val totalTipAmount = paidTips.sumOf { it.amountPaise }
    val recentTipAmount = paidTips
        .filter { tip ->
            val created = tip.createdAt?.let { raw -> runCatching { Instant.parse(raw) }.getOrNull() } ?: return@filter false
            created.isAfter(Instant.now().minusSeconds(30L * 24 * 60 * 60))
        }
        .sumOf { it.amountPaise }
    val averageTip = if (paidTips.isEmpty()) 0 else totalTipAmount / paidTips.size
    val successfulPayoutAmount = payouts
        .filter { it.status == "PROCESSED" || it.status == "SUCCESS" || it.status == "COMPLETED" }
        .sumOf { it.amountPaise }

    RoleSectionCard(title = "Performance") {
        DetailLine("Paid tips", paidTips.size.toString())
        DetailLine("Average tip", roleAmountText(averageTip))
        DetailLine("Last 30 days", roleAmountText(recentTipAmount))
        DetailLine("Recurring supporters", recurringTips.count { it.status == "ACTIVE" || it.status == "PAUSED" }.toString())
        DetailLine("Payouts processed", roleAmountText(successfulPayoutAmount))
    }
}

@Composable
private fun ProviderAffiliationsSection(
    affiliations: List<BusinessAffiliation>,
) {
    RoleSectionCard(title = "Business affiliations") {
        if (affiliations.isEmpty()) {
            Text("No active business memberships yet.")
        } else {
            affiliations.forEach { affiliation ->
                RoleListCard {
                    Text(affiliation.businessName, fontWeight = FontWeight.Bold)
                    DetailLine("Role", if (affiliation.isOwner) "${affiliation.role} (Owner)" else affiliation.role)
                    DetailLine("Type", affiliation.businessType)
                    if (affiliation.joinedAt != null) {
                        DetailLine("Joined", roleDateText(affiliation.joinedAt) ?: affiliation.joinedAt)
                    }
                    if (affiliation.contactPhone != null) {
                        DetailLine("Phone", affiliation.contactPhone)
                    }
                    if (affiliation.contactEmail != null) {
                        DetailLine("Email", affiliation.contactEmail)
                    }
                }
            }
        }
    }
}

@Composable
private fun BusinessReportingSection(
    dashboard: BusinessDashboardSnapshot,
    staff: List<BusinessStaffMember>,
) {
    val topStaff = staff.sortedByDescending { it.totalAmountPaise }.take(3)
    RoleSectionCard(title = "Reporting") {
        DetailLine("Gross tipped", roleAmountText(dashboard.totalAmountPaise))
        DetailLine("Net after commissions", roleAmountText(dashboard.totalNetAmountPaise))
        DetailLine("Ratings captured", dashboard.totalRatingsCount.toString())
        if (dashboard.recentTipTrend.isEmpty()) {
            Text("No 30-day trend data yet.")
        } else {
            dashboard.recentTipTrend.takeLast(5).forEach { point ->
                val dateLabel = point.createdAt?.let { roleDateText(it) } ?: "Trend point"
                DetailLine(dateLabel, "${roleAmountText(point.totalAmountPaise)} from ${point.tipCount} tips")
            }
        }

        if (topStaff.isNotEmpty()) {
            Text("Top staff", fontWeight = FontWeight.Bold)
            topStaff.forEach { member ->
                DetailLine(member.displayName, roleAmountText(member.totalAmountPaise))
            }
        }
    }
}

@Composable
private fun ProviderProfileEditorCard(
    hasProfile: Boolean,
    displayName: String,
    onDisplayNameChange: (String) -> Unit,
    category: String,
    onCategoryChange: (String) -> Unit,
    bio: String,
    onBioChange: (String) -> Unit,
    upiVpa: String,
    onUpiVpaChange: (String) -> Unit,
    isSavingProfile: Boolean,
    onSaveProfile: () -> Unit,
) {
    RoleSectionCard(title = if (hasProfile) "Profile" else "Provider onboarding") {
        OutlinedTextField(
            value = displayName,
            onValueChange = onDisplayNameChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Display name") },
        )
        RoleChoiceRow(
            label = "Category",
            options = providerCategories,
            selected = category,
            onSelected = onCategoryChange,
        )
        OutlinedTextField(
            value = bio,
            onValueChange = onBioChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Bio") },
            minLines = 3,
        )
        OutlinedTextField(
            value = upiVpa,
            onValueChange = onUpiVpaChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("UPI VPA") },
        )
        Button(
            onClick = onSaveProfile,
            enabled = !isSavingProfile,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isSavingProfile) "Saving..." else if (hasProfile) "Save profile" else "Create profile")
        }
    }
}

@Composable
private fun ProviderQrSection(
    qrCodes: List<ProviderQrCode>,
    qrLocationLabel: String,
    onQrLocationLabelChange: (String) -> Unit,
    isCreatingQr: Boolean,
    onCreateQr: () -> Unit,
) {
    RoleSectionCard(title = "QR codes") {
        OutlinedTextField(
            value = qrLocationLabel,
            onValueChange = onQrLocationLabelChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Location label") },
        )
        Button(
            onClick = onCreateQr,
            enabled = !isCreatingQr,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isCreatingQr) "Creating..." else "Create QR code")
        }
        if (qrCodes.isEmpty()) {
            Text("No QR codes yet.")
        } else {
            qrCodes.forEach { qr ->
                RoleListCard {
                    DetailLine("Label", qr.locationLabel ?: "QR code")
                    DetailLine("Scans", (qr.scanCount).toString())
                    qr.upiUrl?.let { DetailLine("UPI URL", it) }
                }
            }
        }
    }
}

@Composable
private fun ProviderPaymentLinkSection(
    paymentLinks: List<ProviderPaymentLink>,
    role: String,
    onRoleChange: (String) -> Unit,
    workplace: String,
    onWorkplaceChange: (String) -> Unit,
    description: String,
    onDescriptionChange: (String) -> Unit,
    suggestedAmount: String,
    onSuggestedAmountChange: (String) -> Unit,
    allowCustomAmount: Boolean,
    onToggleAllowCustomAmount: () -> Unit,
    isCreatingLink: Boolean,
    onCreateLink: () -> Unit,
) {
    RoleSectionCard(title = "Payment links") {
        OutlinedTextField(
            value = role,
            onValueChange = onRoleChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Role") },
        )
        OutlinedTextField(
            value = workplace,
            onValueChange = onWorkplaceChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Workplace") },
        )
        OutlinedTextField(
            value = description,
            onValueChange = onDescriptionChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Description") },
            minLines = 2,
        )
        OutlinedTextField(
            value = suggestedAmount,
            onValueChange = onSuggestedAmountChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Suggested amount in rupees") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        OutlinedButton(onClick = onToggleAllowCustomAmount, modifier = Modifier.fillMaxWidth()) {
            Text(if (allowCustomAmount) "Custom amount allowed" else "Amount locked to suggested value")
        }
        Button(
            onClick = onCreateLink,
            enabled = !isCreatingLink,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isCreatingLink) "Creating..." else "Create payment link")
        }
        if (paymentLinks.isEmpty()) {
            Text("No payment links yet.")
        } else {
            paymentLinks.forEach { link ->
                RoleListCard {
                    DetailLine("Short code", link.shortCode)
                    link.role?.let { DetailLine("Role", it) }
                    link.workplace?.let { DetailLine("Workplace", it) }
                    link.shareableUrl?.let { DetailLine("Shareable URL", it) }
                    DetailLine("Clicks", (link.clickCount).toString())
                }
            }
        }
    }
}

@Composable
private fun ProviderTipsSection(
    tips: List<ProviderTipItem>,
) {
    RoleSectionCard(title = "Recent tips") {
        if (tips.isEmpty()) {
            Text("No tips received yet.")
        } else {
            tips.take(10).forEach { tip ->
                RoleListCard {
                    Text(
                        text = "${roleAmountText(tip.amountPaise)}${tip.customerName?.let { " from $it" } ?: ""}",
                        fontWeight = FontWeight.Bold,
                    )
                    DetailLine("Status", tip.status)
                    tip.rating?.let { DetailLine("Rating", "$it/5") }
                    tip.intent?.let { DetailLine("Intent", it) }
                    tip.message?.let { DetailLine("Message", it) }
                    tip.createdAt?.let { DetailLine("Created", roleDateText(it) ?: it) }
                }
            }
        }
    }
}

@Composable
private fun ProviderDreamSection(
    dream: ProviderDreamData?,
    dreamTitle: String,
    onDreamTitleChange: (String) -> Unit,
    dreamDescription: String,
    onDreamDescriptionChange: (String) -> Unit,
    dreamCategory: String,
    onDreamCategoryChange: (String) -> Unit,
    dreamGoalAmount: String,
    onDreamGoalAmountChange: (String) -> Unit,
    isSavingDream: Boolean,
    onSaveDream: () -> Unit,
) {
    RoleSectionCard(title = "Dream") {
        dream?.let {
            DetailLine("Current dream", it.title)
            DetailLine("Progress", "${it.percentage}% funded")
        }
        OutlinedTextField(
            value = dreamTitle,
            onValueChange = onDreamTitleChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Dream title") },
        )
        OutlinedTextField(
            value = dreamDescription,
            onValueChange = onDreamDescriptionChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Dream description") },
            minLines = 3,
        )
        RoleChoiceRow(
            label = "Dream category",
            options = dreamCategories,
            selected = dreamCategory,
            onSelected = onDreamCategoryChange,
        )
        OutlinedTextField(
            value = dreamGoalAmount,
            onValueChange = onDreamGoalAmountChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Goal amount in rupees") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        Button(
            onClick = onSaveDream,
            enabled = !isSavingDream,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isSavingDream) "Saving..." else "Save dream")
        }
    }
}

@Composable
private fun ProviderRecurringSection(
    recurringTips: List<ProviderRecurringTip>,
) {
    RoleSectionCard(title = "Recurring support") {
        if (recurringTips.isEmpty()) {
            Text("No active recurring supporters yet.")
        } else {
            recurringTips.forEach { recurring ->
                RoleListCard {
                    Text(
                        text = "${roleAmountText(recurring.amountPaise)} / ${recurring.frequency.lowercase(Locale.US)}",
                        fontWeight = FontWeight.Bold,
                    )
                    DetailLine("Status", recurring.status)
                    recurring.customerName?.let { DetailLine("Customer", it) }
                    recurring.createdAt?.let { DetailLine("Created", roleDateText(it) ?: it) }
                }
            }
        }
    }
}

@Composable
private fun ProviderPayoutSection(
    payouts: List<ProviderPayoutItem>,
    payoutAmountRupees: String,
    onPayoutAmountChange: (String) -> Unit,
    isRequestingPayout: Boolean,
    onRequestPayout: () -> Unit,
) {
    RoleSectionCard(title = "Payouts") {
        OutlinedTextField(
            value = payoutAmountRupees,
            onValueChange = onPayoutAmountChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Payout amount in rupees") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        Button(
            onClick = onRequestPayout,
            enabled = !isRequestingPayout,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isRequestingPayout) "Requesting..." else "Request payout")
        }
        if (payouts.isEmpty()) {
            Text("No payout history yet.")
        } else {
            payouts.forEach { payout ->
                RoleListCard {
                    Text(text = roleAmountText(payout.amountPaise), fontWeight = FontWeight.Bold)
                    DetailLine("Status", payout.status)
                    payout.mode?.let { DetailLine("Mode", it) }
                    payout.createdAt?.let { DetailLine("Created", roleDateText(it) ?: it) }
                }
            }
        }
    }
}

@Composable
private fun BusinessEditorCard(
    isRegistered: Boolean,
    businessName: String,
    onBusinessNameChange: (String) -> Unit,
    businessType: String,
    onBusinessTypeChange: (String) -> Unit,
    businessAddress: String,
    onBusinessAddressChange: (String) -> Unit,
    businessContactPhone: String,
    onBusinessContactPhoneChange: (String) -> Unit,
    businessContactEmail: String,
    onBusinessContactEmailChange: (String) -> Unit,
    businessGstin: String,
    onBusinessGstinChange: (String) -> Unit,
    isSavingBusiness: Boolean,
    onSaveBusiness: () -> Unit,
) {
    RoleSectionCard(title = if (isRegistered) "Business settings" else "Business registration") {
        OutlinedTextField(
            value = businessName,
            onValueChange = onBusinessNameChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Business name") },
        )
        RoleChoiceRow(
            label = "Business type",
            options = businessTypes,
            selected = businessType,
            onSelected = onBusinessTypeChange,
        )
        OutlinedTextField(
            value = businessAddress,
            onValueChange = onBusinessAddressChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Address") },
            minLines = 2,
        )
        OutlinedTextField(
            value = businessContactPhone,
            onValueChange = onBusinessContactPhoneChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Contact phone") },
        )
        OutlinedTextField(
            value = businessContactEmail,
            onValueChange = onBusinessContactEmailChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Contact email") },
        )
        OutlinedTextField(
            value = businessGstin,
            onValueChange = onBusinessGstinChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("GSTIN") },
        )
        Button(
            onClick = onSaveBusiness,
            enabled = !isSavingBusiness,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isSavingBusiness) "Saving..." else if (isRegistered) "Save business" else "Register business")
        }
    }
}

@Composable
private fun BusinessDashboardSection(
    dashboard: BusinessDashboardSnapshot,
) {
    RoleSectionCard(title = "Dashboard") {
        DetailLine("Total tips", roleAmountText(dashboard.totalAmountPaise))
        DetailLine("Transactions", dashboard.totalTipsCount.toString())
        DetailLine("Average rating", providerScoreText(dashboard.averageRating))
        DetailLine("Staff count", dashboard.staffCount.toString())
    }
}

@Composable
private fun BusinessInviteSection(
    invitePhone: String,
    onInvitePhoneChange: (String) -> Unit,
    inviteRole: String,
    onInviteRoleChange: (String) -> Unit,
    isInvitingMember: Boolean,
    onInviteMember: () -> Unit,
) {
    RoleSectionCard(title = "Invite staff") {
        OutlinedTextField(
            value = invitePhone,
            onValueChange = onInvitePhoneChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Staff phone number") },
        )
        RoleChoiceRow(
            label = "Role",
            options = businessRoles,
            selected = inviteRole,
            onSelected = onInviteRoleChange,
        )
        Button(
            onClick = onInviteMember,
            enabled = !isInvitingMember,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isInvitingMember) "Inviting..." else "Send invitation")
        }
    }
}

@Composable
private fun BusinessStaffSection(
    staff: List<BusinessStaffMember>,
    onRemoveMember: (String) -> Unit,
) {
    RoleSectionCard(title = "Staff") {
        if (staff.isEmpty()) {
            Text("No staff members yet.")
        } else {
            staff.forEach { member ->
                RoleListCard {
                    Text(text = member.displayName, fontWeight = FontWeight.Bold)
                    DetailLine("Role", member.role)
                    member.contact?.let { DetailLine("Contact", it) }
                    member.category?.let { DetailLine("Category", it) }
                    DetailLine("Tips", member.tipsCount.toString())
                    DetailLine("Total tipped", roleAmountText(member.totalAmountPaise))
                    if (member.averageRating > 0.0) {
                        DetailLine("Average rating", providerScoreText(member.averageRating))
                    }
                    OutlinedButton(onClick = { onRemoveMember(member.memberId) }, modifier = Modifier.fillMaxWidth()) {
                        Text("Remove member")
                    }
                }
            }
        }
    }
}

@Composable
private fun BusinessSatisfactionSection(
    reviews: List<BusinessReviewItem>,
) {
    RoleSectionCard(title = "Satisfaction") {
        if (reviews.isEmpty()) {
            Text("No review data yet.")
        } else {
            reviews.take(20).forEach { review ->
                RoleListCard {
                    Text(text = review.providerName, fontWeight = FontWeight.Bold)
                    review.rating?.let { DetailLine("Rating", "$it/5") }
                    review.message?.let { DetailLine("Message", it) }
                    DetailLine("Amount", roleAmountText(review.amountPaise))
                    review.createdAt?.let { DetailLine("Created", roleDateText(it) ?: it) }
                }
            }
        }
    }
}

@Composable
private fun BusinessQrSection(
    qrGroups: List<BusinessQrStaffGroup>,
) {
    RoleSectionCard(title = "Staff QR groups") {
        if (qrGroups.isEmpty()) {
            Text("No staff QR codes yet.")
        } else {
            qrGroups.forEach { group ->
                RoleListCard {
                    Text(text = group.displayName, fontWeight = FontWeight.Bold)
                    DetailLine("QR codes", group.qrCodes.size.toString())
                    group.qrCodes.forEach { qr ->
                        DetailLine("QR", qr.locationLabel ?: qr.id)
                    }
                }
            }
        }
    }
}

@Composable
private fun RoleSectionCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
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
            content = {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                content()
            },
        )
    }
}

@Composable
private fun RoleListCard(
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color.White),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}

@Composable
private fun RoleChoiceRow(
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
                    OutlinedButton(
                        onClick = { onSelected(option) },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(if (selected == option) "$option*" else option)
                    }
                }
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

private fun providerScoreText(value: Double?): String {
    val safeValue = value ?: 0.0
    return if (safeValue == 0.0) "0.0" else String.format("%.1f", safeValue)
}

private fun roleAmountText(amountPaise: Int): String = "Rs ${amountPaise / 100}"

private fun roleDateText(value: String?): String? {
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
