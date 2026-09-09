# Pass 51 — tvOS app icon requirements: recon

**Date:** 2026-09-08
**Read-only. Exactly one file is written this pass: this report.** No image file was added, edited,
resized, converted, renamed, moved or deleted anywhere, `icon-source/` included. No change to the
asset catalog, `Info.plist`, any project setting or any Swift source. **No build, archive, upload or
validation run.** No network request to Apple or anywhere else. **No request of any kind to
`192.168.1.250:8090`.** The reference clone and `design/` were not touched.

**I cannot see any of this artwork.** Everything below is metadata read from the files and
definitions read from the installed Xcode. I make no claim about how anything looks.

---

## 0. What the existing record settles — almost nothing

`COLD-START.md` and `DECISIONS.md` were searched for `appicon`, `icon`, `display name`, `bundle id`,
`CFBundleDisplayName`, `TopShelf` and `top shelf`. **Neither notebook says anything about this app's
icon.** What they do settle:

- **The bundle id is `com.marlin1111.MarlinDVRTV`** and the owner registered the explicit App ID with
  description "Marlin DVR TV" (`DECISIONS.md:169`).
- Every other `icon` hit is unrelated — radio station icons from the server (`DECISIONS.md:95`,
  `:98`, `:101`; `COLD-START.md:123-124`) and the rail's focus behaviour (`COLD-START.md:186`).
- `DECISIONS.md:185` records `TVOS_DEPLOYMENT_TARGET = 18.0` and that the bundle id is unchanged.

**There is no prior icon decision, no prior icon pass, and nothing to re-derive.** This is new ground.

---

## 1. Git state, read-only — four raw outputs

```
$ git rev-parse HEAD
3222b614d5e3eebfcc19a36417fef7b0b760d226
```

```
$ git rev-parse origin/main
3222b614d5e3eebfcc19a36417fef7b0b760d226
```

```
$ git ls-remote origin main
3222b614d5e3eebfcc19a36417fef7b0b760d226	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
?? icon-source/AppIcon-1024-square.png
?? icon-source/AppIcon-800x480.png
?? icon-source/AppStore-1280x768.png
?? icon-source/AppStore-2560x1536.png
?? icon-source/TopShelf-1920x720.png
?? icon-source/TopShelf-3840x1440.png
?? icon-source/TopShelfWide-2320x720.png
?? icon-source/TopShelfWide-4640x1440.png
?? icon-source/marlin-dvr-icon.png
```

`icon-source/` exists and **all nine named files are present** (`ls -1 icon-source/*.png | wc -l` →
`9`). All nine are untracked; none is in the repo.

---

## 2. What this Mac's Xcode actually requires

**Xcode 26.6, build 17F113** (`xcodebuild -version`), SDK `appletvos26.5`.

**How this was established — two independent local sources, not memory:**

1. **The asset catalog Xcode itself generated** for this target, at
   `Marlin DVR TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`. Its `Contents.json`
   files are Xcode's own declaration of the slots, their roles, their base sizes and their scales.
2. **`AssetCatalogAppleTVFoundation.framework`**, the tvOS asset-catalog framework inside Xcode
   (`/Applications/Xcode.app/Contents/Frameworks/`). Extracting literal strings from its binary
   yields the role and size vocabulary the toolchain knows:

```
$ strings …/AssetCatalogAppleTVFoundation | grep -E "^(primary-app-icon|[0-9]{3,4}x[0-9]{3,4})$" | sort -u
1280x768
1920x720
2320x720
400x240
primary-app-icon

$ strings …/AssetCatalogAppleTVFoundation | grep -i "top-shelf" | sort -u
top-shelf-image
top-shelf-image-wide
```

**The two sources agree exactly on all four base sizes and all four roles.**

### 2.1 Every slot, with exact pixel dimensions

From the brandassets `Contents.json` (roles and base sizes) and each slot's own imageset
`Contents.json` (scales). **13 images in total.**

