package com.fliq.android.data

import com.fliq.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class PushNotificationRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun registerToken(
        accessToken: String,
        token: String,
        platform: String = "android",
    ) {
        executeJsonRequest(
            path = "/notifications/fcm-token",
            method = "POST",
            body = JSONObject()
                .put("token", token)
                .put("platform", platform),
            accessToken = accessToken,
        )
    }

    suspend fun removeToken(accessToken: String) {
        executeJsonRequest(
            path = "/notifications/fcm-token",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    private suspend fun executeJsonRequest(
        path: String,
        method: String,
        body: JSONObject? = null,
        accessToken: String,
    ): JSONObject = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Authorization", "Bearer $accessToken")

        when (method) {
            "POST" -> requestBuilder
                .addHeader("Content-Type", "application/json")
                .post((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
            "DELETE" -> requestBuilder.delete()
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
