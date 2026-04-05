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
    @State private var showWhatsNew = false
    @ObservedObject private var pushCoordinator = NativePushCoordinator.shared

    private let roles: [RoleCard] = [
        RoleCard(
            role: .customer,
            title: "Tipper",
            subtitle: "Scan QR codes, tip with intent, and see your impact on someone's dream.",
            sfSymbol: "heart",
            accent: Color.dsAccent,
            actionLabel: "Enter as Tipper"
        ),
        RoleCard(
            role: .provider,
            title: "Worker",
            subtitle: "Receive tips, share your dream, and build portable trust on UPI.",
            sfSymbol: "sparkles",
            accent: Color.dsSuccess,
            actionLabel: "Enter as Worker"
        ),
        RoleCard(
            role: .business,
            title: "Business",
            subtitle: "Manage staff, track satisfaction scores, and export QR codes at scale.",
            sfSymbol: "building.2",
            accent: Color.dsAccentLight,
            actionLabel: "Enter as Business"
        )
    ]

    var body: some View {
        ZStack {
            LightBackground()

            if viewModel.isLoading && viewModel.stage != .home {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading…")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            } else if viewModel.stage == .home, let session = viewModel.session {
                homeContent(session: session)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        switch viewModel.stage {
                        case .rolePicker:
                            HeroSection(showDemo: $showDemo, showWhatsNew: $showWhatsNew)
                                .padding(.top, DS.Spacing.sm)
                            RoleSectionHeader()
                            ForEach(roles) { role in
                                RoleEntryCard(role: role) { viewModel.selectRole(role.role) }
                            }

                        case .credential:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "Sign In") { viewModel.backToRolePicker() }
                                AuthCard(
                                    role: role,
                                    credential: $viewModel.credential,
                                    onSubmit: { Task { await viewModel.sendCode() } }
                                )
                            }

                        case .otp:
                            if let selectedRole = viewModel.selectedRole,
                               let role = roles.first(where: { $0.role == selectedRole }) {
                                BackBar(title: "Verify") { viewModel.backToCredential() }
                                OTPCard(
                                    role: role,
                                    credential: viewModel.credential,
                                    code: $viewModel.code,
                                    onResend: { Task { await viewModel.resendCode() } },
                                    onVerify: { Task { await viewModel.verifyCode() } }
                                )
                            }

                        case .home:
                            EmptyView()
                        }

                        if let error = viewModel.errorMessage {
                            FliqErrorBanner(message: error)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xl)
                }
            }
        }
        .onOpenURL { url in
            Task { await viewModel.handleDeepLink(url: url) }
        }
        .onChange(of: pushCoordinator.pendingNotificationUrl) { url in
            guard let url else { return }
            pushCoordinator.pendingNotificationUrl = nil
            Task { await viewModel.handleDeepLink(url: url) }
        }
        .sheet(isPresented: $showDemo) {
            DemoTipView()
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
    }

    @ViewBuilder
    private func homeContent(session: AuthSession) -> some View {
        switch viewModel.selectedRole ?? .customer {
        case .customer:
            CustomerTabView(session: session, viewModel: viewModel)
                .task(id: session.user.id) {
                    await viewModel.loadCustomerHomeDataIfNeeded()
                }
        case .provider:
            ProviderHomeView(session: session) { viewModel.logout() }
        case .business:
            BusinessHomeView(session: session) { viewModel.logout() }
        }
    }
}

// MARK: - Customer Tab View

private struct CustomerTabView: View {
    let session: AuthSession
    @ObservedObject var viewModel: AppViewModel

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var displayName: String {
        let name = viewModel.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "" : name
    }

