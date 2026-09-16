# Pass 99 — inventory of everything unfinished

**Date:** 2026-09-16
**READ-ONLY.** No source file, test file, project file or asset was read for anything but reading.
**No request of any kind was made to `http://192.168.1.250:8090/`.** Neither Apple TV was touched.
`~/Xcode/marlin-dvr-reference` was not fetched, pulled or checked out. No build, no device run.

**HEAD this was read at: `6a1a0ddb9118b6837667a51408be41d5d013f2dc`** (Pass 98).

**What this is, and what it is not.** Every line below is something `COLD-START.md`, `DECISIONS.md`
or a file in `reports/` already records as unfinished, unproven, absent, deferred, waiting on the
owner, or the marlin-dvr project's. **Nothing here is new, nothing is ranked, and nothing is
proposed.** Where the notebook records a thing as closed, it is not listed. Items are counted by
hand at the end of each group and totalled at the end of the file.

**One rule about the groups:** each item appears in exactly one group, so the counts add up. The
**Settings** screen is in **D** rather than **A** because the notebook records it as parked by the
owner's word, which is the more specific fact about it.

---

## A) A feature or screen not built, or not working

| # | In plain English | Where it is recorded | Status |
|---|---|---|---|
| **A1** | Show detail's **"Series pass" button does nothing**. | COLD-START, *What is NOT built*: "Deliberately still inert or absent: show detail's 'Series pass' button … (Pass 8 Open Question 1)" | Inert since Pass 8. The call it would make exists (`createPass`). |
| **A2** | The Player's **"Delete this recording"** (frame 6e) is absent. | Same sentence: "and the Player's 6e 'Delete this recording' (Pass 8 Open Question 1)" | Inert/absent since Pass 8. |
| **A3** | **A plain click on the Guide's channel cell does nothing** — only a click-and-hold works, and it favourites the channel. | COLD-START, *What is NOT built*: "any click behaviour on the Guide's channel cell — the hold favourites it, a click does nothing (Pass 9 Open Question 1)" | No behaviour; Pass 9's question "Should a click tune the channel live?" is unanswered. |
| **A4** | **A cancelled pass airing cannot be un-skipped from the app** — only from the web UI. | COLD-START: "any way to un-skip a cancelled pass airing"; Pass 10 OQ4: "The server takes `{\"skipped\": false}` … and the app never sends it" | Absent. |
| **A5** | **The Manage DVR lists never refresh on their own.** A recording that starts while the schedule list is open still reads "Queued". | COLD-START: "any auto-refresh of the Manage DVR lists (Pass 10 Open Questions 2 and 4)" | Absent by scope lock. |
| **A6** | **Empty Trash has never been sent from an Apple TV.** | COLD-START, *Built but never exercised against the live server*: "**Empty Trash** … it deletes files on disk permanently for every client; never sent." | Wired since Pass 10, code-traced only; DECISIONS (Pass 34) keeps it out of scope "until the owner asks for it by name". |
| **A7** | **Cancel recording on a pass's airing has never been exercised live** — only the one-off Record Now case. | COLD-START, same block: "Same call; the server answers `removed: false` and skips that airing while the pass carries on." | Code-traced only. |
| **A8** | **Stop recording on a pass's airing has never been exercised live.** | COLD-START, same block: "Pass 32 proved Stop on the device for a one-off Record Now only." | Code-traced only. (The wrong control the same bullet mentions was closed by Pass 49.) |
| **A9** | **The Weather alert card has never been drawn with real data.** | COLD-START, *Known and unfixed*: "The Weather alert card has never been drawn with real data; its layout was checked with a disclosed, reverted diagnostic (Pass 22)." | Needs a real weather alert in the owner's area. |
| **A10** | **The restart path has never run on a television.** A restarted recording is believed to resume at the restart point on a code trace alone. | COLD-START, *Known and unfixed*: "Pass 95's T1 is built (Pass 98) but its path has never been driven on a device" | **Closed by the owner on 2026-09-16 without a device test** (DECISIONS, Pass 99). The trace stands; if it is wrong a restarted recording begins at the top, silently. |
| **A11** | **A recording does not start within 2 seconds of pressing Resume**, which is what the owner asked for. | COLD-START, *Known and unfixed*: "The 2 s start the owner asked for is not met and cannot be met inside this app" | Measured at 10.916 s and 7.567 s press-to-picture; 85–94 % is the server's remux. Accepted as measured (DECISIONS, Pass 97). |
| **A12** | **The two Apple TVs run different builds.** The bedroom one does not have Continue watching, the progress bar, or resume-rewind. | COLD-START, *Next step*: "Home Theater runs this build; the bedroom Apple TV does not — it is still on `4396d84`." | Standing difference; bringing it up is not scheduled. |

