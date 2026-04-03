package com.fliq.android.data

import com.fliq.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

data class NativeTipJarMember(
    val id: String,
    val providerId: String,
    val providerName: String?,
    val roleLabel: String?,
    val splitPercentage: Double,
    val isActive: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipJarMember {
            val provider = json.optJSONObject("provider") ?: JSONObject()
            return NativeTipJarMember(
                id = json.optString("id"),
                providerId = json.optString("providerId"),
                providerName = provider.optString("name").takeIf { it.isNotBlank() },
                roleLabel = json.optString("roleLabel").takeIf { it.isNotBlank() },
                splitPercentage = json.optDouble("splitPercentage", 0.0),
                isActive = json.optBoolean("isActive", true),
            )
        }
    }
}

data class NativeTipJar(
    val id: String,
    val name: String,
    val description: String?,
    val eventType: String,
    val shortCode: String,
    val isActive: Boolean,
    val expiresAt: String?,
    val totalCollectedPaise: Int,
    val targetAmountPaise: Int?,
    val contributionCount: Int,
    val members: List<NativeTipJarMember>,
    val shareableUrl: String?,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipJar {
            val membersJson = json.optJSONArray("members") ?: JSONArray()
            val count = json.optJSONObject("_count") ?: JSONObject()
            return NativeTipJar(
                id = json.optString("id"),
                name = json.optString("name", "Tip jar"),
                description = json.optString("description").takeIf { it.isNotBlank() },
                eventType = json.optString("eventType", "CUSTOM"),
                shortCode = json.optString("shortCode"),
                isActive = json.optBoolean("isActive", true),
                expiresAt = json.optString("expiresAt").takeIf { it.isNotBlank() },
                totalCollectedPaise = json.optInt("totalCollected", 0),
                targetAmountPaise = json.optInt("targetAmount").takeIf { !json.isNull("targetAmount") },
                contributionCount = count.optInt("contributions", 0),
                members = buildList {
                    for (index in 0 until membersJson.length()) {
                        add(NativeTipJarMember.fromJson(membersJson.getJSONObject(index)))
                    }
                },
                shareableUrl = json.optString("shareableUrl").takeIf { it.isNotBlank() },
            )
        }
    }
}

data class NativeTipJarCollection(
    val owned: List<NativeTipJar>,
    val memberOf: List<NativeTipJar>,
)

data class NativeTipJarStatsMember(
    val memberId: String,
    val providerId: String,
    val providerName: String?,
    val splitPercentage: Double,
    val amountPaise: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipJarStatsMember {
            return NativeTipJarStatsMember(
                memberId = json.optString("memberId"),
                providerId = json.optString("providerId"),
                providerName = json.optString("providerName").takeIf { it.isNotBlank() },
                splitPercentage = json.optDouble("splitPercentage", 0.0),
                amountPaise = json.optInt("earnedPaise", json.optInt("amountPaise", 0)),
            )
        }
    }
}

data class NativeTipJarStats(
    val jarId: String,
    val jarName: String,
    val totalCollectedPaise: Int,
    val contributionCount: Int,
    val members: List<NativeTipJarStatsMember>,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipJarStats {
            val membersJson = json.optJSONArray("memberBreakdown") ?: json.optJSONArray("members") ?: JSONArray()
            return NativeTipJarStats(
                jarId = json.optString("jarId"),
                jarName = json.optString("jarName", "Tip jar"),
                totalCollectedPaise = json.optInt("totalCollectedPaise", 0),
                contributionCount = json.optInt("contributionCount", 0),
                members = buildList {
                    for (index in 0 until membersJson.length()) {
                        add(NativeTipJarStatsMember.fromJson(membersJson.getJSONObject(index)))
                    }
                },
            )
        }
    }
}

data class NativeTipPoolMember(
    val id: String,
    val userId: String,
    val userName: String?,
    val userPhone: String?,
    val role: String?,
    val splitPercentage: Double?,
    val isActive: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipPoolMember {
            val user = json.optJSONObject("user") ?: JSONObject()
            return NativeTipPoolMember(
                id = json.optString("id"),
                userId = json.optString("userId"),
                userName = user.optString("name").takeIf { it.isNotBlank() },
                userPhone = user.optString("phone").takeIf { it.isNotBlank() },
                role = json.optString("role").takeIf { it.isNotBlank() },
                splitPercentage = json.optDouble("splitPercentage").takeIf { !json.isNull("splitPercentage") },
                isActive = json.optBoolean("isActive", true),
            )
        }
    }
}

