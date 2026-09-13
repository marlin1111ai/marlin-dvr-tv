# Pass 88 — the pushed head installed on the bedroom Apple TV

**Date:** 2026-09-13

**No app-target code changed.** This pass writes `DECISIONS.md`, `COLD-START.md`, this report and
one screenshot, in one commit. `design/` and `~/Xcode/marlin-dvr-reference` were not opened, and no
write was made to the server. Home Theater was not touched.

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass87**, so this is
**Pass 88**.

**The headline.** The bedroom Apple TV now runs the same build as Home Theater — **`168d8a7`**,
carrying the channel logos through Passes 86 and 87 — installed and proven on the device itself, not
assumed from the installer's success message. One thing surfaced that was not asked for and is
disclosed rather than acted on: **a non-fatal CPU-usage diagnostic during the on-device run**, on this
older hardware only.

**Redaction.** Apple TV UDIDs from `devicectl` output are written as `<udid>`. The diagnostic log's
binary-load UUIDs and its per-install app-container UUID are not the device's UDID — they are
regenerated on every build and every install — but are still shown as `<uuid>` here, for the same
reason CLAUDE.md gives for redacting identifiers on principle.

---

## 1. Step 1 — the gate, before anything was touched

```
$ git fetch origin
$ git status --porcelain
?? icon-source/
$ git rev-parse main origin/main
168d8a7c0897c4df43d084b716e1db7c9e31d890
168d8a7c0897c4df43d084b716e1db7c9e31d890
$ git ls-remote origin main
168d8a7c0897c4df43d084b716e1db7c9e31d890	refs/heads/main
```

**`main`, `origin/main` and the live remote all read `168d8a7`, and the tree carries only the
standing `?? icon-source/`.** The stop condition did not arise.

## 2. Step 2 — build and install, Pass 54's method

```
$ xcrun devicectl list devices
Name                 Hostname                              Identifier     State                Model
------------------   -----------------------------------   ------------   ------------------   ------------------------------------------
Home Theater         Home-Theater.coredevice.local         <udid>         available (paired)   Apple TV 4K (3rd generation) (AppleTV14,1)
Marlin iPhone        Marlin-iPhone.coredevice.local        <udid>         available (paired)   iPhone 17 Pro Max (iPhone18,2)
Master Bedroom ATV   Master-Bedroom-ATV.coredevice.local   <udid>         available (paired)   Apple TV 4K (AppleTV6,2)
```

**Three devices reachable; `Master Bedroom ATV` names itself**, the same name, state and model
`COLD-START.md` and Pass 54 record.

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Master Bedroom ATV' -allowProvisioningUpdates \
    -derivedDataPath build/p88 build
...
Signing Identity:     "Apple Development: wayne Coburn (K876F53J4H)"
Provisioning Profile: "tvOS Team Provisioning Profile: com.marlin1111.MarlinDVRTV"
** BUILD SUCCEEDED **

$ xcrun devicectl device install app --device "Master Bedroom ATV" \
    "build/p88/Build/Products/Debug-appletvos/Marlin DVR TV.app"
13:45:57  Acquired tunnel connection to device.
13:45:57  Enabling developer disk image services.
13:45:57  Acquired usage assertion.
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
• installationURL: file:///private/var/containers/Bundle/Application/<udid>/Marlin%20DVR%20TV.app/
• launchServicesIdentifier: unknown
• databaseUUID: <udid>
• databaseSequenceNumber: 432
```

**Both commands verbatim, against the same device Pass 54 named.** No other route was tried.

## 3. Step 3 — launched, the Guide opened, and proven on the device

### 3.1 What the television itself reports about the installed app

```
$ xcrun devicectl device info apps --device "Master Bedroom ATV" --bundle-id com.marlin1111.MarlinDVRTV
Apps installed:
Name            Bundle Identifier            Version   Bundle Version
-------------   --------------------------   -------   --------------
Marlin DVR TV   com.marlin1111.MarlinDVRTV   1.0       1
```

**Asked of the device, not taken from the installer's own report** — the same rule Pass 83 §5.3
followed.

### 3.2 The launch, the Guide, and the screenshot

The app was launched once directly (`xcrun devicectl device process launch --terminate-existing
com.marlin1111.MarlinDVRTV`), which confirmed the binary starts. To open the Guide and capture the
screenshot on the physical remote, the existing `GuideChannelLogosUITests` (Pass 86) was run against
this device **unmodified** — the same file, the same test, only the destination changed:

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Master Bedroom ATV' -allowProvisioningUpdates \
    -derivedDataPath build/p88 test -only-testing:"Marlin DVR TVUITests/GuideChannelLogosUITests"
```

**This is the same route Pass 83 took for its own bedroom screenshot** — no UI-test file was touched,
"the device's own remote" (`XCUIRemote.shared`) drove it, and `git diff` over the test target is
empty. It is not a new step; it is how the pass's one screenshot was produced.

