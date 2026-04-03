package com.fliq.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.fliq.android.payments.NativeCheckoutCallbacks
import com.fliq.android.payments.NativeCheckoutLauncher
import com.fliq.android.payments.NativeCheckoutRequest
import com.fliq.android.payments.NativeCheckoutError
import com.fliq.android.payments.NativeCheckoutSuccess
import com.fliq.android.scanning.NativeQrScannerCallbacks
import com.fliq.android.scanning.NativeQrScannerError
import com.fliq.android.scanning.NativeQrScannerLauncher
import com.fliq.android.scanning.NativeQrScannerResult
import com.fliq.android.ui.FliqAndroidApp
import com.fliq.android.ui.theme.FliqAndroidTheme
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.razorpay.Checkout
import com.razorpay.ExternalWalletListener
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import org.json.JSONObject

class MainActivity : ComponentActivity(), PaymentResultWithDataListener, ExternalWalletListener, NativeCheckoutLauncher, NativeQrScannerLauncher {
    private var activeCheckoutCallbacks: NativeCheckoutCallbacks? = null
    private var activeQrScannerCallbacks: NativeQrScannerCallbacks? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Checkout.preload(applicationContext)
        setContent {
            FliqAndroidTheme {
                FliqAndroidApp()
            }
        }
    }

    override fun launchCheckout(
        request: NativeCheckoutRequest,
        callbacks: NativeCheckoutCallbacks,
    ): Boolean {
        return try {
            activeCheckoutCallbacks = callbacks

            val options = JSONObject().apply {
                put("order_id", request.orderId)
                put("amount", request.amountPaise)
                put("currency", request.currency)
                put("name", request.title)
                put("description", request.description)
                put(
                    "theme",
                    JSONObject().put("color", "#2267F2"),
                )

                val prefill = JSONObject()
                if (!request.contact.isNullOrBlank()) {
                    prefill.put("contact", request.contact)
                }
                if (!request.email.isNullOrBlank()) {
                    prefill.put("email", request.email)
                }
                if (prefill.length() > 0) {
                    put("prefill", prefill)
                }
            }

            Checkout().apply {
                setKeyID(request.keyId)
                open(this@MainActivity, options)
            }
            true
        } catch (error: Exception) {
            activeCheckoutCallbacks = null
            callbacks.onError(
                NativeCheckoutError(
                    code = -1,
                    description = error.message ?: "Unable to open Razorpay checkout.",
                    responseJson = null,
                ),
            )
            false
        }
    }

    override fun launchQrScanner(callbacks: NativeQrScannerCallbacks): Boolean {
        return try {
            activeQrScannerCallbacks = callbacks

            val options = GmsBarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .enableAutoZoom()
                .build()

            GmsBarcodeScanning.getClient(this, options)
                .startScan()
                .addOnSuccessListener { barcode ->
                    val rawValue = barcode.rawValue.orEmpty()
                    if (rawValue.isBlank()) {
                        callbacks.onError(
                            NativeQrScannerError("The scanned QR code did not contain a readable value."),
                        )
                    } else {
                        callbacks.onSuccess(NativeQrScannerResult(rawValue = rawValue))
                    }
                    activeQrScannerCallbacks = null
                }
                .addOnCanceledListener {
                    callbacks.onCancelled()
                    activeQrScannerCallbacks = null
                }
                .addOnFailureListener { error ->
                    val message = if (error.message?.contains(CommonStatusCodes.CANCELED.toString()) == true) {
                        "QR scan cancelled."
                    } else {
                        error.message ?: "Unable to open the QR scanner right now."
                    }
                    callbacks.onError(NativeQrScannerError(message))
                    activeQrScannerCallbacks = null
                }

            true
        } catch (error: Exception) {
            activeQrScannerCallbacks = null
            callbacks.onError(
                NativeQrScannerError(error.message ?: "Unable to open the QR scanner right now."),
            )
            false
        }
    }

    override fun onPaymentSuccess(paymentId: String?, paymentData: PaymentData?) {
        activeCheckoutCallbacks?.onSuccess?.invoke(
            NativeCheckoutSuccess(
                paymentId = paymentId,
                responseJson = paymentData?.data?.toString(),
            ),
        )
        activeCheckoutCallbacks = null
    }

    override fun onPaymentError(code: Int, description: String?, paymentData: PaymentData?) {
        activeCheckoutCallbacks?.onError?.invoke(
            NativeCheckoutError(
                code = code,
                description = description,
                responseJson = paymentData?.data?.toString(),
            ),
        )
        activeCheckoutCallbacks = null
    }

    override fun onExternalWalletSelected(walletName: String?, paymentData: PaymentData?) {
        activeCheckoutCallbacks?.onExternalWallet?.invoke(
            walletName,
            paymentData?.data?.toString(),
        )
        activeCheckoutCallbacks = null
    }
}
