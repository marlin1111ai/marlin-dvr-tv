# Pass 52 — the tvOS icon layer question, settled with actool

**Date:** 2026-09-08
**Exactly one lasting file is written: this report.** All experimental work happened in
`/tmp/marlin-icon-probe/`, which was **deleted and proved gone** (§6). The app's real asset catalog,
`Info.plist`, `project.pbxproj`, every project setting and every Swift source were **not touched**.
No icon was wired in, even temporarily. No build or archive of the actual app, no upload to Apple,
**no network request of any kind**, and **no request to `192.168.1.250:8090`**. `icon-source/` was
copied *from* and never written to — proved by hash (§2, §6).

**Headline: the answer is two, not three.** Apple's own compiler says so in as many words.

---

## 1. Git state, read-only — four raw outputs

```
$ git rev-parse HEAD
9d633fec3c821fe53cafc2022e38a12716ab95f8
```

```
$ git rev-parse origin/main
9d633fec3c821fe53cafc2022e38a12716ab95f8
```

```
$ git ls-remote origin main
9d633fec3c821fe53cafc2022e38a12716ab95f8	refs/heads/main
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

All three SHAs read `9d633fe`, and `git rev-list --left-right --count origin/main...HEAD` returned
**`0	0`** — nothing ahead, nothing behind. The tree is clean apart from the nine untracked PNGs.
Every expectation in the brief matched, so the pass proceeded.

---

## 2. What was copied to scratch, and the hash proof

Three files were **copied** (never moved, never opened for writing) into `/tmp/marlin-icon-probe/art/`:

| Source in `icon-source/` | Scratch name | Real size | Alpha |
|---|---|---|---|
| `AppIcon-800x480.png` | `L800.png` | 800 × 480 | yes |
| `AppStore-1280x768.png` | `L1280.png` | 1280 × 768 | yes |
| `marlin-dvr-icon.png` | `L400.png` | 400 × 240 | yes |

`marlin-dvr-icon.png` was used **only as a 400×240 test bitmap inside scratch** — it is the
marlin-dvr project's asset (Pass 51 §6.2) and nothing here proposes it for this app. It was chosen
because it is the one file already at the exact 1x size.

Three **opaque** variants (`O400`, `O800`, `O1280`) were derived inside scratch by a JPEG round-trip
with `sips`, purely as test fixtures for the transparency runs. **No artwork the owner will use was
generated, resized or edited.**

**Hash proof — `sha256` over all nine, taken before any copying and again after the scratch
directory was deleted:**

```
$ diff <before> <after>
(no differences)
IDENTICAL — all nine unmodified
```

The nine hashes are reproduced in §6.

---

## 3. Every actool run

**Invocation, identical for every case** apart from the catalog and output paths:

```
xcrun actool --output-format human-readable-text --notices --warnings --errors \
  --platform appletvos --minimum-deployment-target 18.0 --target-device tv \
  --app-icon "App Icon & Top Shelf Image" \
  --output-partial-info-plist <partial>.plist \
  --compile <outdir> <catalog>.xcassets
```

Each throwaway catalog reproduced the app's real brandassets shape: a
`primary-app-icon` stack at `400x240` with `1x`+`2x` per layer, and a `primary-app-icon` stack at
`1280x768` with `1x` only — the structure Pass 51 established. "Layers populated" means an actual
PNG plus a `filename` key; unpopulated layers keep their empty `Contents.json`, exactly as the real
catalog has them today.

### 3.1 Case A — control, all three layers in both stacks

Images present: 3 layers × 2 scales (small) + 3 layers × 1 scale (App Store) = 9 files.

```
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-probe/out-all3/Assets.car
/tmp/marlin-icon-probe/partial-all3.plist

