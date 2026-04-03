package com.fliq.android.data

import com.fliq.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import org.json.JSONObject

class ProviderRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun getOwnProfile(accessToken: String): ProviderSelfProfile {
        val response = executeJsonRequest(
            path = "/providers/profile",
            method = "GET",
            accessToken = accessToken,
        )
        return ProviderSelfProfile.fromJson(response)
    }

    suspend fun createProfile(
        accessToken: String,
        displayName: String,
        category: String,
        bio: String?,
        upiVpa: String?,
    ): ProviderSelfProfile {
        val body = JSONObject()
            .put("displayName", displayName)
            .put("category", category)

        bio?.takeIf { it.isNotBlank() }?.let { body.put("bio", it) }
        upiVpa?.takeIf { it.isNotBlank() }?.let { body.put("upiVpa", it) }

        executeJsonRequest(
            path = "/providers/profile",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
        return getOwnProfile(accessToken)
    }

    suspend fun updateProfile(
        accessToken: String,
        displayName: String?,
        category: String?,
        bio: String?,
        upiVpa: String?,
    ): ProviderSelfProfile {
        val body = JSONObject()
        displayName?.takeIf { it.isNotBlank() }?.let { body.put("displayName", it) }
        category?.takeIf { it.isNotBlank() }?.let { body.put("category", it) }
        bio?.takeIf { it.isNotBlank() }?.let { body.put("bio", it) }
        upiVpa?.takeIf { it.isNotBlank() }?.let { body.put("upiVpa", it) }

        executeJsonRequest(
            path = "/providers/profile",
            method = "PATCH",
            body = body,
            accessToken = accessToken,
        )
        return getOwnProfile(accessToken)
    }

    suspend fun uploadAvatar(
        accessToken: String,
        imageBytes: ByteArray,
        mimeType: String = "image/jpeg",
    ): String? = withContext(Dispatchers.IO) {
        val tempFile = File.createTempFile("fliq-avatar", ".jpg")
        tempFile.writeBytes(imageBytes)

        try {
            val requestBody = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart(
                    "avatar",
                    tempFile.name,
                    tempFile.asRequestBody(mimeType.toMediaType()),
                )
                .build()

            val request = Request.Builder()
                .url("${BuildConfig.API_BASE_URL}/providers/profile/avatar")
                .addHeader("Authorization", "Bearer $accessToken")
                .post(requestBody)
                .build()

            client.newCall(request).execute().use { response ->
                val text = response.body?.string().orEmpty()
                val json = if (text.isBlank()) JSONObject() else JSONObject(text)
                if (!response.isSuccessful) {
                    throw AuthException(
                        message = json.optString("message", "Request failed with ${response.code}"),
                        statusCode = response.code,
                    )
                }
                json.optString("avatarUrl").takeIf { it.isNotBlank() }
            }
        } finally {
            tempFile.delete()
        }
    }

    suspend fun getReceivedTips(accessToken: String): List<ProviderTipItem> {
        val response = executeJsonRequest(
            path = "/tips/provider",
            method = "GET",
            accessToken = accessToken,
        )
        val tips = response.optJSONArray("tips") ?: return emptyList()
        return buildList {
            for (index in 0 until tips.length()) {
                add(ProviderTipItem.fromJson(tips.getJSONObject(index)))
            }
        }
    }

    suspend fun getQrCodes(accessToken: String): List<ProviderQrCode> {
        val response = executeJsonArrayRequest(
            path = "/qrcodes/my",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(ProviderQrCode.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun createQrCode(accessToken: String, locationLabel: String?): ProviderQrCode {
        val body = JSONObject()
        locationLabel?.takeIf { it.isNotBlank() }?.let { body.put("locationLabel", it) }
        val response = executeJsonRequest(
            path = "/qrcodes",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
        return ProviderQrCode.fromJson(response)
    }

    suspend fun getPaymentLinks(accessToken: String): List<ProviderPaymentLink> {
        val response = executeJsonArrayRequest(
            path = "/payment-links/my",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(ProviderPaymentLink.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun createPaymentLink(
        accessToken: String,
        role: String?,
        workplace: String?,
        description: String?,
        suggestedAmountPaise: Int?,
        allowCustomAmount: Boolean,
    ): ProviderPaymentLink {
        val body = JSONObject()
        role?.takeIf { it.isNotBlank() }?.let { body.put("role", it) }
        workplace?.takeIf { it.isNotBlank() }?.let { body.put("workplace", it) }
        description?.takeIf { it.isNotBlank() }?.let { body.put("description", it) }
        suggestedAmountPaise?.takeIf { it > 0 }?.let { body.put("suggestedAmountPaise", it) }
        body.put("allowCustomAmount", allowCustomAmount)

        val response = executeJsonRequest(
            path = "/payment-links",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
        return ProviderPaymentLink.fromJson(response)
    }

    suspend fun getPayoutHistory(accessToken: String): List<ProviderPayoutItem> {
        val response = executeJsonRequest(
            path = "/payouts/history",
            method = "GET",
            accessToken = accessToken,
        )
        val payouts = response.optJSONArray("payouts") ?: return emptyList()
        return buildList {
            for (index in 0 until payouts.length()) {
                add(ProviderPayoutItem.fromJson(payouts.getJSONObject(index)))
            }
        }
    }

    suspend fun requestPayout(accessToken: String, amountPaise: Int, mode: String = "IMPS") {
        executeJsonRequest(
            path = "/payouts/request",
            method = "POST",
            body = JSONObject()
                .put("amountPaise", amountPaise)
                .put("mode", mode),
            accessToken = accessToken,
        )
    }

    suspend fun getActiveDream(accessToken: String): ProviderDreamData? {
        val response = executeJsonNullableRequest(
            path = "/dreams/active",
            accessToken = accessToken,
        ) ?: return null
        return ProviderDreamData.fromJson(response)
    }

    suspend fun saveDream(
        accessToken: String,
        existingDreamId: String?,
        title: String,
        description: String,
        category: String,
        goalAmountPaise: Int,
    ): ProviderDreamData {
        val response = if (existingDreamId.isNullOrBlank()) {
            executeJsonRequest(
                path = "/dreams",
                method = "POST",
                body = JSONObject()
                    .put("title", title)
                    .put("description", description)
                    .put("category", category)
                    .put("goalAmount", goalAmountPaise),
                accessToken = accessToken,
            )
        } else {
            executeJsonRequest(
                path = "/dreams/$existingDreamId",
                method = "PUT",
                body = JSONObject()
                    .put("title", title)
                    .put("description", description)
                    .put("goalAmount", goalAmountPaise),
                accessToken = accessToken,
            )
        }
        return ProviderDreamData.fromJson(response)
    }

    suspend fun getRecurringTips(accessToken: String): List<ProviderRecurringTip> {
        val response = executeJsonArrayRequest(
            path = "/recurring-tips/provider",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(ProviderRecurringTip.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun getBusinessInvitations(accessToken: String): List<BusinessInvitationData> {
        val response = executeJsonArrayRequest(
            path = "/business/invitations/mine",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(BusinessInvitationData.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun getBusinessAffiliations(accessToken: String): List<BusinessAffiliation> {
        val response = executeJsonArrayRequest(
            path = "/business/memberships/mine",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(BusinessAffiliation.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun respondToInvitation(
        accessToken: String,
        invitationId: String,
        response: String,
    ) {
        executeJsonRequest(
            path = "/business/invitations/$invitationId/respond",
            method = "POST",
            body = JSONObject().put("response", response),
            accessToken = accessToken,
        )
    }

    private suspend fun executeJsonRequest(
        path: String,
        method: String,
        body: JSONObject? = null,
        accessToken: String? = null,
    ): JSONObject {
        return withContext(Dispatchers.IO) {
            val requestBuilder = Request.Builder()
                .url("${BuildConfig.API_BASE_URL}$path")
                .addHeader("Content-Type", "application/json")

            if (!accessToken.isNullOrBlank()) {
                requestBuilder.addHeader("Authorization", "Bearer $accessToken")
            }

            when (method) {
                "POST" -> requestBuilder.post((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
                "PATCH" -> requestBuilder.patch((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
                "PUT" -> requestBuilder.put((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
                "GET" -> requestBuilder.get()
                else -> error("Unsupported method: $method")
            }

            client.newCall(requestBuilder.build()).execute().use { response ->
                val text = response.body?.string().orEmpty()
                val json = if (text.isBlank()) JSONObject() else JSONObject(text)

                if (!response.isSuccessful) {
                    throw AuthException(
                        message = json.optString("message", "Request failed with ${response.code}"),
                        statusCode = response.code,
                    )
                }

                json
            }
        }
    }

    private suspend fun executeJsonArrayRequest(
        path: String,
        accessToken: String,
    ) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val json = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                throw AuthException(
                    message = json.optString("message", "Request failed with ${response.code}"),
                    statusCode = response.code,
                )
            }
            org.json.JSONArray(text.ifBlank { "[]" })
        }
    }

    private suspend fun executeJsonNullableRequest(
        path: String,
        accessToken: String,
    ): JSONObject? {
        return withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${BuildConfig.API_BASE_URL}$path")
                .addHeader("Content-Type", "application/json")
                .addHeader("Authorization", "Bearer $accessToken")
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                val text = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    val json = if (text.isBlank()) JSONObject() else JSONObject(text)
                    throw AuthException(
                        message = json.optString("message", "Request failed with ${response.code}"),
                        statusCode = response.code,
                    )
                }
                if (text.isBlank() || text == "null") {
                    null
                } else {
                    JSONObject(text)
                }
            }
        }
    }
}
