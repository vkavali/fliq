import Foundation
import RazorpayCheckout

struct NativeCheckoutSuccess {
    let paymentId: String
    let response: [AnyHashable: Any]?
}

enum NativeCheckoutCoordinatorError: LocalizedError {
    case missingKey

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Razorpay key is missing from the order response."
        }
    }
}

final class NativeCheckoutCoordinator: NSObject, PaymentCompletionWithDataDelegate {
    private var checkout: RazorpaySwift?
    private var onSuccess: ((NativeCheckoutSuccess) -> Void)?
    private var onError: ((String) -> Void)?

    func open(
        order: CreatedTipOrder,
        providerName: String,
        contact: String?,
        email: String?,
        onSuccess: @escaping (NativeCheckoutSuccess) -> Void,
        onError: @escaping (String) -> Void
    ) throws {
        guard !order.razorpayKeyId.isEmpty else {
            throw NativeCheckoutCoordinatorError.missingKey
        }

        self.onSuccess = onSuccess
        self.onError = onError
        self.checkout = RazorpaySwift.initWithKey(
            key: order.razorpayKeyId,
            andDelegateWithData: self
        )

        var payload: [AnyHashable: Any] = [
            "order_id": order.orderId,
            "amount": order.amount,
            "currency": order.currency,
            "name": "Fliq",
            "description": "Tip for \(providerName)",
            "theme": ["color": "#2267F2"]
        ]

        var prefill: [String: String] = [:]
        if let contact, !contact.isEmpty {
            prefill["contact"] = contact
        }
        if let email, !email.isEmpty {
            prefill["email"] = email
        }
        if !prefill.isEmpty {
            payload["prefill"] = prefill
        }

        try checkout?.open(withPayload: payload)
    }

    func open(
        order: NativePaymentOrder,
        contact: String?,
        email: String?,
        onSuccess: @escaping (NativeCheckoutSuccess) -> Void,
        onError: @escaping (String) -> Void
    ) throws {
        guard !order.razorpayKeyId.isEmpty else {
            throw NativeCheckoutCoordinatorError.missingKey
        }

        self.onSuccess = onSuccess
        self.onError = onError
        self.checkout = RazorpaySwift.initWithKey(
            key: order.razorpayKeyId,
            andDelegateWithData: self
        )

        var payload: [AnyHashable: Any] = [
            "order_id": order.orderId,
            "amount": order.amountPaise,
            "currency": order.currency,
            "name": "Fliq",
            "description": order.title,
            "theme": ["color": "#2267F2"]
        ]

        var prefill: [String: String] = [:]
        if let contact, !contact.isEmpty {
            prefill["contact"] = contact
        }
        if let email, !email.isEmpty {
            prefill["email"] = email
        }
        if !prefill.isEmpty {
            payload["prefill"] = prefill
        }

        try checkout?.open(withPayload: payload)
    }

    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable : Any]?) {
        onError?("Checkout failed (\(code)): \(str)")
        clearHandlers()
    }

    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable : Any]?) {
        onSuccess?(
            NativeCheckoutSuccess(
                paymentId: payment_id,
                response: response
            )
        )
        clearHandlers()
    }

    private func clearHandlers() {
        onSuccess = nil
        onError = nil
    }
}