--- exit: 0 ---
```

**Clean — no errors, no warnings, no notices.** `Assets.car` produced, 7,749,256 bytes. Its partial
Info.plist:

```xml
<key>CFBundleIcons</key>
<dict><key>CFBundlePrimaryIcon</key><string>App Icon</string></dict>
```

### 3.2 Case B — only ONE layer (Back) populated, in both stacks

```
/* com.apple.actool.document.errors */
/tmp/marlin-icon-probe/B-backonly.xcassets:./App Icon & Top Shelf Image.brandassets/App Icon.imagestack: error: The image stack "App Icon" must have at least 2 layers with applicable content. Although it has 3 layers, only 1 has applicable content.
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-probe/out-backonly/Assets.car
/tmp/marlin-icon-probe/partial-backonly.plist

--- exit: 0 ---
```

**This single line is the whole answer to the pass's question**, and it is Apple's wording, not mine:

> **"The image stack "App Icon" must have at least 2 layers with applicable content. Although it has
> 3 layers, only 1 has applicable content."**

### 3.3 Case C — TWO layers (Front + Back) populated, in both stacks

```
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-probe/out-two/Assets.car
/tmp/marlin-icon-probe/partial-two.plist

--- exit: 0 ---
```

**Clean.** Two layers is sufficient; the third is not required.

### 3.4 Cases D–H — isolating which stack the rule applies to

| Case | small `App Icon` | `App Icon - App Store` | actool output |
|---|---|---|---|
| **D** | 3 layers | **1 layer** | **clean, no error** |
| **E** | **1 layer** | 3 layers | **error on `App Icon`** (same text as B) |
| **F** | 3 layers | **0 layers** | **clean** |
| **G** | **0 layers** | 3 layers | **clean** |
| **H** | **0 layers** | **1 layer** | **clean, no error** |

Full output for E, the only one that errored:

```
/* com.apple.actool.document.errors */
/tmp/marlin-icon-probe/E-smallone.xcassets:./App Icon & Top Shelf Image.brandassets/App Icon.imagestack: error: The image stack "App Icon" must have at least 2 layers with applicable content. Although it has 3 layers, only 1 has applicable content.
```

D, F, G and H each produced only the two compilation-results lines and no diagnostics.

**Two things fall out of this table.** The rule fires **only on the small `App Icon` stack** — case H
isolates the App Store stack alone at one layer and it passes. And **an entirely empty stack is
silently accepted** (F, G), which is precisely why the real app builds today with a wholly empty
catalog, as Pass 51 §5 found.

**`CFBundlePrimaryIcon` across the runs:**

```
all3:            App Icon
two:             App Icon
storezero:       App Icon
smallzero:       Print: Entry, ":CFBundleIcons:CFBundlePrimaryIcon", Does Not Exist
storeone-only:   Print: Entry, ":CFBundleIcons:CFBundlePrimaryIcon", Does Not Exist
```

The bundle's icon key comes from the **small 400×240 stack**. With that stack empty, no icon key is
emitted at all — however well populated the App Store stack is.

### 3.5 Cases I–L — the transparency variants

Run on the small stack, each layer's real colour type verified with `file -b` before the run.

| Case | Front | Middle | Back | actool output |
|---|---|---|---|---|
| **A** (control) | RGBA | RGBA | RGBA | **clean** |
| **I** | RGB (opaque) | RGB | RGB | **clean** |
| **J** | RGBA | RGBA | **RGB (opaque back)** | **clean** |
| **K** | RGB | RGB | **RGBA (transparent back)** | **clean** |
| **L** | RGB | *(empty)* | RGB | **clean** — two layers, no alpha anywhere |

Every one produced only:

```
/* com.apple.actool.compilation-results */
…/Assets.car
…/partial-*.plist

--- exit: 0 ---
```

**No warning, no note, no error mentioning alpha or transparency in any run.**

### 3.6 One behaviour worth recording precisely: the exit code

Re-run with the exit status captured directly rather than through the runner:

```
actool exit code (1-layer case): 0
/* com.apple.actool.document.errors */
… error: The image stack "App Icon" must have at least 2 layers with applicable content …
/* com.apple.actool.compilation-results */
/tmp/marlin-icon-probe/out2/Assets.car

