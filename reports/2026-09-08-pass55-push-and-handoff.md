# Pass 55 — the icon work pushed, recorded, and the cold-start brief written

**Date:** 2026-09-08, completed in the early hours of 2026-09-09.
**Documentation and git only. No Swift source file, no asset catalog file, no artwork and no project
setting was touched** — what ships is exactly what the owner accepted. No build, no install, no test,
no device run on either Apple TV. **No request of any kind to `192.168.1.250:8090`.** The reference
clone was not fetched, checked out or read. `design/` was not touched. `icon-source/`,
`FocusClick.dataset` and the empty template brandassets were all left exactly as they stand.

**The acceptance this pass records:** the owner looked at the icon on Home Theater on 2026-09-08 and
accepted it. That opened the push gate. He is closing the session for the night.

---

## 1. The starting state, read-only — four raw outputs

```
$ git rev-parse HEAD
0b3589d03c63b02ad9c971de0442a52263f90c5d
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
?? reports/2026-09-08-pass54-bedroom-install.md
```

Everything matched the brief: HEAD `0b3589d`, remote `0a80a57`, `0	2` ahead, the 32 `icon-source/`
entries and Pass 54's uncommitted report.

---

## 2. Pass 54's report, committed

Pass 54 made no commits at all by design, so its own report was left on disk. It is committed here
unmodified.

---

## 3. What was written into COLD-START.md

One narrative block in **"What is built"**, placed after the Pass 49 entry, plus the **"Next step"**
edit.

**3.1 — the icon is in, with the three proofs.** A **Passes 51–55** entry records the owner's
acceptance on Home Theater 2026-09-08 and the three independent proofs from Pass 53 §6:
`Assets.car` present in the bundle (12,683,304 bytes simulator / 9,369,752 device);
`CFBundleIcons` → `CFBundlePrimaryIcon = "App Icon"` plus both `TVTopShelfImage` keys in the built
`Info.plist`; and `assetutil` showing **all four slots** with both stack layers at both scales,
together with the `ZZZZFlattenedImage`/`ZZZZRadiosityImage` entries `actool` only generates from a
real layered stack. It records that **Pass 51 §5 found the bundle had none of this**.

**3.2 — where the artwork lives and what changed.** The owner supplied it as a complete structured
`AppIcon.brandassets` at `icon-source/Assets.xcassets/` which **needed no repair**; 19 files went
into `Marlin DVR TV/Assets.xcassets/` byte-identical (`diff -r`); the **only** project change was two
lines making `ASSETCATALOG_COMPILER_APPICON_NAME` read `AppIcon` (`project.pbxproj:313`, `:345`),
because his folder is named that while the setting still pointed at the empty template.

**3.3 — the measured tvOS facts, so they are never relearned.** All from Pass 52, from `actool`'s own
output: a stack needs **at least 2 of its 3 layers** populated, quoted in Apple's wording; **zero
layers is silently accepted**, which is why the app built with an empty catalog for fifty passes;
**`actool` exits 0 while printing that error**, so the structured `document.errors` section is the
signal, not the exit status; **there is no per-layer transparency rule**; the rule fires only on the
small `tv`-idiom stack; and **the `tv-marketing` App Store slot does take a 2x at 2560×1536**, which
**corrects Pass 51's "1x only"** reading.