| # | Slot (real name) | Role | Base | Layered? | Scale | **Exact pixels** |
|---|---|---|---|---|---|---|
| 1 | `App Icon` | `primary-app-icon` | 400×240 | **yes, 3 layers** | 1x | **400 × 240** × 3 layers |
| 2 | `App Icon` | `primary-app-icon` | 400×240 | **yes, 3 layers** | 2x | **800 × 480** × 3 layers |
| 3 | `App Icon - App Store` | `primary-app-icon` | 1280×768 | **yes, 3 layers** | **1x only** | **1280 × 768** × 3 layers |
| 4 | `Top Shelf Image` | `top-shelf-image` | 1920×720 | no, flat | 1x | **1920 × 720** |
| 5 | `Top Shelf Image` | `top-shelf-image` | 1920×720 | no, flat | 2x | **3840 × 1440** |
| 6 | `Top Shelf Image Wide` | `top-shelf-image-wide` | 2320×720 | no, flat | 1x | **2320 × 720** |
| 7 | `Top Shelf Image Wide` | `top-shelf-image-wide` | 2320×720 | no, flat | 2x | **4640 × 1440** |

**The App Store icon is 1x only** — established directly, not assumed:

```
$ cat "App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/Contents.json"
{ "images" : [ { "idiom" : "tv", "scale" : "1x" } ], … }
```

whereas the small App Icon's and both Top Shelf layers' imagesets each declare `1x` **and** `2x`.
**So there is no 2560×1536 slot.** That matters in §4.

Counting the images: App Icon 3 layers × 2 scales = **6**; App Store icon 3 layers × 1 scale = **3**;
Top Shelf 2 scales = **2**; Top Shelf Wide 2 scales = **2**. **13 image files.**

### 2.2 Required vs optional for TestFlight/App Store validation

**I could not establish this locally with confidence, and I am not going to fill it in from memory.**

What I *can* state from this Mac:

- **Xcode's own tvOS app template creates all four slots**, and the target is pointed at that
  brandassets group (`ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image"`,
  `project.pbxproj:313` and `:345`). So all four are what Xcode expects a tvOS app to have.
- Searching `actool`, `AssetCatalogAppleTVKit` and `AssetCatalogAppleTVFoundation` for validation
  text (`required`, `must be`, `missing`) surfaced only generic strings —
  `Required component for identifier "%@" is missing.` — with **no tvOS-icon-specific requirement
  rule extractable**.
- The authoritative gate is App Store Connect's own validation, which runs on Apple's servers. This
  pass is forbidden to upload or run validation, so **that gate was not exercised.**

**UNVERIFIED, and flagged as such:** which of the four slots App Store Connect will reject a build
for omitting. My understanding is that the App Store icon (1280×768) and the small App Icon are
required for a tvOS submission and the two Top Shelf images are expected too, but **I did not
establish that on this Mac and it should not be treated as fact.** §7 plans for all four, which is
safe regardless of which are strictly required.

### 2.3 Is the tvOS app icon layered? Yes — exactly three layers

Established from the generated catalog, which contains a real `.imagestack` for each app icon:

```
$ cat "App Icon.imagestack/Contents.json"
{ "layers" : [ { "filename" : "Front.imagestacklayer" },
               { "filename" : "Middle.imagestacklayer" },
               { "filename" : "Back.imagestacklayer" } ], … }
```

- **Three layers, named `Front`, `Middle`, `Back`**, declared front-to-back in that order. Both app
  icon stacks (`App Icon.imagestack` and `App Icon - App Store.imagestack`) have all three.
- **Each layer is its own `.imageset`** (`<Layer>.imagestacklayer/Content.imageset/`) and carries the
  scales in the §2.1 table. So a layer is supplied as an ordinary image — **PNG is what the catalog
  takes**; the nine candidates are already PNG.
