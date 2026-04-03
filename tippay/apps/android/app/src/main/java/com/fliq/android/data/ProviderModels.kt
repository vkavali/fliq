package com.fliq.android.data

import org.json.JSONObject

data class ProviderSelfProfile(
    val id: String,
    val displayName: String,
    val bio: String?,
    val avatarUrl: String?,
    val category: String?,
    val upiVpa: String?,
    val totalTipsReceived: Int,
    val ratingAverage: Double,
    val userName: String?,
    val userPhone: String?,
    val kycStatus: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderSelfProfile {
            val user = json.optJSONObject("user") ?: JSONObject()
            return ProviderSelfProfile(
                id = json.getString("id"),
                displayName = json.optString("displayName", user.optString("name", "Provider")),
                bio = json.optString("bio").takeIf { it.isNotBlank() },
                avatarUrl = json.optString("avatarUrl").takeIf { it.isNotBlank() },
                category = json.optString("category").takeIf { it.isNotBlank() },
                upiVpa = json.optString("upiVpa").takeIf { it.isNotBlank() },
                totalTipsReceived = json.optInt("totalTipsReceived", 0),
                ratingAverage = json.optDouble("ratingAverage", 0.0),
                userName = user.optString("name").takeIf { it.isNotBlank() },
                userPhone = user.optString("phone").takeIf { it.isNotBlank() },
                kycStatus = user.optString("kycStatus").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class ProviderTipItem(
    val id: String,
    val amountPaise: Int,
    val status: String,
    val rating: Int?,
    val message: String?,
    val intent: String?,
    val createdAt: String?,
    val customerName: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderTipItem {
            val customer = json.optJSONObject("customer") ?: JSONObject()
            return ProviderTipItem(
                id = json.getString("id"),
                amountPaise = json.optInt("amountPaise", 0),
                status = json.optString("status", "UNKNOWN"),
                rating = json.optInt("rating").takeIf { !json.isNull("rating") },
                message = json.optString("message").takeIf { it.isNotBlank() },
                intent = json.optString("intent").takeIf { it.isNotBlank() },
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
                customerName = customer.optString("name").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class ProviderQrCode(
    val id: String,
    val locationLabel: String?,
    val qrImageUrl: String?,
    val upiUrl: String?,
    val scanCount: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderQrCode {
            return ProviderQrCode(
                id = json.getString("id"),
                locationLabel = json.optString("locationLabel").takeIf { it.isNotBlank() },
                qrImageUrl = json.optString("qrImageUrl").takeIf { it.isNotBlank() },
                upiUrl = json.optString("upiUrl").takeIf { it.isNotBlank() },
                scanCount = json.optInt("scanCount", 0),
            )
        }
    }
}

data class ProviderPaymentLink(
    val id: String,
    val shortCode: String,
    val role: String?,
    val workplace: String?,
    val description: String?,
    val suggestedAmountPaise: Int?,
    val allowCustomAmount: Boolean,
    val clickCount: Int,
    val shareableUrl: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderPaymentLink {
            val suggestedAmount = json.optInt("suggestedAmountPaise", 0).takeIf { it > 0 }
            return ProviderPaymentLink(
                id = json.getString("id"),
                shortCode = json.optString("shortCode"),
                role = json.optString("role").takeIf { it.isNotBlank() },
                workplace = json.optString("workplace").takeIf { it.isNotBlank() },
                description = json.optString("description").takeIf { it.isNotBlank() },
                suggestedAmountPaise = suggestedAmount,
                allowCustomAmount = json.optBoolean("allowCustomAmount", true),
                clickCount = json.optInt("clickCount", 0),
                shareableUrl = json.optString("shareableUrl").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class ProviderPayoutItem(
    val id: String,
    val amountPaise: Int,
    val status: String,
    val mode: String?,
    val createdAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderPayoutItem {
            return ProviderPayoutItem(
                id = json.getString("id"),
                amountPaise = json.optInt("amountPaise", 0),
                status = json.optString("status", "UNKNOWN"),
                mode = json.optString("mode").takeIf { it.isNotBlank() },
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class ProviderDreamData(
    val id: String,
    val title: String,
    val description: String?,
    val category: String?,
    val goalAmount: Int,
    val currentAmount: Int,
    val percentage: Int,
    val isActive: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderDreamData {
            return ProviderDreamData(
                id = json.getString("id"),
                title = json.optString("title", "Dream"),
                description = json.optString("description").takeIf { it.isNotBlank() },
                category = json.optString("category").takeIf { it.isNotBlank() },
                goalAmount = json.optInt("goalAmount", 0),
                currentAmount = json.optInt("currentAmount", 0),
                percentage = json.optInt("percentage", 0),
                isActive = json.optBoolean("isActive", true),
            )
        }
    }
}

data class ProviderRecurringTip(
    val id: String,
    val amountPaise: Int,
    val frequency: String,
    val status: String,
    val createdAt: String?,
    val customerName: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): ProviderRecurringTip {
            val customer = json.optJSONObject("customer") ?: JSONObject()
            return ProviderRecurringTip(
                id = json.getString("id"),
                amountPaise = json.optInt("amountPaise", 0),
                frequency = json.optString("frequency", "MONTHLY"),
                status = json.optString("status", "UNKNOWN"),
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
                customerName = customer.optString("name").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class BusinessInvitationData(
    val id: String,
    val role: String,
    val expiresAt: String?,
    val businessId: String?,
    val businessName: String?,
    val businessType: String?,
    val senderName: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessInvitationData {
            val business = json.optJSONObject("business") ?: JSONObject()
            val sender = json.optJSONObject("sender") ?: JSONObject()
            return BusinessInvitationData(
                id = json.getString("id"),
                role = json.optString("role", "STAFF"),
                expiresAt = json.optString("expiresAt").takeIf { it.isNotBlank() },
                businessId = business.optString("id").takeIf { it.isNotBlank() },
                businessName = business.optString("name").takeIf { it.isNotBlank() },
                businessType = business.optString("type").takeIf { it.isNotBlank() },
                senderName = sender.optString("name").takeIf { it.isNotBlank() },
            )
        }
    }
}