actool exit code (2-layer case): 0
```

**`actool` exits 0 even when it prints a `document.errors` entry, and still writes an `Assets.car`.**
The signal is the structured error section, not the exit status. (For contrast, a genuinely fatal
invocation error — a missing output directory — did exit `1`.)

**Whether Xcode fails a build on that error section is NOT established here.** Testing it would need
a real build of the app, which this pass is forbidden. **Marked unverified.**

---

## 4. The three questions

### Q1 — Must all three layers be populated? **SETTLED: NO.**

**At least two layers must have content. Three is not required. One is an error. Zero is silently
accepted.**

How: case B and case E each produce the error verbatim quoted in §3.2 — *"must have at least 2
layers with applicable content"*. Case C (two layers) and case A (three) compile clean. Cases F and G
show an empty stack draws no complaint at all.

**This differs from what Pass 51 assumed.** Pass 51 §7 planned for **nine** app-icon images (3 layers
× 3 size/scale combinations) and listed "whether all three layers must be populated" as unverified.
The tool says two layers per stack suffices, so the real minimum is **six**, not nine — see §5. Pass
51 was not wrong, it was uncommitted; this pass commits it.

### Q2 — The per-layer transparency rule? **SETTLED at compile time: there is none.**

**`actool` enforces no alpha requirement on any layer.** All-alpha, all-opaque, opaque-back, and
transparent-back all compiled clean with no diagnostic mentioning transparency (§3.5, five cases).

Two limits stated rather than glossed:

- **This is the compiler's view only.** What App Store Connect does with alpha is not knowable
  locally and is **unverified** — it is the same server-side gate the brief excludes.
- **Compiling clean is not the same as looking right.** A stack whose front layers are fully opaque
  will hide the ones behind it, so the parallax effect the layered format exists for would have
  nothing to show. **That is an appearance judgement I cannot make** — I cannot see the artwork — and
  `actool` plainly does not police it.

### Q3 — Do both icon slots behave the same? **SETTLED: NO.**

**The ≥2-layer rule is enforced on the small `App Icon` (400×240) stack only.** The
`App Icon - App Store` (1280×768) stack accepted **one** layer (cases D and H) and **zero** layers
(case F) without any diagnostic.

A second asymmetry, from the partial plists (§3.4): **`CFBundlePrimaryIcon` is emitted only when the
small stack has content.** The App Store stack does not produce the app bundle's icon key at all —
consistent with it being consumed at submission rather than by the app.

**Unverified:** whether App Store Connect independently requires the App Store stack, or requires it
layered. Server-side, excluded by the brief.

---

## 5. What the tool proved about how much artwork is needed

This restates Pass 51's plan with the measured minimum substituted. **No step is added that Pass 51
did not have.**

**The four Top Shelf images are unchanged and already done** — `TopShelf-1920x720.png`,
`TopShelf-3840x1440.png`, `TopShelfWide-2320x720.png`, `TopShelfWide-4640x1440.png` are exact
(Pass 51 §4.1). Nothing here touches that.

**For the app icon, the compiler's minimum is two layers per stack:**

| Slot | Scale | Layers needed | Exact pixels | Count |
|---|---|---|---|---|
| `App Icon` | 1x | 2 (e.g. Back + Front) | **400 × 240** each | 2 |
| `App Icon` | 2x | the same 2 layers | **800 × 480** each | 2 |
| `App Icon - App Store` | 1x only | 2 layers *(see below)* | **1280 × 768** each | 2 |
| | | | **total** | **6** |

**Six images, not nine** — if the owner takes the two-layer minimum. Three layers per stack is still
permitted and still compiles (case A); it is a choice about depth, not a requirement.

**On the App Store stack specifically:** `actool` accepted it with one layer and with none (§4 Q3),
so its two layers are **not** compiler-enforced. Whether to fill it at all, and with how many layers,
turns on the App Store Connect question this pass may not answer. **Filling it with two is the safe
reading and is what the table assumes; that is a judgement, not something the tool proved.**

**Per-layer transparency: no requirement to satisfy**, only the practical point that opaque front
layers will occlude the ones behind (§4 Q2).

---

## 6. Cleanup, proved

```
$ rm -rf /tmp/marlin-icon-probe
$ ls -la /tmp/marlin-icon-probe
ls: /tmp/marlin-icon-probe: No such file or directory
$ find /tmp -maxdepth 1 -name "marlin-icon-probe"
(no output)
$ pgrep -fl actool
(no output)
```

The scratch directory held 98 MB across 12 test catalogs and their outputs. **It is gone**, no actool
process is left running, and the three temporary hash files under `/tmp` were removed too.

**`icon-source/` after the pass — all nine present and byte-identical to before:**

```
42425d92fcec3c4422b196f65f2a3836b815f4fa0b0074c4d5fe0ccbb92a371d  icon-source/AppIcon-1024-square.png
d9efd7ff1d0e9caa59fd4fb3a150fb63221a81e4953e2dfa8543fd54d12bd81d  icon-source/AppIcon-800x480.png
b37d421184fa35b640f840efe105084edefb00dcb2a98029b67e526ea2099170  icon-source/AppStore-1280x768.png
7710ffdc2ad8d663984515bcc153e33e1856e70da724083338ac93e8dd6e3c2e  icon-source/AppStore-2560x1536.png
7d41016e0da61de1d82aa19d5d4d16652a2086f319c63b3d2dfc5e6fa5d504f6  icon-source/marlin-dvr-icon.png
ed1be017cf04166430e7fa698c53f0940961f9567cf1ba68401ddb54e72b9037  icon-source/TopShelf-1920x720.png
e2b5df14d56aec597591494fffd17bd5289d81459f095feb5f227de8e27ed841  icon-source/TopShelf-3840x1440.png
3d7a68b59f08ede8a1bb28f75a4f1d3cf3fa8b39f213760e7da2ea133ba66de0  icon-source/TopShelfWide-2320x720.png
35cb19c7493ec47511e837f1ad3bc196821b5f8e10b63b316cdd5f18de35bfd7  icon-source/TopShelfWide-4640x1440.png
```

`diff` against the hashes taken before any copying: **no differences.** Count: **9**.

---

## 7. The push, and the three readings

The push was a plain fast-forward — two dots, no `+`:

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   9d633fe..ac704f2  main -> main
```

