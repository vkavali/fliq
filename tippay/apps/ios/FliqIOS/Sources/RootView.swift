import SwiftUI

// MARK: - Role Model

private struct RoleCard: Identifiable {
    let role: NativeRole
    let title: String
    let subtitle: String
    let sfSymbol: String
    let accent: Color
    let actionLabel: String

    var id: String { role.rawValue }
}

// MARK: - Root View

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showDemo = false

    private let roles: [RoleCard] = [
        RoleCard(
            role: .customer,
            title: "Tipper",
            subtitle: "Scan QR codes, tip with intent, and see your impact on someone's dream.",
            sfSymbol: "heart",
            accent: Color.fliqTeal,
            actionLabel: "Enter as Tipper"
        ),
        RoleCard(
            role: .provider,
            title: "Worker",
            subtitle: "Receive tips, share your dream, and build portable trust on UPI.",
            sfSymbol: "sparkles",
            accent: Color.fliqGreen,
            actionLabel: "Enter as Worker"
        ),
        RoleCard(
            role: .business,
            title: "Business",
            subtitle: "Manage staff, track satisfaction scores, and export QR codes at scale.",
            sfSymbol: "building.2",
            accent: Color.fliqLilac,
            actionLabel: "Enter as Business"
        )
    ]

    var body: some View {
        ZStack {
            GradientBackground()

            if viewModel.isLoading && viewModel.stage != .home {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.regular)
                    Text("Authenticating…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch viewModel.stage {
                        case .rolePicker:
                            HeroSection(showDemo: $showDemo)
                                .padding(.top, 8)

                            RoleSectionHeader()
                            ForEach(roles) { role in
                                RoleEntryCard(role: role) {
                                    viewModel.selectRole(role.role)
                                }
                            }

                        case .credential:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "Sign In", onBack: { viewModel.backToRolePicker() })
                                AuthCard(
                                    role: role,
                                    credential: $viewModel.credential,
                                    onSubmit: { Task { await viewModel.sendCode() } }
                                )
                            }

                        case .otp:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "Verify", onBack: { viewModel.backToCredential() })
                                OTPCard(
                                    role: role,
                                    credential: viewModel.credential,
                                    code: $viewModel.code,
                                    onResend: { Task { await viewModel.resendCode() } },
                                    onVerify: { Task { await viewModel.verifyCode() } }
                                )
                            }

                        case .home:
                            if let session = viewModel.session {
                                let effectiveRole: NativeRole = {
                                    if session.user.type.hasPrefix("BUSINESS") { return .business }
                                    if session.user.type == NativeRole.provider.rawValue ||
                                        (viewModel.selectedRole == .provider &&
                                         session.user.type == NativeRole.customer.rawValue) {
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
                                    BusinessHomeView(session: session) { viewModel.logout() }
                                } else {
                                    ProviderHomeView(session: session) { viewModel.logout() }
                                }
                            }
                        }

                        if viewModel.errorMessage != nil ||
                            !viewModel.statusMessage.isEmpty {
                            StatusCard(
                                message: viewModel.errorMessage ?? viewModel.statusMessage,
                                isError: viewModel.errorMessage != nil
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
        }
        .sheet(isPresented: $showDemo) {
            DemoTipView()
        }
    }
}

// MARK: - Back Bar

