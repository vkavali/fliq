package com.fliq.android.data

import com.fliq.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

enum class NativeRecurringFrequency(
    val apiValue: String,
    val label: String,
) {
    WEEKLY("WEEKLY", "Weekly"),
    MONTHLY("MONTHLY", "Monthly"),
}

data class NativeRecurringAuthorization(
    val recurringTipId: String,
    val subscriptionId: String,
    val authorizationUrl: String,
    val razorpayKeyId: String,
    val providerName: String,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeRecurringAuthorization {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            return NativeRecurringAuthorization(
                recurringTipId = json.getString("recurringTipId"),
                subscriptionId = json.optString("subscriptionId"),
                authorizationUrl = json.optString("authorizationUrl"),
                razorpayKeyId = json.optString("razorpayKeyId"),
                providerName = provider.optString("name", "Provider"),
            )
        }
    }
}

data class NativeRecurringTip(
    val id: String,
    val providerName: String?,
    val providerCategory: String?,
    val amountPaise: Int,
    val frequency: String,
    val status: String,
    val nextChargeDate: String?,
    val totalCharges: Int,
    val createdAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeRecurringTip {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            val providerProfile = provider.optJSONObject("providerProfile") ?: JSONObject()
            return NativeRecurringTip(
                id = json.getString("id"),
                providerName = provider.optString("name").takeIf { it.isNotBlank() },
                providerCategory = providerProfile.optString("category").takeIf { it.isNotBlank() },
                amountPaise = json.optInt("amountPaise", 0),
                frequency = json.optString("frequency", "MONTHLY"),
                status = json.optString("status", "UNKNOWN"),
                nextChargeDate = json.optString("nextChargeDate").takeIf { it.isNotBlank() },
                totalCharges = json.optInt("totalCharges", 0),
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class NativeDeferredTip(
    val id: String,
    val providerId: String,
    val providerName: String?,
    val providerCategory: String?,
    val amountPaise: Int,
    val message: String?,
    val rating: Int?,
    val promisedAt: String?,
    val dueAt: String?,
    val status: String,
    val tipId: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeDeferredTip {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            val providerProfile = provider.optJSONObject("providerProfile") ?: JSONObject()
            return NativeDeferredTip(
                id = json.getString("id"),
                providerId = json.optString("providerId"),
                providerName = provider.optString("name").takeIf { it.isNotBlank() },
                providerCategory = providerProfile.optString("category").takeIf { it.isNotBlank() },
                amountPaise = json.optInt("amountPaise", 0),
                message = json.optString("message").takeIf { it.isNotBlank() },
                rating = json.optInt("rating").takeIf { !json.isNull("rating") },
                promisedAt = json.optString("promisedAt").takeIf { it.isNotBlank() },
                dueAt = json.optString("dueAt").takeIf { it.isNotBlank() },
                status = json.optString("status", "PROMISED"),
                tipId = json.optString("tipId").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class NativeBadge(
    val id: String,
    val code: String,
    val name: String,
    val description: String,
    val category: String,
    val threshold: Int,
    val earned: Boolean,
    val earnedAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeBadge {
            return NativeBadge(
                id = json.getString("id"),
                code = json.optString("code"),
                name = json.optString("name", "Badge"),
                description = json.optString("description"),
                category = json.optString("category", "GENERAL"),
                threshold = json.optInt("threshold", 0),
                earned = json.optBoolean("earned", false),
                earnedAt = json.optString("earnedAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class NativeStreak(
    val currentStreak: Int,
    val longestStreak: Int,
    val lastTipDate: String?,
)

data class NativeLeaderboardEntry(
    val rank: Int,
    val userId: String?,
    val name: String,
    val tipCount: Int,
    val totalAmountPaise: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeLeaderboardEntry {
            return NativeLeaderboardEntry(
                rank = json.optInt("rank", 0),
                userId = json.optString("userId").takeIf { it.isNotBlank() },
                name = json.optString("name", "User"),
                tipCount = json.optInt("tipCount", 0),
                totalAmountPaise = json.optInt(
                    "totalAmountPaise",
                    json.optInt("totalEarnedPaise", 0),
                ),
            )
        }
    }
}

data class NativePaymentOrder(
    val tipId: String,
    val orderId: String,
    val amountPaise: Int,
    val currency: String,
    val razorpayKeyId: String,
    val title: String,
    val subtitle: String?,
) {
    val isMockOrder: Boolean
        get() = orderId.startsWith("mock_order_")

    companion object {
        fun fromJson(json: JSONObject): NativePaymentOrder {
            return NativePaymentOrder(
                tipId = json.getString("tipId"),
                orderId = json.optString("orderId"),
                amountPaise = json.optInt("amount", json.optInt("amountPaise", 0)),
                currency = json.optString("currency", "INR"),
                razorpayKeyId = json.optString("razorpayKeyId"),
                title = json.optString("providerName")
                    .takeIf { it.isNotBlank() }
                    ?: json.optString("jarName").takeIf { it.isNotBlank() }
                    ?: "Fliq payment",
                subtitle = json.optString("jarName").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class NativeEkycInitiation(
    val sessionToken: String,
    val maskedPhone: String,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeEkycInitiation {
            return NativeEkycInitiation(
                sessionToken = json.optString("sessionToken"),
                maskedPhone = json.optString("maskedPhone"),
            )
        }
    }
}

data class NativeEkycProfile(
    val name: String,
    val dob: String,
    val gender: String,
    val address: String,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeEkycProfile {
            return NativeEkycProfile(
                name = json.optString("name", ""),
                dob = json.optString("dob", ""),
                gender = json.optString("gender", ""),
                address = json.optString("address", ""),
            )
        }
    }
}

data class NativeEkycStatus(
    val kycVerified: Boolean,
    val kycMethod: String?,
    val kycCompletedAt: String?,
    val kycStatus: String,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeEkycStatus {
            return NativeEkycStatus(
                kycVerified = json.optBoolean("kycVerified", false),
                kycMethod = json.optString("kycMethod").takeIf { it.isNotBlank() },
                kycCompletedAt = json.optString("kycCompletedAt").takeIf { it.isNotBlank() },
                kycStatus = json.optString("kycStatus", "PENDING"),
            )
        }
    }
}

data class NativeTipResponse(
    val id: String,
    val type: String,
    val emoji: String?,
    val mediaUrl: String?,
    val createdAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipResponse {
            return NativeTipResponse(
                id = json.optString("id"),
                type = json.optString("type", "emoji"),
                emoji = json.optString("emoji").takeIf { it.isNotBlank() },
                mediaUrl = json.optString("mediaUrl").takeIf { it.isNotBlank() },
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

class ParityCompletionRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun createRecurringTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        frequency: NativeRecurringFrequency,
    ): NativeRecurringAuthorization {
        val response = executeJsonRequest(
            path = "/recurring-tips",
            method = "POST",
            body = JSONObject()
                .put("providerId", providerId)
                .put("amountPaise", amountPaise)
                .put("frequency", frequency.apiValue),
            accessToken = accessToken,
        )
        return NativeRecurringAuthorization.fromJson(response)
    }

    suspend fun getMyRecurringTips(accessToken: String): List<NativeRecurringTip> {
        val response = executeJsonArrayRequest(
            path = "/recurring-tips",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(NativeRecurringTip.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun pauseRecurringTip(accessToken: String, recurringTipId: String) {
        executeJsonRequest(
            path = "/recurring-tips/$recurringTipId/pause",
            method = "PATCH",
            accessToken = accessToken,
        )
    }

    suspend fun resumeRecurringTip(accessToken: String, recurringTipId: String) {
        executeJsonRequest(
            path = "/recurring-tips/$recurringTipId/resume",
            method = "PATCH",
            accessToken = accessToken,
        )
    }

    suspend fun cancelRecurringTip(accessToken: String, recurringTipId: String) {
        executeJsonRequest(
            path = "/recurring-tips/$recurringTipId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun createDeferredTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        message: String?,
        rating: Int?,
    ): NativeDeferredTip {
        val body = JSONObject()
            .put("providerId", providerId)
            .put("amountPaise", amountPaise)
        message?.takeIf { it.isNotBlank() }?.let { body.put("message", it) }
        rating?.let { body.put("rating", it) }

        val response = executeJsonRequest(
            path = "/tip-later",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
        return NativeDeferredTip.fromJson(response)
    }

    suspend fun getMyDeferredTips(accessToken: String): List<NativeDeferredTip> {
        val response = executeJsonArrayRequest(
            path = "/tip-later/my",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(NativeDeferredTip.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun payDeferredTip(accessToken: String, deferredTipId: String): NativePaymentOrder {
        val response = executeJsonRequest(
            path = "/tip-later/$deferredTipId/pay",
            method = "POST",
            accessToken = accessToken,
        )
        return NativePaymentOrder.fromJson(response)
    }

    suspend fun cancelDeferredTip(accessToken: String, deferredTipId: String) {
        executeJsonRequest(
            path = "/tip-later/$deferredTipId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun getBadges(accessToken: String): List<NativeBadge> {
        val response = executeJsonArrayRequest(
            path = "/gamification/badges",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(NativeBadge.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun getStreak(accessToken: String): NativeStreak {
        val response = executeJsonRequest(
            path = "/gamification/streak",
            method = "GET",
            accessToken = accessToken,
        )
        return NativeStreak(
            currentStreak = response.optInt("currentStreak", 0),
            longestStreak = response.optInt("longestStreak", 0),
            lastTipDate = response.optString("lastTipDate").takeIf { it.isNotBlank() },
        )
    }

    suspend fun getLeaderboard(
        path: String,
        period: String = "week",
    ): List<NativeLeaderboardEntry> {
        val response = executeJsonArrayRequest("$path?period=$period")
        return buildList {
            for (index in 0 until response.length()) {
                add(NativeLeaderboardEntry.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun saveBankDetails(
        accessToken: String,
        upiVpa: String?,
        bankAccountNumber: String?,
        ifscCode: String?,
        pan: String?,
    ) {
        val body = JSONObject()
        upiVpa?.takeIf { it.isNotBlank() }?.let { body.put("upiVpa", it) }
        bankAccountNumber?.takeIf { it.isNotBlank() }?.let { body.put("bankAccountNumber", it) }
        ifscCode?.takeIf { it.isNotBlank() }?.let { body.put("ifscCode", it) }
        pan?.takeIf { it.isNotBlank() }?.let { body.put("pan", it) }

        executeJsonRequest(
            path = "/providers/profile",
            method = "PATCH",
            body = body,
            accessToken = accessToken,
        )
    }

    suspend fun initiateEkyc(accessToken: String, aadhaarOrVid: String): NativeEkycInitiation {
        val response = executeJsonRequest(
            path = "/ekyc/initiate",
            method = "POST",
            body = JSONObject().put("aadhaarOrVid", aadhaarOrVid),
            accessToken = accessToken,
        )
        return NativeEkycInitiation.fromJson(response)
    }

    suspend fun verifyEkycOtp(
        accessToken: String,
        sessionToken: String,
        otp: String,
    ): NativeEkycProfile {
        val response = executeJsonRequest(
            path = "/ekyc/verify-otp",
            method = "POST",
            body = JSONObject()
                .put("sessionToken", sessionToken)
                .put("otp", otp),
            accessToken = accessToken,
        )
        return NativeEkycProfile.fromJson(response.optJSONObject("profile") ?: JSONObject())
    }

    suspend fun getEkycStatus(accessToken: String): NativeEkycStatus {
        val response = executeJsonRequest(
            path = "/ekyc/status",
            method = "GET",
            accessToken = accessToken,
        )
        return NativeEkycStatus.fromJson(response)
    }

    suspend fun createEmojiResponse(
        accessToken: String,
        tipId: String,
        emoji: String,
    ): NativeTipResponse {
        val response = executeJsonRequest(
            path = "/responses",
            method = "POST",
            body = JSONObject()
                .put("tipId", tipId)
                .put("type", "emoji")
                .put("emoji", emoji),
            accessToken = accessToken,
        )
        return NativeTipResponse.fromJson(response)
    }

    suspend fun getTipResponse(tipId: String): NativeTipResponse? {
        val response = executeJsonNullableRequest(
            path = "/responses/tip/$tipId",
        ) ?: return null
        return NativeTipResponse.fromJson(response)
    }

    suspend fun exportBusinessCsv(
        accessToken: String,
        businessId: String,
    ): String {
        return executeRawRequest(
            path = "/business/$businessId/export",
            method = "GET",
            accessToken = accessToken,
        )
    }

    private suspend fun executeJsonRequest(
        path: String,
        method: String,
        body: JSONObject? = null,
        accessToken: String? = null,
    ): JSONObject = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Content-Type", "application/json")

        if (!accessToken.isNullOrBlank()) {
            requestBuilder.addHeader("Authorization", "Bearer $accessToken")
        }

        when (method) {
            "POST" -> requestBuilder.post((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
            "PATCH" -> requestBuilder.patch((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
            "DELETE" -> requestBuilder.delete()
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

    private suspend fun executeJsonArrayRequest(
        path: String,
        accessToken: String? = null,
    ): JSONArray = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Content-Type", "application/json")
            .get()

        if (!accessToken.isNullOrBlank()) {
            requestBuilder.addHeader("Authorization", "Bearer $accessToken")
        }

        client.newCall(requestBuilder.build()).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val json = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                throw AuthException(
                    message = json.optString("message", "Request failed with ${response.code}"),
                    statusCode = response.code,
                )
            }
            JSONArray(text.ifBlank { "[]" })
        }
    }

    private suspend fun executeJsonNullableRequest(
        path: String,
        accessToken: String? = null,
    ): JSONObject? = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Content-Type", "application/json")
            .get()

        if (!accessToken.isNullOrBlank()) {
            requestBuilder.addHeader("Authorization", "Bearer $accessToken")
        }

        client.newCall(requestBuilder.build()).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (response.code == 404 || text.isBlank() || text == "null") {
                return@withContext null
            }
            if (!response.isSuccessful) {
                val json = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                throw AuthException(
                    message = json.optString("message", "Request failed with ${response.code}"),
                    statusCode = response.code,
                )
            }
            JSONObject(text)
        }
    }

    private suspend fun executeRawRequest(
        path: String,
        method: String,
        accessToken: String? = null,
    ): String = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")

        if (!accessToken.isNullOrBlank()) {
            requestBuilder.addHeader("Authorization", "Bearer $accessToken")
        }

        when (method) {
            "GET" -> requestBuilder.get()
            else -> error("Unsupported method: $method")
        }

        client.newCall(requestBuilder.build()).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val json = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                throw AuthException(
                    message = json.optString("message", "Request failed with ${response.code}"),
                    statusCode = response.code,
                )
            }
            text
        }
    }
}
