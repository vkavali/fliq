package com.fliq.android.data

import android.net.Uri
import com.fliq.android.BuildConfig
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class CustomerRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun searchProviders(query: String): List<ProviderSearchResult> {
        val encodedQuery = URLEncoder.encode(query, StandardCharsets.UTF_8.toString())
        val response = executeJsonRequest(
            path = "/providers/search?q=$encodedQuery",
            method = "GET",
        )
        val providers = response.optJSONArray("providers") ?: return emptyList()
        return buildList {
            for (index in 0 until providers.length()) {
                add(ProviderSearchResult.fromJson(providers.getJSONObject(index)))
            }
        }
    }

    suspend fun getPublicProfile(providerId: String): ProviderProfile {
        val response = executeJsonRequest(
            path = "/providers/$providerId/public",
            method = "GET",
        )
        return ProviderProfile.fromJson(response)
    }

    suspend fun resolveQrCode(rawInput: String): TipEntryContext {
        val qrCodeId = extractIdentifier(rawInput, "qr")
        val response = executeJsonRequest(
            path = "/qrcodes/$qrCodeId/resolve",
            method = "GET",
        )
        return TipEntryContext.fromQrJson(response)
    }

    suspend fun resolvePaymentLink(rawInput: String): TipEntryContext {
        val paymentLinkId = extractIdentifier(rawInput, "tip")
        val response = executeJsonRequest(
            path = "/payment-links/$paymentLinkId/resolve",
            method = "GET",
        )
        return TipEntryContext.fromPaymentLinkJson(response)
    }

    suspend fun createAuthenticatedTip(
        accessToken: String,
        providerId: String,
        amountPaise: Int,
        source: TipSourceOption,
        intent: TipIntentOption,
        message: String?,
        rating: Int,
        idempotencyKey: String = UUID.randomUUID().toString(),
    ): CreatedTipOrder {
        val body = JSONObject()
            .put("providerId", providerId)
            .put("amountPaise", amountPaise)
            .put("source", source.apiValue)
            .put("intent", intent.apiValue)
            .put("rating", rating)

        if (!message.isNullOrBlank()) {
            body.put("message", message)
        }

        val response = executeJsonRequest(
            path = "/tips/authenticated",
            method = "POST",
            body = body,
            accessToken = accessToken,
            extraHeaders = mapOf("idempotency-key" to idempotencyKey),
        )

        return CreatedTipOrder.fromJson(response)
    }

    suspend fun verifyPayment(
        tipId: String,
        orderId: String,
        paymentId: String,
        signature: String,
    ): VerifiedTipResult {
        val response = executeJsonRequest(
            path = "/tips/$tipId/verify",
            method = "POST",
            body = JSONObject()
                .put("razorpay_order_id", orderId)
                .put("razorpay_payment_id", paymentId)
                .put("razorpay_signature", signature),
        )
        return VerifiedTipResult.fromJson(response)
    }

    suspend fun verifyMockPayment(
        tipId: String,
        orderId: String,
    ): VerifiedTipResult {
        return verifyPayment(
            tipId = tipId,
            orderId = orderId,
            paymentId = "mock_payment_${System.currentTimeMillis()}",
            signature = "mock_signature",
        )
    }

    suspend fun getTipStatus(tipId: String): TipStatusSnapshot {
        val response = executeJsonRequest(
            path = "/tips/$tipId/status",
            method = "GET",
        )
        return TipStatusSnapshot.fromJson(response)
    }

    suspend fun getTipImpact(tipId: String): TipImpactSnapshot {
        val response = executeJsonRequest(
            path = "/tips/$tipId/impact",
            method = "GET",
        )
        return TipImpactSnapshot.fromJson(response)
    }

    suspend fun getCustomerTipHistory(
        accessToken: String,
        page: Int = 1,
        limit: Int = 20,
    ): CustomerTipHistoryPage {
        val response = executeJsonRequest(
            path = "/tips/customer?page=$page&limit=$limit",
            method = "GET",
            accessToken = accessToken,
        )
        return CustomerTipHistoryPage.fromJson(response)
    }

    suspend fun getCurrentUserProfile(accessToken: String): AuthUser {
        val response = executeJsonRequest(
            path = "/users/me",
            method = "GET",
            accessToken = accessToken,
        )
        return AuthUser.fromJson(response)
    }

    suspend fun updateCurrentUserProfile(
        accessToken: String,
        name: String?,
        email: String?,
        phone: String?,
        languagePreference: String?,
    ): AuthUser {
        val body = JSONObject()
        name?.takeIf { it.isNotBlank() }?.let { body.put("name", it) }
        email?.takeIf { it.isNotBlank() }?.let { body.put("email", it) }
        phone?.takeIf { it.isNotBlank() }?.let { body.put("phone", it) }
        languagePreference?.takeIf { it.isNotBlank() }?.let { body.put("languagePreference", it) }

        val response = executeJsonRequest(
            path = "/users/me",
            method = "PATCH",
            body = body,
            accessToken = accessToken,
        )
        return AuthUser.fromJson(response)
    }

    private suspend fun executeJsonRequest(
        path: String,
        method: String,
        body: JSONObject? = null,
        accessToken: String? = null,
        extraHeaders: Map<String, String> = emptyMap(),
    ): JSONObject {
        return withContext(Dispatchers.IO) {
            val requestBuilder = Request.Builder()
                .url("${BuildConfig.API_BASE_URL}$path")
                .addHeader("Content-Type", "application/json")

            if (!accessToken.isNullOrBlank()) {
                requestBuilder.addHeader("Authorization", "Bearer $accessToken")
            }

            extraHeaders.forEach { (name, value) ->
                requestBuilder.addHeader(name, value)
            }

            when (method) {
                "POST" -> requestBuilder.post((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
                "PATCH" -> requestBuilder.patch((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
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

    private fun extractIdentifier(rawInput: String, expectedSegment: String): String {
        val trimmed = rawInput.trim()
        if (trimmed.isBlank()) {
            return trimmed
        }

        val parsed = runCatching { Uri.parse(trimmed) }.getOrNull()
        val pathSegments = parsed?.pathSegments.orEmpty()

        if (pathSegments.isNotEmpty()) {
            val expectedIndex = pathSegments.indexOf(expectedSegment)
            if (expectedIndex >= 0 && expectedIndex + 1 < pathSegments.size) {
                return pathSegments[expectedIndex + 1]
            }

            return pathSegments.last()
        }

        return trimmed.substringAfterLast('/')
    }
}
