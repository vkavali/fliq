package com.fliq.android.data

import org.json.JSONObject

enum class NativeRole {
    CUSTOMER,
    PROVIDER,
    BUSINESS,
}

data class AuthUser(
    val id: String,
    val phone: String?,
    val email: String?,
    val name: String?,
    val type: String,
    val kycStatus: String?,
    val languagePreference: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): AuthUser {
            return AuthUser(
                id = json.getString("id"),
                phone = json.optString("phone").takeIf { it.isNotBlank() },
                email = json.optString("email").takeIf { it.isNotBlank() },
                name = json.optString("name").takeIf { it.isNotBlank() },
                type = json.optString("type"),
                kycStatus = json.optString("kycStatus").takeIf { it.isNotBlank() },
                languagePreference = json.optString("languagePreference").takeIf { it.isNotBlank() },
            )
        }
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("phone", phone)
            put("email", email)
            put("name", name)
            put("type", type)
            put("kycStatus", kycStatus)
            put("languagePreference", languagePreference)
        }
    }
}

data class AuthSession(
    val accessToken: String,
    val refreshToken: String,
    val user: AuthUser,
)

data class SendCodeResult(
    val message: String,
    val otpHint: String?,
)

class AuthException(
    override val message: String,
    val statusCode: Int,
) : Exception(message)
