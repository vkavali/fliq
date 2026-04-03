package com.fliq.android.data

import org.json.JSONObject

enum class TipIntentOption(
    val apiValue: String,
    val label: String,
    val summary: String,
) {
    KINDNESS("KINDNESS", "Kindness", "Warm, thoughtful service"),
    SPEED("SPEED", "Speed", "Fast help when it mattered"),
    EXPERIENCE("EXPERIENCE", "Experience", "Memorable hospitality"),
    SUPPORT("SUPPORT", "Support", "Reliable support throughout"),
}

enum class TipSourceOption(
    val apiValue: String,
    val label: String,
) {
    QR_CODE("QR_CODE", "QR code"),
    PAYMENT_LINK("PAYMENT_LINK", "Payment link"),
    IN_APP("IN_APP", "In-app search"),
}

data class ProviderSearchResult(
    val id: String,
    val name: String,
    val phone: String?,
    val category: String?,
    val ratingAverage: Double,
    val totalTipsReceived: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderSearchResult {
            return ProviderSearchResult(
                id = json.getString("id"),
                name = json.optString("name", "Provider"),
                phone = json.optString("phone").takeIf { it.isNotBlank() },
                category = json.optString("category").takeIf { it.isNotBlank() },
                ratingAverage = json.optDouble("ratingAverage", 0.0),
                totalTipsReceived = json.optInt("totalTipsReceived", 0),
            )
        }
    }
}

data class ProviderStats(
    val tipsToday: Int,
    val recentAppreciations: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderStats {
            return ProviderStats(
                tipsToday = json.optInt("tipsToday", 0),
                recentAppreciations = json.optInt("recentAppreciations", 0),
            )
        }
    }
}

data class ProviderDream(
    val id: String,
    val title: String,
    val description: String?,
    val goalAmount: Double,
    val currentAmount: Double,
    val percentage: Int,
    val verified: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderDream {
            return ProviderDream(
                id = json.getString("id"),
                title = json.optString("title", "Dream"),
                description = json.optString("description").takeIf { it.isNotBlank() },
                goalAmount = json.optDouble("goalAmount", 0.0),
                currentAmount = json.optDouble("currentAmount", 0.0),
                percentage = json.optInt("percentage", 0),
                verified = json.optBoolean("verified", false),
            )
        }
    }
}

data class ProviderReputation(
    val score: Double,
    val consistency: Double,
    val uniqueTippers: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderReputation {
            return ProviderReputation(
                score = json.optDouble("score", 0.0),
                consistency = json.optDouble("consistency", 0.0),
                uniqueTippers = json.optInt("uniqueTippers", 0),
            )
        }
    }
}

data class ProviderProfile(
    val id: String,
    val name: String,
    val displayName: String,
    val bio: String?,
    val avatarUrl: String?,
    val category: String?,
    val ratingAverage: Double,
    val totalTipsReceived: Int,
    val upiVpa: String?,
    val stats: ProviderStats,
    val dream: ProviderDream?,
    val reputation: ProviderReputation?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderProfile {
            return ProviderProfile(
                id = json.getString("id"),
                name = json.optString("name", "Provider"),
                displayName = json.optString("displayName", json.optString("name", "Provider")),
                bio = json.optString("bio").takeIf { it.isNotBlank() },
                avatarUrl = json.optString("avatarUrl").takeIf { it.isNotBlank() },
                category = json.optString("category").takeIf { it.isNotBlank() },
                ratingAverage = json.optDouble("ratingAverage", 0.0),
                totalTipsReceived = json.optInt("totalTipsReceived", 0),
                upiVpa = json.optString("upiVpa").takeIf { it.isNotBlank() },
                stats = ProviderStats.fromJson(json.optJSONObject("stats") ?: JSONObject()),
                dream = json.optJSONObject("dream")?.let(ProviderDream::fromJson),
                reputation = json.optJSONObject("reputation")?.let(ProviderReputation::fromJson),
            )
        }
    }
}