    var body: some View {
        TabView {
            // ── Tab 1: Tip ────────────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                        // Greeting header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? greeting : "\(greeting), \(displayName.components(separatedBy: " ").first ?? displayName)")
                                .font(DS.Typography.title)
                                .foregroundStyle(.white)
                            Text("Tip someone who made your day")
                                .font(DS.Typography.body)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.top, DS.Spacing.sm)

                        // Primary action — Scan QR
                        Button(action: { viewModel.openScanner() }) {
                            HStack(spacing: DS.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Scan QR to Tip")
                                        .font(DS.Typography.headline)
                                        .foregroundStyle(.white)
                                    Text("Point camera at worker's QR code")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(DS.Spacing.lg)
                            .background(Color.dsAccent)
                            .cornerRadius(DS.CornerRadius.card)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isScannerPresented || viewModel.isResolvingScannedCode)

                        // Search providers
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Find a provider")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.white)

                            HStack(spacing: DS.Spacing.sm) {
                                FliqTextField(
                                    placeholder: "Name or phone number",
                                    text: $viewModel.providerQuery
                                )
                                Button(action: { Task { await viewModel.searchProviders() } }) {
                                    Group {
                                        if viewModel.isSearchingProviders {
                                            ProgressView().tint(.white).controlSize(.small)
                                        } else {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                                    .foregroundStyle(.white)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                            .fill(viewModel.providerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? Color.dsAccent : Color.dsTertiary)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(
                                    viewModel.providerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ||
                                    viewModel.isSearchingProviders
                                )
                            }
                        }

                        // Provider results + tip flow
                        ProviderResultsSection(viewModel: viewModel)
                        ProviderTipFlowSection(viewModel: viewModel)
                        TipOrderSection(viewModel: viewModel)
                        CustomerTipSuccessSection(viewModel: viewModel)

                        // Recent activity preview (last 3)
                        if !viewModel.customerTipHistory.isEmpty && viewModel.selectedProvider == nil {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                HStack {
                                    Text("Recent tips")
                                        .font(DS.Typography.title2)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                ForEach(Array(viewModel.customerTipHistory.prefix(3))) { tip in
                                    TipHistoryRow(tip: tip)
                                }
                            }
                        }

                        // Error only
                        if let error = viewModel.errorMessage {
                            FliqErrorBanner(message: error)
                        }

                        Spacer(minLength: DS.Spacing.xxl)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
                }
                .navigationTitle("Fliq")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Tip", systemImage: "heart.fill") }
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

            // ── Tab 2: Activity ───────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                            // Offline queue — only shown if there are pending tips
                            if !viewModel.pendingTipDrafts.isEmpty {
                                PendingTipQueueSection(viewModel: viewModel)
                            }

                            // Tip history
                            CustomerHistorySection(viewModel: viewModel)

                            Spacer(minLength: DS.Spacing.xxl)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                }
                .navigationTitle("Activity")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Activity", systemImage: "clock.fill") }

            // ── Tab 3: Profile ────────────────────────────────────────────
            NavigationStack {
                ZStack(alignment: .top) {
                    LightBackground()
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            CustomerProfileCard(viewModel: viewModel)

                            Button(action: { viewModel.logout() }) {
                                Text("Sign Out")
                                    .font(DS.Typography.bodyMedium)
                                    .foregroundStyle(Color.dsError)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, DS.Spacing.sm)

                            Spacer(minLength: DS.Spacing.xxl)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Color.dsAccent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

// MARK: - Provider Results Section

private struct ProviderResultsSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if !viewModel.providerResults.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("\(viewModel.providerResults.count) result\(viewModel.providerResults.count == 1 ? "" : "s")")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.dsSecondary)

                ForEach(viewModel.providerResults) { provider in
                    Button(action: { Task { await viewModel.loadProvider(provider.id) } }) {
                        HStack(spacing: DS.Spacing.md) {
                            // Avatar placeholder
                            ZStack {
                                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                    .fill(Color.dsAccentTint)
                                    .frame(width: 44, height: 44)
                                Text(String(provider.name.prefix(2)).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.dsAccent)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(provider.name)
                                    .font(DS.Typography.bodyMedium)
                                    .foregroundStyle(Color.dsPrimary)
                                if let cat = provider.category {
                                    Text(cat.capitalized)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsSecondary)
                                }
                            }

                            Spacer()

                            if viewModel.isLoadingProvider {
                                ProgressView().tint(Color.dsAccent).controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dsTertiary)
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(Color.dsSurface)
                        .cornerRadius(DS.CornerRadius.card)
                        .shadow(color: Color.dsPrimary.opacity(0.05), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoadingProvider)
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
            FliqCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {

                    // Provider header
                    HStack(spacing: DS.Spacing.md) {
                        if let avatarUrl = provider.avatarUrl, let imageUrl = URL(string: avatarUrl) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.sm))
                                case .failure, .empty:
                                    providerAvatar(name: provider.displayName)
                                @unknown default:
                                    providerAvatar(name: provider.displayName)
                                }
                            }
                        } else {
                            providerAvatar(name: provider.displayName)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.displayName)
                                .font(DS.Typography.headline)
                                .foregroundStyle(Color.dsPrimary)
                            if let cat = provider.category {
                                Text(cat.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            if let rep = provider.reputation {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.dsWarning)
                                    Text(scoreText(rep.score))
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsSecondary)
                                }
                            }
                        }
                        Spacer()
                    }

                    // Dream progress
                    if let dream = provider.dream {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dsAccent)
                                Text("Dream: \(dream.title)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                                Spacer()
                                Text("\(dream.percentage)%")
                                    .font(DS.Typography.micro)
                                    .foregroundStyle(Color.dsAccent)
                                    .fontWeight(.semibold)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.dsBorder)
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.dsAccent)
                                        .frame(width: geo.size.width * (CGFloat(dream.percentage) / 100), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }

                    FliqDivider()

                    // Amount
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Tip amount")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)

                        HStack(spacing: DS.Spacing.sm) {
                            ForEach([50, 100, 200], id: \.self) { amount in
                                DSChoiceChip(
                                    label: "₹\(amount)",
                                    isSelected: viewModel.amountRupees == String(amount)
                                ) { viewModel.usePresetAmount(amount) }
                                .disabled(isCustomAmountLocked)
                            }
                        }

                        FliqTextField(
                            placeholder: "Custom amount (₹)",
                            text: amountBinding,
                            keyboardType: .numberPad
                        )
                        .disabled(isCustomAmountLocked)
                    }

                    FliqDivider()

                    // Intent
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Tip for")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                            ForEach(TipIntentOption.allCases) { intent in
                                DSChoiceChip(
                                    label: intent.label,
                                    isSelected: intent == viewModel.selectedIntent
                                ) { viewModel.selectedIntent = intent }
                            }
                        }
                    }

                    FliqDivider()

                    // Rating
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Rating")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)

                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: { viewModel.selectedRating = rating }) {
                                    Image(systemName: rating <= viewModel.selectedRating ? "star.fill" : "star")
                                        .font(.system(size: 22))
                                        .foregroundStyle(rating <= viewModel.selectedRating ? Color.dsWarning : Color.dsTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                    // Message
                    FliqTextField(
                        placeholder: "Add a message (optional)",
                        text: $viewModel.tipMessage,
                        axis: .vertical
                    )

                    // CTA
                    Button(action: { Task { await viewModel.createTip() } }) {
                        HStack {
                            if viewModel.isSubmittingTip {
                                ProgressView().tint(.white).controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(viewModel.isSubmittingTip ? "Creating order…" : "Send Tip")
                        }
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                .fill(Color.dsAccent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSubmittingTip)
                }
            }
        }
    }

    @ViewBuilder
    private func providerAvatar(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                .fill(Color.dsAccentTint)
                .frame(width: 52, height: 52)
            Text(String(name.prefix(2)).uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dsAccent)
        }
    }
}