- **Every layer is the full slot size.** The layers are stacked, not tiled: a `Front` layer for the
  400×240 slot at 2x is itself 800×480. Depth comes from the parallax effect the system applies, not
  from differing sizes.
- **Transparency per layer: UNVERIFIED.** By construction a stack only reads as layered if the front
  layers have transparent regions letting the back show through, and `AssetCatalogFoundation`
  contains transparency-diagnostic symbols (`messageDescribingTransparency`, `Transparent`) — but I
  could not extract the rule text, and running the tool is out of scope. **Whether Xcode *requires*
  the back layer to be opaque, or *requires* the front layers to have alpha, is not established
  here.**
- **Whether all three layers must be populated is also UNVERIFIED.** The template ships all three
  empty; nothing local told me whether one filled layer is a legal stack.

### 2.4 Transparency, alpha, colour profile, embedded text

**Largely UNVERIFIED locally, and stated as such rather than recalled.**

- **Alpha/transparency rule:** not established (see §2.3). The toolchain has transparency diagnostics
  but their conditions were not extractable without running them.
- **Colour profile:** no constraint was found in any local definition. All nine candidate files carry
  **no embedded profile at all** (§3), which is a fact about the files, not a verdict on validation.
- **Embedded text:** no *validation* constraint was found locally. There is a **practical** issue with
  text in this artwork, and it is a fact about naming rather than about validation — §6.1.

**One thing I can state as established fact rather than inference:** the app currently ships **no
icon at all** (§5), so whatever the exact requirements are, today's bundle does not meet them.

---

## 3. The nine files, read from the files themselves

**Method:** `sips -g pixelWidth -g pixelHeight -g hasAlpha -g space -g profile -g bitsPerSample
-g samplesPerPixel` on each file, cross-checked independently with `file -b`. Both are stock macOS
tools — **no dependency was installed.** The two agreed on every dimension and colour type.

| File | **Real pixels** | Aspect | Alpha | Bits | Profile | Filename honest? |
|---|---|---|---|---|---|---|
| `AppIcon-800x480.png` | **800 × 480** | 5:3 | yes (RGBA) | 8 | none | ✔ |
| `AppIcon-1024-square.png` | **1024 × 1024** | 1:1 | yes (RGBA) | 8 | none | ✔ |
| `AppStore-1280x768.png` | **1280 × 768** | 5:3 | yes (RGBA) | 8 | none | ✔ |
| `AppStore-2560x1536.png` | **2560 × 1536** | 5:3 | yes (RGBA) | 8 | none | ✔ |
| `TopShelf-1920x720.png` | **1920 × 720** | 8:3 | yes (RGBA) | 8 | none | ✔ |
| `TopShelf-3840x1440.png` | **3840 × 1440** | 8:3 | yes (RGBA) | 8 | none | ✔ |
| `TopShelfWide-2320x720.png` | **2320 × 720** | 29:9 | yes (RGBA) | 8 | none | ✔ |
| `TopShelfWide-4640x1440.png` | **4640 × 1440** | 29:9 | yes (RGBA) | 8 | none | ✔ |
| `marlin-dvr-icon.png` | **400 × 240** | 5:3 | yes (RGBA) | 8 | none | ✖ — see §6.2 |

**Every filename matches its real dimensions except `marlin-dvr-icon.png`**, which carries no
dimensions in its name and turns out to be **400 × 240** — exactly the App Icon 1x size. That
coincidence is addressed in §6.2.

**All nine have an alpha channel** (`samplesPerPixel: 4`, `hasAlpha: yes`, `8-bit/color RGBA`) and
**none carries an embedded colour profile** (`profile: <nil>` on all nine).

---

## 4. File → slot, exact on pixels

### 4.1 Exact matches (right pixel dimensions, no resize)

