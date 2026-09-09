# Pass 40 — the play-session `start` values, for the marlin-dvr project

**Date:** 2026-09-08
**Read-only.** No Swift written, no notebook file edited, nothing committed or pushed.
**The server at 192.168.1.250 was not called, probed or curled at any point.** No app was run and
no new play session was created; every number below comes from evidence captured in Pass 38.

---

## ⚠ FIRST: the request asks for twenty sessions. There are twenty-seven.

Pass 39 reported "**Twenty play sessions** across three different recordings on Home Theater in
Pass 38" (`reports/2026-09-08-pass39-three-defects-recon.md:156-157`). **That count is wrong**, and
this pass re-derived it by hand rather than inheriting it, as the evidence rules require.

The command Pass 39 used ended in `sed … | sort -u`. The `sed` replaced each session id with
`<redacted>` *before* the sort, so `sort -u` collapsed every pair of sessions that happened to share
a `start` **and** a `duration`. Twenty was the number of **distinct redacted lines**, not the number
of sessions. Re-run this pass against the same files:

```
$ grep -h "player\] session" $S/console-*.log | sed 's/session smts[a-z0-9]*/session <redacted>/' | sort -u | wc -l
20      ← distinct redacted lines (what Pass 39 counted)

$ grep -h "player\] session" $S/console-*.log | wc -l
27      ← raw session lines

$ grep -ho "session smts[a-z0-9]*" $S/console-*.log | sort -u | wc -l
27      ← distinct session ids
```

The seven that were collapsed, and by how much:

```
$ grep -h "player\] session" $S/console-*.log | sed 's/.*mode=//' | sort | uniq -c | sort -rn
   5 copy start=0.0 duration=2402.4
   4 copy start=0.0 duration=2570.568
   (every other line appears exactly once)
```

`(5−1) + (4−1) = 7` collapsed, `27 − 7 = 20`. **The set is 27 sessions.** All 27 are reported below;
the "twenty" of the request does not correspond to any real subset. Pass 39's substantive finding is
unaffected — every one of the 27 is `mode=copy`, not just the 20 it counted.

---

## 1. Provenance — where the sessions came from

**The capture.** Pass 38 could not read the app's `print` output through XCUITest, so the app was
launched separately with a console attached and the harness used `XCUIApplication.activate()` to
join the running process. The command, run once per test round:

```
xcrun devicectl device process launch --device <Home Theater, id redacted> \
  --console --terminate-existing com.marlin1111.MarlinDVRTV > $S/console-<round>.log 2>&1 &
```

**The files.** Thirteen console captures, all still present, in
`…/6cafe40a-344a-4ba6-a8b1-458f674f1865/scratchpad/` (this session's scratchpad — **not** in the
repo; see OPEN QUESTIONS 1):

| file | bytes | last written |
|---|---|---|
| `console-probe.log` | 1101 | 2026-09-08 08:24:51 |
| `console-run1.log` | 14690 | 08:33:31 |
| `console-run2.log` | 3332 | 08:35:46 |
| `console-run3.log` | 10699 | 08:41:31 |
| `console-run4.log` | 10738 | 08:45:54 |
| `console-run5.log` | 30030 | 08:55:44 |
| `console-run6.log` | 37214 | 09:07:56 |
| `console-diag.log` | 51410 | 09:13:24 |
| `console-diag2.log` | 35589 | 09:17:01 |
| `console-run7.log` | 5216 | 09:20:44 |
| `console-diag3.log` | 26908 | 09:25:09 |
| `console-final.log` | 81976 | 09:37:10 |
| `console-pause.log` | 2559 | 09:44:36 |

**The line that carries every number.** The app prints one line per created session,
`PlayerModel.swift:122`:

```
122	            print("[player] session \(created.id) \(created.kind) mode=\(created.mode) start=\(created.start) duration=\(created.duration)")
```

`created` is the decoded `PlaySession` from `POST /api/play/sessions`. **So `start` here is the
value the server echoed back, not a log of what the app put in the request body** — the app never
logs its outgoing body. Contract §2.2 (`HLS-CLIENT-API.md:103`) says the field "echoes the requested
offset", so the two are the same number, but the distinction is real and is stated rather than
glossed. See OPEN QUESTIONS 2.

**None of the 27 came from a restart.** A session created by `restart(at:)` prints a different line
(`PlayerModel.swift:726`, `"[player] session … restarted start=…"`), and that form appears **zero
times** in the whole capture set:

```
$ grep -h "restarted start=" $S/console-*.log | wc -l
0
```

Every one of the 27 is a first `start()` for its playback.