```
Test Case '-[Marlin_DVR_TVUITests.GuideChannelLogosUITests testTheGuideDrawsLogosOnTheirBackingAndTheInitialsTileWithoutOne]' started.
[pass86] OPEN collections=Local focus=["2026 U.S. Open Tennis: Men's Championship Preshow"]
[pass86] SWITCHED to All Channels from Local; now All Channels
[pass86] LOGO[13.1] drawn after ~0 s: "WJZ-TV, 13.1" frame=(246.0, 520.5, 174.0, 62.0)
[pass86] LOGO[45.1] drawn after ~0 s: "WBFF45, 45.1" frame=(246.0, 614.5, 180.0, 62.0)
[pass86] FOCUS[86a] on target after 5 press(es): "WBFF45, 45.1" frame=(236.0, 604.5, 300.0, 82.0)
[pass86] 86a 13.1="WJZ-TV, 13.1" ... 45.1="WBFF45, 45.1" ... focus=["WBFF45, 45.1"]
[pass86] FOCUS[86b] on target after 6 press(es): "FOX, 9000" frame=(236.0, 658.5, 300.0, 82.0)
[pass86] LOGO[FOX 9000] drawn after ~0 s: "FOX, 9000" frame=(236.0, 658.5, 300.0, 82.0)
[pass86] LOGO[CBS 9000] drawn after ~0 s: "CBS, 9000" frame=(246.0, 762.5, 136.5, 62.0)
[pass86] 86b FOX="FOX, 9000" ... CBS="CBS, 9000" ... focus=["FOX, 9000"]
[pass86] FOCUS[86c] on target after 56 press(es): "AS, AS-INFOMERCIALS, 9023" frame=(236.0, 658.5, 300.0, 82.0)
[pass86] 86c 9023="AS, AS-INFOMERCIALS, 9023" ... focus=["AS, AS-INFOMERCIALS, 9023"]
[pass86] READ 50000 NFL Network: logo — "NFL Network, 50000" frame=(246.0, 3300.5, 227.5, 62.0)
[pass86] READ 50001 Golf Channel: logo — "Golf Channel, 50001" frame=(246.0, 3394.5, 226.0, 62.0)
[pass86] READ 50002 Science Channel: initials tile — "SC, Science Channel, 50002" frame=(246.0, 3488.5, 251.5, 62.0)
[pass86] RESTORED collections=Local
Test Case '-[…testTheGuideDrawsLogosOnTheirBackingAndTheInitialsTileWithoutOne]' passed (671.080 seconds).
** TEST SUCCEEDED **
```

**TEST SUCCEEDED, 671.080 s.** The device's own saved collection was **"Local"**, not "All Channels"
as Home Theater's was — this Apple TV's `UserDefaults` is its own, per the standing rule — and the
harness's existing restore step put it back before ending, exactly as it does on Home Theater.

### 3.3 The screenshot

`reports/assets/pass88/88a-logos-on-the-bedroom-apple-tv.jpg`, 1920 × 1080, exported from the result
bundle with `xcrun xcresulttool export attachments` and converted from the device's native
3840 × 2160 with `sips -Z 1920 -s format jpeg`.

It shows the Guide on All Channels, 1:30–3:30 PM, WBFF45 45.1 focused. **Channel logos are drawn on
their light backing**: WMAR-HD's black "abc" disc, WGAL-TV's and WBAL-DT's NBC peacock, WJZ-TV's CBS
eye, WBFF45's FOX wordmark, and the CWWNUV rows' orange logos — the same picture Pass 86's `86a`
photographed on Home Theater.

### 3.4 A CPU-usage diagnostic, found in the result bundle and read rather than ignored

The exported attachments included a third file beside the two screenshots: a `.ips` diagnostic
report, timestamped inside the run. **It is not a crash** — read in full before writing anything
about it:

```
"app_name":"Marlin DVR TV", "bug_type":"202", "bundleID":"com.marlin1111.MarlinDVRTV",
"duration_ms":"105487", "os_version":"Apple TVOS 26.6 (23L773)"

Date/Time:        2026-09-13 13:49:10.503 -0400
End time:         2026-09-13 13:50:55.990 -0400
Data Source:      Microstackshots
Command:          Marlin DVR TV
Identifier:       com.marlin1111.MarlinDVRTV
Version:          1.0 (1)
PID:              743

Event:            cpu usage
Action taken:     none
CPU:              90 seconds cpu time over 105 seconds (85% cpu average), exceeding limit of 50% cpu over 180 seconds
CPU limit:        90s
Limit duration:   180s
Hardware model:   AppleTV6,2

Heaviest stack for the target process:
  11  ??? (dyld + 82408)
  ...
  11  ??? (SwiftUI + 4414408)
  11  ??? (SwiftUI + 6477972)
  ...
  7   ??? (AXRuntime + 12812)
  7   ??? (AXRuntime + 13380)
  7   ??? (UIAccessibility + 20484)
  ...
```