| Slot + scale | Required | File | |
|---|---|---|---|
| `Top Shelf Image` @1x | 1920×720 | `TopShelf-1920x720.png` | **exact** |
| `Top Shelf Image` @2x | 3840×1440 | `TopShelf-3840x1440.png` | **exact** |
| `Top Shelf Image Wide` @1x | 2320×720 | `TopShelfWide-2320x720.png` | **exact** |
| `Top Shelf Image Wide` @2x | 4640×1440 | `TopShelfWide-4640x1440.png` | **exact** |
| `App Icon` @2x, **one layer** | 800×480 | `AppIcon-800x480.png` | **exact on pixels only** — see 4.4 |
| `App Icon - App Store` @1x, **one layer** | 1280×768 | `AppStore-1280x768.png` | **exact on pixels only** — see 4.4 |

**The four Top Shelf images are flat imagesets, so those four slots are genuinely, completely
covered.**

### 4.2 Fits after a plain proportional resize, no cropping

Every app-icon slot is 5:3 and every 5:3 candidate downsizes onto every smaller 5:3 slot with no
cropping:

| Target | From | Scale factor |
|---|---|---|
| `App Icon` @1x — 400×240 | `AppIcon-800x480.png` | exactly 50 % |
| `App Icon` @1x — 400×240 | `AppStore-2560x1536.png` | exactly 15.625 % |
| `App Icon` @2x — 800×480 | `AppStore-2560x1536.png` | exactly 31.25 % |
| `App Icon - App Store` @1x — 1280×768 | `AppStore-2560x1536.png` | exactly 50 % |
| `Top Shelf Image` @1x — 1920×720 | `TopShelf-3840x1440.png` | exactly 50 % |
| `Top Shelf Image Wide` @1x — 2320×720 | `TopShelfWide-4640x1440.png` | exactly 50 % |

All are exact integer-ratio downscales — no cropping and no aspect change.

### 4.3 Needs cropping or recomposition, or has no slot

- **`AppIcon-1024-square.png` (1024×1024) fits nothing.** Every tvOS slot is 5:3, 8:3 or 29:9;
  **none is square.** Using it means cropping or recomposing. It is the odd file out.
- **`AppStore-2560x1536.png` (2560×1536) has no slot of its own.** The App Store icon is **1x only**
  (§2.1), so there is no 2560×1536 destination. It is useful only as the resize source in 4.2.
- **`marlin-dvr-icon.png`** — excluded from the mapping, §6.2.

### 4.4 The gap that matters most: **flat images, layered slots**

**Both app icon slots are three-layer imagestacks (§2.3), and every file the owner generated is a
single flat image.** So of the six 5:3 candidates, none is *an app icon* — each is at best **one
layer of one**.

Concretely, the app icon needs **9 images** (3 layers × 2 scales for the small icon, 3 layers × 1
scale for the App Store icon), and the owner has supplied **flat artwork for 0 of those 9 as a
complete layered set.**

**Slots with no candidate at all:**

| Slot | Required | Candidate |
|---|---|---|
| `App Icon` @1x, all 3 layers | 400×240 each | **none** (resizable from 4.2, but still flat) |
| `App Icon` @2x — `Middle`, `Back` | 800×480 each | **none** |
| `App Icon - App Store` @1x — `Middle`, `Back` | 1280×768 each | **none** |

---

## 5. The current state of the target's icon setup

**The slots exist and are wired up. Every one of them is empty.**

- **The target points at the right catalog group:**
  `ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image"` — `project.pbxproj:313`
  (Debug) and `:345` (Release). That name matches the brandassets folder exactly.
- **The catalog contains no image files whatsoever:**

```
$ find "Marlin DVR TV/Assets.xcassets" -type f ! -name "Contents.json"
(no output)
```

  Every `Contents.json` under the brandassets declares its slots and scales with **no `filename`
  key on any image entry**. The only `filename` keys in the tree are structural — the brandassets
  root pointing at its four slots, and each imagestack pointing at its three layers.

- **What already shipped confirms it.** Reading the app bundle that is already built (an existing
  artifact — **nothing was built for this**):

