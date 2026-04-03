import PhotosUI
import SwiftUI
import UIKit

private let nativeJarEvents: [String] = ["WEDDING", "RESTAURANT", "SALON", "EVENT", "CUSTOM"]
private let nativePoolSplitMethods: [String] = ["EQUAL", "PERCENTAGE", "ROLE_BASED"]

struct CustomerJarView: View {
    let session: AuthSession

    @State private var shortCode = ""
    @State private var amountRupees = "100"
    @State private var message = ""
    @State private var rating = "5"
    @State private var resolvedJar: NativeTipJar?
    @State private var paymentOrder: NativePaymentOrder?
    @State private var paymentStatus: TipStatusSnapshot?
    @State private var paymentImpact: TipImpactSnapshot?
    @State private var statusMessage = "Tip jars can now be resolved and paid natively from iOS."
    @State private var errorMessage: String?
    @State private var isResolving = false
    @State private var isCreatingTip = false
    @State private var isLaunchingCheckout = false
    @State private var isVerifyingPayment = false
    @State private var isRefreshingStatus = false

    private let collectionsClient = AdvancedCollectionsClient()
    private let customerClient = CustomerClient()
    private let checkoutCoordinator = NativeCheckoutCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tip jars")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            AdvancedNativeCard(title: "Resolve a jar") {
                TextField("Jar short code", text: $shortCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(advancedFieldBackground)

                HStack(spacing: 12) {
                    Button(action: {
                        Task { await resolveJar() }
                    }) {
                        Text(isResolving ? "Resolving..." : "Resolve")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                    .disabled(isResolving)

                    Button(action: clearState) {
                        Text("Clear")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }

                if let resolvedJar {
                    AdvancedNativeListCard {
                        Text(resolvedJar.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fliqInk)
                        DetailLine(label: "Event", value: resolvedJar.eventType.replacingOccurrences(of: "_", with: " "))
                        DetailLine(label: "Members", value: String(resolvedJar.members.count))
                        DetailLine(label: "Collected", value: advancedAmountText(resolvedJar.totalCollectedPaise))
                        if let targetAmountPaise = resolvedJar.targetAmountPaise {
                            DetailLine(label: "Target", value: advancedAmountText(targetAmountPaise))
                        }
                        if let shareableUrl = resolvedJar.shareableUrl {
                            DetailLine(label: "Shareable URL", value: shareableUrl)
                        }
                    }
                }
            }

            AdvancedNativeCard(title: "Contribute to jar") {
                TextField("Amount in rupees", text: $amountRupees)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(advancedFieldBackground)

                TextField("Message", text: $message, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(advancedFieldBackground)

                TextField("Rating 1-5", text: $rating)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(advancedFieldBackground)

                Button(action: {
                    Task { await createJarPayment() }
                }) {
                    Text(isCreatingTip ? "Creating..." : "Create jar payment")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
                .disabled(isCreatingTip)

                if let paymentOrder {
                    AdvancedNativeListCard {
                        Text(paymentOrder.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fliqInk)
                        DetailLine(label: "Order ID", value: paymentOrder.orderId)
                        DetailLine(label: "Amount", value: advancedAmountText(paymentOrder.amountPaise))
                        if let paymentStatus {
                            DetailLine(label: "Status", value: paymentStatus.status)
                        }
                        if let paymentImpact {
                            Text(paymentImpact.message)
                                .foregroundStyle(Color.fliqInk)
                        }

                        HStack(spacing: 12) {
                            if paymentOrder.isMockOrder {
                                Button(action: {
                                    Task { await completeMockPayment(paymentOrder) }
                                }) {
                                    Text(isVerifyingPayment ? "Verifying..." : "Complete mock payment")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                                .disabled(isVerifyingPayment)
                            } else {
                                Button(action: {
                                    openCheckout(paymentOrder)
                                }) {
                                    Text(isLaunchingCheckout ? "Opening..." : "Open checkout")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                                .disabled(isLaunchingCheckout || isVerifyingPayment)
                            }

                            Button(action: {
                                Task { await refreshStatus(paymentOrder) }
                            }) {
                                Text(isRefreshingStatus ? "Refreshing..." : "Refresh")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRefreshingStatus)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func resolveJar() async {
        guard !shortCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a tip jar short code first."
            return
        }

        isResolving = true
        do {
            resolvedJar = try await collectionsClient.resolveTipJar(shortCode: shortCode.trimmingCharacters(in: .whitespacesAndNewlines))
            paymentOrder = nil
            paymentStatus = nil
            paymentImpact = nil
            statusMessage = "Resolved tip jar \(resolvedJar?.name ?? shortCode)."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to resolve that tip jar right now."
        }
        isResolving = false
    }

    @MainActor
    private func createJarPayment() async {
        guard let resolvedJar else {
            errorMessage = "Resolve a tip jar first."
            return
        }
        guard let amount = Int(amountRupees), amount >= 10 else {
            errorMessage = "Minimum tip jar amount is Rs 10."
            return
        }

        isCreatingTip = true
        do {
            paymentOrder = try await collectionsClient.createAuthenticatedJarTip(
                accessToken: session.accessToken,
                shortCode: resolvedJar.shortCode,
                amountPaise: amount * 100,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: Int(rating)?.clamped(to: 1...5)
            )
            paymentStatus = paymentOrder.map { TipStatusSnapshot(tipId: $0.tipId, status: "INITIATED", updatedAt: nil) }
            paymentImpact = nil
            statusMessage = paymentOrder?.isMockOrder == true
                ? "Tip jar order created. Complete the mock payment from this screen."
                : "Tip jar order created. Open native checkout to continue."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create the tip jar payment right now."
        }
        isCreatingTip = false
    }

    @MainActor
    private func completeMockPayment(_ order: NativePaymentOrder) async {
        isVerifyingPayment = true
        do {
            _ = try await customerClient.verifyMockPayment(tipId: order.tipId, orderId: order.orderId)
            try await refreshPaymentState(order)
            statusMessage = "Mock tip jar payment completed."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to verify the mock tip jar payment right now."
        }
        isVerifyingPayment = false
    }

    private func openCheckout(_ order: NativePaymentOrder) {
        guard !order.razorpayKeyId.isEmpty else {
            errorMessage = "Razorpay key is missing from the backend response."
            return
        }

        isLaunchingCheckout = true
        errorMessage = nil

        do {
            try checkoutCoordinator.open(
                order: order,
                contact: session.user.phone,
                email: session.user.email,
                onSuccess: { success in
                    Task { @MainActor in
                        isLaunchingCheckout = false
                        isVerifyingPayment = true
                        do {
                            let orderId = (success.response?["razorpay_order_id"] as? String) ?? order.orderId
                            guard let signature = success.response?["razorpay_signature"] as? String else {
                                errorMessage = "Checkout returned without a signature."
                                isVerifyingPayment = false
                                return
                            }
                            _ = try await customerClient.verifyPayment(
                                tipId: order.tipId,
                                orderId: orderId,
                                paymentId: success.paymentId,
                                signature: signature
                            )
                            try await refreshPaymentState(order)
                            statusMessage = "Tip jar payment verified on the shared backend."
                            errorMessage = nil
                        } catch {
                            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Checkout returned, but verification failed on this device."
                        }
                        isVerifyingPayment = false
                    }
                },
                onError: { message in
                    Task { @MainActor in
                        isLaunchingCheckout = false
                        errorMessage = message
                    }
                }
            )
        } catch {
            isLaunchingCheckout = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to open native checkout right now."
        }
    }

    @MainActor
    private func refreshStatus(_ order: NativePaymentOrder) async {
        isRefreshingStatus = true
        do {
            try await refreshPaymentState(order)
            statusMessage = "Fetched the latest tip jar payment status."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to refresh the tip jar payment right now."
        }
        isRefreshingStatus = false
    }

    @MainActor
    private func refreshPaymentState(_ order: NativePaymentOrder) async throws {
        paymentStatus = try await customerClient.getTipStatus(tipId: order.tipId)
        paymentImpact = try? await customerClient.getTipImpact(tipId: order.tipId)
    }

    @MainActor
    private func clearState() {
        shortCode = ""
        resolvedJar = nil
        paymentOrder = nil
        paymentStatus = nil
        paymentImpact = nil
        statusMessage = "Tip jar state cleared on this device."
        errorMessage = nil
    }
}

struct ProviderAvatarView: View {
    let session: AuthSession
    let currentAvatarUrl: String?
    let onRefreshRequested: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var statusMessage = "Native provider avatar upload is now available on iOS."
    @State private var errorMessage: String?
    @State private var isUploading = false

    private let providerClient = ProviderClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Avatar")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            if let currentAvatarUrl {
                DetailLine(label: "Current avatar", value: currentAvatarUrl.count > 48 ? "\(currentAvatarUrl.prefix(48))..." : currentAvatarUrl)
            } else {
                Text("No provider avatar uploaded yet.")
                    .foregroundStyle(Color.fliqMuted)
            }

            Text("The backend accepts a compact image, so the app compresses uploads automatically.")
                .foregroundStyle(Color.fliqMuted)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(isUploading ? "Uploading..." : "Choose avatar image")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
            .disabled(isUploading)
            .onChange(of: selectedPhoto) { newValue in
                guard let newValue else { return }
                Task { await uploadAvatar(from: newValue) }
            }
        }
    }

    @MainActor
    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploading = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let compressed = compressAvatarData(data) else {
                errorMessage = "Unable to prepare that image for upload."
                isUploading = false
                return
            }
            _ = try await providerClient.uploadAvatar(accessToken: session.accessToken, imageData: compressed)
            statusMessage = "Provider avatar uploaded to the shared backend."
            errorMessage = nil
            onRefreshRequested()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to upload the provider avatar right now."
        }
        isUploading = false
        selectedPhoto = nil
    }
}

struct ProviderCollectionsView: View {
    let session: AuthSession

    @State private var jars: [NativeTipJar] = []
    @State private var pools: [NativeTipPool] = []
    @State private var selectedJar: NativeTipJar?
    @State private var selectedPool: NativeTipPool?
    @State private var jarStats: NativeTipJarStats?
    @State private var poolEarnings: NativeTipPoolEarnings?
    @State private var statusMessage = "Tip jars and tip pools are now available natively on iOS."
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isSavingJar = false
    @State private var isSavingPool = false

    @State private var jarName = ""
    @State private var jarDescription = ""
    @State private var jarEventType = nativeJarEvents.last ?? "CUSTOM"
    @State private var jarTargetRupees = ""
    @State private var jarMemberProviderId = ""
    @State private var jarMemberSplit = "25"
    @State private var jarMemberRole = ""

    @State private var poolName = ""
    @State private var poolDescription = ""
    @State private var poolSplitMethod = nativePoolSplitMethods.first ?? "EQUAL"
    @State private var poolMemberPhone = ""
    @State private var poolMemberRole = "waiter"
    @State private var poolMemberSplit = "25"

    private let collectionsClient = AdvancedCollectionsClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shared collections")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            StatusCard(
                title: errorMessage == nil ? "Current status" : "Error",
                message: errorMessage ?? statusMessage,
                isError: errorMessage != nil
            )

            Button(action: {
                Task { await refreshCollections() }
            }) {
                Text(isLoading ? "Refreshing..." : "Refresh tip jars and pools")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            AdvancedNativeCard(title: "Create a tip jar") {
                TextField("Jar name", text: $jarName)
                    .padding(14)
                    .background(advancedFieldBackground)

                AdvancedChoiceSection(label: "Event type", options: nativeJarEvents, selected: $jarEventType)

                TextField("Description", text: $jarDescription, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(advancedFieldBackground)

                TextField("Target amount in rupees", text: $jarTargetRupees)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(advancedFieldBackground)

                Button(action: {
                    Task { await createJar() }
                }) {
                    Text(isSavingJar ? "Creating..." : "Create tip jar")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                .disabled(isSavingJar)

                if jars.isEmpty {
                    Text("No tip jars yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(jars.prefix(6))) { jar in
                        AdvancedNativeListCard {
                            Text(jar.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fliqInk)
                            DetailLine(label: "Short code", value: jar.shortCode)
                            DetailLine(label: "Members", value: String(jar.members.count))
                            DetailLine(label: "Contributions", value: String(jar.contributionCount))
                            if let shareableUrl = jar.shareableUrl {
                                DetailLine(label: "Shareable URL", value: shareableUrl)
                            }
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await openJar(jar.id) }
                                }) {
                                    Text("Open")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)

                                if jar.isActive {
                                    Button(action: {
                                        Task { await closeJar(jar.id) }
                                    }) {
                                        Text("Close")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }

            if let selectedJar {
                AdvancedNativeCard(title: "Manage tip jar") {
                    DetailLine(label: "Selected jar", value: selectedJar.name)
                    if let jarStats {
                        DetailLine(label: "Collected", value: advancedAmountText(jarStats.totalCollectedPaise))
                        DetailLine(label: "Contribution count", value: String(jarStats.contributionCount))
                    }

                    TextField("Member provider ID", text: $jarMemberProviderId)
                        .padding(14)
                        .background(advancedFieldBackground)

                    TextField("Split percentage", text: $jarMemberSplit)
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(advancedFieldBackground)

                    TextField("Role label", text: $jarMemberRole)
                        .padding(14)
                        .background(advancedFieldBackground)

                    Button(action: {
                        Task { await addJarMember(selectedJar.id) }
                    }) {
                        Text("Add tip jar member")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))

                    if selectedJar.members.isEmpty {
                        Text("No active members yet.")
                            .foregroundStyle(Color.fliqMuted)
                    } else {
                        ForEach(selectedJar.members) { member in
                            AdvancedNativeListCard {
                                Text(member.providerName ?? member.providerId)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.fliqInk)
                                if let roleLabel = member.roleLabel {
                                    DetailLine(label: "Role", value: roleLabel)
                                }
                                DetailLine(label: "Split", value: "\(member.splitPercentage)%")
                                if member.providerId != session.user.id && selectedJar.isActive {
                                    Button(action: {
                                        Task { await removeJarMember(selectedJar.id, member.id) }
                                    }) {
                                        Text("Remove member")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }

            AdvancedNativeCard(title: "Create a tip pool") {
                TextField("Pool name", text: $poolName)
                    .padding(14)
                    .background(advancedFieldBackground)

                AdvancedChoiceSection(label: "Split method", options: nativePoolSplitMethods, selected: $poolSplitMethod)

                TextField("Description", text: $poolDescription, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(advancedFieldBackground)

                Button(action: {
                    Task { await createPool() }
                }) {
                    Text(isSavingPool ? "Creating..." : "Create tip pool")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                .disabled(isSavingPool)

                if pools.isEmpty {
                    Text("No tip pools yet.")
                        .foregroundStyle(Color.fliqMuted)
                } else {
                    ForEach(Array(pools.prefix(6))) { pool in
                        AdvancedNativeListCard {
                            Text(pool.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fliqInk)
                            DetailLine(label: "Split method", value: pool.splitMethod)
                            DetailLine(label: "Members", value: String(pool.members.count))
                            DetailLine(label: "Tips", value: String(pool.tipCount))
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await openPool(pool.id) }
                                }) {
                                    Text("Open")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)

                                if pool.isActive {
                                    Button(action: {
                                        Task { await deactivatePool(pool.id) }
                                    }) {
                                        Text("Deactivate")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }

            if let selectedPool {
                AdvancedNativeCard(title: "Manage tip pool") {
                    DetailLine(label: "Selected pool", value: selectedPool.name)
                    if let poolEarnings {
                        DetailLine(label: "Total earnings", value: advancedAmountText(poolEarnings.totalEarningsPaise))
                        DetailLine(label: "Tip count", value: String(poolEarnings.tipCount))
                    }

                    TextField("Member phone", text: $poolMemberPhone)
                        .padding(14)
                        .background(advancedFieldBackground)

                    TextField("Role", text: $poolMemberRole)
                        .padding(14)
                        .background(advancedFieldBackground)

                    TextField("Split percentage", text: $poolMemberSplit)
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(advancedFieldBackground)

                    Button(action: {
                        Task { await addPoolMember(selectedPool.id) }
                    }) {
                        Text("Add tip pool member")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))

                    if selectedPool.members.isEmpty {
                        Text("No active pool members yet.")
                            .foregroundStyle(Color.fliqMuted)
                    } else {
                        ForEach(selectedPool.members) { member in
                            AdvancedNativeListCard {
                                Text(member.userName ?? member.userPhone ?? member.userId)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.fliqInk)
                                if let role = member.role {
                                    DetailLine(label: "Role", value: role)
                                }
                                if let splitPercentage = member.splitPercentage {
                                    DetailLine(label: "Split", value: "\(splitPercentage)%")
                                }
                                if member.userId != session.user.id && selectedPool.isActive {
                                    Button(action: {
                                        Task { await removePoolMember(selectedPool.id, member.id) }
                                    }) {
                                        Text("Remove member")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: session.user.id) {
            await refreshCollections()
        }
    }

    @MainActor
    private func refreshCollections() async {
        isLoading = true
        do {
            let jarCollection = try await collectionsClient.getMyTipJars(accessToken: session.accessToken)
            let poolCollection = try await collectionsClient.getMyTipPools(accessToken: session.accessToken)
            jars = jarCollection.owned + jarCollection.memberOf
            pools = poolCollection.owned + poolCollection.memberOf
            if let selectedJarId = selectedJar?.id {
                selectedJar = jars.first { $0.id == selectedJarId }
            }
            if let selectedPoolId = selectedPool?.id {
                selectedPool = pools.first { $0.id == selectedPoolId }
            }
            statusMessage = "Loaded native tip jars and tip pools from the shared backend."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load tip jars or tip pools right now."
        }
        isLoading = false
    }

    @MainActor
    private func createJar() async {
        guard !jarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Tip jar name is required."
            return
        }

        isSavingJar = true
        do {
            selectedJar = try await collectionsClient.createTipJar(
                accessToken: session.accessToken,
                name: jarName.trimmingCharacters(in: .whitespacesAndNewlines),
                eventType: jarEventType,
                description: jarDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : jarDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                targetAmountPaise: Int(jarTargetRupees).map { $0 * 100 }
            )
            jarName = ""
            jarDescription = ""
            jarTargetRupees = ""
            await refreshCollections()
            statusMessage = "Tip jar created natively."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create the tip jar right now."
        }
        isSavingJar = false
    }

    @MainActor
    private func openJar(_ jarId: String) async {
        do {
            selectedJar = try await collectionsClient.getTipJar(accessToken: session.accessToken, jarId: jarId)
            jarStats = try await collectionsClient.getTipJarStats(accessToken: session.accessToken, jarId: jarId)
            statusMessage = "Loaded tip jar details."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load that tip jar right now."
        }
    }

    @MainActor
    private func closeJar(_ jarId: String) async {
        do {
            try await collectionsClient.closeTipJar(accessToken: session.accessToken, jarId: jarId)
            if selectedJar?.id == jarId {
                selectedJar = nil
                jarStats = nil
            }
            await refreshCollections()
            statusMessage = "Tip jar closed."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to close that tip jar right now."
        }
    }

    @MainActor
    private func addJarMember(_ jarId: String) async {
        guard !jarMemberProviderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let split = Double(jarMemberSplit) else {
            errorMessage = "Member provider ID and split percentage are required."
            return
        }

        do {
            try await collectionsClient.addTipJarMember(
                accessToken: session.accessToken,
                jarId: jarId,
                providerId: jarMemberProviderId.trimmingCharacters(in: .whitespacesAndNewlines),
                splitPercentage: split,
                roleLabel: jarMemberRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : jarMemberRole.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            selectedJar = try await collectionsClient.getTipJar(accessToken: session.accessToken, jarId: jarId)
            jarStats = try await collectionsClient.getTipJarStats(accessToken: session.accessToken, jarId: jarId)
            await refreshCollections()
            jarMemberProviderId = ""
            jarMemberSplit = "25"
            jarMemberRole = ""
            statusMessage = "Tip jar member added."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to add that tip jar member right now."
        }
    }

    @MainActor
    private func removeJarMember(_ jarId: String, _ memberId: String) async {
        do {
            try await collectionsClient.removeTipJarMember(accessToken: session.accessToken, jarId: jarId, memberId: memberId)
            selectedJar = try await collectionsClient.getTipJar(accessToken: session.accessToken, jarId: jarId)
            jarStats = try await collectionsClient.getTipJarStats(accessToken: session.accessToken, jarId: jarId)
            await refreshCollections()
            statusMessage = "Tip jar member removed."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to remove that tip jar member right now."
        }
    }

    @MainActor
    private func createPool() async {
        guard !poolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Tip pool name is required."
            return
        }

        isSavingPool = true
        do {
            selectedPool = try await collectionsClient.createTipPool(
                accessToken: session.accessToken,
                name: poolName.trimmingCharacters(in: .whitespacesAndNewlines),
                splitMethod: poolSplitMethod,
                description: poolDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : poolDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            poolName = ""
            poolDescription = ""
            await refreshCollections()
            statusMessage = "Tip pool created natively."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create the tip pool right now."
        }
        isSavingPool = false
    }

    @MainActor
    private func openPool(_ poolId: String) async {
        do {
            selectedPool = try await collectionsClient.getTipPool(accessToken: session.accessToken, poolId: poolId)
            poolEarnings = try await collectionsClient.getTipPoolEarnings(accessToken: session.accessToken, poolId: poolId)
            statusMessage = "Loaded tip pool details."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load that tip pool right now."
        }
    }

    @MainActor
    private func deactivatePool(_ poolId: String) async {
        do {
            try await collectionsClient.deactivateTipPool(accessToken: session.accessToken, poolId: poolId)
            if selectedPool?.id == poolId {
                selectedPool = nil
                poolEarnings = nil
            }
            await refreshCollections()
            statusMessage = "Tip pool deactivated."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to deactivate that tip pool right now."
        }
    }

    @MainActor
    private func addPoolMember(_ poolId: String) async {
        guard !poolMemberPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Member phone is required."
            return
        }

        do {
            try await collectionsClient.addTipPoolMember(
                accessToken: session.accessToken,
                poolId: poolId,
                phone: poolMemberPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                role: poolMemberRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : poolMemberRole.trimmingCharacters(in: .whitespacesAndNewlines),
                splitPercentage: Double(poolMemberSplit)
            )
            selectedPool = try await collectionsClient.getTipPool(accessToken: session.accessToken, poolId: poolId)
            poolEarnings = try await collectionsClient.getTipPoolEarnings(accessToken: session.accessToken, poolId: poolId)
            await refreshCollections()
            poolMemberPhone = ""
            poolMemberRole = "waiter"
            poolMemberSplit = "25"
            statusMessage = "Tip pool member added."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to add that tip pool member right now."
        }
    }

    @MainActor
    private func removePoolMember(_ poolId: String, _ memberId: String) async {
        do {
            try await collectionsClient.removeTipPoolMember(accessToken: session.accessToken, poolId: poolId, memberId: memberId)
            selectedPool = try await collectionsClient.getTipPool(accessToken: session.accessToken, poolId: poolId)
            poolEarnings = try await collectionsClient.getTipPoolEarnings(accessToken: session.accessToken, poolId: poolId)
            await refreshCollections()
            statusMessage = "Tip pool member removed."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to remove that tip pool member right now."
        }
    }
}

private struct AdvancedNativeCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqInk)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private struct AdvancedNativeListCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }
}

private struct AdvancedChoiceSection: View {
    let label: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)

            ForEach(Array(options.chunked(into: 3)), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        if option == selected {
                            Button(action: { selected = option }) {
                                Text(option.replacingOccurrences(of: "_", with: " "))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                        } else {
                            Button(action: { selected = option }) {
                                Text(option.replacingOccurrences(of: "_", with: " "))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}

private let advancedFieldBackground =
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.white)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)

private func advancedAmountText(_ amountPaise: Int) -> String {
    "Rs \(amountPaise / 100)"
}

private func compressAvatarData(_ data: Data) -> Data? {
    guard let image = UIImage(data: data) else {
        return nil
    }

    let candidates: [CGFloat] = [256, 192, 160, 128]
    let qualities: [CGFloat] = [0.82, 0.72, 0.62, 0.52, 0.42, 0.32]

    for dimension in candidates {
        guard let resized = image.resized(maxDimension: dimension) else {
            continue
        }
        for quality in qualities {
            if let encoded = resized.jpegData(compressionQuality: quality), encoded.count <= 72_000 {
                return encoded
            }
        }
    }

    return image.jpegData(compressionQuality: 0.24).flatMap { $0.count <= 72_000 ? $0 : nil }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
