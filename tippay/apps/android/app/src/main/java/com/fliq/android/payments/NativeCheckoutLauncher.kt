package com.fliq.android.payments

data class NativeCheckoutRequest(
    val keyId: String,
    val orderId: String,
    val amountPaise: Int,
    val currency: String,
    val title: String,
    val description: String,
    val contact: String?,
    val email: String?,
)

data class NativeCheckoutSuccess(
    val paymentId: String?,
    val responseJson: String?,
)

data class NativeCheckoutError(
    val code: Int,
    val description: String?,
    val responseJson: String?,
)

data class NativeCheckoutCallbacks(
    val onSuccess: (NativeCheckoutSuccess) -> Unit,
    val onError: (NativeCheckoutError) -> Unit,
    val onExternalWallet: (String?, String?) -> Unit,
)

interface NativeCheckoutLauncher {
    fun launchCheckout(
        request: NativeCheckoutRequest,
        callbacks: NativeCheckoutCallbacks,
    ): Boolean
}
