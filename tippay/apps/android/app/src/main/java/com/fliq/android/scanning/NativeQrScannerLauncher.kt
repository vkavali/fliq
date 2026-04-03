package com.fliq.android.scanning

data class NativeQrScannerResult(
    val rawValue: String,
)

data class NativeQrScannerError(
    val message: String,
)

data class NativeQrScannerCallbacks(
    val onSuccess: (NativeQrScannerResult) -> Unit,
    val onCancelled: () -> Unit = {},
    val onError: (NativeQrScannerError) -> Unit,
)

interface NativeQrScannerLauncher {
    fun launchQrScanner(callbacks: NativeQrScannerCallbacks): Boolean
}