**Group A: 12 items.**

---

## B) Smaller known defects

| # | In plain English | Where it is recorded | Status |
|---|---|---|---|
| **B1** | **Frame stepping went erratic near the end of the prepared range** — the clock ran backwards at 1:05:27 of a 1:11:10 recording. | COLD-START, *Known and unfixed* (Passes 29, 42) | "**very likely closed by the file route, not proven**: nobody has watched the same spot since". |
| **B2** | **`armArrowOwnership` depends on `AVPlayerViewController`'s internals** and fails open to Apple's 10-second skip if a future tvOS changes them. | COLD-START (Pass 29) | Standing risk, unchanged. |
| **B3** | **Live playback was never driven on the device in the frame-stepping passes.** | COLD-START (Pass 29) | `frameStep` bails when the item is not a recording. |
| **B4** | **Nobody has diffed two stills** to prove a frame step advances the picture rather than only the clock. | COLD-START (Pass 29) | Never done. |
| **B5** | **Old-form (pre-1.6.0) trash entries are untested and now untestable**, and resume survival across a trash-and-restore was reasoned, never watched. | COLD-START (Pass 33) | The owner's own Empty Trash of 2026-09-07 removed the only subjects. |
| **B6** | **"A playback that starts inside a break offers it" is unproved**, and one commercial skip landed **1.01 s past** `endSeconds` instead of on it, unexplained. | COLD-START (Pass 38) | Open. |
| **B7** | **Three branches of commercial skip were never exercised live** — the end-of-recording clamp, the `hdhomerun` `"none"` branch, and the network-failure branch. | COLD-START (Pass 38) | Code-traced only. |
| **B8** | **A break the viewer scrubs through is spent for that playback** and will not be offered again until the Player is re-entered. | COLD-START (Pass 96): "rewind past a break and it will not be offered again until the Player is re-entered. Raised in Pass 96, not changed." | Pass 38's deliberate design; more visible now that the whole recording is reachable. |
| **B9** | **On the file route, a recording still being written and one that is not H.264/AAC have never been exercised**, and the remux wait was never measured on the Unraid box. | COLD-START (Pass 42) | Both still earn the server's 502; never driven. |
| **B10** | **Multi-card focus traversal on the reflowing Recordings shelf is untested.** | COLD-START (Pass 47) | Untested. |
| **B11** | **Continue watching is stale after a playback** — play something and press Menu twice and the shelf is the one read on the way in; the **empty-shelf case was never exercised**; and a position on a show past the shelves' `limit: 6` **would go undrawn**. | COLD-START (Pass 91) | The staleness is the same the server's shelf had; leaving Recordings and coming back rebuilds it. |
| **B12** | **The Continue watching bar**: the zero-duration branch was never exercised; the translucent track has only been seen over dark posters; **nothing distinguishes 99 % from 100 %**; and the bar is **silent to VoiceOver**. | COLD-START (Pass 92) | All four open. |
| **B13** | **Three UI-test harnesses use `activate()` and can photograph the previous build** — `ContinueWatchingUITests`, `GuideChannelLogosUITests`, `OnLaterPillsUITests`. | COLD-START (Pass 92): "check for the launch ping before believing their screenshots" | Unchanged; they are other passes' files. |
| **B14** | **The airing sheet's "● Recording" and "● Scheduled" branches were code-traced only** and accepted by eye. | COLD-START (Pass 49) | Never driven. |
| **B15** | **The Guide's collections**: the overlay does not scroll, "Collections unavailable" is unproven, and the stale-id revert is unproven (it needs a collection deleted). | COLD-START (Passes 72–74) | Open. |
| **B16** | **The Guide's scroll-right**: a row can have no cell at all in the new window and focus falls back to another row; whether a held Right auto-repeats is unknown; **Up from the middle of a row moves nowhere** and `↩ Now` needs a Left first; `lastListedSlot` is per-fetch; the 150 ms settle costs a fast presser. | COLD-START (Passes 77, 78) | Five items, all open. |
| **B17** | **The Guide's clock**: the `↩ Now` pill vanishes under focus in one case; the beat pauses while a Guide overlay is up; the beat continues behind the Player; the roll's refetch is unexercised; the backgrounded-boundary harness test is still unexecuted. | COLD-START (Passes 79, 80) | Five items, all open. |
| **B18** | **On Later**: the two-read sheet reconstitution; the ≤30-minute far edge of "On This Week"; which sentence an undrawable-but-non-empty union should get; the card carries no new/live/premiere tags; and the block builder **loses 2 airings in 140** over a week, both on ESPN. | COLD-START (Passes 82, 83) | The 2-in-140 loss is accepted; the rest are open. |
| **B19** | **Dead code left in place**: `api.later()`, `LaterResponse`, `LaterSection` and `LaterItem` are uncalled; `TimeFormat.currentHalfHour` has no caller; and `request.withStart(target)` now changes nothing. | COLD-START (Passes 82, 83; Passes 79, 80); Pass 98 report OQ3 | All three deliberately left; removing them was never a pass's scope. |
| **B20** | **Both Apple TVs run development-signed builds that will stop launching when the provisioning profile expires**, and **when that is has not been checked**. | COLD-START, *Foundation, packaging and the two Apple TVs* (Passes 54, 83) | Unchecked. |

