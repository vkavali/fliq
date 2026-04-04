import SwiftUI

private struct RoleCard: Identifiable {
    let role: NativeRole
    let title: String
    let subtitle: String
    let accent: Color
    let actionLabel: String

    var id: String { role.rawValue }
}

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()

    private let roles: [RoleCard] = [
        RoleCard(
            role: .customer,
            title: "Customer",
            subtitle: "Scan QR codes, tip instantly, and manage your history.",
            accent: .fliqBlue,
            actionLabel: "Continue as customer"
        ),
        RoleCard(
            role: .provider,
            title: "Provider",
            subtitle: "Receive tips, manage QR links, and track payouts.",
            accent: .fliqMint,
            actionLabel: "Continue as provider"
        ),
        RoleCard(
            role: .business,
            title: "Business",
            subtitle: "Manage staff, invitations, satisfaction, and QR exports.",
            accent: .fliqGold,
            actionLabel: "Continue as business"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.fliqSky, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.isLoading && viewModel.stage != .home {
                ProgressView()
                    .controlSize(.large)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HeaderView()

                        switch viewModel.stage {
                        case .rolePicker:
                            ForEach(roles) { role in
                                RoleEntryCard(role: role) {
                                    viewModel.selectRole(role.role)
                                }
                            }

                        case .credential:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                CredentialCard(
                                    role: role,
                                    credential: $viewModel.credential,
                                    onBack: { viewModel.backToRolePicker() },
                                    onSubmit: {
                                        Task { await viewModel.sendCode() }
                                    }
                                )
                            }

                        case .otp:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                OTPCard(
                                    role: role,
                                    credential: viewModel.credential,
                                    code: $viewModel.code,
                                    onBack: { viewModel.backToCredential() },
                                    onResend: { Task { await viewModel.resendCode() } },
                                    onVerify: { Task { await viewModel.verifyCode() } }
                                )
                            }

                        case .home:
                            if let session = viewModel.session {
                                let effectiveRole: NativeRole = {
                                    if session.user.type.hasPrefix("BUSINESS") {
                                        return .business
                                    }
                                    if session.user.type == NativeRole.provider.rawValue ||
                                        (viewModel.selectedRole == .provider && session.user.type == NativeRole.customer.rawValue) {
                                        return .provider
                                    }
                                    return .customer
                                }()

                                if effectiveRole == .customer {
                                    CustomerHomeCard(session: session, viewModel: viewModel)
                                        .task(id: session.user.id) {
                                            await viewModel.loadCustomerHomeDataIfNeeded()
                                        }
                                } else if effectiveRole == .business {
                                    BusinessHomeView(session: session) {
                                        viewModel.logout()
                                    }
                                } else {
                                    ProviderHomeView(session: session) {
                                        viewModel.logout()
                                    }
                                }
                            }
                        }

                        StatusCard(
                            title: viewModel.errorMessage == nil ? "Current status" : "Error",
                            message: viewModel.errorMessage ?? viewModel.statusMessage,
                            isError: viewModel.errorMessage != nil
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fliq iOS")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            Text("Native auth and session foundation on the shared Fliq backend. Customer, provider, and business roles all route through this native codebase.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)
        }
    }
}

private struct RoleEntryCard: View {
    let role: RoleCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(role.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    Text(role.subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.fliqMuted)
                }

