# Marlin DVR TV — cold-start brief, 2026-09-09

**This file supersedes `MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`. Delete that one from the Context
panel.**

Facts only. Nothing here proposes work. **The owner directs what happens next.**

---

## 1. The project

- **Marlin DVR TV** — a tvOS app (SwiftUI), client of the Marlin DVR server.
- **Folder:** `~/Xcode/Marlin DVR TV` — the only writable tree.
- **Repo:** `git@github.com:marlin1111ai/marlin-dvr-tv.git`, branch `main`, **public**.
- **Server:** `http://192.168.1.250:8090/` — Marlin DVR on Unraid, source repo
  `git@github.com:marlin1111ai/marlin-dvr.git`.
- **The server is now marlin-dvr 1.8.0.** The owner read his own Status page on 2026-09-08 and it
  showed **VERSION 1.8.0, "up to date · checked 45m ago"** (owner, 2026-09-08). Not measured from
  this project — the running server is on the do-not-touch list.
- **Read-only reference clone:** `~/Xcode/marlin-dvr-reference`. Its checkout is still at **1.2.1**;
  its `origin/main` was last fetched in Pass 41 and reads `095de81`. Never edited, never pushed,
  never run from.
- **Approved design:** `design/` — read-only, never edited.
- Deployment target **tvOS 18.0**; both Apple TVs run tvOS 26.6.

## 2. Where the code is

**`origin/main` = <!--SHA-->**

**Verify this rather than trusting the number.** Run `git rev-parse HEAD`, `git rev-parse
origin/main` and `git ls-remote origin main` and check all three agree. This brief was written
immediately after that push; anything could have happened since.

## 3. What the 2026-09-08 session built, and the owner accepted

Four pieces of work, each accepted on the Apple TV named "Home Theater" before it was pushed.

**The single-file MP4 playback route — Passes 41–45.** A recording now plays as one complete,
seekable MP4 instead of a growing HLS EVENT playlist. Recordings take it; **live TV, cameras and
radio still use HLS**, decided at one line (`PlayRequest.swift:49`) reaching the wire at
`PlaybackSession.swift:70`. The app reads the response's `format` field, which nothing read before,
because the server's own `format` switch has no `default` arm — a pre-1.8.0 server answers **200**
with the old unseekable pipe and only that field says so. The first fetch for a file session is
`Range: bytes=0-0` on its own `URLSession` with an 11-minute timeout, above the server's 10-minute
remux ceiling.

**The Recordings shelf focus fix — Passes 46–48.** A focused poster card had its top edge cut off.
`scaleEffect` is a render transform that changes no layout, so it grew the card about its centre and
threw ~38 pt upward on top of the 22 pt lift, into 44 pt of padding, and the horizontal `ScrollView`
cropped it. The card now grows its **real layout box** — 252×344 to 296×404 — per `design/`
`dc:1273`, so the only upward overhang is the 22 pt lift.

**The airing sheet's three-state first control — Passes 49–50.** It read "Record this airing" even
for an airing already recording under a series pass. It now reports **the airing's own state**:
"● Recording", "● Scheduled", or a pressable "Record this airing". It is **never hidden** — a series
pass covers a show, not every airing, so hiding it would leave no way to record a missed episode
(owner, 2026-09-08).

**The app icon and Top Shelf art — Passes 51–55.** The app had **no icon at all**: no `Assets.car`
in the bundle and no icon key. The owner supplied a complete `AppIcon.brandassets` catalog which
needed no repair; it went in byte-identical and the icon setting was repointed at it in two lines.

## 4. The three defects the owner named — two closed, one still open

- **A "LIVE" indicator showing while a recording plays — CLOSED.** The owner confirmed on
  2026-09-08 that the badge is gone. It was never the app's own: a recording is drawn by
  `RecordingHUD` and can never reach either app live indicator, so it was
  `AVPlayerViewController`'s transport reacting to a playlist with no `#EXT-X-ENDLIST`.
- **Having to wait before fast forward works — CLOSED** (owner, 2026-09-08). The seekable range was
  short because only the written part of the playlist was advertised.
