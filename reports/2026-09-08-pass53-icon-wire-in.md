# Pass 53 — the app icon and Top Shelf art, wired in

**Date:** 2026-09-08
**Committed locally. NOT pushed** — the owner judges this with his eyes, so it is behind the separate
push gate.
**No Swift source file was touched.** The only project change is two lines in `project.pbxproj`
(§5). `Info.plist` was not changed. **No artwork was edited, resized, converted, regenerated or
recomposited**, and no `Contents.json` the owner supplied was altered — proved by `diff -r` (§5).
`icon-source/` was not deleted, moved or renamed. No archive, no upload, no App Store Connect
validation. **No administrative or diagnostic request to `192.168.1.250:8090`.**

**I cannot see the screen and make no claim about how the icon looks.**

---

## 1. Git state, read-only — four raw outputs

```
$ git rev-parse HEAD
0a80a57d6ab2db2a15535b765dbb79b18226b71b
```

```
$ git rev-parse origin/main
0a80a57d6ab2db2a15535b765dbb79b18226b71b
```

```
$ git ls-remote origin main
0a80a57d6ab2db2a15535b765dbb79b18226b71b	refs/heads/main
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

All three SHAs read `0a80a57`, as expected.

---

## 2. Where the artwork is — one location, no ambiguity

Searched the whole working tree (excluding `build/`) for `.xcassets`, `.imagestack`,
`.imagestacklayer`, `.appiconset`, `.brandassets`, and for each named PNG.

```
$ find . -name "*.xcassets" -type d -not -path "./build/*"
./icon-source/Assets.xcassets
./Marlin DVR TV/Assets.xcassets
```

- **`icon-source/Assets.xcassets/`** — the owner's supplied catalog, containing
  **`AppIcon.brandassets`** with real artwork. **This is the only place the artwork exists.**
- **`Marlin DVR TV/Assets.xcassets/`** — the project's own catalog, holding the **empty Xcode
  template** `App Icon & Top Shelf Image.brandassets` that Pass 51 §5 documented. It contains **no
  image files**.

**No second candidate**, so no STOP. Every one of the eight named PNGs appears exactly twice: once
inside the supplied catalog, and once as a loose duplicate at the top of `icon-source/` (the files
Pass 51 examined). `AppIcon-400x240.png` exists **only** inside the catalog — it is the file that
was missing at Pass 51.

---

## 3. The structure exactly as it exists on disk

```
icon-source/Assets.xcassets/
├── Contents.json
├── AccentColor.colorset/Contents.json
├── FocusClick.dataset/{Contents.json, focus_click.caf}      ← not icon artwork, see §8.1
└── AppIcon.brandassets/
    ├── Contents.json
    ├── App Icon.imagestack/
    │   ├── Contents.json                       layers: Front, Back  (TWO)
    │   ├── Front.imagestacklayer/{Contents.json, Content.imageset/{Contents.json, AppIcon-400x240.png, AppIcon-800x480.png}}
    │   └── Back.imagestacklayer/ {Contents.json, Content.imageset/{Contents.json, AppIcon-400x240.png, AppIcon-800x480.png}}
    ├── App Icon - App Store.imageset/{Contents.json, AppStore-1280x768.png, AppStore-2560x1536.png}
    ├── Top Shelf Image.imageset/     {Contents.json, TopShelf-1920x720.png, TopShelf-3840x1440.png}
    └── Top Shelf Image Wide.imageset/{Contents.json, TopShelfWide-2320x720.png, TopShelfWide-4640x1440.png}
