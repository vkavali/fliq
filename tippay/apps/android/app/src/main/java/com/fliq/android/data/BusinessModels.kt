package com.fliq.android.data

import org.json.JSONObject

data class BusinessSummary(
    val id: String,
    val name: String,
    val type: String,
    val ownerId: String?,
    val address: String?,
    val contactPhone: String?,
    val contactEmail: String?,
    val gstin: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessSummary {
            return BusinessSummary(
                id = json.getString("id"),
                name = json.optString("name", "Business"),
                type = json.optString("type", "OTHER"),
                ownerId = json.optString("ownerId").takeIf { it.isNotBlank() },
                address = json.optString("address").takeIf { it.isNotBlank() },
                contactPhone = json.optString("contactPhone").takeIf { it.isNotBlank() },
                contactEmail = json.optString("contactEmail").takeIf { it.isNotBlank() },
                gstin = json.optString("gstin").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class BusinessTrendPoint(
    val createdAt: String?,
    val totalAmountPaise: Int,
    val tipCount: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessTrendPoint {
            val sum = json.optJSONObject("_sum") ?: JSONObject()
            val count = json.optJSONObject("_count") ?: JSONObject()
            return BusinessTrendPoint(
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
                totalAmountPaise = sum.optInt("amountPaise", 0),
                tipCount = count.optInt("id", 0),
            )
        }
    }
}

data class BusinessDashboardSnapshot(
    val totalTipsCount: Int,
    val totalAmountPaise: Int,
    val totalNetAmountPaise: Int,
    val averageRating: Double,
    val staffCount: Int,
    val totalRatingsCount: Int,
    val recentTipTrend: List<BusinessTrendPoint>,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessDashboardSnapshot {
            val trend = json.optJSONArray("recentTipTrend")
            return BusinessDashboardSnapshot(
                totalTipsCount = json.optInt("totalTipsCount", 0),
                totalAmountPaise = json.optInt("totalAmountPaise", 0),
                totalNetAmountPaise = json.optInt("totalNetAmountPaise", 0),
                averageRating = json.optDouble("averageRating", 0.0),
                staffCount = json.optInt("staffCount", 0),
                totalRatingsCount = json.optInt("totalRatingsCount", 0),
                recentTipTrend = buildList {
                    if (trend != null) {
                        for (index in 0 until trend.length()) {
                            add(BusinessTrendPoint.fromJson(trend.getJSONObject(index)))
                        }
                    }
                },
            )
        }
    }
}

data class BusinessAffiliation(
    val businessId: String,
    val businessName: String,
    val businessType: String,
    val role: String,
    val joinedAt: String?,
    val isOwner: Boolean,
    val contactPhone: String?,
    val contactEmail: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessAffiliation {
            val business = json.optJSONObject("business") ?: JSONObject()
            return BusinessAffiliation(
                businessId = json.optString("businessId").ifBlank { business.optString("id") },
                businessName = business.optString("name", "Business"),
                businessType = business.optString("type", "OTHER"),
                role = json.optString("role", "STAFF"),
                joinedAt = json.optString("joinedAt").takeIf { it.isNotBlank() },
                isOwner = json.optBoolean("isOwner", false),
                contactPhone = business.optString("contactPhone").takeIf { it.isNotBlank() },
                contactEmail = business.optString("contactEmail").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class BusinessStaffMember(
    val memberId: String,
    val providerId: String,
    val role: String,
    val joinedAt: String?,
    val displayName: String,
    val contact: String?,
    val category: String?,
    val totalAmountPaise: Int,
    val tipsCount: Int,
    val averageRating: Double,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessStaffMember {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            val profile = provider.optJSONObject("providerProfile") ?: JSONObject()
            val tips = json.optJSONObject("tips") ?: JSONObject()
            return BusinessStaffMember(
                memberId = json.getString("memberId"),
                providerId = provider.optString("id"),
                role = json.optString("role", "STAFF"),
                joinedAt = json.optString("joinedAt").takeIf { it.isNotBlank() },
                displayName = profile.optString("displayName")
                    .takeIf { it.isNotBlank() }
                    ?: provider.optString("name", "Staff Member"),
                contact = provider.optString("phone").takeIf { it.isNotBlank() }
                    ?: provider.optString("email").takeIf { it.isNotBlank() },
                category = profile.optString("category").takeIf { it.isNotBlank() },
                totalAmountPaise = tips.optInt("totalAmountPaise", 0),
                tipsCount = tips.optInt("count", 0),
                averageRating = tips.optDouble("averageRating", 0.0),
            )
        }
    }
}

data class BusinessReviewItem(
    val id: String,
    val providerName: String,
    val rating: Int?,
    val message: String?,
    val amountPaise: Int,
    val createdAt: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessReviewItem {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            val profile = provider.optJSONObject("providerProfile") ?: JSONObject()
            return BusinessReviewItem(
                id = json.getString("id"),
                providerName = profile.optString("displayName")
                    .takeIf { it.isNotBlank() }
                    ?: provider.optString("name", "Staff"),
                rating = json.optInt("rating").takeIf { !json.isNull("rating") },
                message = json.optString("message").takeIf { it.isNotBlank() },
                amountPaise = json.optInt("amountPaise", 0),
                createdAt = json.optString("createdAt").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class RatingDistributionItem(
    val star: Int,
    val count: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): RatingDistributionItem {
            return RatingDistributionItem(
                star = json.optInt("star", 0),
                count = json.optInt("count", 0),
            )
        }
    }
}

data class BusinessSatisfactionSnapshot(
    val ratingDistribution: List<RatingDistributionItem>,
    val reviews: List<BusinessReviewItem>,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessSatisfactionSnapshot {
            val distribution = json.optJSONArray("ratingDistribution")
            val tips = json.optJSONArray("tips")
            return BusinessSatisfactionSnapshot(
                ratingDistribution = buildList {
                    if (distribution != null) {
                        for (index in 0 until distribution.length()) {
                            add(RatingDistributionItem.fromJson(distribution.getJSONObject(index)))
                        }
                    }
                },
                reviews = buildList {
                    if (tips != null) {
                        for (index in 0 until tips.length()) {
                            add(BusinessReviewItem.fromJson(tips.getJSONObject(index)))
                        }
                    }
                },
            )
        }
    }
}

data class BusinessQrStaffGroup(
    val memberId: String,
    val providerId: String,
    val displayName: String,
    val qrCodes: List<ProviderQrCode>,
) {
    companion object {
        fun fromJson(json: JSONObject): BusinessQrStaffGroup {
            val qrCodes = json.optJSONArray("qrCodes")
            return BusinessQrStaffGroup(
                memberId = json.optString("memberId"),
                providerId = json.optString("providerId"),
                displayName = json.optString("displayName", "Staff"),
                qrCodes = buildList {
                    if (qrCodes != null) {
                        for (index in 0 until qrCodes.length()) {
                            add(ProviderQrCode.fromJson(qrCodes.getJSONObject(index)))
                        }
                    }
                },
            )
        }
    }
}