- **`bug_type: "202"` is a system CPU-usage watchdog, not an exception or a signal.** There is no
  crashed thread, no `EXC_*` type and no fault address anywhere in the 283-line file — every field
  that would mark an actual crash is absent.
- **`Action taken: none`.** The process was not killed. The test's own transcript above is unbroken
  across the window (13:49:10–13:50:55) — no relaunch, no gap in the log — which is consistent with
  the process surviving.
- **The entire sampled stack is `SwiftUI` → `UIAccessibility` → `AXRuntime`**, on the app's main
  thread, "Frontmost App … Effective Thread QoS User Interactive." No frame is in this app's own
  code. The `Binary Images` list confirms the app binary
  (`com.marlin1111.MarlinDVRTV 1.0 (1) <uuid>`) was loaded, but nothing in the sampled stack is
  inside it.
- **What this does and does not establish.** The window overlaps the run's collection-switch and the
  56-press walk to channel 9023 — both drive repeated accessibility-tree queries against the Guide's
  fully realised grid, the same shape of traffic Passes 32, 33 and 72 measured as expensive on this
  app's other screens. **That reading is plausible, not proven**: the diagnostic carries no
  correlation to the harness's own print lines, and no earlier pass measured this specific harness
  against `AppleTV6,2`.
- **Nothing was changed because of it.** This pass's scope lock forbids app-target and test-target
  edits, and finding this was not a numbered step. It is disclosed because CLAUDE.md requires
  stopping and reporting when something blocks, not because the run failed — it did not.
- **The pace difference is measured, not assumed.** The identical, unmodified harness took **238.705 s
  on Home Theater (`AppleTV14,1`, Pass 86)** and **671.080 s on this device (`AppleTV6,2`)** — 2.8×.

---

## 4. Step 4 — the notebook

- **`DECISIONS.md`**: one entry, 2026-09-13 (Pass 88), recording the bedroom install from `070c9a5`
  to `168d8a7` by Pass 54's method, the device's own app listing, the Guide-logos run and its
  screenshot, and the CPU-usage diagnostic as disclosed-not-acted-on evidence.
- **`COLD-START.md`**: a new head paragraph under "Next step" — nothing unpushed as of Pass 88, both
  Apple TVs on `168d8a7`, this pass's own SHA not written (DECISIONS.md, 2026-09-11 (Pass 68)). The
  Pass 87 paragraph is kept below it as history.

## 5. Step 5 — commit, push, verify

One commit carries this report, the one screenshot and the two notebook files. It is pushed as a
fast-forward from `168d8a7`. The verification — a fresh `git fetch` followed by `git rev-parse main`,
`git rev-parse origin/main` and `git ls-remote origin main` all matching — runs after the push, so its
output and this pass's own SHA are in the pass response, not here (DECISIONS.md, 2026-09-11
(Pass 68)).

---

## 6. Files touched, mapped to steps

| Path | Change | Step |
|---|---|---|
| `DECISIONS.md` | one entry appended | 4 |
| `COLD-START.md` | one head paragraph under "Next step" | 4 |
| `reports/assets/pass88/88a-logos-on-the-bedroom-apple-tv.jpg` | created | 3 |
| `reports/2026-09-13-pass88-bedroom-install.md` | created | 5 |

**Not touched:** every app-target file, every test-target file, the Xcode project, `design/`,
`~/Xcode/marlin-dvr-reference`, `icon-source/`, Home Theater, and every earlier report.

**Not in the repo — git-ignored, left on this Mac:** `build/p88/`, the bedroom device build and its
result bundle, including the diagnostic `.ips` file described above.

## 7. What is pushed, and what stays local

- **Pushed by this pass:** this pass's own commit, fast-forward from `168d8a7`.
- **Stays local, untracked:** `icon-source/`.
- **Stays local, git-ignored:** `build/p88/`.
- **Outside the repo:** the session scratchpad.

## 8. Open questions

1. **Whether the CPU-usage diagnostic is specific to this harness's polling shape, to `AppleTV6,2`'s
   slower hardware, or both.** No prior pass ran an accessibility-heavy UI test against this device;
   nothing here isolates the two variables.
2. **Whether the 2.8× wall-clock difference between the two Apple TVs matters for future harnesses
   run against the bedroom device.** No timeout in this run was close to being hit, but a longer or
   more query-heavy test could be.
3. **Whether the app itself runs any differently under ordinary use on `AppleTV6,2`** — nothing here
   measures the app outside a UI test's own accessibility traffic.

## 9. The three things I am least sure of

1. **The stack's connection to the harness's own presses.** I read the diagnostic's timestamps as
   overlapping the run's later steps by position in the transcript and by wall-clock plausibility, not
   by any shared identifier between the `.ips` file and the harness's print lines.
2. **That nothing in the sampled stack is app code.** I read every frame in the excerpted stack and
   found none inside the app's own binary, but the full stack (283 lines) was not exhaustively
   traced frame by frame against the app's source.
3. **Whether this diagnostic would recur on a second run.** Only one run was made, per the pass's own
   scope (build, install, one launch, one test run).