**Group B: 20 items.**

---

## C) Questions waiting on the owner

| # | In plain English | Where it is recorded | Status |
|---|---|---|---|
| **C1** | Should a recording the **server** calls `watched` drop off the Continue watching shelf? It does not today. | Pass 91 report OQ1: "**One line in `loadContinueWatching`**, and his call." | Open; not re-raised by Pass 93's acceptance. |
| **C2** | Should an empty **server** shelf stop drawing its "Nothing yet." line, the way the new shelf does? | Pass 91 report OQ3 | Open. |
| **C3** | The **`> 5 s` bar**: a recording opened and abandoned inside five seconds gets no card. | Pass 91 report OQ4: "it is a rule, and he should know it is there" | Open, for information. |
| **C4** | Should `ProgressBar` and `PosterProgressBar` be merged into one view? | Pass 92 report OQ5 | Open. |
| **C5** | Should the other three harnesses move from `activate()` to `launch()`? | Pass 92 report OQ6 | Open (the defect itself is B13). |
| **C6** | Does a bar sitting at **99 %** want its own treatment? | Pass 92 report OQ3: "a decision, not a defect" | Open. |
| **C7** | Should the chosen Guide collection also filter `GET /api/guide/now` and `GET /api/channels`? | COLD-START (Passes 72–74); DECISIONS (Pass 74): "is still the owner's call (Pass 71 open question 8)" | Open. |
| **C8** | **What should the Starting screen say during a long remux?** Today it says "Preparing the recording" and nothing else. | COLD-START: "Pass 41's open questions … 7.3 … are still unanswered"; re-flagged by Passes 96 and 98 | Open, and more visible since Pass 96. |
| **C9** | Should a **refused** recording fall back to HLS, or show the error? Today it fails loudly. | COLD-START: Pass 41 OQ 7.4 | Open; DECISIONS (Pass 42): "**The owner has not been asked**". |
| **C10** | **Temp space on Unraid** for the remuxed MP4. | COLD-START: Pass 41 OQ 7.5 | Open. |
| **C11** | Should the app **say anything** when a recording answers `state: "unknown"`? Today it says nothing. | Pass 94 report OQ2 | Open; the owner spent eight days assuming the feature was broken. |
| **C12** | Should Pass 94's commercial-detection finding be raised with marlin-dvr, and in what form? | Pass 94 report OQ1: "**Nothing was asked of them**" | Open (the finding itself is E5). |
| **C13** | Should **"Play newest" and a plain episode click** still resume silently, without a button that says so? | Pass 95 report OQ2 | Open; unchanged by Pass 96. |
| **C14** | Should `armResumeSeek`'s target be passed in explicitly instead of read out of `position`? | Pass 98 report OQ2: "**not built**, and it is the cleanest thing a later pass could do here" | Open. |
| **C15** | **The fate of `icon-source/`** — all 32 entries untracked, nothing deleted, moved, renamed or committed. | DECISIONS (Pass 55): "**The fate of `icon-source/` is the owner's call and has not been decided.**" | Open; it is the one permanent entry in `git status`. |
| **C16** | **`MARLIN-DVR-TV-HANDOFF-2026-09-08b.md`** exists only in the owner's Context panel, not on disk. | DECISIONS (Pass 56): "**Removing it from the Context panel is the owner's to do.**" | Open. |
| **C17** | Should `COLD-START.md`'s **"Next step" section be consolidated**? It runs most-recent-first and each pass prepends. | DECISIONS (Pass 59): "**Whether the section should be consolidated is the owner's call and is not decided.**" | Open. |
| **C18** | Should the notebook's **dangling and overtaken sentences** be reworded — the "paragraph below … is kept as history" pointer, and the stale lines inside `What is NOT built`? | DECISIONS (Pass 60): "**Whether to reword them is the owner's call.**"; Pass 89 report OQ1 and OQ2 | Open; Pass 89 left both verbatim. |

