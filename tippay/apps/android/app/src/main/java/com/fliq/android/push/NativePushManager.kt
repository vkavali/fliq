package com.fliq.android.push

import android.content.Context
import com.fliq.android.data.AuthSession
import com.fliq.android.data.PushNotificationRepository
import com.fliq.android.data.SessionStore
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

class NativePushManager(
    private val context: Context,
) {
    private val repository = PushNotificationRepository()
    private val sessionStore = SessionStore(context)

    suspend fun syncTokenIfPossible(session: AuthSession) {
        if (!isConfigured()) {
            return
        }

        val token = runCatching { FirebaseMessaging.getInstance().token.await() }.getOrNull() ?: return
        repository.registerToken(
            accessToken = session.accessToken,
            token = token,
            platform = "android",
        )
    }

    suspend fun removeTokenIfPossible(accessToken: String?) {
        if (accessToken.isNullOrBlank()) {
            return
        }

        runCatching { repository.removeToken(accessToken) }
        if (isConfigured()) {
            runCatching { FirebaseMessaging.getInstance().deleteToken().await() }
        }
    }

    suspend fun registerTokenFromService(token: String) {
        if (!isConfigured()) {
            return
        }

        val session = sessionStore.loadSession() ?: return
        repository.registerToken(
            accessToken = session.accessToken,
            token = token,
            platform = "android",
        )
    }

    private suspend fun isConfigured(): Boolean = withContext(Dispatchers.IO) {
        FirebaseApp.getApps(context).isNotEmpty()
    }
}