- **AUDIO OUT OF SYNC WITH VIDEO ON RECORDINGS — STILL OPEN.** Pass 39 sorted it **NOT OURS**: every
  parameter, setting and seek in this app was inventoried and none can shift audio against video.
  Nothing in Passes 42–55 changed it, and **no client-side compensation has ever been built for it,
  nor is any to be.** It is with the **marlin-dvr** project.
  **They have asked the owner to match the sessions where he observed desync to individual session
  records.** That request is outstanding and is his to answer.

## 5. Their contract is behind their server — read this before trusting it

`HLS-CLIENT-API.md` in the marlin-dvr repo is **byte-unchanged across the whole 1.8.0 delivery**
(`git diff --stat c417c60 095de81 -- HLS-CLIENT-API.md` returned nothing, Pass 41). It still declares
in its own header that it describes **1.7.0**, and its **§2 request-body table at line 68 states the
opposite of the new behaviour**: *"`"hls"` selects HLS. Absent, `""` or `"mp4"` gives the old
fragmented-MP4 pipe"* — `"file"` appears nowhere in the file. Their own `COLD-START.md` omits the
route too.

**§2.3 of `reports/2026-09-08-pass41-single-file-route-recon.md` is the only written description of
the file route that exists**, read from their Go source (`cmd/marlin-dvr/playfile.go`,
`cmd/marlin-dvr/stream.go`). **Anyone building against the contract file alone will be wrong about
this route.**

## 6. KNOWN AND UNFIXED, as `COLD-START.md` now holds it

Three sections there carry the full text and the measurements. In summary:

**After Pass 29:**
- **Stepping erratic near the end of the prepared range — VERY LIKELY closed by Pass 42, not
  proven.** Its named suspect (`timeJumped()`'s restart) cannot fire on a complete file, but it was
  always a suspect and nobody has watched the same spot since.
- The recognizer-disabling fix depends on `AVPlayerViewController` internals; it fails open.
- Live playback was never driven on the device across Passes 28–29.
- Nobody has diffed two stills to prove the picture advances one frame.

**After Pass 33:**
- The series-pass sheet chip is **CLOSED by Pass 49**.
- Stopping a pass's airing has never been exercised on the device.
- Old-form (pre-1.6.0) trash entries are untested and now untestable.
- The recording-id rule is an inference from two files, not a proof.
- Resume survival across trash-and-restore was reasoned, never watched.
- `trashedAt` does not update when the same file is trashed twice (a marlin-dvr matter).

**After Pass 38:**
- The resumed-recording overshoot is **CLOSED by Pass 42**.
- "A playback that starts inside a break offers it" is **still unproved**.
- **One skip landed 1.01 s past `endSeconds`** instead of on it, unexplained. Pass 42 landed exactly
  on `endSeconds` from a session with `startOffset = 1206.001`, which is evidence against that
  entry's stated correlation; **the entry was left standing** (Pass 43 raised it, no decision taken).

## 7. Open questions, still open

**The six from `reports/2026-09-08-pass41-single-file-route-recon.md` §7. None was answered, decided
or narrowed by any later pass.**

| # | Question |
|---|---|
| **7.2** | `start: 0` or `start: N` for resume — **this is what blocked build-plan step 7** |
| **7.3** | What the Starting screen should say during a long remux |
| **7.4** | Should a refused recording fall back to HLS, or show the error — fail-loudly is what ships, on the scope lock's authority; the owner has not been asked |
| **7.5** | Temp space on Unraid |
| **7.6** | Whether to ask the marlin-dvr project to document the file route in `HLS-CLIENT-API.md` |
| **7.7** | The two formerly-untracked report files — subject settled (committed in Pass 44, notebook corrected in Pass 45) |

**Build-plan step 7 was never built.** It is "resume by seeking rather than by `start`", conditional
on 7.2. Pass 42 stopped rather than choosing. Pass 42 §3 also **corrected Pass 41's own claim** that
`start: N` would break `fullyPrepared`, the HUD and the commercial clamp: it does not — the server
echoes the same `start` it trims with, so `startOffset` compensates exactly, measured on device
(a skip landed at `t=272.538500` with the app reporting `position 1478.54`, the break's exact
`endSeconds`). **7.2 is a wait-versus-cleanliness trade, not a correctness bug.**

**The 27-session start-values table is still unsettled with the marlin-dvr foreman.** Its prompt
**must NOT be re-issued unprompted.**

## 8. Things proven only partly, or only by eye

- **Multi-card shelf traversal is untested.** Pass 47's device run proved focus navigation survives a
  card whose layout box changes on focus, but the harness matched the first card it read and sent
  **zero** rightward presses. Reaching more would have needed a new test file or the harness that
  deletes one of the owner's recordings.
- **The 60 pt shelf shift is accepted, not absent.** The focused card is 60 pt taller, so shelves
  below it move down while it holds focus. It is `design/`'s own behaviour (`dc:383`), it clips
  nothing, **the owner was told after Pass 47 and accepted it**, and **nothing was built to absorb
  it** because every way to do so goes through `RecordingsScreen.swift:114` or `:127`, which he
  instructed be left alone. Recorded as reopenable.
- **The airing sheet's "Recording" and "Scheduled" states are owner-verified by eye only.** Pass 49's
  device run proved the **unbooked** case; the two status renderings were **code-traced**, because
  reaching them needed a new harness or one that books and stops a real recording on his DVR.
- **The icon has never been machine-checked for appearance**, only for presence.
- **A pass-scheduled airing shows a green "● Scheduled" where the Guide grid shows gold
  "◆ SERIES PASS".** Same meaning; a gold chip would have been a fourth state the owner did not ask
  for. Raised with him and left as built.
- **The app is on a second Apple TV** — "Master Bedroom ATV" (`AppleTV6,2`, tvOS 26.6), same binary
  as Home Theater (Pass 54). **Development-signed: it will stop launching when the provisioning
  profile expires. When that is has not been checked.**

## 9. How this project runs

- **Recon before build.** A read-only pass establishes the ground truth and writes a report; a later
  pass builds from it.
- **Scope lock.** Nothing not named in a pass's numbered steps gets built or changed. Anything extra
  goes in the report as a question, never into the work.
- **Separate push gate for code the owner tests.** Code and UI are committed locally and **not
  pushed**; the owner tests on Home Theater and a later pass pushes after he accepts. Notebook and
  recon passes push in the same pass.
- **Nothing force-pushed, ever.** No amends, no rebases, no history rewriting. Pushes are plain
  fast-forwards, verified by reading the remote back with `git rev-parse HEAD`, `git rev-parse
  origin/main` and `git ls-remote origin main` as three separate commands.
- **Every claim cites file:line or pasted command output.** Counts and file lists are re-verified in
  each pass, never inherited. Anything that cannot be established is labelled unverified rather than
  filled in from memory.
- **No secrets in the repo, logs or reports.** Credentials, tokens, device ids and account
  identifiers are redacted.
- **The server repo is read-only reference.** Server changes are raised as decisions for the
  marlin-dvr project, never made here.
- **Do not touch:** the other folders under `~/Xcode`; the Marlin DVR server, its data, config and
  admin UI; Unraid 192.168.1.250; marlinpc 192.168.1.245; the HDHomeRun 192.168.1.105; the UNAS4Pro
  share; `design/`.
- **Every report lands in `reports/`**, dated and numbered by pass.

## 10. Context panel

- `COLD-START.md` — the full project state, what is built, and KNOWN AND UNFIXED
- `DECISIONS.md` — every decision, dated
- **`MARLIN-DVR-TV-HANDOFF-2026-09-09.md`** — this brief
  *(remove `MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`, which this replaces)*

## 11. Untracked in the working tree

`icon-source/` — **32 entries**, all untracked: the loose PNGs Pass 51 examined, the owner's
structured `Assets.xcassets` (whose `AppIcon.brandassets` is now duplicated inside the project),
`AccentColor.colorset`, and `FocusClick.dataset`. **Nothing there has been deleted, moved, renamed or
committed by any pass. Its fate is the owner's call and has not been decided.**