```
$ find "…/Debug-appletvos/Marlin DVR TV.app" -iname "Assets.car"
(no output — absent)

$ /usr/libexec/PlistBuddy -c "Print:CFBundleIconName" "…/Marlin DVR TV.app/Info.plist"
Print: Entry, ":CFBundleIconName", Does Not Exist
```

  **There is no `Assets.car` in the bundle at all** and **no `CFBundleIconName`**. The catalog
  compiles to nothing shippable because it holds nothing.

**What would happen at validation right now.** I did not run validation — it is out of scope and it
runs on Apple's servers. What is established is stronger than a prediction about the rules: **the
build contains no app icon asset of any kind.** Whatever the exact requirements turn out to be
(§2.2 is unverified), a tvOS submission with no icon in the bundle does not meet them. **Today's
build would not pass a TestFlight upload**, and the reason is not a subtlety of sizes — it is that
there is nothing there.

---

## 6. Two things the owner needs told plainly

### 6.1 The artwork says "MARLIN TV". The app is called "Marlin DVR TV".

**The app's display name, established locally:**

- `PRODUCT_NAME = "$(TARGET_NAME)"` — `project.pbxproj:331`, `:363`. There is **no
  `CFBundleDisplayName`** anywhere: not in `Info.plist` (which holds only the location string and
  the ATS exception) and not as an `INFOPLIST_KEY_` build setting.
- The built bundle settles it: **`CFBundleName = Marlin DVR TV`**, and
  `Print:CFBundleDisplayName` → `Does Not Exist`.

**So the app's name is "Marlin DVR TV". The artwork has "MARLIN TV" rendered into it. Those are two
different strings** — the artwork is missing the "DVR". This is not only a duplication question; the
two would disagree.

**Does the Apple TV Home screen draw the name beneath the icon?** On tvOS the Home screen shows the
app's name under its icon when the icon is focused. **I did not verify this on this Mac** — it is
platform behaviour, and this pass may not run the device or the Simulator. **Marked unverified.**

If it does, the owner would see **"MARLIN TV" inside the icon and "Marlin DVR TV" underneath it.**
Whether that matters is his call; that the two strings differ is a fact he should have before
regenerating anything. **Nothing was changed** — not the artwork, not the display name.

### 6.2 `marlin-dvr-icon.png` has no role here

It is the Unraid container's icon and belongs to the **marlin-dvr** project — `COLD-START.md`'s
runtime-host row records that project's `deploy/marlin-dvr.xml` `<Icon>` pointing at
`marlin-dvr-icon.png` on the Unraid share. **It is a different project's asset for a different
purpose, and it is excluded from the §4 mapping.**

One factual note so nobody is tempted by it later: it happens to be **exactly 400 × 240**, which is
the App Icon 1x size. That is a coincidence of dimensions and **not** a reason to use it — it is the
server's branding, not this app's, and it is flat where the slot needs three layers.

---

## 7. PLAN for a later pass — on paper only, nothing built or moved

### Part A — what the owner needs to generate

**The four Top Shelf images are already done** (§4.1) and need nothing.

The gap is the app icon, and it is a *shape* gap, not a size gap: **it must be delivered as three
layers, not one flat image.**

1. **Decide the layer split first.** The three layers are `Back`, `Middle`, `Front`, each the full
   slot size, stacked back-to-front. Typically the background/plate goes in `Back` and the elements
   meant to float go in `Middle`/`Front` with transparency around them. **This is an artwork
   decision, not a technical one, and it is the owner's** — nothing here proposes a split.
2. **Generate `App Icon` @2x — three images at exactly 800 × 480**, one per layer.
3. **Generate `App Icon` @1x — three images at exactly 400 × 240**, one per layer.
4. **Generate `App Icon - App Store` @1x — three images at exactly 1280 × 768**, one per layer.
   **There is no 2x for this slot**, so `AppStore-2560x1536.png` has no destination as-is.
