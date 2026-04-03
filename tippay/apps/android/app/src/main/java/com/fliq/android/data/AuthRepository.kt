package com.fliq.android.data

import android.content.Context
import com.fliq.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class AuthRepository(context: Context) {
    private val client = OkHttpClient()
    private val sessionStore = SessionStore(context)
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun restoreSession(): AuthSession? {
        val stored = sessionStore.loadSession() ?: return null
        return try {
            val freshUser = getCurrentUser(stored.accessToken)
            val refreshed = stored.copy(user = freshUser)
            sessionStore.saveSession(refreshed)
            refreshed
        } catch (error: AuthException) {
            if (error.statusCode == 401) {
                sessionStore.clearSession()
                null
            } else {
                stored
            }
        } catch (_: Exception) {
            stored
        }
    }

    suspend fun sendCode(role: NativeRole, credential: String): SendCodeResult {
        val endpoint = if (role == NativeRole.BUSINESS) "/auth/otp/email/send" else "/auth/otp/send"
        val body = if (role == NativeRole.BUSINESS) {
            JSONObject().put("email", credential)
        } else {
            JSONObject().put("phone", credential)
        }

        val response = executeJsonRequest(
            path = endpoint,
            method = "POST",
            body = body,
        )

        return SendCodeResult(
            message = response.optString("message", "Code sent"),
            otpHint = response.optString("otp").takeIf { it.isNotBlank() },
        )
    }

    suspend fun verifyCode(role: NativeRole, credential: String, code: String): AuthSession {
        val endpoint = if (role == NativeRole.BUSINESS) "/auth/otp/email/verify" else "/auth/otp/verify"
        val body = if (role == NativeRole.BUSINESS) {
            JSONObject()
                .put("email", credential)
                .put("code", code)
        } else {
            JSONObject()
                .put("phone", credential)
                .put("code", code)
        }

        val response = executeJsonRequest(
            path = endpoint,
            method = "POST",
            body = body,
        )

        val session = AuthSession(
            accessToken = response.getString("accessToken"),
            refreshToken = response.getString("refreshToken"),
            user = AuthUser.fromJson(response.getJSONObject("user")),
        )
        sessionStore.saveSession(session)
        return session
    }

    suspend fun logout() {
        sessionStore.clearSession()
    }

    fun persistSession(session: AuthSession) {
        sessionStore.saveSession(session)
    }

    private suspend fun getCurrentUser(accessToken: String): AuthUser {
        val response = executeJsonRequest(
            path = "/users/me",
            method = "GET",
            accessToken = accessToken,
        )
        return AuthUser.fromJson(response)
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
}
