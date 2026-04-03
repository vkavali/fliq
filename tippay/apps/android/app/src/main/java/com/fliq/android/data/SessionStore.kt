package com.fliq.android.data

import android.content.Context
import org.json.JSONObject

class SessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("fliq_native_session", Context.MODE_PRIVATE)

    fun saveSession(session: AuthSession) {
        prefs.edit()
            .putString(KEY_ACCESS_TOKEN, session.accessToken)
            .putString(KEY_REFRESH_TOKEN, session.refreshToken)
            .putString(KEY_USER, session.user.toJson().toString())
            .apply()
    }

    fun loadSession(): AuthSession? {
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, null) ?: return null
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null) ?: return null
        val userJson = prefs.getString(KEY_USER, null) ?: return null
        val user = AuthUser.fromJson(JSONObject(userJson))
        return AuthSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            user = user,
        )
    }

    fun clearSession() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_USER = "user"
    }
}
