# Pass 1 — Plumbing — 2026-09-05

## What was created

- Xcode project `Marlin DVR TV.xcodeproj` at `~/Xcode/Marlin DVR TV`: one tvOS App target, SwiftUI, Swift, written to match Xcode 26.6's tvOS App template settings and the layout of the owner's Marlin Weather project (file-system-synchronized source group, shared scheme, generated Info.plist).
- Sources: `Marlin DVR TV/Marlin_DVR_TVApp.swift` (default `@main` App entry point) and `Marlin DVR TV/ContentView.swift` (a single `Text("Marlin DVR TV")`). Nothing else.
- Asset catalog `Marlin DVR TV/Assets.xcassets` with the template's empty `AccentColor` and the tvOS `App Icon & Top Shelf Image` brand-asset placeholders. No images.
- `.gitignore` for Xcode/Swift (xcuserdata, DerivedData, build, .DS_Store, *.xcuserstate, SwiftPM/CocoaPods/Carthage dirs, dSYMs).
- Notebook: `COLD-START.md`, `DECISIONS.md`, `reports/` (this file).
- Git repo initialised on `main`, repo-local identity `marlin1111ai <marlin1111ai@gmail.com>` (the value the other repos on this Mac use), remote `origin = git@github.com:marlin1111ai/marlin-dvr-tv.git` (the GitHub repo already existed, Public and empty).
- Read-only reference clone of the server repo at `~/Xcode/marlin-dvr-reference` with an uncommitted `README-REFERENCE.md`.

## Identifiers

- Product name: `Marlin DVR TV`
- Bundle id: `com.marlin1111.MarlinDVRTV`
- Development team: `C879JNVK7Z` (from Marlin Weather / Marlin Radio / HDHR Signal Strength)
- Deployment target: tvOS 18.0 (`TVOS_DEPLOYMENT_TARGET = 18.0`), SDK `appletvos` 26.5
- Xcode: 26.6 (17F113)

## Pushed SHA

- Pass 1 commit ("Pass 1: Xcode project, .gitignore, notebook"): recorded in the follow-up commit below, because a report cannot contain the hash of the commit that includes it.
- Pass 1 commit SHA: `1d6966629e15f4112b381571d902e158384d4b10` — pushed to `origin main` and verified (below).
- Follow-up commit ("Pass 1: record pushed SHA in report"): its SHA is the current `origin/main` HEAD; it changes only this file.

## Reference clone

- Path: `~/Xcode/marlin-dvr-reference`
- Remote: `git@github.com:marlin1111ai/marlin-dvr.git`, branch `main`
- HEAD: `d0280f76b1e2c17150b936cd14804963231945ef`
- Working tree: clean except the untracked, uncommitted `README-REFERENCE.md`. Never run, never pushed.

## Step 1 checks (evidence)

- `~/Xcode/Marlin DVR TV` existed and was empty (`ls -la` showed only `.` and `..`).
- `ssh -T git@github.com` → `Hi marlin1111ai! You've successfully authenticated, but GitHub does not provide shell access.`
- `xcodebuild -version` → `Xcode 26.6`, `Build version 17F113`.
- `xcodebuild -showsdks` lists `tvOS 26.5 -sdk appletvos26.5` and `Simulator - tvOS 26.5 -sdk appletvsimulator26.5`.
- `xcrun simctl list runtimes` → no runtimes installed (none for any platform). `xcrun simctl runtime list` → `Total Disk Images: 0`.
- Team and organization prefix read from `Marlin Weather.xcodeproj/project.pbxproj`: `DEVELOPMENT_TEAM = C879JNVK7Z`, `PRODUCT_BUNDLE_IDENTIFIER = com.marlin1111.MarlinWeather`.

## Step 2 build (evidence)

The line from the task fails on this Mac:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build
xcodebuild: error: Unable to find a destination matching the provided destination specifier:
  { platform:tvOS, arch:arm64e, id:00008110-…, name:Home Theater, error:tvOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components. }
  { platform:tvOS, arch:arm64, id:5fa6ccde…, name:Master Bedroom ATV, error:tvOS 26.5 is not installed. … }
  { platform:tvOS, id:dvtdevice-DVTiOSDevicePlaceholder-appletvos:placeholder, name:Any tvOS Device, error:tvOS 26.5 is not installed. … }
```

`xcodebuild -showdestinations` lists no eligible destinations (no tvOS simulator runtime installed; the two paired Apple TVs are ineligible for the same reason). Diagnosis: the tvOS platform component (simulator runtime + device support) has never been downloaded on this Mac; the SDK itself ships inside Xcode.app, which is why `-showsdks` lists it. Downloading the platform is an install and was not done.

Building the same target directly against the simulator SDK, which bypasses destination resolution, succeeds:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -target "Marlin DVR TV" -sdk appletvsimulator -configuration Debug build
…
CompileAssetCatalogVariant thinned … Marlin DVR TV.app … Assets.xcassets
ProcessInfoPlistFile … Marlin DVR TV.app/Info.plist
Ld … Objects-normal/x86_64/Binary/Marlin DVR TV normal x86_64
Ld … Objects-normal/arm64/Binary/Marlin DVR TV normal arm64
** BUILD SUCCEEDED **
```

