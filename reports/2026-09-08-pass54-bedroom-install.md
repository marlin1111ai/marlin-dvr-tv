# Pass 54 — the current build installed on the bedroom Apple TV

**Date:** 2026-09-08, running past midnight into 2026-09-09 (the install completed just after the
clock rolled over; the filename keeps the pass's own date).

**This pass changed nothing.** No file in the working tree was edited, no commit was made, no push,
no stash, no branch, no tag. No test or harness was run on either Apple TV. Nothing was uninstalled,
reset or cleared. **No administrative or diagnostic request was made to `192.168.1.250:8090`** — the
only traffic to the DVR is whatever the app itself makes once the owner opens it. Home Theater was
not touched: it already has this build from Pass 53.

**This report is left uncommitted, as the brief requires.**

---

## 1. The tree, and the build being installed

```
$ git rev-parse HEAD
0b3589d03c63b02ad9c971de0442a52263f90c5d
```

```
$ git status --porcelain --untracked-files=all
?? icon-source/AppIcon-1024-square.png
?? icon-source/AppIcon-800x480.png
?? icon-source/AppStore-1280x768.png
?? icon-source/AppStore-2560x1536.png
?? icon-source/Assets.xcassets/AccentColor.colorset/Contents.json
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/AppStore-1280x768.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/AppStore-2560x1536.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon - App Store.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-400x240.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-800x480.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Back.imagestacklayer/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-400x240.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-800x480.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack/Front.imagestacklayer/Contents.json"
?? icon-source/Assets.xcassets/AppIcon.brandassets/Contents.json
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/TopShelfWide-2320x720.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/TopShelfWide-4640x1440.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/Contents.json"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/TopShelf-1920x720.png"
?? "icon-source/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/TopShelf-3840x1440.png"
?? icon-source/Assets.xcassets/Contents.json
?? icon-source/Assets.xcassets/FocusClick.dataset/Contents.json
?? icon-source/Assets.xcassets/FocusClick.dataset/focus_click.caf
?? icon-source/TopShelf-1920x720.png
?? icon-source/TopShelf-3840x1440.png
?? icon-source/TopShelfWide-2320x720.png
?? icon-source/TopShelfWide-4640x1440.png
?? icon-source/marlin-dvr-icon.png
```

**The build installed is local `HEAD` = `0b3589d03c63b02ad9c971de0442a52263f90c5d`** — Pass 53's icon
work, still unpushed and two commits ahead of `origin/main`.

**No modified tracked files.** Every entry above is untracked and every one is under `icon-source/` —
the same **32** entries Pass 53 left alone, unchanged in number and content. Nothing unexpected, so
the pass proceeded. All four readings were taken again after the install and were identical (§5).

---

## 2. The device

**Raw listing:**

```
$ xcrun devicectl list devices
Name                 Hostname                              Identifier    State                Model
------------------   -----------------------------------   -----------   ------------------   ------------------------------------------
Home Theater         Home-Theater.coredevice.local         <REDACTED>    available (paired)   Apple TV 4K (3rd generation) (AppleTV14,1)
Marlin iPhone        Marlin-iPhone.coredevice.local        <REDACTED>    available (paired)   iPhone 17 Pro Max (iPhone18,2)
Master Bedroom ATV   Master-Bedroom-ATV.coredevice.local   <REDACTED>    available (paired)   Apple TV 4K (AppleTV6,2)
```

*(Device identifiers redacted; they are UDIDs.)*

**The bedroom Apple TV is `Master Bedroom ATV`, unambiguously.** Three devices are reachable. One is
an iPhone, not a tvOS device. Of the two Apple TVs, one is `Home Theater` — the machine Pass 53
already installed to and which this pass is forbidden to touch. **That leaves exactly one candidate**,
and its name says what it is. No guessing was required.

It is **`available (paired)`** — no pairing code was requested and nothing needed approving at the
television. It is an **Apple TV 4K (AppleTV6,2)**, the earlier 4K model, distinct from Home Theater's
3rd-generation `AppleTV14,1`.

---

## 3. Build and install

### The build

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Master Bedroom ATV' -allowProvisioningUpdates build
…
** BUILD SUCCEEDED **
```

**Nothing was asked of the owner.** `-allowProvisioningUpdates` was passed as the step specifies and
provisioning resolved without prompting for anything.

Two lines from the asset-catalog step are worth keeping, because they show the build was tailored to
*this* television and that Pass 53's icon wiring is what it used:

```
… actool … --app-icon AppIcon --accent-color AccentColor
          --filter-for-thinning-device-configuration AppleTV6,2
          --filter-for-device-os-version 26.6
          --target-device tv --minimum-deployment-target 18.0 --platform appletvos
/* com.apple.actool.compilation-results */
… /Marlin DVR TV.build/assetcatalog_output/thinned/Assets.car

note: Emplaced … /Marlin DVR TV.app/Assets.car
```

**`--app-icon AppIcon`** is the setting Pass 53 changed, and the catalog compiled with **no error,
warning or note** other than the emplacement note. The bedroom Apple TV runs **tvOS 26.6**, above the
18.0 deployment target.

### The install — a separate claim from the build

```
$ xcrun devicectl device install app --device "Master Bedroom ATV" "…/Debug-appletvos/Marlin DVR TV.app"
00:00:00  Acquired tunnel connection to device.
00:00:00  Enabling developer disk image services.
00:00:00  Acquired usage assertion.
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
• installationURL: file:///private/var/containers/Bundle/Application/<REDACTED>/Marlin%20DVR%20TV.app/
• launchServicesIdentifier: unknown
• databaseUUID: <REDACTED>
• databaseSequenceNumber: 376
• options:
```

**The build succeeded and, separately, the install succeeded.**

The binary that went over is byte-identical to the one Pass 53 put on Home Theater —
`sha256 acde80699d8f4e6f3162e600670e22f27b91896e3a5b46f634452b0e692f3a55` — which is expected: no
code changed, only the asset catalog was re-thinned for this model. `Assets.car`: 9,369,752 bytes.

---

## 4. Confirmation the app is on the device

Asked the device itself what it has, rather than trusting the install's own report:

```
$ xcrun devicectl device info apps --device "Master Bedroom ATV" --bundle-id com.marlin1111.MarlinDVRTV
Apps installed:
Name            Bundle Identifier            Version   Bundle Version
-------------   --------------------------   -------   --------------
Marlin DVR TV   com.marlin1111.MarlinDVRTV   1.0       1
```

The bedroom Apple TV enumerates the app as installed.

**I cannot see the screen and make no claim about how anything looks** — not the icon, not the top
shelf, not any screen in the app. This step evidences that the bundle is present on the device and
nothing more.

---

## 5. Nothing was changed, committed or pushed

Re-checked after the install:

```
$ git rev-parse HEAD
0b3589d03c63b02ad9c971de0442a52263f90c5d          ← unchanged

$ git status --porcelain | grep -v '^??'
(no output — no modified tracked files)

$ git status --porcelain --untracked-files=all | grep -cE '^\?\? "?icon-source/'
32                                                 ← unchanged

$ git rev-list --left-right --count origin/main...HEAD
0	2                                              ← unchanged; still Pass 53's two commits
```

**No commit, no push, no stash, no branch, no tag, and no file in the working tree modified.** The
two Pass 53 commits remain local and unpushed, exactly as that pass left them.

---

## 6. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| the whole working tree | **read only** — `git rev-parse`, `git status`; nothing written | step 1 |
| `Marlin DVR TV.xcodeproj` + sources + `Assets.xcassets` | **read** by `xcodebuild`; **not modified** | step 3 |
| DerivedData build products (outside the repo) | written by `xcodebuild`, as the step requires | step 3 |
| `Master Bedroom ATV` | app installed | steps 2, 3, 4 |
| `reports/2026-09-08-pass54-bedroom-install.md` | **created — the only new file, and left uncommitted** | DELIVERABLE |

**Not touched:** `Home Theater` — no install, no launch, no test; every other folder under
`~/Xcode`; the reference clone; `design/`; `icon-source/`; the Marlin DVR server, its data, its
config and its admin UI — **no administrative or diagnostic request of any kind**; Unraid, marlinpc,
the HDHomeRun, the UNAS4Pro share. No test, harness or UI test was run on either Apple TV. Nothing
was uninstalled, reset or cleared anywhere.

**No new dependency.** Device identifiers, the bundle container UUID and the database UUID are
redacted above.

---

## CLOSING SUMMARY FOR THE OWNER

**Yes — it is on the bedroom Apple TV and ready to use tonight.** The build with your icon in it, the
same one that has been on Home Theater since Pass 53, is now installed on **Master Bedroom ATV**. I
did not take that on trust from the installer: I asked the television afterwards what it has, and it
lists *Marlin DVR TV* as installed.

Picking the device needed no guesswork. Three things are reachable from this Mac — your iPhone, Home
Theater, and Master Bedroom ATV — so once the iPhone and the machine that already had the build are
set aside, exactly one candidate remained, and it names itself.

**There is nothing you have to do at the television.** It was already paired, no pairing code was
asked for, and provisioning went through without prompting for anything. Just open the app.

Two things worth knowing. It is your **earlier Apple TV 4K**, not the same model as Home Theater, so
the app was rebuilt specifically for it — the code is byte-for-byte identical, only the artwork was
re-packed for that model. And this is still a **development build**: it is signed with your own
development profile, so if it ever stops opening with a message about the developer, that is the
profile expiring rather than anything wrong with the app, and it just needs reinstalling.

**This pass changed nothing at all** — no code, no assets, no settings, no commits, no pushes. Pass
53's two commits are still sitting locally, unpushed, waiting on your verdict about how the icon
looks. This report is deliberately left uncommitted too.

**The three things I am least certain about.**

1. **How any of it looks on that television.** I cannot see the screen. Everything I can evidence
   says the app is installed and carries your icon; whether the icon reads well on that set, and
   whether the app behaves as you expect on the older hardware, is entirely yours to judge.
2. **The older model.** Home Theater is a 3rd-generation Apple TV 4K; the bedroom one is the first 4K
   model. It runs tvOS 26.6 so it is comfortably above what the app requires, and the build was
   tailored to it — but nothing in this app has ever been exercised on that hardware before tonight,
   so if something is slow or off there, it would be new information.
3. **How long a development install lasts.** Development-signed builds stop launching when the
   provisioning profile expires. I have not checked when that is, and it was not in scope to.
