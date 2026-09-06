# DECISIONS — Marlin DVR TV

## 2026-09-05

- Name: Marlin DVR TV.
- Repo: `marlin1111ai/marlin-dvr-tv`, Public, SSH remote (`git@github.com:marlin1111ai/marlin-dvr-tv.git`).
- Folder: `~/Xcode/Marlin DVR TV`.
- Platform: tvOS + SwiftUI, built in Xcode on the Mac.
- The server repo (`marlin1111ai/marlin-dvr`) is read-only reference via a local clone at `~/Xcode/marlin-dvr-reference` and is never edited from this project.
- Server changes, if ever needed, are raised as decisions for the marlin-dvr project.
- Rules (the same as marlin-dvr): recon before build; scope lock; no installs without owner authorization; separate push gate for code the owner tests; nothing force-pushed ever; no secrets in the repo, logs, or reports.
- Deployment target stays tvOS 18.0. Both Apple TVs run tvOS 26.6 (owner, 2026-09-05).
- Playback: the app plays video via HLS output from the Marlin DVR server (contract: HLS-CLIENT-API.md in marlin-dvr, server 1.1.0). Raised in the marlin-dvr project; built there in Passes 14–19.
