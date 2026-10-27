//
//  NotifyBanner.swift
//  Marlin DVR TV
//
//  Pass 139 (owner, 2026-10-26): `marlindvr://notify?text=…` — the Channels app's notify banner (REA report §2.4,
//  §2.6: `/api/notify`, "a notification banner" over the player) — and the wording of every deep link that
//  cannot be followed (owner's C-a). One line across the top for five seconds, over whatever is on screen, the
//  Player included: it is drawn in a window of its own above the Player's full-screen cover, which anything in
//  `ContentView`'s ZStack would sit under. The window takes no interaction and holds nothing focusable, so the
//  remote and playback are untouched. A second notify while one shows replaces the text and restarts the five
//  seconds — latest wins (owner's E-a).
//

import SwiftUI
import Observation

@Observable @MainActor
final class NotifyBanner {
    static let duration: Duration = .seconds(5)

    private(set) var text: String?
    private var hide: Task<Void, Never>?

    func show(_ text: String) {
        print("[banner] \(text)")
        hide?.cancel()
        withAnimation(.easeOut(duration: 0.25)) { self.text = text }
        hide = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) { self?.text = nil }
        }
    }
}

struct NotifyBannerView: View {
    let banner: NotifyBanner

    var body: some View {
        VStack(spacing: 0) {
            if let text = banner.text {
                Text(text)
                    .font(.nocturne(Nocturne.TextSize.body, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
                    .frame(maxWidth: 1200)
                    .background(Nocturne.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Nocturne.Radius.lg).strokeBorder(Nocturne.divider, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.5), radius: 24, y: 12)
                    .padding(.top, Nocturne.Layout.marginVertical)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("notifyBanner")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

/// Installs the banner's window over the scene the first time this probe lands in a window — hosted in
/// `ContentView`'s background, the way `RemoteHoldDetector` is.
struct NotifyBannerWindow: UIViewRepresentable {
    let banner: NotifyBanner

    func makeUIView(context: Context) -> UIView { BannerProbeView(banner: banner) }
    func updateUIView(_ view: UIView, context: Context) {}
}

final class BannerProbeView: UIView {
    private let banner: NotifyBanner
    private var bannerWindow: UIWindow?

    init(banner: NotifyBanner) {
        self.banner = banner
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard bannerWindow == nil, let scene = window?.windowScene else { return }
        let overlay = UIWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        let host = UIHostingController(rootView: NotifyBannerView(banner: banner))
        host.view.backgroundColor = .clear
        overlay.rootViewController = host
        overlay.isHidden = false
        bannerWindow = overlay
        print("[banner] window installed over the scene")
    }
}