data class NativeTipPool(
    val id: String,
    val name: String,
    val description: String?,
    val ownerId: String,
    val splitMethod: String,
    val isActive: Boolean,
    val tipCount: Int,
    val members: List<NativeTipPoolMember>,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipPool {
            val membersJson = json.optJSONArray("members") ?: JSONArray()
            val count = json.optJSONObject("_count") ?: JSONObject()
            return NativeTipPool(
                id = json.optString("id"),
                name = json.optString("name", "Tip pool"),
                description = json.optString("description").takeIf { it.isNotBlank() },
                ownerId = json.optString("ownerId"),
                splitMethod = json.optString("splitMethod", "EQUAL"),
                isActive = json.optBoolean("isActive", true),
                tipCount = count.optInt("tips", 0),
                members = buildList {
                    for (index in 0 until membersJson.length()) {
                        add(NativeTipPoolMember.fromJson(membersJson.getJSONObject(index)))
                    }
                },
            )
        }
    }
}

data class NativeTipPoolCollection(
    val owned: List<NativeTipPool>,
    val memberOf: List<NativeTipPool>,
)

data class NativeTipPoolEarningMember(
    val memberId: String,
    val userId: String,
    val userName: String?,
    val role: String?,
    val splitPercentage: Double,
    val amountPaise: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipPoolEarningMember {
            return NativeTipPoolEarningMember(
                memberId = json.optString("memberId"),
                userId = json.optString("userId"),
                userName = json.optString("userName").takeIf { it.isNotBlank() },
                role = json.optString("role").takeIf { it.isNotBlank() },
                splitPercentage = json.optDouble("splitPercentage", 0.0),
                amountPaise = json.optInt("amountPaise", 0),
            )
        }
    }
}

data class NativeTipPoolEarnings(
    val poolId: String,
    val poolName: String,
    val splitMethod: String,
    val totalEarningsPaise: Int,
    val tipCount: Int,
    val members: List<NativeTipPoolEarningMember>,
) {
    companion object {
        fun fromJson(json: JSONObject): NativeTipPoolEarnings {
            val membersJson = json.optJSONArray("members") ?: JSONArray()
            return NativeTipPoolEarnings(
                poolId = json.optString("poolId"),
                poolName = json.optString("poolName", "Tip pool"),
                splitMethod = json.optString("splitMethod", "EQUAL"),
                totalEarningsPaise = json.optInt("totalEarningsPaise", 0),
                tipCount = json.optInt("tipCount", 0),
                members = buildList {
                    for (index in 0 until membersJson.length()) {
                        add(NativeTipPoolEarningMember.fromJson(membersJson.getJSONObject(index)))
                    }
                },
            )
        }
    }
}

class AdvancedCollectionsRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun createTipJar(
        accessToken: String,
        name: String,
        eventType: String,
        description: String?,
        targetAmountPaise: Int?,
    ): NativeTipJar {
        val body = JSONObject()
            .put("name", name)
            .put("eventType", eventType)
        description?.takeIf { it.isNotBlank() }?.let { body.put("description", it) }
        targetAmountPaise?.takeIf { it > 0 }?.let { body.put("targetAmountPaise", it) }
        return NativeTipJar.fromJson(
            executeJsonRequest(
                path = "/tip-jars",
                method = "POST",
                body = body,
                accessToken = accessToken,
            ),
        )
    }

    suspend fun getMyTipJars(accessToken: String): NativeTipJarCollection {
        val response = executeJsonRequest(
            path = "/tip-jars/my",
            method = "GET",
            accessToken = accessToken,
        )
        return NativeTipJarCollection(
            owned = parseTipJarArray(response.optJSONArray("owned")),
            memberOf = parseTipJarArray(response.optJSONArray("memberOf")),
        )
    }

    suspend fun getTipJar(accessToken: String, jarId: String): NativeTipJar {
        return NativeTipJar.fromJson(
            executeJsonRequest(
                path = "/tip-jars/$jarId",
                method = "GET",
                accessToken = accessToken,
            ),
        )
    }

    suspend fun addTipJarMember(
        accessToken: String,
        jarId: String,
        providerId: String,
        splitPercentage: Double,
        roleLabel: String?,
    ) {
        val body = JSONObject()
            .put("providerId", providerId)
            .put("splitPercentage", splitPercentage)
        roleLabel?.takeIf { it.isNotBlank() }?.let { body.put("roleLabel", it) }
        executeJsonRequest(
            path = "/tip-jars/$jarId/members",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
    }

    suspend fun removeTipJarMember(
        accessToken: String,
        jarId: String,
        memberId: String,
    ) {
        executeJsonRequest(
            path = "/tip-jars/$jarId/members/$memberId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun closeTipJar(accessToken: String, jarId: String) {
        executeJsonRequest(
            path = "/tip-jars/$jarId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun getTipJarStats(accessToken: String, jarId: String): NativeTipJarStats {
        return NativeTipJarStats.fromJson(
            executeJsonRequest(
                path = "/tip-jars/$jarId/stats",
                method = "GET",
                accessToken = accessToken,
            ),
        )
    }

    suspend fun resolveTipJar(shortCode: String): NativeTipJar {
        return NativeTipJar.fromJson(
            executeJsonRequest(
                path = "/tip-jars/resolve/$shortCode",
                method = "GET",
            ),
        )
    }

    suspend fun createAuthenticatedJarTip(
        accessToken: String,
        shortCode: String,
        amountPaise: Int,
        message: String?,
        rating: Int?,
    ): NativePaymentOrder {
        val body = JSONObject().put("amountPaise", amountPaise)
        message?.takeIf { it.isNotBlank() }?.let { body.put("message", it) }
        rating?.let { body.put("rating", it) }
        return NativePaymentOrder.fromJson(
            executeJsonRequest(
                path = "/tip-jars/$shortCode/tip/authenticated",
                method = "POST",
                body = body,
                accessToken = accessToken,
            ),
        )
    }

    suspend fun createTipPool(
        accessToken: String,
        name: String,
        splitMethod: String,
        description: String?,
    ): NativeTipPool {
        val body = JSONObject()
            .put("name", name)
            .put("splitMethod", splitMethod)
        description?.takeIf { it.isNotBlank() }?.let { body.put("description", it) }
        return NativeTipPool.fromJson(
            executeJsonRequest(
                path = "/tip-pools",
                method = "POST",
                body = body,
                accessToken = accessToken,
            ),
        )
    }

    suspend fun getMyTipPools(accessToken: String): NativeTipPoolCollection {
        val response = executeJsonRequest(
            path = "/tip-pools/my",
            method = "GET",
            accessToken = accessToken,
        )
        return NativeTipPoolCollection(
            owned = parseTipPoolArray(response.optJSONArray("owned")),
            memberOf = parseTipPoolArray(response.optJSONArray("memberOf")),
        )
    }

    suspend fun getTipPool(accessToken: String, poolId: String): NativeTipPool {
        return NativeTipPool.fromJson(
            executeJsonRequest(
                path = "/tip-pools/$poolId",
                method = "GET",
                accessToken = accessToken,
            ),
        )
    }

    suspend fun addTipPoolMember(
        accessToken: String,
        poolId: String,
        phone: String,
        role: String?,
        splitPercentage: Double?,
    ) {
        val body = JSONObject().put("phone", phone)
        role?.takeIf { it.isNotBlank() }?.let { body.put("role", it) }
        splitPercentage?.let { body.put("splitPercentage", it) }
        executeJsonRequest(
            path = "/tip-pools/$poolId/members",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
    }

    suspend fun removeTipPoolMember(
        accessToken: String,
        poolId: String,
        memberId: String,
    ) {
        executeJsonRequest(
            path = "/tip-pools/$poolId/members/$memberId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun updateTipPool(
        accessToken: String,
        poolId: String,
        name: String?,
        description: String?,
        splitMethod: String?,
    ) {
        val body = JSONObject()
        name?.takeIf { it.isNotBlank() }?.let { body.put("name", it) }
        description?.takeIf { it.isNotBlank() }?.let { body.put("description", it) }
        splitMethod?.takeIf { it.isNotBlank() }?.let { body.put("splitMethod", it) }
        executeJsonRequest(
            path = "/tip-pools/$poolId",
            method = "PATCH",
            body = body,
            accessToken = accessToken,
        )
    }

    suspend fun deactivateTipPool(accessToken: String, poolId: String) {
        executeJsonRequest(
            path = "/tip-pools/$poolId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun getTipPoolEarnings(accessToken: String, poolId: String): NativeTipPoolEarnings {
        return NativeTipPoolEarnings.fromJson(
            executeJsonRequest(
                path = "/tip-pools/$poolId/earnings",
                method = "GET",
                accessToken = accessToken,
            ),
        )
    }

    private fun parseTipJarArray(array: JSONArray?): List<NativeTipJar> = buildList {
        if (array == null) return@buildList
        for (index in 0 until array.length()) {
            add(NativeTipJar.fromJson(array.getJSONObject(index)))
        }
    }

    private fun parseTipPoolArray(array: JSONArray?): List<NativeTipPool> = buildList {
        if (array == null) return@buildList
        for (index in 0 until array.length()) {
            add(NativeTipPool.fromJson(array.getJSONObject(index)))
        }
    }

    private suspend fun executeJsonRequest(
        path: String,
        method: String,
        body: JSONObject? = null,
        accessToken: String? = null,
    ): JSONObject = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")

        if (!accessToken.isNullOrBlank()) {
            requestBuilder.addHeader("Authorization", "Bearer $accessToken")
        }

        when (method) {
            "POST" -> requestBuilder.post((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
            "PATCH" -> requestBuilder.patch((body?.toString() ?: "{}").toRequestBody(jsonMediaType))
            "DELETE" -> requestBuilder.delete()
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
