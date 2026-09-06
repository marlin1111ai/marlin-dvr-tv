//
//  CamerasScreen.swift
//  Marlin DVR TV
//
//  Cameras, frame 5e (dc:654-687): a grid of snapshot cards from GET /api/cameras
//  (cameras.go:280-289) and GET /api/cameras/{id}/snapshot.jpg (cached 45 s server-side,
//  cameras.go:191-201), refreshed every 45 s; "N of M online", the snapshot age, name,
//  codec, and the error line when offline. Selecting a card is the Player's (sweep 3).
//

import SwiftUI

@Observable
final class CamerasModel {
    static let refreshSeconds = 45

    private let api: APIClient
    private(set) var cameras: [Camera] = []
    private(set) var count = 0
    private(set) var online = 0
    private(set) var tick = 0
    private(set) var snapshotAt: Date?
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            let response = try await api.cameras()
            cameras = response.cameras.filter { !$0.hidden }
            count = response.count
            online = response.online
            tick += 1
            snapshotAt = Date()
            error = nil
        } catch {
            self.error = "\(error)"
            print("[cameras] cameras: \(error)")
        }
        loaded = true
    }

    /// A new query value each refresh so AsyncImage requests the snapshot again.
    func snapshotPath(for camera: Camera) -> String {
        "/api/cameras/\(camera.id)/snapshot.jpg?v=\(tick)"
    }
}

struct CamerasScreen: View {
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @State private var model: CamerasModel
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: CamerasModel(api: api))
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 34), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            ScreenHeader("Cameras", subtitle: model.loaded ? "\(model.online) of \(model.count) online" : nil) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(ageLine(at: context.date))
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral600)
                }
            }
            if let error = model.error, model.cameras.isEmpty {
                ErrorLine(text: error)
            } else if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Self.columns, spacing: 34) {
                    ForEach(model.cameras) { camera in
                        Button {
                            onPlay(.camera(camera))   // sweep 3 entry point
                        } label: {
                            CameraCard(camera: camera, snapshotPath: model.snapshotPath(for: camera), focused: focused == camera.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: camera.id)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .defaultFocus($focused, model.cameras.first?.id ?? "loading")
        .task {
            var first = true
            while !Task.isCancelled {
                await model.load()
                if first {
                    first = false
                    let id = model.cameras.first?.id
                    focusSoon { focused = id ?? "loading" }
                }
                try? await Task.sleep(for: .seconds(CamerasModel.refreshSeconds))
            }
        }
        .onExitCommand { onLeave() }
    }

    private func ageLine(at date: Date) -> String {
        guard let at = model.snapshotAt else { return "click for live view" }
        let age = max(0, Int(date.timeIntervalSince(at)))
        return "Snapshot age \(age) s · click for live view"
    }
}

/// One camera card (dc:671-683).
struct CameraCard: View {
    let camera: Camera
    let snapshotPath: String
    let focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ServerImage(path: snapshotPath) {
                    ZStack {
                        LinearGradient(colors: [Nocturne.neutral800, Nocturne.neutral900], startPoint: .top, endPoint: .bottom)
                        Text(camera.online ? "snapshot.jpg" : "no snapshot")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral600)
                    }
                }
                .frame(height: 330)
                .clipped()
                Text(camera.online ? "Online" : "Offline")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral200)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Nocturne.bg.opacity(0.72), in: Capsule())
                    .padding(.top, 18)
                    .padding(.leading, 20)
            }
            HStack(spacing: 18) {
                Text(camera.name)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                Text(camera.codec.isEmpty ? "codec unknown" : camera.codec.uppercased())
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                Spacer(minLength: 0)
                if !camera.online, !camera.lastError.isEmpty {
                    Text("✕ \(camera.lastError) · checked \(camera.lastCheck)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral200)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}