**Group C: 18 items.**

---

## D) Deferred or future by the owner's word

| # | In plain English | Where it is recorded | Status |
|---|---|---|---|
| **D1** | **A tvOS Top Shelf extension showing Continue watching.** | DECISIONS (Pass 94): "**Deferred (owner, 2026-09-16): a tvOS Top Shelf extension showing Continue watching — not now, later. Nothing built.**" | Deferred 2026-09-16. |
| **D2** | **The Settings screen** — present as drawn and inert. | COLD-START, *What is NOT built*: "parked until the owner says otherwise"; DECISIONS (2026-09-06): "Weather, Radio and Settings stay parked" | Parked since 2026-09-06. Weather left the list in Pass 13 and Radio in Pass 19; Settings did not. |
| **D3** | **Both layers of the app-icon stack point at the same two opaque images**, so the parallax depth effect has nothing behind it. | DECISIONS (Pass 53): "**This is the owner's choice for now** (owner, 2026-09-08)." | Deferred by his word; nothing generated, suggested or stubbed. |
| **D4** | **The Recordings shelves shift down 60 pt while a card is focused.** | COLD-START (Pass 47): "an open item the owner has seen and accepted, **not a decision to leave it forever**" | Seen and accepted; explicitly not settled permanently. |

**Group D: 4 items.**

---

## E) Belongs to the marlin-dvr project

All five of the first entries sit under COLD-START's *"Raised for the marlin-dvr project — recorded
here, not acted on"*. Nothing in this group was changed, worked around, or compensated for in the app.