private struct BackBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Text("Fliq")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.fliqTeal.opacity(0.9))
        }
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    @Binding var showDemo: Bool
    @State private var phoneFloat: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Brand bar ──────────────────────────────────────────────────
            HStack {
                // "Human Value Infrastructure" pill badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.fliqGreen)
                        .frame(width: 6, height: 6)
                    Text("Human Value Infrastructure")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.12))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )

                Spacer()

                Text("Fliq")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)

            // ── Hero title ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Text("Every tip tells a")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                // "story" in green gradient
                Text("story.")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.fliqGreen, Color.fliqTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.bottom, 20)

            // ── Subtitle ───────────────────────────────────────────────────
            Text("Fliq transforms tipping into meaningful appreciation. Workers define dreams, tippers see impact — all on UPI, zero friction.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(6)
                .padding(.bottom, 32)

            // ── CTA buttons ────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button(action: { showDemo = true }) {
                    HStack(spacing: 8) {
                        Text("Try Demo")
                            .font(.system(size: 15, weight: .semibold))
                        Text("→")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NothingGhostButtonStyle())

                Button(action: {}) {
                    Text("See What's New")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NothingGhostButtonStyle())
            }
            .padding(.bottom, 36)

            // ── Phone mockup card ──────────────────────────────────────────
            PhoneWidget()
                .offset(y: phoneFloat)
                .onAppear {
                    withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                        phoneFloat = -9
                    }
                }
        }
    }
}

// MARK: - Phone Widget (glassmorphism tipping mockup)

private struct PhoneWidget: View {
    @State private var progressFraction: CGFloat = 0.18
    @State private var selectedAmount = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Widget header
            HStack {
                Text("Provider Profile")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.fliqGreen)
                        .frame(width: 6, height: 6)
                    Text("UPI Live")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.fliqGreen)
                }
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.bottom, 18)

            // Provider row
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Text("RK")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ravi Kumar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Text("Trust")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        HStack(spacing: 2) {
                            Text("82")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.fliqGreen, Color.fliqTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("/ 100")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                Spacer()
            }
            .padding(.bottom, 20)

            // Dream section
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Dream")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(0.5)

                Text("Daughter's School Books")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)
                            .cornerRadius(2)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.fliqGreen, Color.fliqTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressFraction, height: 3)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text("65% funded")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.fliqGreen)
                    Spacer()
                    Text("₹3,250 / ₹5,000")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 20)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.bottom, 16)

            // Tip presets
            HStack(spacing: 8) {
                ForEach([50, 100, 200], id: \.self) { amount in
                    Text("₹\(amount)")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(selectedAmount == amount ? Color.fliqTeal : .white.opacity(0.5))
                        .background(Color.white.opacity(selectedAmount == amount ? 0.15 : 0.06))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    selectedAmount == amount
                                        ? Color.fliqTeal.opacity(0.8)
                                        : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                        .onTapGesture { selectedAmount = amount }
                }
            }
            .padding(.bottom, 14)

            // CTA
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Tip ₹100 with Kindness")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("→")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [Color.fliqIndigo, Color.fliqTeal],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.07))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 2.8).delay(0.5)) {
                progressFraction = 0.65
            }
        }
    }
}

// MARK: - Role Section Header

private struct RoleSectionHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fliqGreen, Color.fliqTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3, height: 18)
                Text("Choose your role")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .kerning(0.5)
            }
            Text("How would you like to use Fliq?")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Role Entry Card