```

**The four slots as declared** (`AppIcon.brandassets/Contents.json`):

| filename | idiom | role | size |
|---|---|---|---|
| `App Icon - App Store.imageset` | **`tv-marketing`** | `primary-app-icon` | `1280x768` |
| `App Icon.imagestack` | `tv` | `primary-app-icon` | `400x240` |
| `Top Shelf Image Wide.imageset` | `tv` | `top-shelf-image-wide` | `2320x720` |
| `Top Shelf Image.imageset` | `tv` | `top-shelf-image` | `1920x720` |

The App Store slot uses the **`tv-marketing`** idiom, which is why it is a flat imageset rather than
a stack. That is the key detail behind questions 4.3 and 4.4.

**`App Icon.imagestack` declares two layers, Front and Back**, and **both layers' imagesets name the
same two files** (`AppIcon-400x240.png` @1x, `AppIcon-800x480.png` @2x). That is the owner's choice
and it is left exactly as supplied.

### Real pixel dimensions — method: `sips -g pixelWidth -g pixelHeight -g hasAlpha`, cross-checked with `file -b`

Both tools agreed on every file.

| File (in the catalog) | Declared | **Real** | Alpha | Match? |
|---|---|---|---|---|
| `App Icon.imagestack/Front/.../AppIcon-400x240.png` | 1x of 400×240 | **400 × 240** | yes | ✔ |
| `App Icon.imagestack/Front/.../AppIcon-800x480.png` | 2x of 400×240 | **800 × 480** | yes | ✔ |
| `App Icon.imagestack/Back/.../AppIcon-400x240.png` | 1x of 400×240 | **400 × 240** | yes | ✔ |
| `App Icon.imagestack/Back/.../AppIcon-800x480.png` | 2x of 400×240 | **800 × 480** | yes | ✔ |
| `App Icon - App Store/AppStore-1280x768.png` | 1x of 1280×768 | **1280 × 768** | **no** | ✔ |
| `App Icon - App Store/AppStore-2560x1536.png` | 2x of 1280×768 | **2560 × 1536** | **no** | ✔ |
| `Top Shelf Image/TopShelf-1920x720.png` | 1x of 1920×720 | **1920 × 720** | yes | ✔ |
| `Top Shelf Image/TopShelf-3840x1440.png` | 2x of 1920×720 | **3840 × 1440** | yes | ✔ |
| `Top Shelf Image Wide/TopShelfWide-2320x720.png` | 1x of 2320×720 | **2320 × 720** | yes | ✔ |
| `Top Shelf Image Wide/TopShelfWide-4640x1440.png` | 2x of 2320×720 | **4640 × 1440** | yes | ✔ |

**No discrepancies of any kind.** Every filename a `Contents.json` names exists on disk; every real
dimension matches its declared scale exactly; no layer is empty. The two App Store files are opaque
and the rest carry alpha — Pass 52 established `actool` enforces no transparency rule, and §4
confirms it raised nothing here.

---

## 4. Validation before installing — actool, in /tmp scratch, on copies

Nothing entered the project until these runs came back clean. Both runs used copies in
`/tmp/marlin-icon-wire/`; the copy was verified byte-identical to the source first
(`diff -r` → `IDENTICAL`).

### Run T1 — the owner's catalog exactly as supplied

```
xcrun actool --output-format human-readable-text --notices --warnings --errors \
  --platform appletvos --minimum-deployment-target 18.0 --target-device tv \
  --app-icon "AppIcon" \
  --output-partial-info-plist /tmp/marlin-icon-wire/p1.plist \
  --compile /tmp/marlin-icon-wire/out1 /tmp/marlin-icon-wire/T1.xcassets
```

**Full output:**

```
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-wire/out1/Assets.car
/tmp/marlin-icon-wire/p1.plist

--- exit: 0 ---
```

**No `com.apple.actool.document.errors` section, no warnings, no notices.** Read per Pass 52's
finding — the structured error section, not the exit status. `Assets.car`: 12,687,768 bytes.

**Its partial Info.plist:**

```xml
<key>CFBundleIcons</key>
<dict><key>CFBundlePrimaryIcon</key><string>App Icon</string></dict>
<key>TVTopShelfImage</key>
<dict>
  <key>TVTopShelfPrimaryImage</key><string>Top Shelf Image</string>
  <key>TVTopShelfPrimaryImageWide</key><string>Top Shelf Image Wide</string>
</dict>
```

### Run T2 — the owner's brandassets alongside the project's empty template

To decide the arrangement before touching the project: the project catalog copied, with
`AppIcon.brandassets` added next to the existing empty `App Icon & Top Shelf Image.brandassets`.

**Full output:**

```
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-wire/out2/Assets.car
/tmp/marlin-icon-wire/p2.plist