// MARK: - Tip Order Section

private struct TipOrderSection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if let order = viewModel.createdTipOrder {
            FliqCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Order created")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.dsSecondary)
                            Text(order.provider.name)
                                .font(DS.Typography.headline)
                                .foregroundStyle(Color.dsPrimary)
                        }
                        Spacer()
                        Text("₹\(order.amount / 100)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.dsAccent)
                    }

                    if let tipStatus = viewModel.tipStatus {
                        FliqStatusBadge(status: tipStatus.status)
                    }

                    FliqDivider()

                    HStack(spacing: DS.Spacing.sm) {
                        Button(action: { Task { await viewModel.refreshTipStatus() } }) {
                            HStack {
                                if viewModel.isRefreshingTipStatus {
                                    ProgressView().tint(Color.dsAccent).controlSize(.small)
                                }
                                Text("Refresh")
                            }
                            .font(DS.Typography.bodyMedium)
                            .foregroundStyle(Color.dsAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                    .strokeBorder(Color.dsAccent, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRefreshingTipStatus)

                        if order.isMockOrder {
                            Button(action: { Task { await viewModel.completeMockPayment() } }) {
                                HStack {
                                    if viewModel.isCompletingMockPayment {
                                        ProgressView().tint(.white).controlSize(.small)
                                    }
                                    Text(viewModel.isCompletingMockPayment ? "Completing…" : "Complete Payment")
                                }
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                        .fill(Color.dsAccent)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isCompletingMockPayment)
                        } else {
                            Button(action: { viewModel.openCheckout() }) {
                                HStack {
                                    if viewModel.isVerifyingCheckout || viewModel.isLaunchingCheckout {
                                        ProgressView().tint(.white).controlSize(.small)
                                    }
                                    Text(viewModel.isVerifyingCheckout ? "Verifying…" :
                                         viewModel.isLaunchingCheckout ? "Opening…" : "Pay Now")
                                }
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                        .fill(Color.dsAccent)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLaunchingCheckout || viewModel.isVerifyingCheckout)
                        }
                    }
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
            FliqCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if viewModel.isLoadingTipImpact && viewModel.tipImpact == nil {
                        HStack {
                            ProgressView().tint(Color.dsAccent)
                            Text("Processing payment…")
                                .font(DS.Typography.body)
                                .foregroundStyle(Color.dsSecondary)
                        }
                    } else if let impact = viewModel.tipImpact {
                        // Success header
                        HStack(spacing: DS.Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(Color.dsSuccessTint)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.dsSuccess)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tip sent!")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.dsPrimary)
                                Text(historyAmountPaiseText(impact.amountPaise) + " to \(impact.workerName)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                            }
                        }

                        if !impact.message.isEmpty {
                            Text(impact.message)
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.dsPrimary)
                                .lineSpacing(4)
                        }

                        if let dream = impact.dream {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack {
                                    Text("Dream progress")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsSecondary)
                                    Spacer()
                                    Text("\(dream.previousProgress)% → \(dream.newProgress)%")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsAccent)
                                        .fontWeight(.semibold)
                                }
                                Text(dream.title)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.dsBorder)
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.dsAccent)
                                            .frame(width: geo.size.width * (CGFloat(dream.newProgress) / 100), height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }
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
        FliqCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(Color.dsWarning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Offline tips pending")
                                .font(DS.Typography.headline)
                                .foregroundStyle(Color.dsPrimary)
                            Text("\(viewModel.pendingTipDrafts.count) tip\(viewModel.pendingTipDrafts.count == 1 ? "" : "s") queued")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.dsSecondary)
                        }
                    }
                    Spacer()
                    Button(action: { Task { await viewModel.syncPendingTipDrafts() } }) {
                        Text(viewModel.isSyncingPendingTips ? "Syncing…" : "Sync")
                            .font(DS.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.dsAccent)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(Color.dsAccentTint)
                            .cornerRadius(DS.CornerRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSyncingPendingTips)
                }

                FliqDivider()

                ForEach(viewModel.pendingTipDrafts) { draft in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.providerName)
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.dsPrimary)
                            Text(historyAmountPaiseText(draft.amountPaise))
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.dsSecondary)
                        }
                        Spacer()
                        Button(action: { viewModel.discardPendingTipDraft(draft.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dsError)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSyncingPendingTips)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
    }
}