private struct RoleEntryCard: View {
    let role: RoleCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(role.accent.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(role.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(role.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text(role.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
            }
            .padding(18)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Action row
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 12, weight: .medium))
                    Text(role.actionLabel)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(role.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(role.accent.opacity(0.08))
            }
            .buttonStyle(.plain)
        }
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - Auth Card (Credential)

private struct AuthCard: View {
    let role: RoleCard
    @Binding var credential: String
    let onSubmit: () -> Void
    @State private var selectedCountryCode = "+91"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Rectangle()
                    .fill(role.accent)
                    .frame(width: 3, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(role.accent)
                        .kerning(1.5)
                    Text(role.role.usesEmail ? "Enter business email" : "Enter phone number")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if !role.role.usesEmail {
                HStack(spacing: 8) {
                    ForEach([("🇮🇳 +91", "+91"), ("🇺🇸 +1", "+1")], id: \.1) { label, code in
                        Button {
                            let oldPrefix = selectedCountryCode
                            selectedCountryCode = code
                            let raw = credential.hasPrefix(oldPrefix)
                                ? String(credential.dropFirst(oldPrefix.count))
                                : credential
                            credential = code + raw
                        } label: {
                            Text(label)
                                .font(.system(size: 13, weight: selectedCountryCode == code ? .bold : .regular))
                                .foregroundStyle(selectedCountryCode == code ? role.accent : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(role.accent.opacity(selectedCountryCode == code ? 0.15 : 0.0))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedCountryCode == code ? role.accent.opacity(0.6) : Color.white.opacity(0.18),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField(
                role.role.usesEmail ? "name@company.com" : "\(selectedCountryCode)98765 43210",
                text: $credential
            )
            .keyboardType(role.role.usesEmail ? .emailAddress : .phonePad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onSubmit) {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 13, weight: .medium))
                    Text("Send One-Time Code")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("→")
                        .font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
            .disabled(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - OTP Card

private struct OTPCard: View {
    let role: RoleCard
    let credential: String
    @Binding var code: String
    let onResend: () -> Void
    let onVerify: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(role.accent)
                    .frame(width: 3, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VERIFICATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(role.accent)
                        .kerning(1.5)
                    Text("Enter the code we sent")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(credential)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))

            TextField("_ _ _ _ _ _", text: $code)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .kerning(10)
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

            Button(action: onVerify) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13, weight: .medium))
                    Text("Verify & Sign In")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("→")
                        .font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)

            Button("Resend code →", action: onResend)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .buttonStyle(.plain)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Customer Home Card

private struct CustomerHomeCard: View {
    let session: AuthSession
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DarkSectionHeader(label: "CUSTOMER HOME", title: "Welcome back")

            if let name = session.user.name {
                DetailLine(label: "SIGNED IN AS", value: name)
            }

            Button("Log Out →") { viewModel.logout() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .buttonStyle(.plain)

            DarkDivider()

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

            DarkSectionHeader(label: "RESOLVE", title: "QR or payment link")

            DarkTextField(placeholder: "Paste /qr/… or /tip/… or raw ID",
                          text: $viewModel.resolutionInput)

            HStack(spacing: 8) {
                Button(action: { viewModel.openScanner() }) {
                    labelMono(viewModel.isResolvingScannedCode ? "Resolving…" : "Scan QR")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(viewModel.isScannerPresented || viewModel.isResolvingScannedCode)

                Button(action: { Task { await viewModel.resolveQr() } }) {
                    labelMono(viewModel.isResolvingQr ? "Resolving…" : "Resolve QR")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingQr || viewModel.isResolvingScannedCode
                )

                Button(action: { Task { await viewModel.resolvePaymentLink() } }) {
                    labelMono(viewModel.isResolvingPaymentLink ? "Resolving…" : "Resolve Link")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingPaymentLink || viewModel.isResolvingScannedCode
                )
            }

            DarkSectionHeader(label: "SEARCH", title: "Find a provider")

            DarkTextField(placeholder: "Name or phone number",
                          text: $viewModel.providerQuery)

            Button(action: { Task { await viewModel.searchProviders() } }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                    labelMono(viewModel.isSearchingProviders ? "Searching…" : "Search Providers")
                    Spacer()
                    Text("→").font(.system(size: 13))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .buttonStyle(FliqPrimaryButtonStyle())
            .disabled(
                viewModel.providerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ||
                viewModel.isSearchingProviders
            )

            if let entry = viewModel.selectedEntryContext {
                DarkCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("ENTRY CONTEXT")
                        DetailLine(label: "SOURCE", value: entry.source.label)
                        DetailLine(label: "PROVIDER", value: entry.providerName)
                        if let category = entry.category {
                            DetailLine(label: "CATEGORY", value: category)
                        }
                        if let detail = entry.entryDetail {
                            DetailLine(label: "CONTEXT", value: detail)
                        }
                        if let paise = entry.suggestedAmountPaise {
                            DetailLine(label: "SUGGESTED AMOUNT", value: "₹\(paise / 100)")
                        }
                        DetailLine(label: "CUSTOM AMOUNT", value: entry.allowCustomAmount ? "Allowed" : "Locked")
                    }
                }
            }

            ProviderResultsSection(viewModel: viewModel)
            ProviderTipFlowSection(viewModel: viewModel)
            TipOrderSection(viewModel: viewModel)
            CustomerTipSuccessSection(viewModel: viewModel)
            CustomerHistorySection(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isScannerPresented) {
            QRScannerSheet(
                onCode: { code in Task { await viewModel.handleScannedCode(code) } },
                onCancel: { viewModel.dismissScanner() },
                onError: { message in
                    viewModel.dismissScanner()
                    viewModel.errorMessage = message
                }
            )
        }
    }
}

// MARK: - Provider Results Section

private struct ProviderResultsSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if !viewModel.providerResults.isEmpty {
            DarkSectionHeader(label: "RESULTS", title: "\(viewModel.providerResults.count) provider(s) found")
            ForEach(viewModel.providerResults) { provider in
                DarkCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(provider.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        if let cat = provider.category { DetailLine(label: "CATEGORY", value: cat) }
                        if let ph = provider.phone { DetailLine(label: "PHONE", value: ph) }
                        DetailLine(label: "RATING", value: scoreText(provider.ratingAverage))
                        DetailLine(label: "TOTAL TIPS", value: "\(provider.totalTipsReceived)")
                        Button(action: { Task { await viewModel.loadProvider(provider.id) } }) {
                            HStack {
                                labelMono(viewModel.isLoadingProvider ? "Loading…" : "Open Provider")
                                Spacer()
                                Text("→").font(.system(size: 13))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(FliqPrimaryButtonStyle())
                        .disabled(viewModel.isLoadingProvider)
                    }
                }
            }
        }
    }
}

// MARK: - Provider Tip Flow Section

private struct ProviderTipFlowSection: View {
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
        if let provider = viewModel.selectedProvider {
            DarkCard {
                VStack(alignment: .leading, spacing: 14) {
                    DarkSectionHeader(label: "SELECTED PROVIDER", title: provider.displayName)
                    if let cat = provider.category { DetailLine(label: "CATEGORY", value: cat) }
                    if let bio = provider.bio { DetailLine(label: "BIO", value: bio) }
                    DetailLine(label: "RATING", value: scoreText(provider.ratingAverage))
                    DetailLine(label: "TIPS TODAY", value: "\(provider.stats.tipsToday)")
                    DetailLine(label: "APPRECIATIONS", value: "\(provider.stats.recentAppreciations)")
                    if let rep = provider.reputation {
                        DetailLine(label: "REPUTATION", value: scoreText(rep.score))
                    }
                    if let dream = provider.dream {
                        DetailLine(label: "DREAM", value: "\(dream.title) (\(dream.percentage)% funded)")
                    }
                    DarkDivider()
                    SectionLabel("TIP AMOUNT")
                    HStack(spacing: 8) {
                        ForEach([50, 100, 200], id: \.self) { amount in
                            Button("₹\(amount)") { viewModel.usePresetAmount(amount) }
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(isCustomAmountLocked)
                        }
                    }
                    DarkTextField(placeholder: "Custom amount in rupees",
                                  text: amountBinding, keyboardType: .numberPad)
                        .disabled(isCustomAmountLocked)
                    if isCustomAmountLocked {
                        Text("Amount locked by payment link.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    DarkDivider()
                    SectionLabel("INTENT")
                    ForEach(TipIntentOption.allCases) { intent in
                        IntentButton(intent: intent,
                                     isSelected: intent == viewModel.selectedIntent,
                                     onTap: { viewModel.selectedIntent = intent })
                    }
                    DarkTextField(placeholder: "Message (optional)",
                                  text: $viewModel.tipMessage, axis: .vertical)
                    DarkDivider()
                    SectionLabel("RATING")
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { rating in
                            RatingButton(rating: rating,
                                         isSelected: rating == viewModel.selectedRating,
                                         onTap: { viewModel.selectedRating = rating })
                        }
                    }
                    Button(action: { Task { await viewModel.createTip() } }) {
                        HStack {
                            Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold))
                            labelMono(viewModel.isSubmittingTip ? "Creating Order…" : "Create Tip Order")
                            Spacer()
                            Text("→").font(.system(size: 14))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(NothingFilledButtonStyle())
                    .disabled(viewModel.isSubmittingTip)
                }
            }
        }
    }
}

// MARK: - Tip Order Section

private struct TipOrderSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if let order = viewModel.createdTipOrder {
            DarkCard {
                VStack(alignment: .leading, spacing: 10) {
                    DarkSectionHeader(label: "TIP ORDER CREATED", title: order.provider.name)
                    if let cat = order.provider.category { DetailLine(label: "CATEGORY", value: cat) }
                    DetailLine(label: "AMOUNT", value: "₹\(order.amount / 100)")
                    DetailLine(label: "CURRENCY", value: order.currency)
                    DetailLine(label: "TIP ID", value: order.tipId)
                    DetailLine(label: "ORDER ID", value: order.orderId)
                    DetailLine(label: "RAZORPAY KEY", value: order.razorpayKeyId)
                    if let tipStatus = viewModel.tipStatus {
                        DetailLine(label: "STATUS", value: tipStatus.status)
                        if let updatedAt = tipStatus.updatedAt {
                            DetailLine(label: "UPDATED AT", value: updatedAt)
                        }
                    }
                    HStack(spacing: 8) {
                        Button(action: { Task { await viewModel.refreshTipStatus() } }) {
                            labelMono(viewModel.isRefreshingTipStatus ? "Refreshing…" : "Refresh Status")
                                .padding(.vertical, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(NothingGhostButtonStyle())
                        .disabled(viewModel.isRefreshingTipStatus)

                        if order.isMockOrder {
                            Button(action: { Task { await viewModel.completeMockPayment() } }) {
                                labelMono(viewModel.isCompletingMockPayment ? "Completing…" : "Mock Payment")
                                    .padding(.vertical, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(FliqPrimaryButtonStyle())
                            .disabled(viewModel.isCompletingMockPayment)
                        } else {
                            Button(action: { viewModel.openCheckout() }) {
                                labelMono(viewModel.isVerifyingCheckout ? "Verifying…" :
                                          viewModel.isLaunchingCheckout ? "Opening…" : "Open Checkout")
                                    .padding(.vertical, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(NothingFilledButtonStyle())
                            .disabled(viewModel.isLaunchingCheckout || viewModel.isVerifyingCheckout)
                        }
                    }
                    Text(order.isMockOrder
                         ? "Dev-bypass order — complete without the Razorpay SDK."
                         : "Native Razorpay checkout wired. Opens SDK and verifies callback.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }
}

// MARK: - Customer Tip Success Section

private struct CustomerTipSuccessSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.isLoadingTipImpact || viewModel.tipImpact != nil {
            DarkCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        DarkSectionHeader(label: "PAYMENT SUCCESS", title: "Tip impact")
                        Spacer()
                        if viewModel.tipImpact != nil {
                            Button(action: { Task { await viewModel.refreshTipImpact() } }) {
                                labelMono(viewModel.isLoadingTipImpact ? "Refreshing…" : "Refresh")
                            }
                            .buttonStyle(NothingGhostButtonStyle())
                            .disabled(viewModel.isLoadingTipImpact)
                        }
                    }

                    if viewModel.isLoadingTipImpact, viewModel.tipImpact == nil {
                        ProgressView().tint(Color.fliqTeal).frame(maxWidth: .infinity)
                    } else if let impact = viewModel.tipImpact {
                        DetailLine(label: "WORKER", value: impact.workerName)
                        DetailLine(label: "AMOUNT", value: historyAmountPaiseText(impact.amountPaise))
                        if let intent = historyIntentText(impact.intent) {
                            DetailLine(label: "INTENT", value: intent)
                        }
                        Text(impact.message)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let dream = impact.dream {
                            DetailLine(label: "DREAM", value: dream.title)
                            DetailLine(label: "PROGRESS", value: "\(dream.previousProgress)% → \(dream.newProgress)%")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pending Tip Queue Section

private struct PendingTipQueueSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    DarkSectionHeader(label: "OFFLINE QUEUE", title: "Pending tips")
                    Spacer()
                    Button(action: { Task { await viewModel.syncPendingTipDrafts() } }) {
                        labelMono(viewModel.isSyncingPendingTips ? "Syncing…" : "Sync Now")
                    }
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.pendingTipDrafts.isEmpty || viewModel.isSyncingPendingTips)
                }

                if viewModel.pendingTipDrafts.isEmpty {
                    Text("Offline-created tips will queue here when the backend is unreachable.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(viewModel.pendingTipDrafts) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(historyAmountPaiseText(draft.amountPaise)) → \(draft.providerName)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            if let cat = draft.providerCategory { DetailLine(label: "CATEGORY", value: cat) }
                            DetailLine(label: "SOURCE", value: draft.source.label)
                            DetailLine(label: "INTENT", value: draft.intent.label)
                            if let msg = draft.message { DetailLine(label: "MESSAGE", value: msg) }
                            DetailLine(label: "QUEUED", value: historyDateText(draft.createdAt) ?? draft.createdAt)

                            HStack(spacing: 8) {
                                Button(action: { Task { await viewModel.syncPendingTipDrafts() } }) {
                                    labelMono("Retry Sync").padding(.vertical, 11)
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(FliqPrimaryButtonStyle())
                                .disabled(viewModel.isSyncingPendingTips)

                                Button(action: { viewModel.discardPendingTipDraft(draft.id) }) {
                                    labelMono("Discard").padding(.vertical, 11)
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(viewModel.isSyncingPendingTips)
                            }
                        }
                        .padding(.top, 10)

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Customer Profile Editor Card

private struct CustomerProfileEditorCard: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 14) {
                DarkSectionHeader(label: "PROFILE", title: "Your details")

                if let profile = viewModel.customerProfile {
                    DetailLine(label: "CUSTOMER ID", value: profile.id)
                }

                DarkTextField(placeholder: "Name", text: $viewModel.profileName)
                DarkTextField(placeholder: "Email", text: $viewModel.profileEmail,
                              keyboardType: .emailAddress)
                DarkTextField(placeholder: "Phone", text: $viewModel.profilePhone,
                              keyboardType: .phonePad)
                DarkTextField(placeholder: "Language (en, hi, ta, te, kn, mr)",
                              text: $viewModel.profileLanguage)

                HStack(spacing: 8) {
                    Button(action: { Task { await viewModel.refreshCustomerProfile() } }) {
                        labelMono(viewModel.isLoadingCustomerProfile ? "Refreshing…" : "Refresh")
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.isLoadingCustomerProfile || viewModel.isSavingCustomerProfile)

                    Button(action: { Task { await viewModel.saveCustomerProfile() } }) {
                        labelMono(viewModel.isSavingCustomerProfile ? "Saving…" : "Save Profile")
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(FliqPrimaryButtonStyle())
                    .disabled(viewModel.isLoadingCustomerProfile || viewModel.isSavingCustomerProfile)
                }
            }
        }
    }
}

// MARK: - Customer History Section

private struct CustomerHistorySection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    DarkSectionHeader(label: "HISTORY", title: "Recent tips")
                    Spacer()
                    Button(action: { Task { await viewModel.refreshCustomerHistory() } }) {
                        labelMono(viewModel.isLoadingCustomerHistory ? "Refreshing…" : "Refresh")
                    }
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.isLoadingCustomerHistory)
                }

                if viewModel.isLoadingCustomerHistory && viewModel.customerTipHistory.isEmpty {
                    ProgressView().tint(Color.fliqTeal).frame(maxWidth: .infinity)
                } else if viewModel.customerTipHistory.isEmpty {
                    Text("No tips yet. Authenticated tips will appear here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(viewModel.customerTipHistory) { tip in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(historyAmountText(tip)) → \(tip.providerName)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            if let cat = tip.providerCategory { DetailLine(label: "CATEGORY", value: cat) }
                            DetailLine(label: "STATUS", value: tip.status)
                            if let intent = historyIntentText(tip.intent) { DetailLine(label: "INTENT", value: intent) }
                            if let msg = tip.message { DetailLine(label: "MESSAGE", value: msg) }
                            if let date = historyDateText(tip.createdAt) { DetailLine(label: "CREATED", value: date) }
                        }
                        .padding(.top, 10)

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Shared UI Primitives

private func labelMono(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
}

private struct DarkSectionHeader: View {
    let label: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(1)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.5))
            .kerning(1)
    }
}

private struct DarkDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }
}

private struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(axis == .vertical ? 3...6 : 1...1)
            .padding(13)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct DarkCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Intent & Rating Buttons

private struct IntentButton: View {
    let intent: TipIntentOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(isSelected ? "✓ \(intent.label.uppercased())" : "\(intent.label.uppercased()): \(intent.summary)")
                    .font(.system(size: 12, weight: .medium))
                    .kerning(0.3)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.fliqTeal : Color.white.opacity(0.65))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.fliqTeal.opacity(isSelected ? 0.15 : 0.0))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                isSelected ? Color.fliqTeal.opacity(0.5) : Color.white.opacity(0.15),
                lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RatingButton: View {
    let rating: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isSelected ? "★\(rating)" : "\(rating)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? Color.fliqAmber : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.fliqAmber.opacity(isSelected ? 0.18 : 0.0))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                    isSelected ? Color.fliqAmber.opacity(0.5) : Color.white.opacity(0.15),
                    lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Line

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    var title: String = ""
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(isError ? Color.red.opacity(0.8) : Color.fliqTeal)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(isError ? "Error" : "Status")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isError ? Color.red.opacity(0.9) : Color.fliqTeal)
                    .kerning(0.8)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isError ? Color.red.opacity(0.85) : .white.opacity(0.75))
                    .lineLimit(4)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isError ? Color.red.opacity(0.3) : Color.white.opacity(0.15),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Role Badge (legacy compat, renders nothing)

struct RoleBadge: View {
    let accent: Color
    var body: some View { EmptyView() }
}

// MARK: - Demo Tip View

struct DemoTipView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount = 100
    @State private var showSuccess = false
    @State private var progressFraction: CGFloat = 0.42

    private let demoGoal = "Buy a bicycle for daily commute"
    private let demoProgress = 42
    private let demoTrust = 87

    var body: some View {
        ZStack {
            GradientBackground()

            if showSuccess {
                DemoSuccessView(amount: selectedAmount, onDismiss: { dismiss() })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header bar ─────────────────────────────────────
                        HStack {
                            HStack(spacing: 8) {
                                Text("DEMO")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(.white)
                                Text("MODE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.fliqTeal)
                                    .kerning(1.5)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.fliqTeal.opacity(0.15))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.fliqTeal.opacity(0.4), lineWidth: 1)
                                    )
                            }
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)

                        Text("No sign-up needed. Experience the full tipping flow.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 28)

                        // ── Worker profile ─────────────────────────────────
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 60, height: 60)
                                Text("DW")
                                    .font(.system(size: 17, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Demo Worker")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(.white)

                                HStack(spacing: 8) {
                                    Text("Trust")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("\(demoTrust)")
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.fliqGreen, Color.fliqTeal],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Text("/ 100")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Text("Delivery · 4 years on Fliq")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                        }
                        .padding(.bottom, 24)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // ── Dream goal ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Active Dream")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(0.5)

                            Text(demoGoal)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.fliqGreen, Color.fliqTeal],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progressFraction, height: 4)
                                        .cornerRadius(2)
                                }
                            }
                            .frame(height: 4)

                            HStack {
                                Text("\(demoProgress)% funded")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.fliqGreen)
                                Spacer()
                                Text("₹2,100 / ₹5,000")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.bottom, 28)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
                                progressFraction = CGFloat(demoProgress) / 100.0
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // ── Tip amount selector ────────────────────────────
                        Text("Tip Amount")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(0.5)
                            .padding(.bottom, 12)