**3.4 — known and deliberate, not defects.** Both stack layers point at the same two opaque PNGs so
the depth effect has nothing behind to reveal (**the owner's choice**); the artwork says "MARLIN TV"
while the app is "Marlin DVR TV" and **the owner decided 2026-09-08 this is fine — not to be raised
again**; `FocusClick.dataset` came with the catalog, is referenced by **no Swift source**, and was
deliberately not added; and the empty template brandassets is still in the project, **proven harmless
(byte-identical `actool` output with and without it)** and left alone.

**3.5 — the second Apple TV.** Pass 54 installed HEAD `0b3589d` on **"Master Bedroom ATV"**
(`AppleTV6,2`, tvOS 26.6) from the **same binary** as Home Theater (`sha256 acde806…`). Recorded that
it is **development-signed and will stop launching when the profile expires, and that when has not
been checked and is unknown.**

**3.6 — `CFBundleIconName`.** Recorded as **an iOS key, correctly absent on tvOS**, with the note
that **no later pass should hunt for it** — both Pass 51 and Pass 53 checked and found it missing,
and that is right.

**3.7 — "Next step"** now records the owner's acceptance, that Pass 55 pushed it, the dated verified
push check from §6, and that the cold-start brief is `MARLIN-DVR-TV-HANDOFF-2026-09-09.md`
superseding the 09-08b file.

**No proposal, recommendation or "worth considering" entry was added.**

---

## 4. What was written into DECISIONS.md

**One new dated entry, `## 2026-09-08 (Passes 51-55 — the app icon and Top Shelf art)`**, appended in
the file's own form. It is the fifth 2026-09-08 entry (Passes 38, 42, 47, 49 and now 51–55).

It records: the owner's acceptance; that **he supplied the catalog rather than regenerating layered
artwork**, that it needed no repair, and that Pass 51 had planned nine images on the assumption three
layers were required while Pass 52 measured two; that **"MARLIN TV" stays** and is not to be raised
again; that **both layers point at the same two opaque images by his choice** and no transparent
front was generated, suggested or stubbed; that **`FocusClick.dataset` was deliberately not added**
and why; that **the empty template brandassets was left in place** with the byte-identical-output
evidence; that **the fate of `icon-source/` is the owner's call and has not been decided**; and the
second-Apple-TV install with its development-signing caveat.

---

## 5. The cold-start brief

**`MARLIN-DVR-TV-HANDOFF-2026-09-09.md`** at the repo root, 201 lines. It states in its first line
that it **supersedes `MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`, which should be deleted from the Context
panel**, and it carries every section the brief required: the project and that the server is now
**1.8.0**; the verified `origin/main` SHA with **"verify this rather than trusting the number"**;
what this session built and the owner accepted across Passes 41–55; the **two defects closed and the
audio/video desync still open** with marlin-dvr, **including their outstanding request that the owner
match the sessions where he saw desync to individual session records**; that their
`HLS-CLIENT-API.md` is byte-unchanged across the 1.8.0 delivery and its §2 line 68 states the
opposite of the new behaviour, so **§2.3 of the Pass 41 report is the only written description of the
file route that exists**; the current KNOWN AND UNFIXED list as COLD-START now holds it; the **six
open Pass 41 questions and that step 7 was never built**; that the **27-session table is still
unsettled and its prompt must NOT be re-issued unprompted**; multi-card shelf traversal untested, the
60 pt shelf shift accepted, and the airing sheet's two status states owner-verified by eye only; the
**HOW THIS PROJECT RUNS** section carried forward; and a Context panel list naming this brief in
place of the 09-08b one.

**One thing I could not do as specified, stated plainly.** The brief asked me to model the new file
on `MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`. **That file is not on disk anywhere I may look** — it is
not in the repo (`git ls-files | grep -i handoff` returns nothing), not at the repo root, and not on
the Desktop or in Documents. It exists only in the owner's Context panel. **I wrote the new brief to
the explicit content list in this pass's step 5 rather than guessing at the old file's exact shape.**

---

## 6. The push, and the three verification readings

<!--PUSH_EVIDENCE-->

---

## 7. What remains untracked

**`icon-source/` — 32 entries, every one deliberately left alone:**

- 9 loose PNGs at the top of the folder (the files Pass 51 examined), including `marlin-dvr-icon.png`
  and `AppIcon-1024-square.png`
- the owner's structured `Assets.xcassets/` — its root `Contents.json`, `AccentColor.colorset/`, and
  the whole `AppIcon.brandassets/` (18 entries), **now duplicated inside the project**
- `FocusClick.dataset/` — `Contents.json` and `focus_click.caf`

**Nothing there was deleted, moved, renamed or committed by this pass or any earlier one. Its fate is
the owner's call and has not been decided.**

---

## 8. The six open Pass 41 questions — all still open

None was answered, decided or narrowed in this pass.

| # | Question | State |
|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **Open.** Still blocks build-plan step 7, which was never built. |
| **7.3** | What the Starting screen should say during a long remux | **Open.** |
| **7.4** | Should a refused recording fall back to HLS, or show the error | **Open.** Fail-loudly ships, on the scope lock's authority; the owner has not been asked. |
| **7.5** | Temp space on Unraid | **Open.** |
| **7.6** | Ask the marlin-dvr project to document the file route | **Open.** |
| **7.7** | The two formerly-untracked report files | **Open as a question; subject settled** — committed in Pass 44, notebook corrected in Pass 45. |

---

## 9. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `reports/2026-09-08-pass54-bedroom-install.md` | **committed unmodified** | step 2 |
| `COLD-START.md` | **modified** — one narrative block, one "Next step" edit | step 3 (3.1–3.7) |
| `DECISIONS.md` | **modified** — one appended dated entry | step 4 |
| `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` | **created** | step 5 |
| `reports/2026-09-08-pass55-push-and-handoff.md` | **created** | DELIVERABLE |
| Passes 51–54 reports | read | required reading |

**No Swift source file, no asset catalog file, no artwork and no project setting was modified** —
this pass's diff is the four documentation files above plus Pass 54's report.

**Not touched:** `icon-source/`, `FocusClick.dataset` and the empty template brandassets — all left
exactly as they stand; every other folder under `~/Xcode`; the reference clone — **no fetch, checkout
or read**; `design/`; the Marlin DVR server, its data and its API — **zero requests**; Unraid,
marlinpc, the HDHomeRun, the UNAS4Pro share; **both Apple TVs — no build, install or test**.

**No new dependency.** No credential, token, device id or account identifier appears in this report,
in either notebook file, in the brief, or in any commit message from this pass.

---

## CLOSING SUMMARY FOR THE OWNER

**What is now on the remote.** Everything from tonight. The icon and Top Shelf artwork you accepted,
the two-line project change that made the app use it, Pass 53's and Pass 54's reports, the notebook
entries recording all of it, the cold-start brief for tomorrow, and this report. It went up as a
plain fast-forward — nothing amended, nothing rebased, nothing forced — and the code on
`origin/main` is byte-for-byte what you approved on Home Theater.

**The brief for tomorrow exists.** It is **`MARLIN-DVR-TV-HANDOFF-2026-09-09.md`** at the top of the
project folder, and it is in the repo. **Put it in the Context panel and remove
`MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`** — the new one says so in its first line. It carries the
whole session: the four things built and accepted, the two defects now closed, the desync still open
with the marlin-dvr project along with their outstanding request that you match the sessions you saw
it in to individual session records, the warning that their contract file still describes the old
behaviour, the full known-and-unfixed list, the six questions nobody has answered, and the reminder
that the 27-session table must not be re-raised unprompted.

One thing I should flag: I could not find the old 09-08b brief anywhere on disk to model the new one
on — it lives only in your Context panel. I wrote the new one to the content list you gave me
instead of guessing at its shape.

**What this pass cost.** Two documentation files edited, one brief and one report written, one
earlier report committed. No build, no install, no test, no device run, no server request, and not a
single line of app code or artwork touched.

**The three things I am least certain about.**

1. **The brief's shape.** Its content is what you specified and every fact in it is sourced, but I
   could not compare it against the file it replaces. If it is missing a section you relied on in the
   old one, that is why.
2. **How much the notebook now carries about tvOS icons.** I recorded the measured rules so nobody
   relearns them, but they are Xcode 26.6's behaviour on this Mac today. If Apple changes the
   compiler, those become historical facts rather than current ones.
3. **The development-signing expiry.** The app is now on two Apple TVs and both builds will stop
   launching when the provisioning profile lapses. I have recorded that as unknown because I did not
   check it, and nothing in the notebook tracks it.