// MARK: - Customer Profile Card (read-only)

private struct CustomerProfileCard: View {
    @ObservedObject var viewModel: AppViewModel

    private var initials: String {
        let name = viewModel.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "?" }
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String((parts[0].first.map(String.init) ?? "") + (parts[1].first.map(String.init) ?? "")).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Avatar + name + role
            FliqCard {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(spacing: DS.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.dsAccent)
                                .frame(width: 80, height: 80)
                            Text(initials)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(spacing: 6) {
                            Text(viewModel.profileName.isEmpty ? "Fliq User" : viewModel.profileName)
                                .font(DS.Typography.title)
                                .foregroundStyle(Color.dsPrimary)
                            if !viewModel.profilePhone.isEmpty {
                                Text(viewModel.profilePhone)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            Text("Customer")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.dsAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .background(Color.dsAccentTint)
                                .cornerRadius(20)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if viewModel.isLoadingCustomerProfile {
                        HStack { Spacer(); ProgressView().tint(Color.dsAccent); Spacer() }
                    }
                }
            }

            // Settings section
            FliqCard {
                VStack(spacing: 0) {
                    ProfileSettingsRow(icon: "globe", label: "Language", value: viewModel.profileLanguage.isEmpty ? "English" : viewModel.profileLanguage.uppercased())
                    FliqDivider()
                    ProfileSettingsRow(icon: "bell", label: "Notifications", value: "On")
                    FliqDivider()
                    ProfileSettingsRow(icon: "questionmark.circle", label: "Help & Support", value: "")
                }
            }

            if let error = viewModel.errorMessage {
                FliqErrorBanner(message: error)
            }
        }
    }
}

private struct ProfileSettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.dsAccent)
                .frame(width: 22)
            Text(label)
                .font(DS.Typography.body)
                .foregroundStyle(Color.dsPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(Color.dsSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dsTertiary)
        }
        .padding(.vertical, DS.Spacing.sm + 2)
    }
}

// MARK: - Customer History Section

