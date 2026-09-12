# Pass 83 — On Later's pills accepted and pushed, and the bedroom Apple TV brought current

**Date:** 2026-09-12
**Base commit:** `ad7f5f5` (Pass 82, "On Later's three pills").
**Result: the owner accepted On Later's three pills on Home Theater — "good to go" — Pass 82 is
pushed, and the bedroom Apple TV is built and installed from the pushed head.**

**No app-target code changed in this pass.** The binary the owner tested is Pass 82's, and the binary
installed on the bedroom Apple TV is built from those same sources. **Home Theater was not
reinstalled**, as the brief requires.

**Server traffic: none of this pass's own.** No request was made to `192.168.1.250:8090` by hand.
The only traffic to the DVR is whatever the app itself makes when it is opened on the bedroom
television — including the `POST /api/clients/{id}/ping` it has sent on every launch since sweep 1
(`ClientSession.swift:62-81`), which writes nothing but that device's own last-seen record.
**Nothing was written to the server, the lineup, the library, the schedule or `/api/collections`.**
`~/Xcode/marlin-dvr-reference` was not opened. `design/` was not opened. Unraid `192.168.1.250` as a
host, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched.

**Device identifiers, bundle container UUIDs and database UUIDs are redacted throughout**, as they
were in Pass 54.

---

## 0. One thing in the brief that could not be taken literally, and why

**Step 3 asks this report to carry "the bedroom install result from step 5", and to be committed
before the push in step 4. Those cannot both hold.** Step 5 installs **the pushed head**, and after
step 4 the pushed head *is this pass's own commit* — the one containing this report. A commit cannot
contain the result of installing itself, for the same structural reason it cannot contain its own
SHA.

**This project has settled that exact shape once already** and this pass follows it rather than
inventing a second answer: the post-push SHA "lives in the pass response and in the next pass's
notebook update" (DECISIONS.md, 2026-09-09 (Pass 60) rule (b); 2026-09-11 (Pass 68)). Pass 74 hit
the same wall and recorded it the same way — *"the step asked for it by name; this is the one place
its text could not be taken literally, and the reason is structural rather than a choice."*

**So:** §5 below records the device, the method, the exact commands and every check that will be
made, all of which are fixed before the push. **The install's own readings — the version and build
the television reports, the SHA it was built from, and the screenshot — are in the Pass 83
response and belong in the next pass's notebook entry.** Nothing is lost; it is one hop later than
the brief's wording implies.

**The alternative was considered and rejected:** installing *before* the push, so the result could
go in this file. That would have installed `ad7f5f5` rather than the pushed head, which contradicts
step 5 more directly. It is also a distinction without a binary difference — this pass changes no
app-target code, so the app built from `ad7f5f5` and the app built from the Pass 83 head are the
same bits, and §5 checks that rather than asserting it.

---

## 1. Step 1 — the tree, confirmed before anything else

```
$ git status --porcelain --untracked-files=normal
?? icon-source/

$ git rev-parse main
ad7f5f512fe7836dcc340425aa11143ca51b45f7
$ git rev-parse origin/main
54b233507c78f9b64693ef7cae5ad9d8bbe7348a

$ git log origin/main..main --oneline
ad7f5f5 Pass 82: On Later's three pills

$ git log --merges origin/main..main --oneline | wc -l
0
$ git merge-base --is-ancestor origin/main main   → yes
$ git rev-parse main^
54b233507c78f9b64693ef7cae5ad9d8bbe7348a
```

**Exactly one commit ahead, and `ad7f5f5`'s parent is `54b2335` itself — linear, no merges, no
divergence.** The only untracked entry is the standing `icon-source/`, the owner's undecided call
since Passes 51–55. **The step's condition is met and the pass proceeded.**

---

## 2. Step 2 — what the owner accepted

**"Good to go"** (owner, 2026-09-12), on Home Theater.

**The acceptance covers**, named so no later pass has to infer it from a commit message:

- On Later taking **On Now's page layout** — the header, a pill row beneath it built the same way, a
  three-column card grid;
- **exactly three pills** — "On Today" · "On This Week" · "Premieres" — and **no channel-filter
  pills**;
- the screen listing **every** upcoming airing on the channels his collections hold, with **no
  "notable" narrowing**;
- **opening on On Today every visit**, the pick not persisting;
- the **sort** by start time then channel number;
- the **empty states**, with focus staying on the pill row;
- **Select on a card** opening the airing sheet with its controls live.

**Three things were accepted explicitly rather than by silence**, and two of them close Pass 82's
open questions:

| # | What | Status |
|---|---|---|
| 1 | **The Premieres pill is empty on the current data** and says "Nothing on Premieres for your collections" | **accepted; not a defect and not an open item.** `program.premiere` is true on nothing this server holds (Pass 81), and the three derived clauses select nothing on his collection channels this week either. He was shown it before accepting |
| 2 | **The two app files touched outside `OnLaterScreen.swift`** — `Models.swift` (`ChannelCollection` gained `channelIds`) and one line at `ScreenShell.swift:99` (`onPlay`, so the sheet's "Watch live" has a Player) | **accepted as built. Closes Pass 82 open question 2** |
| 3 | **The `/api/guide` block-layout loss** — **2 airings of 140 over seven days, 1.4 %**, measured against the complete `/export/*/guide.xml` for the same five channels: a 15-minute *Monday Night Postgame* at 23:15 and a three-hour *College Football*, **both on ESPN**; the four antenna channels lost nothing | **accepted. Closes Pass 82 open question 1.** He was told which two airings and took the trade rather than `/export/guide.xml`, which is complete but cannot carry the premiere flag, `seriesId` or `rating` (`export.go:95-111`). **Nothing is to be raised with the marlin-dvr project about it** |

**Nothing else Pass 82 raised is closed by this acceptance**, and none of it is re-raised here: the
two-read sheet reconstitution (open question 3), the ≤30-minute far edge of "On This Week" (4), the
now-dead `api.later()` / `LaterResponse` / `LaterSection` / `LaterItem` (5), which sentence an
undrawable-but-non-empty union should get (6), and the card carrying no new/live/premiere tags (7).

---

## 3. Step 3 — files touched, by step

| File | Step | What |
|---|---|---|
| `DECISIONS.md` | **2** | the Pass 83 acceptance entry — **additions only, +49 −0** |
| `COLD-START.md` | **2** | the Pass 83 entry in "What is built" and a new first paragraph under "Next step" — **additions only, +37 −0** |
| `reports/2026-09-12-pass83-on-later-accepted-pushed-bedroom.md` | **3** | this report |

**No app-target file was touched**, as the brief requires — `git diff` over `Marlin DVR TV/` is
empty. No Swift source, no project file, no `Info.plist`, no entitlements, no asset, no build
setting. No test target file either. **Not touched:** `design/`, `icon-source/`, the reference clone,
every earlier report, and every other folder under `~/Xcode`.

**Neither notebook file had an existing line reworded, moved or removed.** The Passes 81-82 entry
still reads "committed locally and NOT pushed — the owner tests it first"; the new Pass 83 entry
says plainly that it supersedes that clause and that it is kept as history, which is this project's
standing way of doing it (DECISIONS.md, 2026-09-09 (Pass 56)).

---

## 4. Step 4 — the push

One commit, made **before** the push, carrying the two notebook files and this report — the Pass 68
rule that a pass's report goes inside its own commit.

The push is a **fast-forward from `54b2335`**, verified before it (§1: `origin/main` an ancestor of
`main`, no merges in the range, `ad7f5f5`'s parent `54b2335`) and again afterwards by
`git fetch origin` followed by `git rev-parse main`, `git rev-parse origin/main` and
`git ls-remote origin main` all reading the same SHA. **Nothing forced, nothing rebased, nothing
amended, and no branch other than `main`.**

**The post-push SHAs are in the Pass 83 response**, for the reason §0 gives.

---

## 5. Step 5 — the bedroom Apple TV

### 5.1 The device, and that it is the right one

```
$ xcrun devicectl list devices
Name                 Hostname                              Identifier     State                Model
------------------   -----------------------------------   ------------   ------------------   ------------------------------------------
Home Theater         Home-Theater.coredevice.local         <REDACTED>     available (paired)   Apple TV 4K (3rd generation) (AppleTV14,1)
Marlin iPhone        Marlin-iPhone.coredevice.local        <REDACTED>     available (paired)   iPhone 17 Pro Max (iPhone18,2)
Master Bedroom ATV   Master-Bedroom-ATV.coredevice.local   <REDACTED>     available (paired)   Apple TV 4K (AppleTV6,2)
```

**`Master Bedroom ATV`, `available (paired)`, Apple TV 4K `AppleTV6,2`** — the same name, the same
state and the same model COLD-START.md and Pass 54 §2 record. Three devices are reachable; one is an
iPhone and one is Home Theater, which this pass is forbidden to reinstall, so exactly one candidate
remains and it names itself. **No guessing, and no pairing code was needed.**

### 5.2 The method — Pass 54's, unchanged

COLD-START.md records the install at its Passes 51–55 entry and names
`reports/2026-09-08-pass54-bedroom-install.md`, whose §3 is the method. It is two commands, and this
pass uses both verbatim against the same device:

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'platform=tvOS,name=Master Bedroom ATV' -allowProvisioningUpdates build

$ xcrun devicectl device install app --device "Master Bedroom ATV" \
    "<DerivedData>/Build/Products/Debug-appletvos/Marlin DVR TV.app"
```

**If either stops working, or the device is unreachable, the pass stops there and reports it. No
other route is tried** — not Xcode's UI, not a re-pair, not `ios-deploy`, not a fresh provisioning
profile.

### 5.3 What the install is proved against

Four readings, all taken after the install and all quoted in the Pass 83 response:

1. **The head it was built from** — `git rev-parse HEAD`, which is this pass's own commit and which
   `git ls-remote origin main` shows is what is on the remote.
2. **What the television itself says it has**, asked of the device rather than taken from the
   installer's own report:
   `xcrun devicectl device info apps --device "Master Bedroom ATV" --bundle-id com.marlin1111.MarlinDVRTV`
   → the app's **Version** and **Bundle Version**.
3. **That the bits are the ones the owner accepted.** This pass changes no app-target code, so the
   binary built here must be identical to the one built from `ad7f5f5`. That is **checked by hashing
   the executable**, not asserted.
4. **One screenshot of On Later on that television, showing the three pills** — which is new. Pass 54
   deliberately made no claim about how anything looked, because it had no way to see the screen;
   this pass drives the device's own remote to capture it.

**The bedroom Apple TV had run Pass 53's `0b3589d` since 2026-09-08 — 28 commits behind `ad7f5f5`,
29 behind the head this pass pushes.** Everything from the Weather fixes through the Search screen,
the Guide's collections, its scroll-right, its clock and On Later's pills arrives on that television
in one step.

**It remains a development-signed build** and will stop launching when the provisioning profile
expires; when that is has still not been checked, and was not in this pass's scope.

---

## 6. What is left local

**Nothing.** After step 4 the working tree's only entry is the standing untracked `icon-source/`, and
`main`, `origin/main` and `git ls-remote origin main` all read this pass's commit. The three
readings are in the Pass 83 response.

**Nothing forced. No history rewritten.**