Then `git fetch origin` (exit 0), and the three readings, each as its own command:

```
$ git rev-parse HEAD
ac704f271c1ec1207b59b1bc38820569cce1233e
```

```
$ git rev-parse origin/main
ac704f271c1ec1207b59b1bc38820569cce1233e
```

```
$ git ls-remote origin main
ac704f271c1ec1207b59b1bc38820569cce1233e	refs/heads/main
```

**All three agree**, and the remote was read back rather than trusted from local state. Nothing was
forced, rebased or amended.

**Only this report went up** — 1 file changed. `git status` after staging showed the report staged
and **all nine `icon-source/` PNGs still untracked**, and they remain so; nothing from the scratch
directory was committed either. A second commit records these SHAs, since they cannot exist inside
the commit they name.

---

## 8. Open questions

1. **The App Store Connect requirement is still unverified**, as the brief instructed. `actool`
   accepts an app with no icon at all (cases F, G), so **the compiler is not the gate** — what Apple
   rejects on upload cannot be learned on this Mac.
2. **Whether Xcode fails a build on `actool`'s error section (§3.6).** `actool` itself exits 0 while
   printing the error. Testing it needs a real build, which this pass may not do. *What breaks
   without it:* nothing for the owner's decision — the error is unambiguous either way.
3. **Whether two layers looks acceptable.** The tool permits it; whether the icon reads well with two
   rather than three is an appearance question, and **I cannot see the artwork.**
4. **The 400×240 fixture was the marlin-dvr icon.** It was a convenient bitmap of the right size in
   a throwaway catalog, nothing more. If some property of that particular file influenced a result,
   the runs at 800×480 and 1280×768 used the owner's own artwork and behaved identically —
   but I did not test a third distinct 400×240 image.