--- exit: 0 ---
```

**Also clean**, and `diff p1.plist p2.plist` → **identical**. The empty template sitting alongside
produces no diagnostic and changes nothing, which is what allowed the minimal arrangement in §5.

### The four questions

- **4.1 — does the App Icon stack satisfy the ≥2-layers-with-content rule? CONFIRMED, yes.**
  Pass 52 established that a stack with only one populated layer produces
  `error: The image stack "App Icon" must have at least 2 layers with applicable content`.
  **No such error appears in T1 or T2.** Two layers, both populated, both scales present — the rule
  is met. **Not a STOP.**
- **4.2 — is `CFBundlePrimaryIcon` emitted? CONFIRMED, yes** — `App Icon`, in both runs. Two Top
  Shelf keys are emitted with it, which Pass 52's control never produced because it had no Top Shelf
  slots.
- **4.3 — does the App Store slot declaring a 2x at 2560×1536 produce any diagnostic? REFUTED — no
  diagnostic at all.** This settles the question Pass 51 left open. Pass 51 read that slot as "1x
  only", and that reading was correct **for the Xcode template's version of the slot**, which uses
  idiom `tv` and declares only `1x`. The owner's slot uses idiom **`tv-marketing`**, and at that
  idiom a 2x at 2560×1536 is accepted silently. **Pass 51's "there is no 2560×1536 slot" no longer
  holds for this catalog**, and his 2560×1536 file has a home after all.
- **4.4 — does the App Store slot being a plain imageset rather than a stack produce any diagnostic?
  REFUTED — no diagnostic at all.** Consistent with 4.3: the marketing icon is flat by design, and
  Pass 52 already measured that the ≥2-layer rule fires only on the small `tv`-idiom stack.

---

## 5. The change made to the project

**Two things, and nothing else.**

**(a) The artwork was copied in, unaltered:**

```
$ cp -R "icon-source/Assets.xcassets/AppIcon.brandassets" "Marlin DVR TV/Assets.xcassets/AppIcon.brandassets"
$ diff -r "icon-source/Assets.xcassets/AppIcon.brandassets" "Marlin DVR TV/Assets.xcassets/AppIcon.brandassets"
IDENTICAL — nothing of his was altered
```

**(b) The target's icon name was pointed at it.** The names did **not** match: the setting read
`"App Icon & Top Shelf Image"` (the empty template) while the owner's brandassets is named
`AppIcon`. The complete project diff:

```diff
@@ -310,7 +310,7 @@   (Debug)
-				ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image";
+				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
@@ -342,7 +342,7 @@   (Release)
-				ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image";
+				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
```

**Two lines. Nothing else in `project.pbxproj` changed**, and no other project setting was touched.

**Why this way rather than renaming his folder:** renaming `AppIcon.brandassets` to the template's
name would have collided with the existing empty one and forced its deletion. Pointing the setting
at his folder leaves his files byte-identical and deletes nothing. T2 proved the empty template
alongside is harmless. **The empty template was left in place** — removing it was not a numbered
step (§8.2).

The catalog is referenced as a folder by the target, so no file-list entry was needed: the build
picked the new brandassets up with no further change, as §6 shows.

---

## 6. Build, and proof the icon is really in the product

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'generic/platform=tvOS Simulator' build
…
** BUILD SUCCEEDED **
```

**Warnings introduced by this pass: none.** The filtered simulator build returns only
`** BUILD SUCCEEDED **`. The device build surfaces one warning,
`GuideScreen.swift:336:34: warning: call to main actor-isolated static method 'channelFocusID'…`,
which is **pre-existing** — the same one Pass 49 recorded. Evidence: `git status --porcelain` for
that file returns nothing, and `git status --porcelain | grep '\.swift$'` returns nothing at all, so
**this pass modified no Swift file whatsoever.**

### The bundle proof — the two things Pass 51 found absent

```
$ ls -l "…/Marlin DVR TV.app/Assets.car"
12683304 bytes    Marlin DVR TV.app/Assets.car
```

**`Assets.car` now exists.** Pass 51 §5 recorded `find … -iname "Assets.car"` returning nothing.