private struct CustomerHistorySection: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Tip history")
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { Task { await viewModel.refreshCustomerHistory() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewModel.isLoadingCustomerHistory ? .white.opacity(0.4) : .white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingCustomerHistory)
            }

            if viewModel.isLoadingCustomerHistory && viewModel.customerTipHistory.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.dsAccent)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.xl)
            } else if viewModel.customerTipHistory.isEmpty {
                FliqCard {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "heart")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.dsTertiary)
                        Text("No activity yet")
                            .font(DS.Typography.bodyMedium)
                            .foregroundStyle(Color.dsSecondary)
                        Text("Your tips will appear here once you start tipping")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
                }
            } else {
                ForEach(viewModel.customerTipHistory) { tip in
                    TipHistoryRow(tip: tip)
                }

                if viewModel.customerHistoryHasMore {
                    Button(action: { Task { await viewModel.loadMoreCustomerHistory() } }) {
                        HStack {
                            if viewModel.isLoadingCustomerHistory {
                                ProgressView().tint(Color.dsAccent).controlSize(.small)
                            }
                            Text(viewModel.isLoadingCustomerHistory ? "Loading…" : "Load more")
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.dsAccent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoadingCustomerHistory)
                }
            }
        }
    }
}

// MARK: - Tip History Row

struct TipHistoryRow: View {
    let tip: CustomerTipHistoryItem

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                    .fill(statusColor(tip.status).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon(tip.status))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(tip.status))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tip.providerName)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.dsPrimary)
                HStack(spacing: DS.Spacing.xs) {
                    if let cat = tip.providerCategory {
                        Text(cat.capitalized)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)
                        Text("·")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsTertiary)
                    }
                    if let date = historyDateText(tip.createdAt) {
                        Text(date)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.dsSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(historyAmountText(tip))
                    .font(DS.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsPrimary)
                FliqStatusBadge(status: tip.status)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func statusIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "PAID", "SETTLED": return "checkmark.circle.fill"
        case "INITIATED", "PENDING": return "clock.fill"
        case "FAILED": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PAID", "SETTLED", "SUCCESS": return .dsSuccess
        case "INITIATED", "PENDING": return .dsWarning
        case "FAILED": return .dsError
        default: return .dsSecondary
        }
    }
}

// MARK: - What's New View

private struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private let updates: [(String, String, String)] = [
        ("sparkles", "Native iOS app", "Full tipping flow, QR scanning, provider search, and payment via Razorpay — all native."),
        ("qrcode.viewfinder", "QR & Deep Links", "Scan provider QR codes or open fliq.co.in links directly in the app."),
        ("bell.badge", "Push Notifications", "Tap a notification to jump straight to the relevant tip or payout."),
        ("person.crop.square.fill", "Avatar Uploads", "Providers can upload a profile photo directly from their camera roll."),
        ("tablecells", "Tab Navigation", "Three-tab layout for Tippers, four-tab layout for Workers and Businesses."),
        ("clock.arrow.circlepath", "Tip History", "Scroll through your full tip history with load-more support."),
    ]

    var body: some View {
        ZStack {
            LightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What's New")
                                .font(DS.Typography.title)
                                .foregroundStyle(.white)
                            Text("Recent updates")
                                .font(DS.Typography.body)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(DS.Spacing.sm)
                                .background(.white.opacity(0.15))
                                .cornerRadius(DS.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, DS.Spacing.xl)

                    ForEach(updates, id: \.0) { icon, title, desc in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.2))
                                .cornerRadius(DS.CornerRadius.sm)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(DS.Typography.bodyMedium)
                                    .foregroundStyle(.white)
                                Text(desc)
                                    .font(DS.Typography.footnote)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.bottom, DS.Spacing.lg)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
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
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(DS.Typography.bodyMedium)
                }
                .foregroundStyle(Color.dsAccent)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.dsSecondary)

            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.dsAccent)
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    @Binding var showDemo: Bool
    @Binding var showWhatsNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand bar
            HStack {
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(Color.dsSuccess)
                        .frame(width: 6, height: 6)
                    Text("Human Value Infrastructure")
                        .font(DS.Typography.micro)
                        .foregroundStyle(Color.dsSecondary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Color.dsBorderLight)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.dsBorder, lineWidth: 1)
                )

                Spacer()

                Text("Fliq")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, DS.Spacing.xl)

            // Hero title
            VStack(alignment: .leading, spacing: 0) {
                Text("Every tip tells a")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                Text("story.")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, DS.Spacing.lg)

            Text("Fliq transforms tipping into meaningful appreciation. Workers define dreams, tippers see impact — all on UPI, zero friction.")
                .font(DS.Typography.body)
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(5)
                .padding(.bottom, DS.Spacing.xl)

            HStack(spacing: DS.Spacing.sm) {
                Button(action: { showDemo = true }) {
                    Text("Try Demo")
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(Color.dsAccent)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                .strokeBorder(Color.dsAccent, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: { showWhatsNew = true }) {
                    Text("What's New")
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(Color.dsSecondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(Color.dsBorderLight)
                        .cornerRadius(DS.CornerRadius.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, DS.Spacing.xl)

            // Mini preview card
            PhoneWidget()
        }
    }
}

// MARK: - Phone Widget

private struct PhoneWidget: View {
    @State private var progressFraction: CGFloat = 0.18
    @State private var selectedAmount = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Provider Profile")
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.dsSecondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.dsSuccess).frame(width: 6, height: 6)
                    Text("UPI Live")
                        .font(DS.Typography.micro)
                        .foregroundStyle(Color.dsSuccess)
                }
            }
            .padding(.bottom, DS.Spacing.md)

            FliqDivider().padding(.bottom, DS.Spacing.md)

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                        .fill(Color.dsAccentTint)
                        .frame(width: 48, height: 48)
                    Text("RK")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.dsAccent)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ravi Kumar")
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(Color.dsPrimary)
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Trust")
                            .font(DS.Typography.micro)
                            .foregroundStyle(Color.dsSecondary)
                        Text("82/100")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.dsAccent)
                    }
                }
                Spacer()
            }
            .padding(.bottom, DS.Spacing.lg)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Active Dream")
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.dsSecondary)
                Text("Daughter's School Books")
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.dsPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.dsBorder).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.dsAccent)
                            .frame(width: geo.size.width * progressFraction, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("65% funded").font(DS.Typography.micro).foregroundStyle(Color.dsAccent).fontWeight(.semibold)
                    Spacer()
                    Text("₹3,250 / ₹5,000").font(DS.Typography.micro).foregroundStyle(Color.dsSecondary)
                }
            }
            .padding(.bottom, DS.Spacing.lg)

            FliqDivider().padding(.bottom, DS.Spacing.md)

            HStack(spacing: DS.Spacing.sm) {
                ForEach([50, 100, 200], id: \.self) { amount in
                    Text("₹\(amount)")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedAmount == amount ? Color.dsAccent : Color.dsSecondary)
                        .background(selectedAmount == amount ? Color.dsAccentTint : Color.dsBorderLight)
                        .cornerRadius(DS.CornerRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                .strokeBorder(selectedAmount == amount ? Color.dsAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture { selectedAmount = amount }
                }
            }
            .padding(.bottom, DS.Spacing.sm)

            HStack {
                Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold))
                Text("Tip ₹100 with Kindness").font(DS.Typography.caption).fontWeight(.bold)
                Spacer()
                Text("→").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 13)
            .background(Color.dsAccent)
            .cornerRadius(DS.CornerRadius.sm)
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.08), radius: 12, x: 0, y: 4)
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
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Choose your role")
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
            Text("How would you like to use Fliq?")
                .font(DS.Typography.body)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

// MARK: - Role Entry Card

private struct RoleEntryCard: View {
    let role: RoleCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm, style: .continuous)
                        .fill(role.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(role.accent)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(role.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.dsPrimary)
                    Text(role.subtitle)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(Color.dsSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }
            .padding(DS.Spacing.md)

            Rectangle().fill(Color.dsBorder).frame(height: 1)

            Button(action: action) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 12, weight: .medium))
                    Text(role.actionLabel)
                        .font(DS.Typography.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(role.accent)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.md)
                .background(role.accent.opacity(0.06))
            }
            .buttonStyle(.plain)
        }
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Auth Card