5. **Transparency:** the front two layers need transparent regions or the stack cannot read as
   layered. **Whether Xcode enforces this, and whether the back layer must be opaque, is UNVERIFIED
   (§2.3)** and is an open question below rather than a stated requirement.
6. **`AppIcon-1024-square.png` cannot be used** in any slot without cropping or recomposition (§4.3).
   If it is the master artwork, the 5:3 renders should come from it rather than the reverse.

### Part B — what the builder would then do

7. Drop each image into its layer's `Content.imageset` inside
   `Marlin DVR TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/` and add the `filename`
   key to the matching entry in that imageset's `Contents.json`. **No build setting changes** —
   `ASSETCATALOG_COMPILER_APPICON_NAME` is already correct (§5).
8. Build, and confirm an `Assets.car` now exists in the bundle and that `CFBundleIconName` appears
   in the built `Info.plist` — the two checks §5 used to prove today's absence, run in reverse.

### Part C — two honest routes for getting the artwork in, NOT chosen here

- **Route 1 — the owner regenerates the app icon as three layers.** Truest to the platform: the icon
  gets the parallax effect on focus, which is what the layered format exists for. **Cost:** he has to
  produce nine new images and decide the split.
- **Route 2 — the same flat artwork in all three layers, or in `Back` with the others transparent.**
  **Cost:** the icon would be flat and would not parallax; and whether an imagestack with empty or
  duplicate layers is even legal is **UNVERIFIED (§2.3)**. Cheaper, possibly not valid, and visibly
  less good on the platform.

**I have not chosen between them.** Route 1 is more work and Route 2 may not be permitted at all;
that trade is the owner's, and the unverified point should be settled first.

---

## 8. Open questions

1. **Which slots App Store Connect actually requires (§2.2).** Not establishable on this Mac; the
   gate is Apple's server. §7 plans for all four, which is safe either way. *What breaks without an
   answer:* nothing, unless the owner wants to do less work than "fill all four".
2. **Whether all three layers must be populated, and the transparency rule per layer (§2.3, §2.4).**
   The toolchain has transparency diagnostics but their conditions were not extractable without
   running `actool`, which this pass may not do. **This is the question that decides whether Route 2
   in §7 exists at all.** *What breaks without it:* the owner might generate nine images when three
   would have done, or three when nine are needed.
3. **Whether the Apple TV Home screen draws the app name under the icon (§6.1).** Platform behaviour;
   no device or Simulator run was permitted. It decides whether "MARLIN TV" in the artwork would sit
   above a differing "Marlin DVR TV" label.
4. **Whether the artwork should say "Marlin DVR TV" at all.** The rendered text and the app's name
   differ (§6.1). **Not a technical defect and nothing was changed** — reported so the owner decides
   before regenerating.
5. **Whether `icon-source/` should enter the repo.** It is nine untracked files totalling ~21 MB.
   **This pass committed none of them**, as instructed; whether the artwork belongs in git is the
   owner's call.

---

