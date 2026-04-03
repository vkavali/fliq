package com.fliq.android.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class PendingTipDraft(
    val id: String,
    val providerId: String,
    val providerName: String,
    val providerCategory: String?,
    val amountPaise: Int,
    val source: TipSourceOption,
    val intent: TipIntentOption,
    val message: String?,
    val rating: Int,
    val idempotencyKey: String,
    val createdAt: String,
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("providerId", providerId)
            put("providerName", providerName)
            put("providerCategory", providerCategory)
            put("amountPaise", amountPaise)
            put("source", source.apiValue)
            put("intent", intent.apiValue)
            put("message", message)
            put("rating", rating)
            put("idempotencyKey", idempotencyKey)
            put("createdAt", createdAt)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): PendingTipDraft {
            return PendingTipDraft(
                id = json.getString("id"),
                providerId = json.getString("providerId"),
                providerName = json.optString("providerName", "Provider"),
                providerCategory = json.optString("providerCategory").takeIf { it.isNotBlank() },
                amountPaise = json.optInt("amountPaise", 0),
                source = TipSourceOption.values().firstOrNull { it.apiValue == json.optString("source") }
                    ?: TipSourceOption.IN_APP,
                intent = TipIntentOption.values().firstOrNull { it.apiValue == json.optString("intent") }
                    ?: TipIntentOption.KINDNESS,
                message = json.optString("message").takeIf { it.isNotBlank() },
                rating = json.optInt("rating", 5),
                idempotencyKey = json.optString("idempotencyKey"),
                createdAt = json.optString("createdAt"),
            )
        }
    }
}

class PendingTipQueueStore(context: Context) {
    private val prefs = context.getSharedPreferences("fliq_native_pending_tips", Context.MODE_PRIVATE)

    fun loadDrafts(userId: String): List<PendingTipDraft> {
        val raw = prefs.getString(queueKey(userId), null) ?: return emptyList()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                add(PendingTipDraft.fromJson(item))
            }
        }
    }

    fun saveDrafts(userId: String, drafts: List<PendingTipDraft>) {
        val array = JSONArray().apply {
            drafts.forEach { put(it.toJson()) }
        }
        prefs.edit().putString(queueKey(userId), array.toString()).apply()
    }

    fun enqueue(userId: String, draft: PendingTipDraft) {
        val updated = loadDrafts(userId).toMutableList().apply { add(0, draft) }
        saveDrafts(userId, updated)
    }

    fun remove(userId: String, draftId: String) {
        saveDrafts(userId, loadDrafts(userId).filterNot { it.id == draftId })
    }

    fun clear(userId: String) {
        prefs.edit().remove(queueKey(userId)).apply()
    }

    private fun queueKey(userId: String): String = "pending_tips_$userId"
}