**Which recording each session was.** Each session line is followed, in the same file, by the
`[commercials] <recordingId> → …` line that Pass 38's fetch prints from `attach()`. The two counts
match exactly — 27 session lines, 27 `[commercials] <id> →` lines — so the pairing is one-to-one and
no session's recording id is missing.

---

## 2. The table — all 27 sessions

In capture order (files ordered by last-written time; the app's own lines carry no timestamps, so
ordering *within* a file is line order, which is creation order).

| # | Capture | Session id | `start` (s, as echoed) | Recording id | Kind | Mode | `duration` (s) | Recording |
|---|---|---|---|---|---|---|---|---|
| 1 | `console-probe.log` | `smtsn3fawf30b6f` | **0.0** | `1f728c318959` | recording | copy | 54.054 | Storage Wars S4 E19 |
| 2 | `console-run1.log` | `smtsnd96aae9c0d` | **2112.000724826** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 3 | `console-run1.log` | `smtsnf76l45919e` | **0.0** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 4 | `console-run2.log` | `smtsninvvf3aff8` | **0.0** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 5 | `console-run3.log` | `smtsnmv8q9496ad` | **212.000115209** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 6 | `console-run3.log` | `smtsnpiqccd8105` | **759.005354585** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 7 | `console-run4.log` | `smtsnt2nl71823f` | **281.000369607** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 8 | `console-run4.log` | `smtsnvgz1e6906e` | **1089.005747855** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 9 | `console-run5.log` | `smtsnyljq141d1e` | **1374.010438483** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 10 | `console-run5.log` | `smtso2iaq8eddca` | **2196.010650717** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 11 | `console-run5.log` | `smtso3mjc3f32fb` | **0.0** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 12 | `console-run6.log` | `smtsobgchbecd41` | **0.0** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 13 | `console-run6.log` | `smtsocn7vc79ec2` | **194.000662764** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 14 | `console-run6.log` | `smtsof05yd83618` | **508.000856557** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 15 | `console-run6.log` | `smtsoiyxn6e6f8a` | **1265.0011675380001** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 16 | `console-diag.log` | `smtsoqy293244dc` | **2155.001539748** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 17 | `console-diag.log` | `smtsoro4p1ba766` | **0.0** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 18 | `console-diag2.log` | `smtsoxx721e5df6` | **0.0** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 19 | `console-run7.log` | `smtsp2mc197a70f` | **932.000091311** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 20 | `console-run7.log` | `smtsp3kdlc5d3e8` | **1284.000524329** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 21 | `console-diag3.log` | `smtsp7em46b74c3` | **1680.000649333** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 22 | `console-diag3.log` | `smtspbspwede482` | **0.0** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 23 | `console-final.log` | `smtspgfjl8cceb7` | **931.000155362** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 24 | `console-final.log` | `smtspik5df03cde` | **1439.000253668** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 25 | `console-final.log` | `smtspo3loa3c787` | **2258.000414998** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |
| 26 | `console-final.log` | `smtsponqy7578a7` | **0.0** | `62be7fad307a` | recording | copy | 2402.4 | HGM S7 E20 |
| 27 | `console-pause.log` | `smtspsidmba24c4` | **0.0** | `5328bb632e76` | recording | copy | 2570.568 | HGM S4 E14 |

**No field is absent for any of the 27.** Every line carried an id, a kind, a mode, a start and a
duration, and every one had a paired recording id.

**Kind and mode, counted by hand rather than read off the table:**

```
$ grep -ho "session smts[a-z0-9]* [a-z]*" $S/console-*.log | awk '{print $3}' | sort | uniq -c
  27 recording          ← no live session, no camera session, anywhere in the set

$ grep -ho "mode=[a-z]*" $S/console-*.log | sort | uniq -c
  27 mode=copy          ← Pass 39's finding holds for all 27, not only its 20
```

**How the three recordings were identified**, each from the same captures and not from memory:

- **`5328bb632e76` — History's Greatest Mysteries S04E14 "Who Is D.B. Cooper?"** (20 sessions).
  Named outright by the server in the app's own log line: `4 commercial segments from History's
  Greatest Mysteries S04E14 Who Is D.B. Cooper 2026-09-07-1100.edl.`
- **`62be7fad307a` — History's Greatest Mysteries S7 E20 "The Hunt for Osama bin Laden: Case
  Closed"** (6 sessions). Its `[commercials]` answer was `"unknown"` and carries no filename, so it
  is tied through the paired harness log of the same run: `run4.log` records
  `episode row 5 is the one: S7 E20, The Hunt for Osama bin Laden: Case Closed`, and
  `console-run4.log` shows that run's session `smtsnt2nl71823f` → `62be7fad307a`. Its `duration`
  2402.4 s = 40.04 min matches the "40 min" the harness read off the episode row.
- **`1f728c318959` — Storage Wars S4 E19 "This Lamp's for You"** (1 session). `probe.log` records
  `probe: card 0 is Storage Wars, 1 episode`, and `console-probe.log` shows the only session in that
  file at `duration=54.054` s, matching the "54 sec" the harness read.

---

## 3. Where the `start` value comes from — code answer

**The request body, and the only place `start` enters it** — `PlaybackSession.swift:41-51`:

```
41	    private struct CreateBody: Encodable {
42	        let kind: String
43	        let id: String
44	        let format: String
45	        let client: String
46	        let start: Double
47	    }
…
51	        let body = CreateBody(kind: request.kind, id: request.targetID, format: "hls", client: clientID ?? "", start: request.startSeconds)
```

**It is read straight off the `PlayRequest` enum case** — `PlayRequest.swift:43-47`:

```
43	    /// The `start` for a recording (contract §3); live and camera ignore it.
44	    var startSeconds: Double {
45	        if case .recording(_, _, let start) = self { return start }
46	        return 0
47	    }
```

**There are exactly three places a `.recording` request's `start` is set.** A repo-wide grep for
every construction and every rewrite:

```
PlayerModel.swift:722   let created = try await sessions.create(request.withStart(target))
PlayerScreen.swift:101  let request = model.request.replacing(episode: next, start: 0)
ShowDetailScreen.swift:149  onPlay(.recording(episode: episode, show: model.detail, start: start))
```

1. **Show detail** — `ShowDetailScreen.swift:148-149` takes whatever its three call sites hand it,
   and all three read the resume store:

```
148	    private func play(_ episode: Episode, from start: Double) {
149	        onPlay(.recording(episode: episode, show: model.detail, start: start))
…
177	                    play(resume.episode, from: resume.entry.position)          ← the Resume button
188	                        play(newest, from: ResumeStore.entry(for: newest.id)?.position ?? 0)   ← Play newest
236	                            play(episode, from: ResumeStore.entry(for: episode.id)?.position ?? 0)   ← an episode row
```

2. **Auto-play-next** — `PlayerScreen.swift:101`, a hard-coded literal `0`, ignoring any stored
   resume for the next episode.

3. **`restart(at:)`** — `PlayerModel.swift:702-714`, which is how a seek past the prepared range and
   the failure-state Restart button rebuild a session. **None of the 27 came through this path**
   (§1). It is the only place the app writes a resume as well as reading one:

```
702	    func restart(at requested: Double? = nil) async {
703	        let target = requested ?? (isRecording ? position : 0)
…
709	        if isRecording, let episode = request.episode {
710	            ResumeStore.save(recordingID: episode.id, position: target, duration: duration)
711	        }
712	        startOffset = target
```

**What the number means.** It is `PlayerModel.position` as it stood when the resume was last saved.
`position` is `startOffset + item.currentTime().seconds` (`PlayerModel.swift:222`) — absolute
seconds from the first frame of the recording file, the same base as contract §10's EDL times. It is
written by `saveResume()`, `PlayerModel.swift:771-776`:

```
771	    private func saveResume() {
772	        guard isRecording, let episode = request.episode else { return }
773	        lastResumeSave = Date()
774	        if duration > 0, position >= duration - 3 { return }
775	        ResumeStore.save(recordingID: episode.id, position: position, duration: duration)
776	    }
```

**Is it ever adjusted, rounded or clamped before the request goes out? Almost never — one clamp,
one refusal, and no rounding anywhere.**

- **The one clamp** is in the store, not the request path — `ResumeStore.swift:26-27`:

```
26	    static func save(recordingID: String, position: Double, duration: Double) {
27	        let entry = Entry(position: max(0, position), duration: duration, savedAt: Date())
```

  `max(0, position)` — a floor at zero and nothing else. There is no ceiling.
- **The one refusal** is `saveResume`'s `if duration > 0, position >= duration - 3 { return }`
  (`:774`): within three seconds of the end nothing is written, so no stored resume can sit at the
  very end of a recording.
- **No rounding, no truncation, no snapping to a keyframe or a segment boundary** anywhere between
  the store and `CreateBody`. The value is carried as a `Double` the whole way and encoded by
  `JSONEncoder` as-is.

The captured values are the visible proof of that: `1265.0011675380001`, `2196.010650717`,
`931.000155362`. Those fractions are what `position` actually held — `startOffset` plus a player
time sampled by the 1-second periodic observer — and they reach the server untouched. A rounding
step anywhere would have erased them.

One thing that is *not* a clamp but is easy to mistake for one: `ResumeStore.latest(among:)` only
offers an entry to the **Resume button** when `entry.position > 5` (`ResumeStore.swift:41`). That
gates which button appears; it does not alter any value, and the episode-row and Play-newest paths
do not consult it.

---

## 4. Fresh play versus resume — what the evidence distinguishes

**It distinguishes them, but not by the `start` value alone.** `start = 0.0` has two different
causes in this set, and the captures separate them because the app logs the end-of-playback event.
`ResumeStore.clear` is called at end of playback, and `PlayerScreen.swift:101` starts the next
episode at a hard-coded `0` regardless of any stored resume.

```
$ grep -h "player\] session smts\|player\] played to end" $S/console-run1.log
[player] session smtsnd96aae9c0d recording mode=copy start=2112.000724826 duration=2570.568
[player] played to end
[player] session smtsnf76l45919e recording mode=copy start=0.0 duration=2402.4
```

That shape — a session, `played to end`, then a **different** recording at `0.0` — occurs in five of
the thirteen captures (`run1`, `run5`, `diag`, `diag3`, `final`; `grep -c "played to end"` returns 1
in each of those five and 0 in the other eight). Every one of them is the auto-next path.

**The split, all 27:**

```
$ grep -h "player\] session" $S/console-*.log | grep -c "start=0.0 "
10
$ grep -h "player\] session" $S/console-*.log | grep -vc "start=0.0 "
17
```

| Category | Count | Sessions (by # in §2) |
|---|---|---|
| **Resumed from a stored position** — a show-detail play where the resume store held a value | **17** | 2, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 19, 20, 21, 23, 24, 25 |
| **Fresh play, start hard-coded 0** — auto-play-next after the previous episode ended | **5** | 3, 11, 17, 22, 26 |
| **Fresh play, start 0 because the store held nothing** — first session of its capture, after an earlier capture's end-of-playback cleared that recording's entry | **5** | 1, 4, 12, 18, 27 |

The last two rows are both `start = 0.0` on the wire and are indistinguishable from the session line
alone; they are separated here by the `played to end` line that immediately precedes the auto-next
ones, and by the fact that each of sessions 1, 4, 12, 18 and 27 is the **first** session in its own
capture with no `played to end` before it.

**A caveat on the five "store held nothing" sessions.** They are fresh plays *as far as this
evidence goes* — the app does not log what it read from `ResumeStore`, so "the store held nothing"
is an inference from the sequence, not a direct observation. What is directly observed is that they
were plays begun from show detail and the server echoed `start=0.0`. Named as an inference rather
than presented as a measurement.

---

## OPEN QUESTIONS

Raised, not acted on.

1. **This evidence lives in a session-scoped temp directory, not in the repo.** All thirteen captures
   sit under `/private/tmp/claude-501/…/6cafe40a-…/scratchpad/`, which belongs to one Claude Code
   session and is not guaranteed to survive it. Pass 38's report quotes a handful of these lines and
   is committed, but **the full 27-session set exists only in those files.** If the marlin-dvr
   project may want to re-read them, they should be copied somewhere durable. **This pass did not
   copy them** — the scope lock allows exactly one new file, the report. **Does the owner want a
   later pass to land the raw captures in `reports/`?**

2. **The `start` values are the server's echo, not a log of the app's request.** The app never logs
   its outgoing `CreateBody`; `PlayerModel.swift:122` prints `created.start` from the response.
   Contract §2.2 (`:103`) says the field echoes the requested offset, and §3 depends on that, so the
   numbers should be identical — but if the marlin-dvr project is chasing a discrepancy *between*
   what was sent and what was applied, **this evidence cannot show one**, by construction. Producing
   that would need either a client change to log the request or the server's own request log.

3. **Pass 39's "twenty" is a landed error in a pushed report.** `reports/2026-09-08-pass39-…md:156`
   says "Twenty play sessions"; the set is 27. Pass 39's conclusion is unharmed — all 27 are
   `mode=copy` — but the number is wrong in a file that is on `origin/main`. **Correcting it means
   editing a notebook/report file, which this pass's scope lock forbids.** Reported here as a
   question: should a later pass amend that line, or does this report standing beside it suffice?

4. **Whether 27 is the complete set of play sessions Pass 38 created is not certain.** It is the
   complete set *the captures recorded*, and Pass 38 measured that `devicectl`'s console **drops
   lines under high output volume** (recorded in COLD-START.md under the `CommercialSkipUITests`
   harness note). A dropped `[player] session` line would be invisible here. Two things argue
   against it having happened: the session and `[commercials]` line counts match exactly at 27, and
   the paired test logs show no round with an unexplained extra playback. That is corroboration, not
   proof.

5. **The three recording ids are the owner's library ids and are reproduced unredacted**, as are the
   27 play-session ids. A play-session id is a short-lived server-side handle for one ffmpeg
   process — every one of these was `DELETE`d at the end of its playback — and is neither a
   credential, a device id nor an account identifier, so it falls outside the redaction categories.
   They are also the identifier the marlin-dvr project needs in order to match these against its own
   logs, which is the point of the request. **Redacting them would have made the answer useless**;
   flagged here so the choice is visible rather than assumed.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `reports/2026-09-08-pass39-three-defects-recon.md` | read | WHAT TO READ FIRST; step 1 |
| `COLD-START.md` | read | WHAT TO READ FIRST |
| Pass 38's thirteen `console-*.log` captures (scratchpad) | read | steps 1, 2, 4 |
| Pass 38's `probe.log`, `run4.log` harness logs (scratchpad) | read | step 2 (tying ids to episodes) |
| `Marlin DVR TV/PlaybackSession.swift` | read | step 3 |
| `Marlin DVR TV/PlayRequest.swift` | read | step 3 |
| `Marlin DVR TV/PlayerModel.swift` | read | steps 1, 3 |
| `Marlin DVR TV/ShowDetailScreen.swift` | read | step 3 |
| `Marlin DVR TV/PlayerScreen.swift` | read | steps 3, 4 |
| `Marlin DVR TV/ResumeStore.swift` | read (whole) | step 3 |
| `reports/2026-09-08-pass40-session-start-values.md` | **written** (this file, the only write) | DELIVERABLE |
| the server at 192.168.1.250:8090 | **not contacted in any way** | — |
| `~/Xcode/marlin-dvr-reference` | **not entered** | — |

**Left uncommitted for review**, as the brief directs. `git status --porcelain` shows this report as
the only untracked change and `HEAD` is unchanged at `424c584`.

**Not done, per the scope lock.** The server was not called — not `GET /api/logs`, not
`GET /api/system`, nothing; the app was not run and no play session was created; no Swift written;
no notebook file edited, including the Pass 39 line that carries the wrong count; nothing else
investigated or fixed, including the three defects Pass 39 sorted; the reference clone not entered;
nothing committed or pushed.

**Credential scan.** The Apple TV's `devicectl` device identifier, its LAN address and the app's
persisted client id all appear in the raw captures and **none is reproduced here**. Session ids and
recording ids are reproduced deliberately — see OPEN QUESTIONS 5. The only network address in this
report is `192.168.1.250`, already throughout the notebook.

---

## CLOSING SUMMARY FOR THE OWNER

**Could it be answered from what we already had? Yes — entirely.** Nothing needed to be re-run and
the DVR server was never touched. The recordings the Apple TV played during the commercial-skip
work each logged one line, and those logs are still on the Mac.

**But the number in the request was wrong, and so was the number in my last report.** I said twenty
sessions; there are actually **twenty-seven**. My earlier command tidied the list before counting it
and quietly merged seven lines that looked identical once the session ids were stripped out. The
finding built on it still stands — all twenty-seven were the "copy" mode, so the server never
re-encoded any of them — but the count was wrong and I have said so plainly here rather than quietly
handing over twenty rows.

**What the values show.** Twenty-seven plays of three recordings: mostly *Who Is D.B. Cooper?*, plus
the Osama bin Laden episode and one short *Storage Wars*. Seventeen of them resumed from a saved
position, ten started at zero — five because the app auto-played the next episode (which always
starts at zero), five because there was no saved position left. The saved positions carry odd long
decimals like `1265.0011675380001`, and that turns out to be useful: it proves the app passes the
position straight through without rounding or tidying it.

**The three things I am least certain about.**

1. **This evidence is sitting in a temporary folder, not in the project.** It survived long enough to
   answer today's question, but it is not somewhere I would trust to still be there next week. If
   the DVR project may want it again, it should be saved properly — and I have not done that,
   because this pass was only allowed to write the one report.
2. **These are the numbers the server sent back, not a recording of what the app asked for.** The
   contract says the server echoes the request exactly, so they should be the same — but if the DVR
   project is hunting for a mismatch between the two, this evidence cannot show one.
3. **I cannot be completely sure twenty-seven is all of them.** The console tool that captured these
   is known to drop lines when the app is chatty. Two cross-checks line up, which is reassuring, but
   it is not proof.