---

## 9. SCOPE CHECK — every file touched or created

| Path | Access | Required by |
|---|---|---|
| `icon-source/` (3 of 9 files) | **read, copied out; never written** — hash-proved unchanged | step 2 |
| `/tmp/marlin-icon-probe/` | **created, written, and deleted** | steps 2, 3, 6 |
| `reports/2026-09-08-pass52-icon-layer-probe.md` | **created — the only lasting write** | DELIVERABLE, step 7 |
| `reports/2026-09-08-pass51-tvos-icon-recon.md` | read | required reading |
| `xcrun actool`, `sips`, `file`, `shasum` | run read-only against scratch | steps 2, 3 |

**Not touched:** the app's real `Assets.xcassets`, `Info.plist`, `project.pbxproj` and every project
setting; every Swift source; every other folder under `~/Xcode`; the reference clone; `design/`; the
Marlin DVR server and its API — **zero requests**; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro
share.

**No icon was wired in.** No artwork for the owner was generated, resized, converted or edited. **No
build or archive of the app, no upload, no network request.** **Nothing from `icon-source/` or from
scratch was committed** — only this report.

**No new dependency** — `actool`, `sips`, `file` and `shasum` are all part of the installed
toolchain. No credential, token, device id or account identifier appears in this report.

---

## CLOSING SUMMARY FOR THE OWNER

**Six images, not nine.** Apple's own icon compiler answered the question in one sentence:

> *"The image stack "App Icon" must have at least 2 layers with applicable content. Although it has
> 3 layers, only 1 has applicable content."*

So a tvOS icon needs **at least two layers, not three**. I proved it both ways — one layer is a hard
error, two compiles clean, three compiles clean. Pass 51 had planned for nine images because it could
not settle this without running the tool; now it is settled, and a third of that work disappears.

**What to generate, at exact sizes** — the same artwork split into a **back** and a **front**:

- **two images at 400 × 240** (the icon at 1x)
- **two images at 800 × 480** (the same icon at 2x)
- **two images at 1280 × 768** (the App Store icon)

**Your Top Shelf images are already perfect and need nothing** — that has not changed.

**Transparency: the compiler does not care.** I tried every combination — everything transparent,
everything opaque, transparent front over opaque back, and the reverse — and not one produced so much
as a warning. The only practical point is that if your front layer is fully opaque it will simply
hide the back one, so the depth effect would have nothing to show. That is a judgement about how it
looks, and I cannot see your artwork.

**One useful surprise.** The rule is enforced on the small 400×240 icon **only** — the 1280×768 App
Store icon was accepted with one layer and even with none. And the app's actual icon comes from the
small stack: with that one empty, no icon is registered at all no matter what the App Store stack
holds. That is exactly why your app builds happily today with a completely empty catalog.

**What remains unknowable without uploading to Apple:** which icons App Store Connect will reject a
build for omitting. The compiler is not that gate — it will happily compile an app with **no icon
whatsoever** — so the only way to learn it is an actual upload. That is why I have kept the App Store
icon in the list at two layers: it is the safe reading, not something I proved.

**What this pass cost.** Twelve throwaway asset catalogs built and compiled in a scratch folder under
`/tmp`, 98 MB, now deleted and proved gone. Three of your files copied out and never written to —
proved by hash before and after. One file written: this report. No build of your app, no upload, no
network, no server request.

**The three things I am least certain about.**

1. **What Apple's servers require, as opposed to Apple's compiler.** I can now tell you exactly what
   compiles; I still cannot tell you what uploads. Those are different gates and only one of them was
   reachable from here.
2. **Whether two layers actually looks good.** The tool permits it and the format allows it, but a
   two-layer icon has less depth than a three-layer one, and that is a judgement about your artwork
   that I am not able to make.
3. **Whether Xcode's build fails on that error.** `actool` prints the error but still exits zero and
   still writes its output file, which surprised me. In a real build Xcode reads the error section
   and should fail — but proving that needed a build I was not to run.