                        HStack(spacing: 10) {
                            ForEach([50, 100, 200], id: \.self) { amount in
                                Button(action: { selectedAmount = amount }) {
                                    VStack(spacing: 4) {
                                        Text("₹\(amount)")
                                            .font(.system(size: 16, weight: .black))
                                        Text(amount == 50 ? "small" : amount == 100 ? "kind" : "generous")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(selectedAmount == amount ? Color.fliqTeal : .white.opacity(0.5))
                                    .background(Color.white.opacity(selectedAmount == amount ? 0.15 : 0.07))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                selectedAmount == amount
                                                    ? Color.fliqTeal.opacity(0.7)
                                                    : Color.white.opacity(0.15),
                                                lineWidth: selectedAmount == amount ? 1.5 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 20)

                        // ── CTA ────────────────────────────────────────────
                        Button(action: { withAnimation(.spring(duration: 0.4)) { showSuccess = true } }) {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Tip ₹\(selectedAmount) with Kindness")
                                    .font(.system(size: 14, weight: .bold))
                                Spacer()
                                Text("→")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(NothingFilledButtonStyle())
                        .padding(.bottom, 16)

                        Text("This is a demo — no real payment is made.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
        }
    }
}

// MARK: - Demo Success View

private struct DemoSuccessView: View {
    let amount: Int
    let onDismiss: () -> Void
    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.fliqGreen.opacity(0.15))
                    .frame(width: 110, height: 110)
                Circle()
                    .stroke(Color.fliqGreen.opacity(0.4), lineWidth: 2)
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.fliqGreen, Color.fliqTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(checkScale)
            .opacity(checkOpacity)
            .padding(.bottom, 32)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.1)) {
                    checkScale = 1.0
                    checkOpacity = 1.0
                }
            }