private struct AuthCard: View {
    let role: RoleCard
    @Binding var credential: String
    let onSubmit: () -> Void
    @State private var selectedCountryCode = "+91"

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                        .fill(role.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(role.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.role.usesEmail ? "Enter email" : "Enter phone")
                        .font(DS.Typography.title2)
                        .foregroundStyle(Color.dsPrimary)
                    Text(role.role.usesEmail ? "We'll send you a one-time code" : "We'll send an OTP to your number")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.dsSecondary)
                }
            }

            if !role.role.usesEmail {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach([("🇮🇳 +91", "+91"), ("🇺🇸 +1", "+1")], id: \.1) { label, code in
                        Button {
                            let oldPrefix = selectedCountryCode
                            selectedCountryCode = code
                            let raw = credential.hasPrefix(oldPrefix) ? String(credential.dropFirst(oldPrefix.count)) : credential
                            credential = code + raw
                        } label: {
                            Text(label)
                                .font(DS.Typography.caption)
                                .fontWeight(selectedCountryCode == code ? .semibold : .regular)
                                .foregroundStyle(selectedCountryCode == code ? role.accent : Color.dsSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedCountryCode == code ? role.accent.opacity(0.1) : Color.dsBorderLight)
                                .cornerRadius(DS.CornerRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                                        .strokeBorder(selectedCountryCode == code ? role.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            FliqTextField(
                placeholder: role.role.usesEmail ? "name@company.com" : "\(selectedCountryCode)98765 43210",
                text: $credential,
                keyboardType: role.role.usesEmail ? .emailAddress : .phonePad
            )

            Button(action: onSubmit) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 13, weight: .medium))
                    Text("Send One-Time Code")
                        .font(DS.Typography.bodyMedium)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                        .fill(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.dsTertiary : role.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Check your \(role.role.usesEmail ? "email" : "messages")")
                    .font(DS.Typography.title2)
                    .foregroundStyle(Color.dsPrimary)
                Text("We sent a code to \(credential)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.dsSecondary)
            }

            TextField("_ _ _ _ _ _", text: $code)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.dsPrimary)
                .kerning(10)
                .padding(DS.Spacing.md)
                .background(Color.dsBorderLight)
                .cornerRadius(DS.CornerRadius.sm)
                .overlay(RoundedRectangle(cornerRadius: DS.CornerRadius.sm).strokeBorder(Color.dsBorder, lineWidth: 1))

            Button(action: onVerify) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13, weight: .medium))
                    Text("Verify & Sign In")
                        .font(DS.Typography.bodyMedium)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                        .fill(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 ? Color.dsTertiary : role.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)

            Button("Resend code", action: onResend)
                .font(DS.Typography.footnote)
                .foregroundStyle(Color.dsAccent)
                .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DS.CornerRadius.card)
        .shadow(color: Color.dsPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Shared Legacy Primitives (used by ProviderBusinessViews, AdvancedNativeViews, etc.)

private func labelMono(_ text: String) -> some View {
    Text(text)
        .font(DS.Typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(Color.dsAccent)
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        FliqDetailRow(label: label, value: value)
    }
}

struct StatusCard: View {
    var title: String = ""
    let message: String
    let isError: Bool

    var body: some View {
        if isError {
            FliqErrorBanner(message: message)
        } else if !message.isEmpty {
            FliqSuccessBanner(message: message)
        }
    }
}

struct RoleBadge: View {
    let accent: Color
    var body: some View { EmptyView() }
}

private struct DarkSectionHeader: View {
    let label: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(DS.Typography.micro)
                .foregroundStyle(Color.dsSecondary)
            Text(title)
                .font(DS.Typography.title2)
                .foregroundStyle(Color.dsPrimary)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(Color.dsSecondary)
    }
}

private struct DarkDivider: View {
    var body: some View { FliqDivider() }
}

private struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        FliqTextField(placeholder: placeholder, text: $text, keyboardType: keyboardType, axis: axis)
    }
}

private struct DarkCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        FliqCard { content }
    }
}

private struct IntentButton: View {
    let intent: TipIntentOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        DSChoiceChip(label: intent.label, isSelected: isSelected, action: onTap)
    }
}