## 9. SCOPE CHECK — every file touched or created

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md`, `DECISIONS.md` | read | step 0 / required reading |
| `icon-source/` (9 PNGs) | **read only** — `sips` and `file` metadata; **none committed** | steps 3, 4, 6.2 |
| `Marlin DVR TV/Assets.xcassets/…brandassets/` (13 `Contents.json`) | **read only** | steps 2.1, 2.3, 5 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **read only** | steps 5, 6.1 |
| `Info.plist` | **read only** | step 6.1 |
| Built `Marlin DVR TV.app` (existing artifact in DerivedData) | **read only**; **nothing built** | steps 5, 6.1 |
| Xcode 26.6 frameworks and `actool` | **read only** (`strings`, `--help`) | step 2 |
| `reports/2026-09-08-pass51-tvos-icon-recon.md` | **created — the only write** | DELIVERABLE, step 8 |

**No image file was added, edited, resized, converted, renamed, moved or deleted.** No asset catalog,
`Info.plist`, project setting or Swift source was changed. **No build, archive, upload or validation
run.** No placeholder artwork was generated.

**Not touched:** every other folder under `~/Xcode`; the reference clone; the Marlin DVR server and
its API — **zero requests**; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share; `design/`.

**No new dependency** — `sips` and `file` are stock macOS. **No network request to Apple or anywhere
else.** No credential, token, device id or account identifier appears in this report.

---

## 10. The push, and the three readings

<!--PUSH_EVIDENCE-->

---

## CLOSING SUMMARY FOR THE OWNER

**Which of your nine files are usable as-is: four.** The four Top Shelf images —
1920×720, 3840×1440, 2320×720 and 4640×1440 — are all **exactly right**, and those two slots are
completely covered. Nothing needs doing to them.

**The app icon is the problem, and it is not about sizes.** A tvOS app icon is not one picture: it is
a **stack of three layers** — Back, Middle, Front — that the Apple TV slides against each other to
give the icon depth when you focus it. Every file you generated is a single flat picture. So
`AppIcon-800x480.png` and `AppStore-1280x768.png` are the right *pixel dimensions*, but each is at
best **one layer of three**, not an icon.

**What you need to generate** — nine images, in three sets, each set being the same artwork split
into a back, a middle and a front:

- **three at 800 × 480** (the icon at 2x)
- **three at 400 × 240** (the same icon at 1x)
- **three at 1280 × 768** (the App Store icon — this one has **no** larger version, so your
  2560×1536 file has nowhere to go except as a source to shrink from)

Two of your files are of no direct use: **`AppIcon-1024-square.png`** is square, and no tvOS slot is
square, so it can only be a master to render from; and **`AppStore-2560x1536.png`** has no slot,
because the App Store icon exists at one size only.

**Would it pass a TestFlight upload today? No — and not for a subtle reason.** Your asset catalog has
all the right slots wired up, but **every one of them is empty**: there is not a single image file in
it, and the app bundle that is already built has **no compiled assets at all** and no icon entry in
its Info.plist. There is nothing there to validate.

**One thing to decide before you regenerate anything.** The artwork has **"MARLIN TV"** rendered into
it, but the app is actually called **"Marlin DVR TV"** — the artwork is missing the "DVR". On tvOS
the Home screen shows the app's name under the focused icon, so you would likely see one name in the
picture and a different one beneath it. I could not verify that display behaviour without running a
device, so treat it as a thing to check rather than a certainty — but the two strings differing is a
plain fact worth knowing before you commit to artwork.

**`marlin-dvr-icon.png` I left out**: it is the Unraid container's icon and belongs to the marlin-dvr
project. It happens to be exactly 400×240, which is a real tvOS icon size — that is a coincidence,
not an invitation.

**What this pass cost.** Read-only throughout: four git reads, metadata read from nine PNGs with two
stock macOS tools, thirteen asset-catalog definition files read, Xcode's own tvOS framework
interrogated for its size vocabulary, and one file written — this report. No build, no upload, no
image touched, no server request.

**The three things I am least certain about.**

1. **Whether all three layers must actually be filled, and what the transparency rule is.** This is
   the one that decides how much work you have — nine images or possibly three. Xcode's tools clearly
   have transparency checks, but I could not read their rules without running them, and running them
   was out of scope. I would rather tell you I do not know than guess and have you render nine images
   for nothing.
2. **Exactly which icons Apple will reject a build for omitting.** That check happens on Apple's
   servers, not on your Mac, so I could not establish it. The plan fills all four slots, which is
   safe whichever way it turns out.
3. **Whether the name really does appear under the icon.** I am fairly confident it does, but I
   could not run a device or Simulator to confirm it, so the "MARLIN TV" versus "Marlin DVR TV"
   consequence rests on that unverified point.
