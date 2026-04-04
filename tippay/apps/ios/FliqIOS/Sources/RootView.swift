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
            title: "TIPPER",
            subtitle: "Scan QR codes, tip with intent, and see your impact on someone's dream.",
            sfSymbol: "heart",
            accent: .black,
            actionLabel: "ENTER AS TIPPER"
        ),
        RoleCard(
            role: .provider,
            title: "WORKER",
            subtitle: "Receive tips, share your dream, and build portable trust on UPI.",
            sfSymbol: "sparkles",
            accent: Color.nothingRed,
            actionLabel: "ENTER AS WORKER"
        ),
        RoleCard(
            role: .business,
            title: "BUSINESS",
            subtitle: "Manage staff, track satisfaction scores, and export QR codes at scale.",
            sfSymbol: "building.2",
            accent: Color.black.opacity(0.65),
            actionLabel: "ENTER AS BUSINESS"
        )
    ]

    var body: some View {
        ZStack {
            DotGridBackground()

            if viewModel.isLoading && viewModel.stage != .home {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.nothingRed)
                        .controlSize(.regular)
                    Text("AUTHENTICATING_")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.35))
                        .kerning(1.5)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch viewModel.stage {
                        case .rolePicker:
                            HeroSection()
                                .padding(.top, 8)

                            // ── Try Demo button ───────────────────────────
                            Button(action: { showDemo = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.circle")
                                        .font(.system(size: 13, weight: .light))
                                    Text("TRY DEMO")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .kerning(1.5)
                                    Spacer()
                                    Text("→")
                                        .font(.system(size: 14, design: .monospaced))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(FliqPrimaryButtonStyle())

                            RoleSectionHeader()
                            ForEach(roles) { role in
                                RoleEntryCard(role: role) {
                                    viewModel.selectRole(role.role)
                                }
                            }

                        case .credential:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "SIGN_IN", onBack: { viewModel.backToRolePicker() })
                                AuthCard(
                                    role: role,
                                    credential: $viewModel.credential,
                                    onSubmit: { Task { await viewModel.sendCode() } }
                                )
                            }

                        case .otp:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "VERIFY", onBack: { viewModel.backToCredential() })
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
                    Text("BACK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                }
                .foregroundStyle(.black.opacity(0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .kerning(2.5)

            Text("FLIQ_v5")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nothingRed.opacity(0.7))
                .kerning(0.5)
        }
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    @State private var dotOpacity: Double = 1.0
    @State private var cursorVisible: Bool = true
    @State private var phoneFloat: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Brand bar ──────────────────────────────────────────────────
            HStack(alignment: .center) {
                DotMatrixText(
                    "FLIQ",
                    font: .system(size: 30, weight: .black, design: .monospaced),
                    foreground: .black,
                    dotSpacing: 3.4,
                    dotSize: 2.1
                )

                HStack(spacing: 1) {
                    Text("v")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))
                    Text("5")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.nothingRed)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.nothingRed.opacity(0.55), lineWidth: 1)
                )

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.nothingRed)
                        .frame(width: 5, height: 5)
                        .opacity(dotOpacity)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.45))
                        .kerning(1.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(.black.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.bottom, 30)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    dotOpacity = 0.18
                }
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true).delay(0.3)) {
                    cursorVisible = false
                }
            }

            // ── Tag line ───────────────────────────────────────────────────
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.nothingRed)
                    .frame(width: 20, height: 1)
                Text("HUMAN VALUE INFRASTRUCTURE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.45))
                    .kerning(2.5)
            }
            .padding(.bottom, 22)

            // ── Hero title ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Every tip tells")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.black)
                    .kerning(-1)

                HStack(alignment: .bottom, spacing: 10) {
                    Text("a")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.black)
                        .kerning(-1)

                    DotMatrixText(
                        "story.",
                        font: .system(size: 48, weight: .black, design: .monospaced),
                        foreground: Color.nothingRed,
                        dotSpacing: 4.0,
                        dotSize: 2.5
                    )
                }
            }
            .padding(.bottom, 16)

            // Blinking cursor accent line
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.black.opacity(0.07))
                    .frame(height: 1)
                Text(cursorVisible ? "█" : " ")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.nothingRed.opacity(0.75))
                    .frame(width: 11)
            }
            .padding(.bottom, 20)

            // ── Subtitle ───────────────────────────────────────────────────
            Text("Fliq transforms tipping from a transaction into meaningful appreciation. Workers define dreams, tippers see impact, trust is portable — all on UPI, zero friction.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.black.opacity(0.55))
                .lineSpacing(6)
                .padding(.bottom, 36)

            // ── Phone widget ───────────────────────────────────────────────
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

// MARK: - Phone Widget

private struct PhoneWidget: View {
    @State private var progressFraction: CGFloat = 0.18
    @State private var selectedAmount = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Widget header
            HStack {
                Text("PROVIDER_PROFILE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.38))
                    .kerning(1.5)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.nothingRed)
                        .frame(width: 5, height: 5)
                    Text("UPI_LIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nothingRed)
                        .kerning(0.5)
                }
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 18)

            // Provider row
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.black.opacity(0.2), lineWidth: 1)
                        .frame(width: 54, height: 54)
                    DotMatrixText(
                        "RK",
                        font: .system(size: 17, weight: .black, design: .monospaced),
                        foreground: .black,
                        dotSpacing: 3.0,
                        dotSize: 1.8
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("RAVI KUMAR")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .kerning(1)

                    HStack(spacing: 8) {
                        Text("TRUST")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.38))
                            .kerning(1)

                        HStack(spacing: 2) {
                            DotMatrixText(
                                "82",
                                font: .system(size: 14, weight: .black, design: .monospaced),
                                foreground: Color.nothingRed,
                                dotSpacing: 2.9,
                                dotSize: 1.7
                            )
                            Text("/ 100")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.4))
                        }
                    }
                }
                Spacer()
            }
            .padding(.bottom, 20)

            // Dream section
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE_DREAM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.38))
                    .kerning(2)

                Text("Daughter's School Books")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.85))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.black.opacity(0.1))
                            .frame(height: 2)
                        Rectangle()
                            .fill(Color.nothingRed)
                            .frame(width: geo.size.width * progressFraction, height: 2)
                    }
                }
                .frame(height: 2)

                HStack {
                    Text("65% FUNDED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nothingRed)
                        .kerning(1)
                    Spacer()
                    Text("₹3,250 / ₹5,000")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.38))
                }
            }
            .padding(.bottom, 20)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 16)

            // Tip presets
            HStack(spacing: 8) {
                ForEach([50, 100, 200], id: \.self) { amount in
                    Text("₹\(amount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(selectedAmount == amount ? Color.nothingRed : .black.opacity(0.4))
                        .overlay(
                            Rectangle()
                                .strokeBorder(
                                    selectedAmount == amount
                                        ? Color.nothingRed.opacity(0.75)
                                        : Color.black.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                }
            }
            .padding(.bottom, 14)

            // CTA — solid black fill
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("TIP ₹100 WITH KINDNESS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .kerning(0.5)
                Spacer()
                Text("→")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.black)
        }
        .padding(20)
        .overlay(
            Rectangle()
                .strokeBorder(.black.opacity(0.12), lineWidth: 1)
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
                    .fill(Color.nothingRed)
                    .frame(width: 3, height: 18)
                Text("SELECT_ROLE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.45))
                    .kerning(2.5)
            }
            Text("How would you like to use Fliq?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
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
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(role.accent.opacity(0.28), lineWidth: 1)
                        .frame(width: 46, height: 46)
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(role.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(role.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(role.accent)
                        .kerning(2.5)

                    Text(role.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.black.opacity(0.5))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
            }
            .padding(18)

            Rectangle()
                .fill(role.accent.opacity(0.1))
                .frame(height: 1)

            // Action row
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 11, weight: .regular))
                    Text(role.actionLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(role.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(role.accent.opacity(0.03))
            }
            .buttonStyle(.plain)
        }
        .overlay(
            Rectangle()
                .strokeBorder(role.accent.opacity(0.16), lineWidth: 1)
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
                    Text(role.title)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(role.accent)
                        .kerning(2.5)
                    Text(role.role.usesEmail ? "Enter business email" : "Enter phone number")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
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
                                .font(.system(size: 12, weight: selectedCountryCode == code ? .bold : .regular,
                                              design: .monospaced))
                                .foregroundStyle(selectedCountryCode == code ? role.accent : .black.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(role.accent.opacity(selectedCountryCode == code ? 0.07 : 0.0))
                                .overlay(
                                    Rectangle()
                                        .strokeBorder(
                                            selectedCountryCode == code ? role.accent.opacity(0.6) : Color.black.opacity(0.12),
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
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundStyle(.black)
            .padding(14)
            .background(Color.black.opacity(0.04))
            .overlay(Rectangle().strokeBorder(.black.opacity(0.12), lineWidth: 1))

            Button(action: onSubmit) {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 13, weight: .light))
                    Text("SEND ONE-TIME CODE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                    Spacer()
                    Text("→")
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
            .disabled(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(role.accent)
                        .kerning(2.5)
                    Text("Enter the code we sent")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                }
            }

            Text(credential)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.black.opacity(0.45))

            TextField("_ _ _ _ _ _", text: $code)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .kerning(10)
                .padding(16)
                .background(Color.black.opacity(0.04))
                .overlay(Rectangle().strokeBorder(.black.opacity(0.12), lineWidth: 1))

            Button(action: onVerify) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13, weight: .light))
                    Text("VERIFY & SIGN IN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                    Spacer()
                    Text("→")
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(FliqPrimaryButtonStyle(accent: role.accent))
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)

            Button("Resend code →", action: onResend)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.4))
                .buttonStyle(.plain)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Customer Home Card

private struct CustomerHomeCard: View {
    let session: AuthSession
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Session header
            DarkSectionHeader(label: "CUSTOMER_HOME", title: "Welcome back")

            if let name = session.user.name {
                DetailLine(label: "SIGNED IN AS", value: name)
            }

            Button("LOG OUT →") { viewModel.logout() }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(.black.opacity(0.45))
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

            // QR / Link resolution
            DarkSectionHeader(label: "RESOLVE", title: "QR or payment link")

            DarkTextField(placeholder: "Paste /qr/… or /tip/… or raw ID",
                          text: $viewModel.resolutionInput)

            HStack(spacing: 8) {
                Button(action: { viewModel.openScanner() }) {
                    labelMono(viewModel.isResolvingScannedCode ? "RESOLVING…" : "SCAN QR")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(viewModel.isScannerPresented || viewModel.isResolvingScannedCode)

                Button(action: { Task { await viewModel.resolveQr() } }) {
                    labelMono(viewModel.isResolvingQr ? "RESOLVING…" : "RESOLVE QR")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingQr || viewModel.isResolvingScannedCode
                )

                Button(action: { Task { await viewModel.resolvePaymentLink() } }) {
                    labelMono(viewModel.isResolvingPaymentLink ? "RESOLVING…" : "RESOLVE LINK")
                }
                .buttonStyle(NothingGhostButtonStyle())
                .disabled(
                    viewModel.resolutionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isResolvingPaymentLink || viewModel.isResolvingScannedCode
                )
            }

            // Provider search
            DarkSectionHeader(label: "SEARCH", title: "Find a provider")

            DarkTextField(placeholder: "Name or phone number",
                          text: $viewModel.providerQuery)

            Button(action: { Task { await viewModel.searchProviders() } }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .light))
                    labelMono(viewModel.isSearchingProviders ? "SEARCHING…" : "SEARCH PROVIDERS")
                    Spacer()
                    Text("→").font(.system(size: 13, design: .monospaced))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .buttonStyle(FliqPrimaryButtonStyle())
            .disabled(
                viewModel.providerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ||
                viewModel.isSearchingProviders
            )

            // Entry context
            if let entry = viewModel.selectedEntryContext {
                DarkCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("ENTRY_CONTEXT")
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

            // Extracted into separate structs to keep body complexity manageable
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
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .kerning(0.5)
                        if let cat = provider.category { DetailLine(label: "CATEGORY", value: cat) }
                        if let ph = provider.phone { DetailLine(label: "PHONE", value: ph) }
                        DetailLine(label: "RATING", value: scoreText(provider.ratingAverage))
                        DetailLine(label: "TOTAL TIPS", value: "\(provider.totalTipsReceived)")
                        Button(action: { Task { await viewModel.loadProvider(provider.id) } }) {
                            HStack {
                                labelMono(viewModel.isLoadingProvider ? "LOADING…" : "OPEN PROVIDER")
                                Spacer()
                                Text("→").font(.system(size: 13, design: .monospaced))
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
                    DarkSectionHeader(label: "SELECTED_PROVIDER", title: provider.displayName)
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
                    SectionLabel("TIP_AMOUNT")
                    HStack(spacing: 8) {
                        ForEach([50, 100, 200], id: \.self) { amount in
                            Button("₹\(amount)") { viewModel.usePresetAmount(amount) }
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
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
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.4))
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
                            labelMono(viewModel.isSubmittingTip ? "CREATING ORDER…" : "CREATE TIP ORDER")
                            Spacer()
                            Text("→").font(.system(size: 14, design: .monospaced))
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
                    DarkSectionHeader(label: "TIP_ORDER_CREATED", title: order.provider.name)
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
                            labelMono(viewModel.isRefreshingTipStatus ? "REFRESHING…" : "REFRESH STATUS")
                                .padding(.vertical, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(NothingGhostButtonStyle())
                        .disabled(viewModel.isRefreshingTipStatus)

                        if order.isMockOrder {
                            Button(action: { Task { await viewModel.completeMockPayment() } }) {
                                labelMono(viewModel.isCompletingMockPayment ? "COMPLETING…" : "MOCK PAYMENT")
                                    .padding(.vertical, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(FliqPrimaryButtonStyle())
                            .disabled(viewModel.isCompletingMockPayment)
                        } else {
                            Button(action: { viewModel.openCheckout() }) {
                                labelMono(viewModel.isVerifyingCheckout ? "VERIFYING…" :
                                          viewModel.isLaunchingCheckout ? "OPENING…" : "OPEN CHECKOUT")
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
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.38))
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
                        DarkSectionHeader(label: "PAYMENT_SUCCESS", title: "Tip impact")
                        Spacer()
                        if viewModel.tipImpact != nil {
                            Button(action: { Task { await viewModel.refreshTipImpact() } }) {
                                labelMono(viewModel.isLoadingTipImpact ? "REFRESHING…" : "REFRESH")
                            }
                            .buttonStyle(NothingGhostButtonStyle())
                            .disabled(viewModel.isLoadingTipImpact)
                        }
                    }

                    if viewModel.isLoadingTipImpact, viewModel.tipImpact == nil {
                        ProgressView().tint(Color.nothingRed).frame(maxWidth: .infinity)
                    } else if let impact = viewModel.tipImpact {
                        DetailLine(label: "WORKER", value: impact.workerName)
                        DetailLine(label: "AMOUNT", value: historyAmountPaiseText(impact.amountPaise))
                        if let intent = historyIntentText(impact.intent) {
                            DetailLine(label: "INTENT", value: intent)
                        }
                        Text(impact.message)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
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
                    DarkSectionHeader(label: "OFFLINE_QUEUE", title: "Pending tips")
                    Spacer()
                    Button(action: { Task { await viewModel.syncPendingTipDrafts() } }) {
                        labelMono(viewModel.isSyncingPendingTips ? "SYNCING…" : "SYNC NOW")
                    }
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.pendingTipDrafts.isEmpty || viewModel.isSyncingPendingTips)
                }

                if viewModel.pendingTipDrafts.isEmpty {
                    Text("Offline-created tips will queue here when the backend is unreachable.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.45))
                } else {
                    ForEach(viewModel.pendingTipDrafts) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(historyAmountPaiseText(draft.amountPaise)) → \(draft.providerName)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            if let cat = draft.providerCategory { DetailLine(label: "CATEGORY", value: cat) }
                            DetailLine(label: "SOURCE", value: draft.source.label)
                            DetailLine(label: "INTENT", value: draft.intent.label)
                            if let msg = draft.message { DetailLine(label: "MESSAGE", value: msg) }
                            DetailLine(label: "QUEUED", value: historyDateText(draft.createdAt) ?? draft.createdAt)

                            HStack(spacing: 8) {
                                Button(action: { Task { await viewModel.syncPendingTipDrafts() } }) {
                                    labelMono("RETRY SYNC").padding(.vertical, 11)
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(FliqPrimaryButtonStyle())
                                .disabled(viewModel.isSyncingPendingTips)

                                Button(action: { viewModel.discardPendingTipDraft(draft.id) }) {
                                    labelMono("DISCARD").padding(.vertical, 11)
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(NothingGhostButtonStyle())
                                .disabled(viewModel.isSyncingPendingTips)
                            }
                        }
                        .padding(.top, 10)

                        Rectangle()
                            .fill(.black.opacity(0.08))
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
                        labelMono(viewModel.isLoadingCustomerProfile ? "REFRESHING…" : "REFRESH")
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.isLoadingCustomerProfile || viewModel.isSavingCustomerProfile)

                    Button(action: { Task { await viewModel.saveCustomerProfile() } }) {
                        labelMono(viewModel.isSavingCustomerProfile ? "SAVING…" : "SAVE PROFILE")
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
                        labelMono(viewModel.isLoadingCustomerHistory ? "REFRESHING…" : "REFRESH")
                    }
                    .buttonStyle(NothingGhostButtonStyle())
                    .disabled(viewModel.isLoadingCustomerHistory)
                }

                if viewModel.isLoadingCustomerHistory && viewModel.customerTipHistory.isEmpty {
                    ProgressView().tint(Color.nothingRed).frame(maxWidth: .infinity)
                } else if viewModel.customerTipHistory.isEmpty {
                    Text("No tips yet. Authenticated tips will appear here.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.45))
                } else {
                    ForEach(viewModel.customerTipHistory) { tip in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(historyAmountText(tip)) → \(tip.providerName)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            if let cat = tip.providerCategory { DetailLine(label: "CATEGORY", value: cat) }
                            DetailLine(label: "STATUS", value: tip.status)
                            if let intent = historyIntentText(tip.intent) { DetailLine(label: "INTENT", value: intent) }
                            if let msg = tip.message { DetailLine(label: "MESSAGE", value: msg) }
                            if let date = historyDateText(tip.createdAt) { DetailLine(label: "CREATED", value: date) }
                        }
                        .padding(.top, 10)

                        Rectangle()
                            .fill(.black.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Shared UI Primitives

/// Monospaced label used inside button closures.
private func labelMono(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .kerning(1)
}

/// Two-line section header: small monospaced label + readable title.
private struct DarkSectionHeader: View {
    let label: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.38))
                .kerning(2)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

/// Tiny all-caps monospaced label for in-card sections.
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.black.opacity(0.38))
            .kerning(2)
    }
}

/// Thin horizontal rule on light backgrounds.
private struct DarkDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.09))
            .frame(height: 1)
    }
}

/// TextField styled for light backgrounds.
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
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(.black)
            .lineLimit(axis == .vertical ? 3...6 : 1...1)
            .padding(13)
            .background(Color.black.opacity(0.04))
            .overlay(Rectangle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
    }
}

/// Card container — thin dark border, near-zero fill.
private struct DarkCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().strokeBorder(.black.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Intent & Rating Buttons
// Extracted into separate structs to avoid SwiftUI type-check timeouts
// when mixing FliqPrimaryButtonStyle / NothingGhostButtonStyle in a ternary.

private struct IntentButton: View {
    let intent: TipIntentOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(isSelected ? "✓ \(intent.label.uppercased())" : "\(intent.label.uppercased()): \(intent.summary)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .kerning(0.5)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.nothingRed : Color.black.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.nothingRed.opacity(isSelected ? 0.06 : 0.0))
            .overlay(Rectangle().strokeBorder(
                isSelected ? Color.nothingRed.opacity(0.5) : Color.black.opacity(0.13),
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
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.nothingRed : Color.black.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.nothingRed.opacity(isSelected ? 0.06 : 0.0))
                .overlay(Rectangle().strokeBorder(
                    isSelected ? Color.nothingRed.opacity(0.5) : Color.black.opacity(0.13),
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
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.38))
                .kerning(1.5)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.85))
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
                .fill(isError ? Color.nothingRed : Color.black.opacity(0.28))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(isError ? "ERROR_" : "STATUS_")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isError ? Color.nothingRed : Color.black.opacity(0.4))
                    .kerning(1.5)
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isError ? Color.nothingRed.opacity(0.85) : .black.opacity(0.55))
                    .lineLimit(4)
            }

            Spacer()
        }
        .padding(14)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isError ? Color.nothingRed.opacity(0.28) : Color.black.opacity(0.1),
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
            DotGridBackground()

            if showSuccess {
                DemoSuccessView(amount: selectedAmount, onDismiss: { dismiss() })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header bar ─────────────────────────────────────
                        HStack {
                            DotMatrixText(
                                "DEMO",
                                font: .system(size: 22, weight: .black, design: .monospaced),
                                foreground: .black,
                                dotSpacing: 3.0,
                                dotSize: 1.9
                            )
                            Text("MODE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.nothingRed)
                                .kerning(2)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Color.nothingRed.opacity(0.55), lineWidth: 1)
                                )
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)

                        Text("No sign-up needed. Experience the full tipping flow.")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.5))
                            .padding(.bottom, 28)

                        // ── Worker profile ─────────────────────────────────
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(.black.opacity(0.2), lineWidth: 1)
                                    .frame(width: 60, height: 60)
                                DotMatrixText(
                                    "DW",
                                    font: .system(size: 18, weight: .black, design: .monospaced),
                                    foreground: .black,
                                    dotSpacing: 3.0,
                                    dotSize: 1.8
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("DEMO WORKER")
                                    .font(.system(size: 15, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .kerning(1.5)

                                HStack(spacing: 8) {
                                    Text("TRUST")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.38))
                                        .kerning(1)
                                    DotMatrixText(
                                        "\(demoTrust)",
                                        font: .system(size: 15, weight: .black, design: .monospaced),
                                        foreground: Color.nothingRed,
                                        dotSpacing: 2.9,
                                        dotSize: 1.7
                                    )
                                    Text("/ 100")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.4))
                                }

                                Text("Delivery · 4 years on Fliq")
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.bottom, 24)

                        Rectangle()
                            .fill(.black.opacity(0.08))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // ── Dream goal ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ACTIVE_DREAM")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.38))
                                .kerning(2)

                            Text(demoGoal)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.85))

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(.black.opacity(0.1))
                                        .frame(height: 3)
                                    Rectangle()
                                        .fill(Color.nothingRed)
                                        .frame(width: geo.size.width * progressFraction, height: 3)
                                }
                            }
                            .frame(height: 3)

                            HStack {
                                Text("\(demoProgress)% FUNDED")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.nothingRed)
                                    .kerning(1)
                                Spacer()
                                Text("₹2,100 / ₹5,000")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.38))
                            }
                        }
                        .padding(.bottom, 28)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
                                progressFraction = CGFloat(demoProgress) / 100.0
                            }
                        }

                        Rectangle()
                            .fill(.black.opacity(0.08))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // ── Tip amount selector ────────────────────────────
                        Text("TIP_AMOUNT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.38))
                            .kerning(2)
                            .padding(.bottom, 12)

                        HStack(spacing: 10) {
                            ForEach([50, 100, 200], id: \.self) { amount in
                                Button(action: { selectedAmount = amount }) {
                                    VStack(spacing: 4) {
                                        Text("₹\(amount)")
                                            .font(.system(size: 15, weight: .black, design: .monospaced))
                                        Text(amount == 50 ? "small" : amount == 100 ? "kind" : "generous")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .kerning(0.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(selectedAmount == amount ? Color.nothingRed : .black.opacity(0.5))
                                    .background(Color.nothingRed.opacity(selectedAmount == amount ? 0.05 : 0.0))
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(
                                                selectedAmount == amount
                                                    ? Color.nothingRed.opacity(0.7)
                                                    : Color.black.opacity(0.12),
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
                                Text("TIP ₹\(selectedAmount) WITH KINDNESS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .kerning(0.5)
                                Spacer()
                                Text("→")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(NothingFilledButtonStyle())
                        .padding(.bottom, 16)

                        Text("This is a demo — no real payment is made.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.35))
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

            // Check mark animation
            ZStack {
                Circle()
                    .fill(Color.nothingRed.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.nothingRed.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Color.nothingRed)
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

            DotMatrixText(
                "₹\(amount) SENT",
                font: .system(size: 28, weight: .black, design: .monospaced),
                foreground: Color.nothingRed,
                dotSpacing: 3.2,
                dotSize: 1.9
            )
            .padding(.bottom, 16)

            Text("Your kindness just moved Demo Worker closer to their dream.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            Text("Buy a bicycle for daily commute")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.bottom, 48)

            Button(action: onDismiss) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("BACK TO HOME")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .kerning(1)
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