data class CreatedTipOrder(
    val tipId: String,
    val orderId: String,
    val amountPaise: Int,
    val currency: String,
    val razorpayKeyId: String,
    val providerName: String,
    val providerCategory: String?,
) {
    val isMockOrder: Boolean
        get() = orderId.startsWith("mock_order_")

    companion object {
        fun fromJson(json: JSONObject): CreatedTipOrder {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            return CreatedTipOrder(
                tipId = json.getString("tipId"),
                orderId = json.getString("orderId"),
                amountPaise = json.optInt("amount", 0),
                currency = json.optString("currency", "INR"),
                razorpayKeyId = json.optString("razorpayKeyId"),
                providerName = provider.optString("name", "Provider"),
                providerCategory = provider.optString("category").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class TipEntryContext(
    val providerId: String,
    val providerName: String,
    val category: String?,
    val source: TipSourceOption,
    val entryLabel: String,
    val entryDetail: String?,
    val suggestedAmountPaise: Int?,
    val allowCustomAmount: Boolean,
) {
    companion object {
        fun inApp(providerId: String, providerName: String, category: String?): TipEntryContext {
            return TipEntryContext(
                providerId = providerId,
                providerName = providerName,
                category = category,
                source = TipSourceOption.IN_APP,
                entryLabel = "In-app search",
                entryDetail = null,
                suggestedAmountPaise = null,
                allowCustomAmount = true,
            )
        }

        fun fromQrJson(json: JSONObject): TipEntryContext {
            return TipEntryContext(
                providerId = json.getString("providerId"),
                providerName = json.optString("providerName", "Provider"),
                category = json.optString("category").takeIf { it.isNotBlank() },
                source = TipSourceOption.QR_CODE,
                entryLabel = "QR code",
                entryDetail = json.optString("locationLabel").takeIf { it.isNotBlank() },
                suggestedAmountPaise = null,
                allowCustomAmount = true,
            )
        }

        fun fromPaymentLinkJson(json: JSONObject): TipEntryContext {
            val suggestedAmount = json.optInt("suggestedAmountPaise", 0).takeIf { it > 0 }
            val detail = sequenceOf(
                json.optString("description").takeIf { it.isNotBlank() },
                json.optString("workplace").takeIf { it.isNotBlank() },
                json.optString("role").takeIf { it.isNotBlank() },
                json.optString("shortCode").takeIf { it.isNotBlank() },
            ).firstOrNull()

            return TipEntryContext(
                providerId = json.getString("providerId"),
                providerName = json.optString("providerName", "Provider"),
                category = json.optString("category").takeIf { it.isNotBlank() },
                source = TipSourceOption.PAYMENT_LINK,
                entryLabel = "Payment link",
                entryDetail = detail,
                suggestedAmountPaise = suggestedAmount,
                allowCustomAmount = json.optBoolean("allowCustomAmount", true),
            )
        }
    }
}

data class VerifiedTipResult(
    val status: String,
    val tipId: String,
    val bypass: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): VerifiedTipResult {
            return VerifiedTipResult(
                status = json.optString("status", "verified"),
                tipId = json.optString("tipId"),
                bypass = json.optBoolean("bypass", false),
            )
        }
    }
}

data class TipStatusSnapshot(
    val tipId: String,
    val status: String,
    val updatedAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): TipStatusSnapshot {
            return TipStatusSnapshot(
                tipId = json.optString("tipId"),
                status = json.optString("status", "UNKNOWN"),
                updatedAt = json.optString("updatedAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class CustomerTipHistoryItem(
    val id: String,
    val amountPaise: Int,
    val netAmountPaise: Int,
    val status: String,
    val intent: String?,
    val message: String?,
    val createdAt: String?,
    val providerName: String,
    val providerCategory: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): CustomerTipHistoryItem {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            val providerProfile = provider.optJSONObject("providerProfile") ?: JSONObject()
            return CustomerTipHistoryItem(
                id = json.getString("id"),
                amountPaise = json.optInt("amountPaise", 0),
                netAmountPaise = json.optInt("netAmountPaise", 0),
                status = json.optString("status", "UNKNOWN"),
                intent = json.optString("intent").takeIf { it.isNotBlank() },
                message = json.optString("message").takeIf { it.isNotBlank() },
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
                providerName = provider.optString("name", "Provider"),
                providerCategory = providerProfile.optString("category").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class CustomerTipHistoryPage(
    val tips: List<CustomerTipHistoryItem>,
    val total: Int,
    val page: Int,
    val limit: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): CustomerTipHistoryPage {
            val tipsArray = json.optJSONArray("tips")
            val tips = buildList {
                if (tipsArray != null) {
                    for (index in 0 until tipsArray.length()) {
                        add(CustomerTipHistoryItem.fromJson(tipsArray.getJSONObject(index)))
                    }
                }
            }
            return CustomerTipHistoryPage(
                tips = tips,
                total = json.optInt("total", tips.size),
                page = json.optInt("page", 1),
                limit = json.optInt("limit", tips.size),
            )
        }
    }
}

data class TipImpactDream(
    val title: String,
    val previousProgress: Int,
    val newProgress: Int,
    val goalAmount: Double,
    val currentAmount: Double,
) {
    companion object {
        fun fromJson(json: JSONObject): TipImpactDream {
            return TipImpactDream(
                title = json.optString("title", "Dream"),
                previousProgress = json.optInt("previousProgress", 0),
                newProgress = json.optInt("newProgress", 0),
                goalAmount = json.optDouble("goalAmount", 0.0),
                currentAmount = json.optDouble("currentAmount", 0.0),
            )
        }
    }
}

data class TipImpactSnapshot(
    val tipId: String,
    val workerName: String,
    val amountPaise: Int,
    val intent: String?,
    val message: String,
    val dream: TipImpactDream?,
) {
    companion object {
        fun fromJson(json: JSONObject): TipImpactSnapshot {
            return TipImpactSnapshot(
                tipId = json.optString("tipId"),
                workerName = json.optString("workerName", "the worker"),
                amountPaise = json.optInt("amount", 0),
                intent = json.optString("intent").takeIf { it.isNotBlank() },
                message = json.optString("message", "Your tip was received."),
                dream = json.optJSONObject("dream")?.let(TipImpactDream::fromJson),
            )
        }
    }
}