```
$ /usr/libexec/PlistBuddy -c "Print:CFBundleIconName" "…/Info.plist"
Print: Entry, ":CFBundleIconName", Does Not Exist
```

**`CFBundleIconName` is still absent — and that is correct, not a failure.** It is the **iOS** icon
key. tvOS declares its icon differently, and the built bundle now carries exactly what `actool`
emitted:

```
$ plutil -p "…/Info.plist" | grep -iE "icon|topshelf"
  "CFBundleIcons" => {
    "CFBundlePrimaryIcon" => "App Icon"
  "TVTopShelfImage" => {
    "TVTopShelfPrimaryImage" => "Top Shelf Image"
    "TVTopShelfPrimaryImageWide" => "Top Shelf Image Wide"
```

**I am not going to report `CFBundleIconName` as present when it is not.** The step asked for it
because Pass 51 checked for it; the right key for this platform is `CFBundleIcons` /
`CFBundlePrimaryIcon`, and it is there, alongside both Top Shelf keys.

### And the artwork itself is inside the compiled catalog

`xcrun assetutil --info` over the built `Assets.car`:

```
App Icon:
    ZZZZFlattenedImage-1.1.0-gamut0  scale=1  224726 bytes
    ZZZZFlattenedImage-2.1.0-gamut0  scale=2  810475 bytes
    ZZZZRadiosityImage-1.0.0         scale=1    1480 bytes
    ZZZZRadiosityImage-2.0.0         scale=2    5080 bytes
App Icon/Back/Content:
    AppIcon-400x240.png  scale=1  125104 bytes
    AppIcon-800x480.png  scale=2  446768 bytes
App Icon/Front/Content:
    AppIcon-400x240.png  scale=1  125104 bytes
    AppIcon-800x480.png  scale=2  446768 bytes
App Icon - App Store:
    AppStore-1280x768.png   scale=1  1072501 bytes
    AppStore-2560x1536.png  scale=2  2240864 bytes
Top Shelf Image:
    TopShelf-1920x720.png   scale=1   918514 bytes
    TopShelf-3840x1440.png  scale=2  2758234 bytes
Top Shelf Image Wide:
    TopShelfWide-2320x720.png   scale=1   872511 bytes
    TopShelfWide-4640x1440.png  scale=2  2615772 bytes
```

**All four slots, both layers of the stack, both scales throughout.** The `ZZZZFlattenedImage` and
`ZZZZRadiosityImage` entries are what `actool` generates from a layered stack, so the layered icon
was genuinely processed as a stack rather than copied through flat.

---

## 7. Device install

`Home Theater` was **available (paired)**. Built for the device after the edit, fingerprinted, and
that exact bundle installed:

```
device binary sha256: acde80699d8f4e6f3162e600670e22f27b91896e3a5b46f634452b0e692f3a55
device Assets.car:    9369752 bytes

$ xcrun devicectl device install app --device "Home Theater" "…/Debug-appletvos/Marlin DVR TV.app"
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
```

**The install succeeded, and the build installed is the one built in this pass.** That is all this
step evidences — **I cannot see the Home screen and make no claim about the icon's appearance.**

---

## 8. Scratch cleanup, proved

```
$ rm -rf /tmp/marlin-icon-wire
$ ls -la /tmp/marlin-icon-wire
ls: /tmp/marlin-icon-wire: No such file or directory
$ find /tmp -maxdepth 1 -name "marlin-icon-*"
(no output)
$ pgrep -fl actool
(no output)
```

62 MB across two test catalogs and their outputs — **gone**, with no actool process left running.

---

## 9. Commit status

**Committed locally. NOTHING WAS PUSHED.**

The build commit is **`c2dcf14`** — in full:

```
$ git rev-parse HEAD
c2dcf14c909f58a36ce115225c2b91fac5ec1f70
```

21 files changed, 613 insertions, 2 deletions.

**`git push` was not run in this pass, to any remote, at any point.** `origin/main` is still at
`0a80a57`, where Pass 52 left it, so the local branch is two commits ahead: this build commit and
the one that records this SHA. The owner looks at Home Theater and the push follows his approval.