| # | In plain English | Where it is recorded | Status |
|---|---|---|---|
| **E1** | **`trashedAt` does not update when the same file is trashed twice**, so a row can report a trashing from hours earlier. | COLD-START, *Raised…* (Pass 33) | Recorded, not acted on. The app shows the server's value unaltered. |
| **E2** | **Empty Trash has no confirmation step server-side** — it deletes every trashed file the moment it arrives. | COLD-START, *Raised…*: "On 2026-09-07 that call removed 3.80 GB of the owner's recordings in one request" | Recorded; both clients invent their own guard. |
| **E3** | **The audio/video desync on recordings**, and **their outstanding request** that the owner match the sessions where he saw it to individual session records. | COLD-START, *Raised…* (Pass 39): "That request is **outstanding and is the owner's to answer**" | Sorted NOT OURS in Pass 39; the request is unanswered. |
| **E4** | **The 27-session start-values table is unsettled with their foreman** — they want 27 rows published with labels `S01`–`S27`, and asked us not to re-capture. | COLD-START, *Raised…*: "**IT MUST NOT BE RE-ISSUED UNPROMPTED.**" | Waiting on the owner to settle the shape with them; the captures live in a session temp directory that may be gone. |
| **E5** | **Commercial detection has failed on the owner's server on every recording made since 2026-09-08** — `the app's comskip.ini is missing`. Nine of eleven recordings answer `state: "unknown"`. | COLD-START, *Raised…* (Pass 94); mechanism in `reports/2026-09-16-pass94-commercial-skip-recon.md` §8 | Recorded; **nothing was sent to them**. Silent and not self-healing: every recording since is permanently without markers. |
| **E6** | **The single-file MP4 route is still undocumented in their own contract.** | COLD-START, *Raised…*: "the undocumented route (Pass 41 open question 7.6) was **not** re-raised and stays open" | Open; `HLS-CLIENT-API.md` does not mention `"file"` anywhere. |
| **E7** | **A recording's first remux is about five times slower than its next** — 10.225 s against 2.124 s for the same file. | COLD-START, *Known and unfixed* (Pass 96): "Why the first is slower is not this project's to answer and no request was made to find out" | Unexplained; not raised. |
| **E8** | **The server has no per-recording read and no per-library storage total.** `GET /api/library/recordings/{id}` answers 404; `diskUsed` is the whole volume. | DECISIONS (Pass 91): "**there is no per-recording read on this server** … **No new route was built and none is raised for marlin-dvr**"; Pass 10 OQ5 (Pass 4 OQ9) | Both known; neither raised. |

**Group E: 8 items.**

---

## The count

| Group | Items |
|---|---|
| **A** — a feature or screen not built, or not working | **12** |
| **B** — smaller known defects | **20** |
| **C** — questions waiting on the owner | **18** |
| **D** — deferred or future by the owner's word | **4** |
| **E** — belongs to the marlin-dvr project | **8** |
| **Total** | **62** |

Counted by hand from the rows above: 12 + 20 + 18 + 4 + 8 = **62**.

---

## What this inventory does not cover

- **The Open Questions sections of the early recon reports.** `COLD-START.md`'s own *Open questions*
  section points at `reports/2026-09-05-pass2-server-recon.md`,
  `reports/2026-09-05-pass3-hls-client-recon.md` and `reports/2026-09-05-pass1-plumbing.md` rather
  than carrying them, and its *Known and unfixed* list ends with "Standing candidates, should the
  owner want them: … the Open Questions of the Pass 9 and Pass 10 reports and the earlier recon
  reports". **Those pointers are reproduced here, not expanded** — the individual questions the
  notebook names by hand are in groups A and C above; the rest stay where the notebook keeps them.
- **Anything the notebook records as closed.** Pass 13's radar-source question (answered by Pass 14),
  Pass 10's per-show trash walk (closed by Passes 33–34), the "MARLIN TV" artwork wording (settled
  2026-09-08 and "not to be raised again"), the focus ring over the Continue watching bar (accepted
  in Pass 93), Pass 77's press ratio (accepted in Pass 78), Pass 41's 7.1, 7.7 and 7.8, and Pass 98's
  open question 1 (closed by this pass) are all absent by design.
- **Anything not written down.** No item here was inferred from the code alone; every one cites the
  notebook or a report.