                Spacer(minLength: 12)
                RoleBadge(accent: role.accent)
            }

            Button(action: action) {
                Text(role.actionLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private struct CredentialCard: View {
    let role: RoleCard
    @Binding var credential: String
    let onBack: () -> Void
    let onSubmit: () -> Void
    @State private var selectedCountryCode = "+91"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(role.title) sign in")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fliqInk)
                Spacer()
                RoleBadge(accent: role.accent)
            }

            Text(role.role.usesEmail ? "Enter the business email used for dashboard access." : "Enter your phone number with country code.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)

            if !role.role.usesEmail {
                HStack(spacing: 8) {
                    ForEach([("🇮🇳 +91", "+91"), ("🇺🇸 +1", "+1")], id: \.1) { label, code in
                        Button {
                            let oldPrefix = selectedCountryCode
                            selectedCountryCode = code
                            let rawNumber = credential.hasPrefix(oldPrefix) ? String(credential.dropFirst(oldPrefix.count)) : credential
                            credential = code + rawNumber
                        } label: {
                            Text(selectedCountryCode == code ? "✓ \(label)" : label)
                                .font(.system(size: 14, weight: selectedCountryCode == code ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedCountryCode == code ? role.accent : Color.black.opacity(0.12), lineWidth: selectedCountryCode == code ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField(role.role.usesEmail ? "Email" : "Phone number (e.g. \(selectedCountryCode)9876543210)", text: $credential)
                .keyboardType(role.role.usesEmail ? .emailAddress : .phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.borderless)

                Button(action: onSubmit) {
                    Text("Send OTP")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
                .disabled(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private struct OTPCard: View {
    let role: RoleCard
    let credential: String
    @Binding var code: String
    let onBack: () -> Void
    let onResend: () -> Void
    let onVerify: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verify \(role.title.lowercased()) code")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            Text("We sent a one-time code to \(credential).")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)

            TextField("6-digit OTP", text: $code)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.borderless)

                Button("Resend", action: onResend)
                    .buttonStyle(.borderless)

                Button(action: onVerify) {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private struct HomeCard: View {
    let session: AuthSession
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Signed in")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            DetailLine(label: "User type", value: session.user.type)
            if let name = session.user.name { DetailLine(label: "Name", value: name) }
            if let phone = session.user.phone { DetailLine(label: "Phone", value: phone) }
            if let email = session.user.email { DetailLine(label: "Email", value: email) }
            if let kycStatus = session.user.kycStatus { DetailLine(label: "KYC", value: kycStatus) }
            DetailLine(label: "User ID", value: session.user.id)

            Text("Next parity slice from here: native customer home, provider resolve, and tip flow screens.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)

            Button(action: onLogout) {
                Text("Log out")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private struct CustomerHomeCard: View {
    let session: AuthSession
    @ObservedObject var viewModel: AppViewModel

    private var amountBinding: Binding<String> {
        Binding(
            get: { viewModel.amountRupees },
            set: { viewModel.amountRupees = String($0.filter(\.isNumber)) }
        )
    }

    private var isCustomAmountLocked: Bool {
        viewModel.selectedEntryContext?.allowCustomAmount == false &&
        viewModel.selectedEntryContext?.suggestedAmountPaise != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Customer home")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            if let name = session.user.name {
                DetailLine(label: "Signed in as", value: name)
            }
            DetailLine(label: "Journey", value: "Provider search, QR or payment-link resolve, and backend tip status")

            CustomerProfileEditorCard(viewModel: viewModel)
            PendingTipQueueSection(viewModel: viewModel)
            CustomerRetentionView(
                session: session,
                selectedProvider: viewModel.selectedProvider,
                amountRupees: viewModel.amountRupees,
                message: viewModel.tipMessage,
                rating: viewModel.selectedRating
            )
            CustomerJarView(session: session)

            Text("Resolve QR or link")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            TextField("Paste /qr/... or /tip/... or raw ID", text: $viewModel.resolutionInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.openScanner()
                }) {
                    Text(viewModel.isResolvingScannedCode ? "Resolving..." : "Scan QR")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isScannerPresented || viewModel.isResolvingScannedCode)

                Button(action: {
                    Task { await viewModel.resolveQr() }
                }) {
                    Text(viewModel.isResolvingQr ? "Resolving..." : "Resolve QR")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingQr ||
                    viewModel.isResolvingScannedCode
                )

                Button(action: {
                    Task { await viewModel.resolvePaymentLink() }
                }) {
                    Text(viewModel.isResolvingPaymentLink ? "Resolving..." : "Resolve link")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingPaymentLink ||
                    viewModel.isResolvingScannedCode
                )
            }

            TextField("Search providers by name or phone", text: $viewModel.providerQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button(action: {
                    Task { await viewModel.searchProviders() }
                }) {
                    Text(viewModel.isSearchingProviders ? "Searching..." : "Search providers")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                .disabled(viewModel.providerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || viewModel.isSearchingProviders)

                Button("Log out") {
                    viewModel.logout()
                }
                .buttonStyle(.borderless)
            }

            if let entry = viewModel.selectedEntryContext {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected entry context")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)
                    DetailLine(label: "Source", value: entry.source.label)
                    DetailLine(label: "Provider", value: entry.providerName)
                    if let category = entry.category {
                        DetailLine(label: "Category", value: category)
                    }
                    if let detail = entry.entryDetail {
                        DetailLine(label: "Context", value: detail)
                    }
                    if let suggestedAmountPaise = entry.suggestedAmountPaise {
                        DetailLine(label: "Suggested amount", value: "Rs \(suggestedAmountPaise / 100)")
                    }
                    DetailLine(label: "Custom amount", value: entry.allowCustomAmount ? "Allowed" : "Locked to suggested amount")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
                )
            }

            if !viewModel.providerResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search results")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    ForEach(viewModel.providerResults) { provider in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(provider.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fliqInk)
                            if let category = provider.category {
                                DetailLine(label: "Category", value: category)
                            }
                            if let phone = provider.phone {
                                DetailLine(label: "Phone", value: phone)
                            }
                            DetailLine(label: "Rating", value: scoreText(provider.ratingAverage))
                            DetailLine(label: "Total tips", value: String(provider.totalTipsReceived))

                            Button(action: {
                                Task { await viewModel.loadProvider(provider.id) }
                            }) {
                                Text(viewModel.isLoadingProvider ? "Loading..." : "Open provider")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                            .disabled(viewModel.isLoadingProvider)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                    }
                }
            }

            if let provider = viewModel.selectedProvider {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Selected provider")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    DetailLine(label: "Name", value: provider.displayName)
                    if let category = provider.category {
                        DetailLine(label: "Category", value: category)
                    }
                    if let bio = provider.bio {
                        DetailLine(label: "Bio", value: bio)
                    }
                    DetailLine(label: "Rating", value: scoreText(provider.ratingAverage))
                    DetailLine(label: "Tips today", value: String(provider.stats.tipsToday))
                    DetailLine(label: "Recent appreciations", value: String(provider.stats.recentAppreciations))
                    if let reputation = provider.reputation {
                        DetailLine(label: "Reputation score", value: scoreText(reputation.score))
                    }
                    if let dream = provider.dream {
                        DetailLine(label: "Dream", value: "\(dream.title) (\(dream.percentage)% funded)")
                    }
                    if let entry = viewModel.selectedEntryContext {
                        DetailLine(label: "Entry source", value: entry.source.label)
                    }

                    Text("Tip amount")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    HStack(spacing: 10) {
                        ForEach([50, 100, 200], id: \.self) { amount in
                            Button("Rs \(amount)") {
                                viewModel.usePresetAmount(amount)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .disabled(isCustomAmountLocked)
                        }
                    }

                    TextField("Custom amount in rupees", text: amountBinding)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .disabled(isCustomAmountLocked)

                    if isCustomAmountLocked {
                        Text("This payment link locks the amount to the suggested value from the backend.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.fliqMuted)
                    }

                    Text("Intent")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    ForEach(TipIntentOption.allCases) { intent in
                        Button(action: {
                            viewModel.selectedIntent = intent
                        }) {
                            Text(intent == viewModel.selectedIntent ? "\(intent.label) selected" : "\(intent.label): \(intent.summary)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                        }
                        .buttonStyle(.bordered)
                    }

                    TextField("Message", text: $viewModel.tipMessage, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    Text("Rating")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { rating in
                            Button(rating == viewModel.selectedRating ? "\(rating)*" : "\(rating)") {
                                viewModel.selectedRating = rating
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Button(action: {
                        Task { await viewModel.createTip() }
                    }) {
                        Text(viewModel.isSubmittingTip ? "Creating order..." : "Create tip order")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                    .disabled(viewModel.isSubmittingTip)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
                )
            }

            if let order = viewModel.createdTipOrder {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tip order created")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)
                    DetailLine(label: "Provider", value: order.provider.name)
                    if let category = order.provider.category {
                        DetailLine(label: "Category", value: category)
                    }
                    DetailLine(label: "Amount", value: "Rs \(order.amount / 100)")
                    DetailLine(label: "Currency", value: order.currency)
                    DetailLine(label: "Tip ID", value: order.tipId)
                    DetailLine(label: "Order ID", value: order.orderId)
                    DetailLine(label: "Razorpay key", value: order.razorpayKeyId)
                    if let tipStatus = viewModel.tipStatus {
                        DetailLine(label: "Backend status", value: tipStatus.status)
                        if let updatedAt = tipStatus.updatedAt {
                            DetailLine(label: "Updated at", value: updatedAt)
                        }
                    }
                    HStack(spacing: 12) {
                        Button(action: {
                            Task { await viewModel.refreshTipStatus() }
                        }) {
                            Text(viewModel.isRefreshingTipStatus ? "Refreshing..." : "Refresh status")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isRefreshingTipStatus)

                        if order.isMockOrder {
                            Button(action: {
                                Task { await viewModel.completeMockPayment() }
                            }) {
                                Text(viewModel.isCompletingMockPayment ? "Completing..." : "Complete mock payment")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                            .disabled(viewModel.isCompletingMockPayment)
                        } else {
                            Button(action: {
                                viewModel.openCheckout()
                            }) {
                                Text(viewModel.isVerifyingCheckout ? "Verifying..." : (viewModel.isLaunchingCheckout ? "Opening..." : "Open checkout"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                            .disabled(viewModel.isLaunchingCheckout || viewModel.isVerifyingCheckout)
                        }
                    }
                    Text(order.isMockOrder
                         ? "The backend is returning a dev-bypass Razorpay order. You can complete verification here without a real checkout SDK."
                         : "Native Razorpay checkout is now wired. This button opens the SDK and verifies the callback back through the shared backend.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
                )
            }

            CustomerTipSuccessSection(viewModel: viewModel)
            CustomerHistorySection(viewModel: viewModel)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
        .sheet(isPresented: $viewModel.isScannerPresented) {
            QRScannerSheet(
                onCode: { code in
                    Task { await viewModel.handleScannedCode(code) }
                },
                onCancel: {
                    viewModel.dismissScanner()
                },
                onError: { message in
                    viewModel.dismissScanner()
                    viewModel.errorMessage = message
                }
            )
        }
    }
}

private struct CustomerTipSuccessSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.isLoadingTipImpact || viewModel.tipImpact != nil {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Payment success")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    Spacer()

                    if viewModel.tipImpact != nil {
                        Button(action: {
                            Task { await viewModel.refreshTipImpact() }
                        }) {
                            Text(viewModel.isLoadingTipImpact ? "Refreshing..." : "Refresh")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isLoadingTipImpact)
                    }
                }

                if viewModel.isLoadingTipImpact, viewModel.tipImpact == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let impact = viewModel.tipImpact {
                    DetailLine(label: "Worker", value: impact.workerName)
                    DetailLine(label: "Amount", value: historyAmountPaiseText(impact.amountPaise))
                    if let intent = historyIntentText(impact.intent) {
                        DetailLine(label: "Intent", value: intent)
                    }
                    Text(impact.message)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fliqInk)

                    if let dream = impact.dream {
                        DetailLine(label: "Dream", value: dream.title)
                        DetailLine(label: "Progress", value: "\(dream.previousProgress)% to \(dream.newProgress)%")
                    }
                }
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
}

private struct PendingTipQueueSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Offline queue")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.fliqInk)

                Spacer()

                Button(action: {
                    Task { await viewModel.syncPendingTipDrafts() }
                }) {
                    Text(viewModel.isSyncingPendingTips ? "Syncing..." : "Sync now")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.pendingTipDrafts.isEmpty || viewModel.isSyncingPendingTips)
            }

            if viewModel.pendingTipDrafts.isEmpty {
                Text("Offline-created customer tips will queue here if the backend cannot be reached.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(viewModel.pendingTipDrafts) { draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(historyAmountPaiseText(draft.amountPaise)) to \(draft.providerName)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fliqInk)
                        if let category = draft.providerCategory {
                            DetailLine(label: "Category", value: category)
                        }
                        DetailLine(label: "Source", value: draft.source.label)
                        DetailLine(label: "Intent", value: draft.intent.label)
                        if let message = draft.message {
                            DetailLine(label: "Message", value: message)
                        }
                        DetailLine(label: "Queued", value: historyDateText(draft.createdAt) ?? draft.createdAt)
                        HStack(spacing: 12) {
                            Button(action: {
                                Task { await viewModel.syncPendingTipDrafts() }
                            }) {
                                Text("Retry sync")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqMint))
                            .disabled(viewModel.isSyncingPendingTips)

                            Button(action: {
                                viewModel.discardPendingTipDraft(draft.id)
                            }) {
                                Text("Discard")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isSyncingPendingTips)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                }
            }
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

private struct CustomerProfileEditorCard: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profile")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            if let profile = viewModel.customerProfile {
                DetailLine(label: "Customer ID", value: profile.id)
            }

            TextField("Name", text: $viewModel.profileName)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            TextField("Email", text: $viewModel.profileEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            TextField("Phone", text: $viewModel.profilePhone)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            TextField("Language code (en, hi, ta, te, kn, mr)", text: $viewModel.profileLanguage)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button(action: {
                    Task { await viewModel.refreshCustomerProfile() }
                }) {
                    Text(viewModel.isLoadingCustomerProfile ? "Refreshing..." : "Refresh profile")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoadingCustomerProfile || viewModel.isSavingCustomerProfile)

                Button(action: {
                    Task { await viewModel.saveCustomerProfile() }
                }) {
                    Text(viewModel.isSavingCustomerProfile ? "Saving..." : "Save profile")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqBlue))
                .disabled(viewModel.isLoadingCustomerProfile || viewModel.isSavingCustomerProfile)
            }
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

private struct CustomerHistorySection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent tips")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.fliqInk)

                Spacer()

                Button(action: {
                    Task { await viewModel.refreshCustomerHistory() }
                }) {
                    Text(viewModel.isLoadingCustomerHistory ? "Refreshing..." : "Refresh")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoadingCustomerHistory)
            }

            if viewModel.isLoadingCustomerHistory && viewModel.customerTipHistory.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.customerTipHistory.isEmpty {
                Text("No customer tips yet. Recent authenticated tips will appear here.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fliqMuted)
            } else {
                ForEach(viewModel.customerTipHistory) { tip in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(historyAmountText(tip)) to \(tip.providerName)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fliqInk)
                        if let category = tip.providerCategory {
                            DetailLine(label: "Category", value: category)
                        }
                        DetailLine(label: "Status", value: tip.status)
                        if let intent = historyIntentText(tip.intent) {
                            DetailLine(label: "Intent", value: intent)
                        }
                        if let message = tip.message {
                            DetailLine(label: "Message", value: message)
                        }
                        if let createdAt = historyDateText(tip.createdAt) {
                            DetailLine(label: "Created", value: createdAt)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                }
            }
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

private struct RoleHomeCard: View {
    let session: AuthSession
    let onLogout: () -> Void

    private var roleTitle: String {
        session.user.type.prefix(1) + session.user.type.dropFirst().lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(roleTitle) home")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            if let name = session.user.name { DetailLine(label: "Name", value: name) }
            if let phone = session.user.phone { DetailLine(label: "Phone", value: phone) }
            if let email = session.user.email { DetailLine(label: "Email", value: email) }

            Text("Auth and session parity are live here. Provider and business feature screens stay separate and will be expanded in their own slices instead of being mixed into customer tipping work.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fliqMuted)

            Button(action: onLogout) {
                Text("Log out")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: .fliqGold))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}

private func historyAmountText(_ tip: CustomerTipHistoryItem) -> String {
    let amount = Double(tip.amountPaise) / 100.0
    return String(format: "Rs %.0f", amount)
}

private func historyAmountPaiseText(_ amountPaise: Int) -> String {
    let amount = Double(amountPaise) / 100.0
    return String(format: "Rs %.0f", amount)
}

private func historyDateText(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: value) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    return value
}

private func historyIntentText(_ value: String?) -> String? {
    switch value {
    case "KINDNESS": return "Kindness"
    case "SPEED": return "Speed"
    case "EXPERIENCE": return "Experience"
    case "SUPPORT": return "Support"
    case let raw?: return raw
    default: return nil
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqMuted)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqInk)
        }
    }
}

struct StatusCard: View {
    let title: String
    let message: String
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fliqInk)

            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(isError ? Color.red : Color.fliqMuted)
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

private struct RoleBadge: View {
    let accent: Color

    var body: some View {
        Text("Native")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(accent.opacity(0.14))
            .foregroundStyle(accent)
            .clipShape(Capsule())
    }
}

#Preview {
    RootView()
}

private func scoreText(_ value: Double?) -> String {
    guard let value else { return "0.0" }
    return String(format: "%.1f", value)
}