private struct RatingButton: View {
    let rating: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isSelected ? "star.fill" : "star")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Color.dsWarning : Color.dsTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.dsWarning.opacity(0.1) : Color.dsBorderLight)
                .cornerRadius(DS.CornerRadius.sm)
        }
        .buttonStyle(.plain)
    }
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
            Color.dsBackground.ignoresSafeArea()

            if showSuccess {
                DemoSuccessView(amount: selectedAmount, onDismiss: { dismiss() })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Demo mode")
                                    .font(DS.Typography.title)
                                    .foregroundStyle(Color.dsPrimary)
                                Text("No sign-up needed · No real payment")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dsSecondary)
                                    .padding(DS.Spacing.sm)
                                    .background(Color.dsBorderLight)
                                    .cornerRadius(DS.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, DS.Spacing.xl)

                        // Worker profile card
                        FliqCard {
                            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                HStack(alignment: .top, spacing: DS.Spacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                                            .fill(Color.dsAccentTint)
                                            .frame(width: 56, height: 56)
                                        Text("DW")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundStyle(Color.dsAccent)
                                    }

                                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                        Text("Demo Worker")
                                            .font(DS.Typography.headline)
                                            .foregroundStyle(Color.dsPrimary)

                                        HStack(spacing: DS.Spacing.xs) {
                                            Text("Trust score")
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(Color.dsSecondary)
                                            Text("\(demoTrust)/100")
                                                .font(.system(size: 15, weight: .black))
                                                .foregroundStyle(Color.dsAccent)
                                        }

                                        Text("Delivery · 4 years on Fliq")
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(Color.dsSecondary)
                                    }
                                    Spacer()
                                }

                                FliqDivider()

                                // Dream goal
                                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                    Text("Active Dream")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(Color.dsSecondary)
                                    Text(demoGoal)
                                        .font(DS.Typography.bodyMedium)
                                        .foregroundStyle(Color.dsPrimary)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2).fill(Color.dsBorder).frame(height: 6)
                                            RoundedRectangle(cornerRadius: 2).fill(Color.dsAccent)
                                                .frame(width: geo.size.width * progressFraction, height: 6)
                                        }
                                    }
                                    .frame(height: 6)

                                    HStack {
                                        Text("\(demoProgress)% funded")
                                            .font(DS.Typography.micro)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.dsAccent)
                                        Spacer()
                                        Text("₹2,100 / ₹5,000")
                                            .font(DS.Typography.micro)
                                            .foregroundStyle(Color.dsSecondary)
                                    }
                                }
                                .onAppear {
                                    withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
                                        progressFraction = CGFloat(demoProgress) / 100.0
                                    }
                                }
                            }
                        }
                        .padding(.bottom, DS.Spacing.lg)

                        // Amount selector
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Tip amount")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.dsSecondary)

                            HStack(spacing: DS.Spacing.sm) {
                                ForEach([50, 100, 200], id: \.self) { amount in
                                    Button(action: { selectedAmount = amount }) {
                                        VStack(spacing: 4) {
                                            Text("₹\(amount)")
                                                .font(.system(size: 16, weight: .black))
                                            Text(amount == 50 ? "small" : amount == 100 ? "kind" : "generous")
                                                .font(DS.Typography.micro)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundStyle(selectedAmount == amount ? Color.dsAccent : Color.dsSecondary)
                                        .background(selectedAmount == amount ? Color.dsAccentTint : Color.dsBorderLight)
                                        .cornerRadius(DS.CornerRadius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                                                .strokeBorder(selectedAmount == amount ? Color.dsAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.bottom, DS.Spacing.lg)

                        Button(action: { withAnimation(.spring(duration: 0.4)) { showSuccess = true } }) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Tip ₹\(selectedAmount) with Kindness")
                                    .font(DS.Typography.bodyMedium)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, 16)
                            .background(Color.dsAccent)
                            .cornerRadius(DS.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
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
                Circle().fill(Color.dsSuccessTint).frame(width: 100, height: 100)
                Circle().stroke(Color.dsSuccess.opacity(0.3), lineWidth: 2).frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Color.dsSuccess)
            }
            .scaleEffect(checkScale)
            .opacity(checkOpacity)
            .padding(.bottom, DS.Spacing.xl)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.1)) {
                    checkScale = 1.0
                    checkOpacity = 1.0
                }
            }

            Text("₹\(amount) Sent")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color.dsAccent)
                .padding(.bottom, DS.Spacing.md)

            Text("Your kindness just moved Demo Worker closer to their dream.")
                .font(DS.Typography.body)
                .foregroundStyle(Color.dsSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)

            Button(action: onDismiss) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back to Home")
                        .font(DS.Typography.bodyMedium)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 15)
                .background(Color.dsAccent)
                .cornerRadius(DS.CornerRadius.sm)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Helpers

private func historyAmountText(_ tip: CustomerTipHistoryItem) -> String {
    String(format: "₹%.0f", Double(tip.amountPaise) / 100.0)
}

func historyAmountPaiseText(_ amountPaise: Int) -> String {
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

// MARK: - Legacy stub (CustomerHomeCard kept for compile compat)

private struct CustomerHomeCard: View {
    let session: AuthSession
    @ObservedObject var viewModel: AppViewModel
    var body: some View { EmptyView() }
}

// MARK: - Preview

#Preview {
    RootView()
}