(Output went to the session scratch directory, not the project tree. One warning: `ONLY_ACTIVE_ARCH=YES requested with multiple ARCHS and no active architecture could be computed` — a consequence of building without a destination.)

## Step 7 push verification

- `git status` before the commit and the `git fetch` / SHA comparison are recorded in the follow-up commit section below.
`git status` before the commit: `On branch main`, `No commits yet`, untracked: `.gitignore`, `COLD-START.md`, `DECISIONS.md`, `Marlin DVR TV.xcodeproj/`, `Marlin DVR TV/`, `reports/`.

```
git push -u origin main
 * [new branch]      main -> main
git fetch origin
local HEAD      : 1d6966629e15f4112b381571d902e158384d4b10
origin/main     : 1d6966629e15f4112b381571d902e158384d4b10
ls-remote main  : 1d6966629e15f4112b381571d902e158384d4b10
MATCH: pass 1 commit is on origin/main
```

The follow-up commit was pushed and verified the same way (fetch, compare `HEAD`, `origin/main`, and `ls-remote`).

## Open Questions

1. tvOS platform component is not installed on this Mac (no tvOS simulator runtime, no device support). Installing it (Xcode > Settings > Components, or `xcodebuild -downloadPlatform tvOS`) needs owner authorization. Until then the scheme/destination build line in COLD-START.md fails and only the `-target -sdk appletvsimulator` form builds; nothing can be run in a simulator or on the paired Apple TVs ("Home Theater", "Master Bedroom ATV").
2. Deployment target was set to tvOS 18.0, mirroring Marlin Weather's iOS 18.0 with the 26.5 SDK. Xcode's template default would have been 26.5 (latest). Which tvOS versions the owner's Apple TVs run is unknown.
3. Bundle id `com.marlin1111.MarlinDVRTV` follows the Marlin Weather pattern (`com.marlin1111.MarlinWeather`). Xcode's template would have produced `com.marlin1111.Marlin-DVR-TV`. The other projects use different prefixes (`com.marlinradio.app`, `com.marlin.HDHRSignalStrength`, `com.marlin.downloader`).
4. The target carries the four Swift settings Xcode 26's template adds (`SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, `STRING_CATALOG_GENERATE_SYMBOLS`). Marlin Weather's project file does not have them.
5. A shared scheme (`xcshareddata/xcschemes/Marlin DVR TV.xcscheme`) was written so `xcodebuild -scheme` works from a fresh clone; Xcode itself would have created a user scheme under gitignored `xcuserdata`. Marlin Weather also has a shared scheme.
6. The pushed SHA is recorded by a second, follow-up commit ("Pass 1: record pushed SHA in report") because the report cannot contain its own commit hash. The task asked for a single commit.

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV.xcodeproj/project.pbxproj` | 2 |
| `Marlin DVR TV.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | 2 |
| `Marlin DVR TV.xcodeproj/xcshareddata/xcschemes/Marlin DVR TV.xcscheme` | 2 |
| `Marlin DVR TV/Marlin_DVR_TVApp.swift` | 2 |
| `Marlin DVR TV/ContentView.swift` | 2 |
| `Marlin DVR TV/Assets.xcassets/Contents.json` | 2 |
| `Marlin DVR TV/Assets.xcassets/AccentColor.colorset/Contents.json` | 2 |
| `Marlin DVR TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Contents.json` | 2 |
| `… brandassets/App Icon.imagestack/Contents.json` + `Front|Middle|Back.imagestacklayer/Contents.json` + each layer's `Content.imageset/Contents.json` (7 files) | 2 |
| `… brandassets/App Icon - App Store.imagestack/` (same 7 files) | 2 |
| `… brandassets/Top Shelf Image.imageset/Contents.json` | 2 |
| `… brandassets/Top Shelf Image Wide.imageset/Contents.json` | 2 |
| `.gitignore` | 3 |
| `COLD-START.md` | 4 |
| `DECISIONS.md` | 4 |
| `reports/2026-09-05-pass1-plumbing.md` | 4 (updated again in step 7's follow-up commit) |
| `~/Xcode/marlin-dvr-reference/` (clone) | 5 |
| `~/Xcode/marlin-dvr-reference/README-REFERENCE.md` (uncommitted) | 5 |
| `.git/` (init on `main`, local `user.name`/`user.email`, remote `origin`) | 6 |
| Commit + push to `origin main` | 7 |

Outside the project tree: build products and logs in the session scratch directory only; xcodebuild wrote its automatic `.xcresult` error bundles under the system temp folder. Nothing under `~/Xcode` other than `Marlin DVR TV` and the new `marlin-dvr-reference` clone was written. No other project, the server, or any host on the network was touched.