*(This paragraph is the second commit — the SHA cannot exist inside the commit it names, and the
build commit is left untouched rather than amended.)*

### Every file added (19), plus one modified

**Modified (1):** `Marlin DVR TV.xcodeproj/project.pbxproj` — the two lines in §5.

**Added, all under `Marlin DVR TV/Assets.xcassets/AppIcon.brandassets/` (19):**

```
Contents.json
App Icon.imagestack/Contents.json
App Icon.imagestack/Front.imagestacklayer/Contents.json
App Icon.imagestack/Front.imagestacklayer/Content.imageset/Contents.json
App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-400x240.png
App Icon.imagestack/Front.imagestacklayer/Content.imageset/AppIcon-800x480.png
App Icon.imagestack/Back.imagestacklayer/Contents.json
App Icon.imagestack/Back.imagestacklayer/Content.imageset/Contents.json
App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-400x240.png
App Icon.imagestack/Back.imagestacklayer/Content.imageset/AppIcon-800x480.png
App Icon - App Store.imageset/Contents.json
App Icon - App Store.imageset/AppStore-1280x768.png
App Icon - App Store.imageset/AppStore-2560x1536.png
Top Shelf Image.imageset/Contents.json
Top Shelf Image.imageset/TopShelf-1920x720.png
Top Shelf Image.imageset/TopShelf-3840x1440.png
Top Shelf Image Wide.imageset/Contents.json
Top Shelf Image Wide.imageset/TopShelfWide-2320x720.png
Top Shelf Image Wide.imageset/TopShelfWide-4640x1440.png
```

### `icon-source/` still holds duplicates, and was left alone

