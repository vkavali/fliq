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

class BusinessRepository {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun getMyBusiness(accessToken: String): BusinessSummary {
        val response = executeJsonRequest(
            path = "/business/mine",
            method = "GET",
            accessToken = accessToken,
        )
        return BusinessSummary.fromJson(response)
    }

    suspend fun registerBusiness(
        accessToken: String,
        name: String,
        type: String,
        address: String?,
        contactPhone: String?,
        contactEmail: String?,
        gstin: String?,
    ): BusinessSummary {
        val body = JSONObject()
            .put("name", name)
            .put("type", type)
        address?.takeIf { it.isNotBlank() }?.let { body.put("address", it) }
        contactPhone?.takeIf { it.isNotBlank() }?.let { body.put("contactPhone", it) }
        contactEmail?.takeIf { it.isNotBlank() }?.let { body.put("contactEmail", it) }
        gstin?.takeIf { it.isNotBlank() }?.let { body.put("gstin", it) }

        val response = executeJsonRequest(
            path = "/business/register",
            method = "POST",
            body = body,
            accessToken = accessToken,
        )
        return BusinessSummary.fromJson(response)
    }

    suspend fun updateBusiness(
        accessToken: String,
        businessId: String,
        name: String?,
        type: String?,
        address: String?,
        contactPhone: String?,
        contactEmail: String?,
        gstin: String?,
    ): BusinessSummary {
        val body = JSONObject()
        name?.takeIf { it.isNotBlank() }?.let { body.put("name", it) }
        type?.takeIf { it.isNotBlank() }?.let { body.put("type", it) }
        address?.takeIf { it.isNotBlank() }?.let { body.put("address", it) }
        contactPhone?.takeIf { it.isNotBlank() }?.let { body.put("contactPhone", it) }
        contactEmail?.takeIf { it.isNotBlank() }?.let { body.put("contactEmail", it) }
        gstin?.takeIf { it.isNotBlank() }?.let { body.put("gstin", it) }

        executeJsonRequest(
            path = "/business/$businessId",
            method = "PATCH",
            body = body,
            accessToken = accessToken,
        )
        return getMyBusiness(accessToken)
    }

    suspend fun getDashboard(
        accessToken: String,
        businessId: String,
    ): BusinessDashboardSnapshot {
        val response = executeJsonRequest(
            path = "/business/$businessId/dashboard",
            method = "GET",
            accessToken = accessToken,
        )
        return BusinessDashboardSnapshot.fromJson(response)
    }

    suspend fun getMyMemberships(accessToken: String): List<BusinessAffiliation> {
        val response = executeJsonArrayRequest(
            path = "/business/memberships/mine",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(BusinessAffiliation.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun getStaff(
        accessToken: String,
        businessId: String,
    ): List<BusinessStaffMember> {
        val response = executeJsonArrayRequest(
            path = "/business/$businessId/staff",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(BusinessStaffMember.fromJson(response.getJSONObject(index)))
            }
        }
    }

    suspend fun inviteMember(
        accessToken: String,
        businessId: String,
        phone: String,
        role: String,
    ) {
        executeJsonRequest(
            path = "/business/$businessId/invite",
            method = "POST",
            body = JSONObject()
                .put("phone", phone)
                .put("role", role),
            accessToken = accessToken,
        )
    }

    suspend fun removeMember(
        accessToken: String,
        businessId: String,
        memberId: String,
    ) {
        executeJsonRequest(
            path = "/business/$businessId/members/$memberId",
            method = "DELETE",
            accessToken = accessToken,
        )
    }

    suspend fun getSatisfaction(
        accessToken: String,
        businessId: String,
    ): BusinessSatisfactionSnapshot {
        val response = executeJsonRequest(
            path = "/business/$businessId/satisfaction",
            method = "GET",
            accessToken = accessToken,
        )
        return BusinessSatisfactionSnapshot.fromJson(response)
    }

    suspend fun getQrCodes(
        accessToken: String,
        businessId: String,
    ): List<BusinessQrStaffGroup> {
        val response = executeJsonArrayRequest(
            path = "/business/$businessId/qrcodes",
            accessToken = accessToken,
        )
        return buildList {
            for (index in 0 until response.length()) {
                add(BusinessQrStaffGroup.fromJson(response.getJSONObject(index)))
            }
        }
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

    private suspend fun executeJsonArrayRequest(
        path: String,
        accessToken: String,
    ): JSONArray = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${BuildConfig.API_BASE_URL}$path")
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()

            if (!response.isSuccessful) {
                val json = runCatching { JSONObject(text) }.getOrDefault(JSONObject())
                throw AuthException(
                    message = json.optString("message", "Request failed with ${response.code}"),
                    statusCode = response.code,
                )
            }

            JSONArray(text.ifBlank { "[]" })
        }
    }
}
