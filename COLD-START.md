# COLD-START — Marlin DVR TV

## What the app is

Marlin DVR TV is a tvOS app (SwiftUI) that will be a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . Pass 1 (2026-09-05) created the empty Xcode project and the plumbing only. No app features are written.

## Where things live

- This folder: `~/Xcode/Marlin DVR TV` — the Xcode project, the notebook (this file, DECISIONS.md, reports/), and the git repo. The only writable tree.
- Repo: `git@github.com:marlin1111ai/marlin-dvr-tv.git` (branch `main`).
- Server reference clone: `~/Xcode/marlin-dvr-reference` — a read-only clone of marlin-dvr. Never edited, never pushed, never run from.
- Server URL: http://192.168.1.250:8090/ (Marlin DVR on Unraid). Not touched by this project's tooling.
- Approved design: `design/` — the Claude Design export (`Marlin DVR TV.dc.html`, Nocturne design system, `ATV-DVR.zip`). Read-only; never edited. The screens are built to it (DECISIONS.md, 2026-09-05 (design)).

## The rules

- Recon before build.
- Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
- No installs without owner authorization.
- Separate push gate for code the owner tests.
- Nothing force-pushed, ever.
- No secrets in the repo, logs, or reports.
- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.

## How to build

- Open `Marlin DVR TV.xcodeproj` in Xcode and press ⌘B.
- Or from the command line:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build
```

  The tvOS 26.5 platform component (simulator runtime and device support) is installed on this Mac (confirmed in Pass 3, 2026-09-05); the scheme/destination line above works, and so does this target/SDK form:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -target "Marlin DVR TV" -sdk appletvsimulator -configuration Debug build
```

## What is built

The empty project — Pass 1 was plumbing. One app entry point (`Marlin_DVR_TVApp.swift`) and one `ContentView` showing the app name.

Pass 2 (server recon, `reports/2026-09-05-pass2-server-recon.md`) and Pass 3 (HLS client recon against `HLS-CLIENT-API.md`, `reports/2026-09-05-pass3-hls-client-recon.md`) are done; both were read-only and wrote reports only.

Pass 4 (`reports/2026-09-05-pass4-design-and-build-recon.md`) put the approved design into `design/`, recorded the design decisions, and mapped every in-scope screen to the server API and into build sweeps.

Pass 5 (sweep 1, `reports/2026-09-05-pass5-sweep1-foundation.md`, pushed after the owner's Home Theater test): the foundation — ATS exception, API client, models, DRM filter, image loader, client register/ping — plus the rail and Home.

Pass 6 (sweep 2, `reports/2026-09-05-pass6-sweep2-screens.md`, pushed after the owner's Home Theater test): the read-only screens — On Now, Guide with the airing sheet, On Later, Recordings with show detail, Cameras.

Pass 7 (sweep 3, `reports/2026-09-06-pass7-sweep3-player.md`, accepted by the owner on Home Theater and pushed): the Player — HLS sessions per `HLS-CLIENT-API.md` (server 1.2.1), AVPlayerViewController with the overlays of frames 6a–6h, recordings with seek-by-new-session, the per-Apple-TV resume store and watched-on-end, live channels with the server's time-shift buffer, cameras, and the entry points from On Now, the Guide, the airing sheet, show detail and Cameras.

Pass 8 (sweep 4, `reports/2026-09-06-pass8-sweep4-writes.md`, tested by the owner on Home Theater; its fixes are Pass 9): the writes — "Record this airing" (`POST /api/record`) and "Record the series" (`POST /api/passes`) on the airing sheet with the ● SCHEDULED / ◆ SERIES PASS marks on the Guide; the show-detail click-and-hold menu (Keep, Favorite, Mark unwatched, Delete → `PUT /api/library/recordings/{id}`, a trashed episode leaving the list); "Hide this channel" (`PUT /api/sources/{id}/lineup/{guid}`); and "Stop the recording and watch" on a tuner-busy 502 (`POST /api/schedule/jobs/{id}/stop`, then the live session). Two defects shipped in sweeps 2–3 were found and fixed there: `.onLongPressGesture` never fires on a tvOS Button (click-and-hold now goes through `HoldButton`), and the episode list could not be reached with the remote (focus sections).

Pass 9 (sweep 4 fixes, `reports/2026-09-06-pass9-sweep4-fixes.md`, committed locally, push gated on the owner's Home Theater test): the seven fixes from that test — click-and-hold rebuilt on UIKit's press pipeline and **proven on the physical Apple TV** by an XCUITest that presses the real remote (a new `Marlin DVR TVUITests` target, four tests including a negative control); the airing sheet's buttons made to fit; "Watch live" only while the programme is on; "Edit series pass" instead of "Record the series" when the show already has one, with no raw 409 ever shown; a new Edit series pass screen (record mode, padding, keep rule, delete with a confirm); the episode menu cut to Keep and Delete; and click-and-hold on a channel cell in the Guide to favourite it.

Pass 10 (`reports/2026-09-06-pass10-favorites-and-manage.md`, committed locally, push gated on the owner's Home Theater test): the Favorites screen — the rail's Favorites entry is live and lists the server's favourite channels with what is on now, clicking one plays it live — and the **Manage DVR** area, reached from a new row at the top of Recordings: the storage line from `GET /api/system`, Scheduled Recordings (the schedule grouped, with a detail view offering Cancel recording and Manage pass), Your Passes (the pass editor, which gains Pause/Resume), and Trash (Restore per row, Empty Trash behind two clicks). Counts on every row come from the server. Neither screen is in the approved design; both are built to the app's look.

## What is NOT built

The future screens Weather, Radio, Settings. Of the writes, these are deliberately still inert or absent: show detail's "Series pass" button and the Player's 6e "Delete this recording" (Pass 8 Open Question 1), and any click behaviour on the Guide's channel cell — the hold favourites it, a click does nothing (Pass 9 Open Question 1). Cancelling a booking, which Pass 8 lacked, now lives in Manage DVR → Scheduled Recordings. Still missing there: any way to un-skip a cancelled pass airing, and any auto-refresh (Pass 10 Open Questions 2 and 4).

## Open questions

See the Open Questions sections of `reports/2026-09-05-pass2-server-recon.md` (server recon) and `reports/2026-09-05-pass3-hls-client-recon.md` (HLS client recon). Environment questions from Pass 1 are listed in `reports/2026-09-05-pass1-plumbing.md`.

## Next step

The owner tests Passes 9 and 10 on Home Theater. From Pass 9, the first check is click-and-hold with the Siri Remote in hand — on a programme airing now, on a channel cell in the Guide's left column, and on an episode row; the mechanism is proven on that device by an automated remote press, but how it feels is not settled (Pass 9 Open Questions 2 and 3). From Pass 10: Favorites in the rail, and Recordings → Manage DVR. Then the acceptance-and-push pass, which pushes Passes 8, 9 and 10 together, and the Open Questions of the three reports.

To run the on-device hold tests again:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/RemoteHoldUITests"
```

The Manage DVR UI test (`ManageDVRUITests`) drives the Simulator and needs a scheduled
recording and a series pass to exist; it is a Pass 10 evidence harness, not a standing test.