            Text("₹\(amount) Sent")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.fliqGreen, Color.fliqTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom, 16)

            Text("Your kindness just moved Demo Worker closer to their dream.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            Text("Buy a bicycle for daily commute")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 48)

            Button(action: onDismiss) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back to Home")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .buttonStyle(FliqPrimaryButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Helpers

private func historyAmountText(_ tip: CustomerTipHistoryItem) -> String {
    String(format: "₹%.0f", Double(tip.amountPaise) / 100.0)
}

private func historyAmountPaiseText(_ amountPaise: Int) -> String {
    String(format: "₹%.0f", Double(amountPaise) / 100.0)
}

private func historyDateText(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date.formatted(date: .abbreviated, time: .shortened) }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: value) { return date.formatted(date: .abbreviated, time: .shortened) }
    return value
}

private func historyIntentText(_ value: String?) -> String? {
    switch value {
    case "KINDNESS":   return "Kindness"
    case "SPEED":      return "Speed"
    case "EXPERIENCE": return "Experience"
    case "SUPPORT":    return "Support"
    case let raw?:     return raw
    default:           return nil
    }
}

private func scoreText(_ value: Double?) -> String {
    guard let value else { return "0.0" }
    return String(format: "%.1f", value)
}

// MARK: - Preview

#Preview {
    RootView()
}