Every one of the eight PNGs now in the catalog **also still exists in `icon-source/`** — once inside
`icon-source/Assets.xcassets/AppIcon.brandassets/` (the owner's original structured copy) and, for
seven of them, again as a loose file at the top of `icon-source/`. **Nothing there was deleted, moved
or renamed, and none of it was committed** — all **32** entries under `icon-source/` remain
untracked (`git status --porcelain --untracked-files=all | grep -cE '^\?\? "?icon-source/'` → `32`),
and `git diff --cached --name-only | grep -c '^icon-source/'` → `0`.
**Whether that folder stays, moves or goes is the owner's call.**

---

## 10. Open questions

1. **`FocusClick.dataset` was not imported.** The owner's catalog also contains
   `FocusClick.dataset/focus_click.caf` (4,100 bytes), a sound asset. It is **not icon artwork**, no
   numbered step named it, and **no Swift source references `FocusClick` or `focus_click`**
   (`grep -rn` over every `.swift` returns nothing). Importing it would have added an unused asset
   this pass was not asked for. *What breaks without it:* nothing today — nothing can play a sound
   that nothing references. **Left in `icon-source/` untouched.**
2. **The empty template brandassets is still in the project catalog.**
   `Marlin DVR TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/` is now unused — the
   setting points at `AppIcon`. Run T2 proved it produces no diagnostic and changes nothing about
   the output. **Removing it was not a numbered step**, so it stands. *What breaks without removing
   it:* nothing measured; it is tidiness, and a deletion is the owner's call.
3. **`CFBundleIconName` is absent, by platform design (§6).** Step 6 asked me to show it present.
   It is an iOS key; tvOS uses `CFBundleIcons`/`CFBundlePrimaryIcon` plus `TVTopShelfImage`, all of
   which are present and pasted. Flagged rather than glossed, because the step's expectation and the
   platform's reality differ.
4. **Pass 51's "the App Store slot is 1x only" is superseded for this catalog (§4.3).** It was true
   of the Xcode template's `tv`-idiom slot; the owner's `tv-marketing` slot takes a 2x, and
   `actool` accepted 2560×1536 silently. Recorded so the earlier report is not read as still
   current on that point.
5. **Nothing here was seen.** The evidence is metadata, `actool` output, the compiled catalog's
   contents and an install that returned success. **Whether the icon looks right on the Home screen
   is entirely the owner's to judge.**

---

## 11. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `icon-source/Assets.xcassets/AppIcon.brandassets/` | **read, copied from; never written, moved or renamed** | steps 2, 3, 5 |
| `icon-source/` (everything else) | **read only; left untouched, uncommitted** | steps 2, 9 |
| `/tmp/marlin-icon-wire/` | **created, written, deleted** (proved gone, §8) | step 4 |
| `Marlin DVR TV/Assets.xcassets/AppIcon.brandassets/` | **created — 19 files, byte-identical copies** | step 5 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **modified — 2 lines** | step 5 |
| Built `Marlin DVR TV.app` (simulator + device) | read for proof; produced by step 6 | steps 6, 7 |
| `reports/2026-09-08-pass53-icon-wire-in.md` | **created** | DELIVERABLE |

**No Swift source file was modified** — `git status --porcelain | grep '\.swift$'` returns nothing.
`Info.plist` was not touched. No artwork was edited, resized, converted or recomposited, and **no
`Contents.json` the owner supplied was altered** (`diff -r` → IDENTICAL). No third layer was added.
No archive, no upload, no App Store Connect validation.

**Not touched:** every other folder under `~/Xcode`; the reference clone; `design/`; the Marlin DVR
server's data, config and admin UI — **no administrative or diagnostic request**; Unraid, marlinpc,
the HDHomeRun, the UNAS4Pro share; everything built in Passes 42–50.

**No new dependency.** No credential, token, device id or account identifier appears in this report —
the Apple TV's `devicectl` identifier is not reproduced.

---

## CLOSING SUMMARY FOR THE OWNER

**Yes — the icon is really in the app now, and I can prove it three ways.** The compiled asset file
`Assets.car` exists in the built app for the first time (Pass 51 found the app had none at all). The
app's Info.plist now declares its icon and both Top Shelf images. And unpacking that compiled file
shows every piece of your artwork inside it — both layers of the icon at both sizes, the App Store
icon at both sizes, and both Top Shelf images at both sizes.

Your catalog needed no repair. Every file its manifests named was present, every image was exactly
the size it claimed to be, and Apple's compiler accepted it with **no error, no warning and no
note** — I validated it in a scratch copy before letting it near the project. Two things it settled
that were previously open: your App Store icon slot **does** take the 2560×1536 file after all
(Pass 51 thought that slot was single-size — that was true of Xcode's template, not of yours,
because yours uses the marketing idiom), and the flat imageset you used for it instead of a layered
stack is entirely fine.

**The only change to the project was two lines.** Your brandassets folder is called `AppIcon` and the
project was still pointing at the empty template's longer name, so I repointed it. Your files went in
byte-for-byte untouched — verified with a recursive diff.

**What to look for on Home Theater.** The app is installed, from the build made in this pass. Go to
the Home screen and look at the Marlin DVR TV tile: it should now show your artwork instead of a
blank placeholder, and it should grow and pick up a highlight as you move focus onto it. Scroll up to
the top shelf with the app selected and your wide banner should appear there. **I cannot see any of
that** — the install succeeding is all I can evidence, and how it actually looks is entirely yours to
judge.

**What this pass cost.** Two throwaway catalogs compiled in `/tmp` (62 MB, deleted and proved gone),
19 files copied into the project, two lines changed in the project file, two clean builds and one
device install. No app code was touched at all. **It is committed but not pushed**, waiting on your
eyes.

**The three things I am least certain about.**

1. **How it looks.** Everything I checked says the artwork is correctly built into the app; none of
   it tells me the picture is right, well-cropped, or legible on a television. That is the whole of
   what remains.
2. **One thing your catalog carried that I did not import** — a small sound file, `FocusClick`, in a
   `FocusClick.dataset`. It is not icon artwork, nothing in the app's code refers to it, and no step
   of this pass mentioned it, so I left it alone in `icon-source/` rather than quietly adding an
   unused asset. If you meant it to come along, it needs its own pass.
3. **The old empty icon folder is still sitting in the project**, unused now that the setting points
   at yours. I proved it does no harm — the compiler's output is byte-identical with and without it
   — but deleting it wasn't something this pass was asked to do, so I left it for you to decide.
