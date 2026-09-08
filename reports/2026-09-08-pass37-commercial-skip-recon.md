# Pass 37 — commercial skip recon

**Date:** 2026-09-08
**Type:** read-only. No Swift written, nothing changed, nothing committed or pushed.
**Working tree:** `~/Xcode/Marlin DVR TV`. One file written: this report.
**The server was not contacted.** The reference clone was not read or entered.

The feature is settled and this pass does not redesign it: while a recording plays,
a small prompt appears for about 5 seconds at the start of a break; press it and
playback jumps past the break; press nothing and it goes away. Everything below
asks only whether the code already in the app can do exactly that.

---

## ⚠ THE REFERENCE FILE DISAPPEARED DURING THIS PASS — read this first

`~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md` **was present and was read in full
at the start of this pass**; §10 exists, describes
`GET /api/library/recordings/{id}/commercials`, and is quoted throughout what
follows. The stop-and-report gate was checked and **passed**.

**The whole folder is now gone.** Measured after the code tracing was finished:

```
$ ls -la /Users/marlin1111/Desktop/marlin-dvr-context
ls: /Users/marlin1111/Desktop/marlin-dvr-context: No such file or directory

$ find /Users/marlin1111/Desktop -maxdepth 2 -iname "*marlin-dvr*"
(no matches)

$ ls -la /Users/marlin1111/Desktop/        # the folder is not there under any name
drwx------@ 10 marlin1111  staff  320 Sep  8 01:30 .
```

Pass 36 created it at 01:09 today; the Desktop's own modification time is 01:30.
**Nothing in this pass deleted it** — this pass writes exactly one file, the report,
and has never written to or removed anything on the Desktop. Most likely the owner
moved or removed it after adding it to the Context panel.

**What this costs, and what it does not.** It costs nothing in §10: that section was
read and quoted before it vanished, and every §10 claim below carries its quoted
line. It costs **one** verification I had intended and could not make — re-reading
**§2.2** to confirm in the contract's own words what `duration` on a play session
means. Step 5's answer therefore rests on the app's own code and its comments,
which I say plainly where it matters. Nothing was recreated, re-fetched or
substituted: this pass is read-only and the clone is out of bounds.

---

## 1. Can the app draw a prompt over playback

**Yes — an app-drawn view over running playback already exists, with a timed
auto-hide. What does not exist is a *pressable* one.**

Everything the app draws over `AVPlayerViewController` is assembled in one `ZStack`,
`PlayerScreen.swift:33-49`. The player goes in first and the app's HUD goes on top
of it, both only while `phase == .playing`:

```
33	        ZStack {
34	            Color.black.ignoresSafeArea()
35	            if model.phase == .playing {
36	                PlayerHost(player: model.player, linearOnly: model.isCamera, shortWindowSelect: model.isLive,
37	                           ownsArrows: model.isRecording && model.isPaused,
38	                           frameStep: { model.frameStep($0) }) { dismiss() }
39	                    .ignoresSafeArea()
40	                hud
41	            }
42	            switch model.phase {
43	            case .starting: StartingOverlay(model: model)
44	            case .ended: EndedState(model: model, focused: $focused, onPlayNext: playNext, onBack: dismiss)
45	            case .failed: FailureState(model: model, focused: $focused, onRetry: { Task { await model.restart() } }, onBack: dismiss)
46	            case .expired: ExpiredState(model: model, focused: $focused, onRestart: { Task { await model.restart() } }, onBack: dismiss)
47	            case .playing: EmptyView()
48	            }
49	        }
```

**The complete inventory of app-drawn views over the player:**

| View | file:line | Attached | Shown when | Over *running* playback? | Pressable? |
|---|---|---|---|---|---|
| `hud` (dispatcher) | `PlayerScreen.swift:72-83` | in the ZStack, above `PlayerHost` | `phase == .playing` | **yes** | no |
| `RecordingHUD` | `PlayerScreen.swift:226-269` | via `hud` | `isRecording` and (`hudVisible` or a notice) | **yes** | no |
| `LiveHUD` | `PlayerScreen.swift:177-222` | via `hud` | live/camera and (`hudVisible` or a notice) | **yes** | no |
| `PausedLiveOverlay` | `PlayerScreen.swift:273-325` | via `hud` | `isPaused && isLive` | no — paused only | no |
| `StartingOverlay` | `PlayerScreen.swift:107-157` | ZStack, `phase == .starting` | before playback | no — replaces the player | no |
| `EndedState` | `PlayerScreen.swift:329-355` | ZStack, `phase == .ended` | playback over | no — replaces the player | **yes** |
| `FailureState` | `PlayerScreen.swift:359-426` | ZStack, `phase == .failed` | failure | no — replaces the player | **yes** |
| `ExpiredState` | `PlayerScreen.swift:428-445` | ZStack, `phase == .expired` | 410 | no — replaces the player | **yes** |

**The dispatcher**, `PlayerScreen.swift:72-83` — note the second branch is exactly
the running-playback case:

```
72	    @ViewBuilder
73	    private var hud: some View {
74	        if model.isPaused && model.isLive {
75	            PausedLiveOverlay(model: model)
76	        } else if model.hudVisible || model.notice != nil {
77	            if model.isRecording {
78	                RecordingHUD(model: model)
79	            } else {
80	                LiveHUD(model: model)
81	            }
82	        }
83	    }
```

**The timed auto-hide already exists and is exactly the 5-second shape the feature
needs.** `PlayerModel.showHUD(for:)`, `PlayerModel.swift:625-634`:

```
625	    func showHUD(for seconds: Double?) {
626	        hudVisible = true
627	        hudTask?.cancel()
628	        guard let seconds else { return }
629	        hudTask = Task { [weak self] in
630	            try? await Task.sleep(for: .seconds(seconds))
631	            guard !Task.isCancelled, let self, !self.isPaused else { return }
632	            self.hudVisible = false
633	        }
634	    }
```

It is called with a duration in four places, three of which are during running
playback: `PlayerModel.swift:151` (`showHUD(for: 6)` the moment the item is
attached and `player.play()` has been called), `:236` (`for: 6` on resuming from
pause), `:388` (`for: 6` after a live seek), `:257` (`for: 8` with a notice). The
one indefinite call is `:228`, `showHUD(for: nil)` on pause.

**So, plainly:** a view the app draws itself, over a recording that is *playing*,
which appears and then disappears on a timer, **already exists and ships today** —
`RecordingHUD` is on screen for the first 6 seconds of every recording. A prompt
that appears for ~5 s and vanishes needs no new mechanism, only new content and a
new trigger.

**What would be new** is that the prompt must be *answerable*. Every pressable
overlay this app has (`StateButton`, `PlayerScreen.swift:502-516`) lives in
`StateCard`, which is `.focusSection()`-ed (`:498`) and only ever appears in a phase
where the player has been replaced — `ended`, `failed`, `expired`. **No focusable
or pressable app view has ever been placed over a running player.** `RecordingHUD`
and `LiveHUD` are `Text` and `VStack` only; neither contains a `Button`, a
`.focusable`, or a `@FocusState` binding. Putting a focusable view over a live
`AVPlayerViewController` is untried in this app and is the one genuinely new thing
step 1 turns up. See OPEN QUESTIONS 1 — it may not need to be focusable at all,
because of what step 2 finds.

---

## 2. Which press the prompt could answer to

**While a recording is PLAYING**, the app claims exactly one press. Here is every
press type, and who has it.

`PlayerScreen.swift:36-38` sets the three switches, and the value of `ownsArrows` is
the whole answer to the arrow question:

```
36	                PlayerHost(player: model.player, linearOnly: model.isCamera, shortWindowSelect: model.isLive,
37	                           ownsArrows: model.isRecording && model.isPaused,
38	                           frameStep: { model.frameStep($0) }) { dismiss() }
```

`isPaused` is false during playback, so **`ownsArrows` is false while a recording
plays**. For a recording `shortWindowSelect` is also false — it is `model.isLive`.

`PlayerHost.pressesBegan`, `PlayerHost.swift:161-178`, is the app's only press entry:

```
161	    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
162	        if presses.contains(where: { $0.type == .menu }) {
163	            onMenu()
164	            return
165	        }
166	        // Pass 28. `frameStep` decides: it acts only while paused on a recording and answers
167	        // false everywhere else, so nothing here changes playing, live or camera behaviour.
168	        if presses.contains(where: { $0.type == .leftArrow }) {
169	            if frameStep(-1) { swallowArrowRelease = true; return }
170	        }
171	        if presses.contains(where: { $0.type == .rightArrow }) {
172	            if frameStep(1) { swallowArrowRelease = true; return }
173	        }
174	        if shortWindowSelect, presses.contains(where: { $0.type == .select }) {
175	            handleShortWindowSelect()
176	        }
177	        super.pressesBegan(presses, with: event)
178	    }
```

`frameStep` refuses while playing — `PlayerModel.swift:327`:

```
327	        guard isRecording, isPaused, phase == .playing, frames != 0, let item = player.currentItem else { return false }
```

so the left/right branches fall through to `super` and the press is Apple's.

**The table. Recording, playing, not paused:**

| Press | Owner during running playback | What it does today |
|---|---|---|
| `.menu` | **this app** | `onMenu()` → `dismiss()` (`PlayerScreen.swift:38`, `:85-90`): stops the session and leaves the Player. Also `.onExitCommand` at `:66`. Never reaches `super` (`PlayerHost.swift:162-165`, and the release is swallowed at `:181`). |
| `.leftArrow` (click) | **Apple's transport** | Skip back. `ownsArrows` is false so `armArrowOwnership` has re-enabled Apple's recognizers; `frameStep` returns false. Measured by Pass 29 as a **10-second skip** (`PlayerHost.swift:23-27`). |
| `.rightArrow` (click) | **Apple's transport** | Skip forward, same 10 s. |
| `.select` | **Apple's transport** | Play/pause and the transport bar. The app's `handleShortWindowSelect` is gated on `shortWindowSelect`, which is `model.isLive` — **false for a recording**, so this code never runs during recording playback. |
| `.upArrow` | **nobody in this app** | No app code references `.upArrow` anywhere (`grep "PressType\."` finds only `.leftArrow`/`.rightArrow` in `PlayerHost.swift:124` and `.select` in `RemoteHold.swift:124`). What Apple's transport does with it **was not measured by this project** and is not asserted here. |
| `.downArrow` | **nobody in this app** | As above — no app code, no measurement. |
| `.playPause` | **nobody in this app** | No app code references it. Not measured. |
| swipes (any direction) | **never reaches app code** | A swipe on the touch surface is not a `UIPress`, so it cannot arrive at `pressesBegan` at all — `PlayerHost.swift:20-21`: "Swipes are untouched: a swipe on the touch surface is not a `UIPress`, so only the discrete click reaches this code at all." |

**What `armArrowOwnership` does, and when.** `PlayerHost.swift:108-120`:

```
108	    func armArrowOwnership(_ owns: Bool) {
109	        guard owns != armed else { return }
110	        armed = owns
111	        if owns {
112	            suppressed = Self.arrowRecognizers(in: playerController.view).filter(\.isEnabled)
113	            suppressed.forEach { $0.isEnabled = false }
114	            print("[framestep] app owns the arrow — \(suppressed.count) player recognizer(s) disabled")
115	        } else {
116	            suppressed.forEach { $0.isEnabled = true }
117	            print("[framestep] arrow returned to the player — \(suppressed.count) recognizer(s) restored")
118	            suppressed = []
119	        }
120	    }
```

It disables **only** the player's own gesture recognizers whose `allowedPressTypes`
contain left or right arrow (`:122-133`), and re-enables exactly those. It is driven
from `makeUIViewController` `:54` and `updateUIViewController` `:61` with
`ownsArrows`, and forced back off in `viewWillDisappear` `:136-139`. **It is armed
only while paused on a recording**, so during running playback the arrows are back
with Apple, by design.

**The output that matters.** Strictly, **no press is unowned during running
playback**: the app has `.menu`, and Apple's transport has select and the arrows.
`.upArrow`, `.downArrow` and `.playPause` are untouched by this app — they are free
*of this app*, not free of Apple, and this project has never measured what Apple
does with them during recording playback.

**But the mechanism to take a press back from Apple exists and is proven on the
device.** `armArrowOwnership` + the `pressesBegan`/`pressesEnded` pair is precisely
a "claim this press while a condition holds, give it back the instant it does not"
machine, and Passes 28/29 settled that it works and that claiming the press alone is
not enough (`PlayerHost.swift:23-31`). Its condition today is
`isRecording && isPaused`; a prompt would need one more condition. **The owner
chooses which press. This pass names none.**

---

## 3. Knowing when playback reaches a break

**Yes — the app already observes position continuously, once a second, and it is
already the place a break would be detected.**

`PlayerModel.observe(_:)`, `PlayerModel.swift:169-173`:

```
169	    private func observe(_ item: AVPlayerItem) {
170	        let interval = CMTime(seconds: 1, preferredTimescale: 10)
171	        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
172	            Task { @MainActor [weak self] in self?.tick() }
173	        }
```

**A periodic time observer at a 1-second interval**, on the main queue, installed
when the item is attached (`attach` calls `observe(item)` at `:146`) and removed in
`detachPlayer` (`:603-604`).

What it is used for — `tick()`, `PlayerModel.swift:203-218`:

```
203	    private func tick() {
204	        guard phase == .playing, let item = player.currentItem else { return }
205	        let t = item.currentTime().seconds
206	        guard t.isFinite else { return }
207	        if isRecording {
208	            position = startOffset + t
209	            refreshFrameRate()
210	            if let range = seekableRange { preparedTo = startOffset + range.end }
211	            if Date().timeIntervalSince(lastResumeSave) >= 10, !isPaused {
212	                saveResume()
213	            }
214	        } else if let range = seekableRange {
215	            behindLive = max(0, range.end - t)
216	            bufferSeconds = range.end - range.start
217	        }
218	    }
```

For a recording it maintains `position` **in absolute seconds from the start of the
recording** (`:208` — `startOffset + t`), refreshes the frame rate, tracks how far
the server has prepared, and saves resume every 10 s.

**`position` is already in exactly the time base §10.4 specifies.** The contract:

> `startSeconds` and `endSeconds` are **seconds from the first frame of the
> recording file** … They match the position `AVPlayer` reports for a **normal
> recording session started with `start` absent or `0`**. If you start a session
> with a `start` offset (§3), that session's positions are relative to `start`
> (`stream.go:255`, `:262`, `:318-319`), so the rule is
> `edlTime = playerPosition + start`.

`startOffset` is the session's `start` (`PlayerModel.swift:47`, set at `:109` and
`:569`), and `position = startOffset + t` is that rule already implemented, for a
different purpose, once a second.

**No boundary time observer is used anywhere.** `grep` finds
`addPeriodicTimeObserver` at `:171` and no `addBoundaryTimeObserver` in the app.
`tick()` does **not** run while paused — noted in the app's own comment at
`PlayerModel.swift:349-350` — which matters only for a prompt that would have to
survive a pause.

---

## 4. Jumping to a given time

**There are exactly two seek mechanisms in the app, and one of them already jumps to
an arbitrary absolute time — but by restarting the session, not by seeking.**

**(a) A real `AVPlayer` seek, used twice.**

Live pause-point recovery, `PlayerModel.swift:253-254`:

```
253	            let target = CMTime(seconds: range.start + 2, preferredTimescale: 10)
254	            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
```

Frame step, `PlayerModel.swift:334-345` — the exact-seek shape, and the only place
the app seeks a recording:

```
334	        item.cancelPendingSeeks()
335	        let from = item.currentTime()
336	        var target = frames > 0 ? CMTimeAdd(from, frameDuration) : CMTimeSubtract(from, frameDuration)
337	        if let range = seekableRange {
338	            let low = CMTime(seconds: range.start, preferredTimescale: Self.frameTimescale)
339	            let high = CMTime(seconds: max(range.start, range.end - 0.05), preferredTimescale: Self.frameTimescale)
340	            if CMTimeCompare(target, low) < 0 { target = low }
341	            if CMTimeCompare(target, high) > 0 { target = high }
342	        }
343	        item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
344	            Task { @MainActor [weak self] in self?.frameStepLanded(from: from) }
345	        }
```

Note `:337-342`: **the app already clamps a seek target to the seekable range**,
low and high, before seeking. That is the clamping shape step 5 asks about, already
written — though against the *prepared* range, not against the duration.

**(b) A new session at an absolute time.** `restart(at:)`,
`PlayerModel.swift:548-561`:

```
548	    func restart(at requested: Double? = nil) async {
549	        let target = requested ?? (isRecording ? position : 0)
550	        writeDone = false
551	        detachPlayer()
552	        keepAliveTask?.cancel()
553	        if let id = session?.id { await sessions.stop(id: id) }
554	        session = nil
555	        if isRecording, let episode = request.episode {
556	            ResumeStore.save(recordingID: episode.id, position: target, duration: duration)
557	        }
558	        startOffset = target
559	        position = target
560	        await startAgain(at: target)
561	    }
```

**Can it seek to an arbitrary absolute time in seconds using existing code?**

- **By new session: yes, today, and it is proven in use.** `restart(at:)` takes an
  absolute second value and `startAgain` (`:563-586`) creates a session with
  `request.withStart(target)`. Its cost is a full teardown — DELETE, POST, first
  playlist fetch (up to 25 s timeout, `PlaybackSession.swift:26`), re-attach — which
  passes through `phase = .starting` at `:564` and therefore **puts the full-screen
  `StartingOverlay` up**, replacing the picture. For a 30-second commercial break
  that is a heavy instrument.
- **By seeking inside the current item: the call exists but no function takes an
  absolute target.** `frameStep` is the only recording seek and its target is always
  `currentTime() ± one frame` (`:336`). Converting an absolute recording second to
  the item's own time is `edlTime - startOffset`, which is `tick()`'s rule at `:208`
  read backwards, but **no code does that today**. The seek call itself would need
  nothing new; the arithmetic and the entry point would.

**What `PlayerModel.swift:382` does.** Line 382 is the first line of the doc comment
for `timeJumped()`; the function itself is `:385-399`:

```
382	    /// A user seek (AVPlayerViewController's scrubber) to the end of the prepared range
383	    /// while the recording is not fully segmented → DELETE, new session at that position,
384	    /// player at 0 (contract §3; standing call).
385	    private func timeJumped() async {
386	        if isLive, phase == .playing, let attachedAt, Date().timeIntervalSince(attachedAt) > 3 {
387	            tick()
388	            showHUD(for: 6)   // a rewind or fast-forward: show how far behind live
389	        }
390	        guard isRecording, phase == .playing, !restartingBeyond, let attachedAt, Date().timeIntervalSince(attachedAt) > 3,
391	              let item = player.currentItem, let range = seekableRange else { return }
392	        let t = item.currentTime().seconds
393	        guard t.isFinite, range.end - t < 1.5, !fullyPrepared else { return }
394	        let target = startOffset + t
395	        print("[player] seek past the prepared range: \(target)s of \(duration)s")
396	        restartingBeyond = true
397	        await restart(at: target)
398	        restartingBeyond = false
399	    }
```

It is driven by `AVPlayerItem.timeJumpedNotification` (`:184-186`), so **any** seek
fires it, including one the app makes itself.

**Would a mid-recording forward jump of a few minutes hit it?** **Usually no, and
the guard at `:393` is why.** Two conditions must both hold:

1. `range.end - t < 1.5` — the playhead must land within 1.5 s of the end of the
   prepared range. AVPlayer clamps a seek beyond the seekable range to its end, so
   "past the prepared range" and "within 1.5 s of its end" are the same landing.
2. `!fullyPrepared` — and `fullyPrepared` is `duration > 0 && preparedTo >= duration - 2`
   (`:90`). **For a finished, fully-segmented recording this is true, so the restart
   can never fire at all**, wherever the jump lands.

So for the ordinary case — a completed recording, a break a few minutes in — a jump
lands deep inside the prepared range, both conditions fail, `timeJumped` returns at
`:393`, and nothing happens beyond the seek. The restart is only reachable when the
recording is **not** fully prepared (still being written, or the server still
segmenting) **and** the target is at or past the prepared edge.

**Relevance of KNOWN AND UNFIXED, reported not fixed.** COLD-START's *KNOWN AND
UNFIXED after Pass 29* names this same restart as the suspect for erratic stepping
near the end of the prepared range — measured at 1:05:27 of a 1:11:10 recording,
where forward clicking moved the clock backwards by 3 s. A commercial-skip jump is
subject to the identical guard, so **a skip near the prepared edge of a
not-yet-complete recording would enter exactly the code path that is already known
to misbehave.** A skip in a completed recording does not go near it. Nothing was
changed.

---

## 5. Duration, for clamping

**Yes — the Player already holds the recording's duration, from the play session,
and neither `/api/play/info` nor `/mediainfo` is called anywhere in this app.**

`PlayerModel.swift:48`:

```
48	    private(set) var duration: Double = 0           // recording: the whole recording (contract §2.2)
```

It is set from the session-create response in both places a session is made —
`:110` in `start()` and `:570` in `startAgain(at:)`:

```
110	            duration = created.duration
570	            duration = created.duration
```

`created` is a `PlaySession`, `Models.swift:394-404`, whose `duration` is a
non-optional `Double` (`:401`, commented "recordings only"). The session is created
by `PlaybackSessionClient.create`, `PlaybackSession.swift:50-63`.

It is already used as a bound: `fullyPrepared` at `PlayerModel.swift:90`, the
`"x of y"` line in `RecordingHUD` at `PlayerScreen.swift:241-243`, and the
end-of-recording guard in `saveResume` at `:618`.

**Neither route step 5 names is called.** Measured across every Swift file in the
repo:

```
$ grep -rn "play/info" --include="*.swift" .        → no matches (exit 1)
$ grep -rn "mediainfo" --include="*.swift" .        → no matches (exit 1)
$ grep -rni "commercial\|/segments" --include="*.swift" .  → no matches (exit 1)
```

There is, however, a **declared-but-unused** `PlayInfo` model, `Models.swift:406-416`,
carrying `duration: Double?` — a shape for `/api/play/info` that nothing constructs.

**One honest limit.** §10.4 says to clamp "to the duration you already have from
`GET /api/play/info?rec=<id>` or `…/mediainfo`". The app has a duration from a third
place — the session response — and its comment at `PlayerModel.swift:48` says that
is the whole recording, citing contract §2.2. **I could not re-read §2.2 to confirm
that in the contract's own words**, because the file disappeared mid-pass (see the
warning above). The claim therefore rests on the app's own comment and on the
consistent way `duration` is used as an absolute bound at `:90`, `:618` and
`PlayerScreen.swift:241-243` — not on the contract read this pass. See OPEN
QUESTIONS 2.

---

## 6. The id, and the API call

**The id: yes, the Player holds it the whole time.**

`PlayerModel` keeps the request as a stored property, `PlayerModel.swift:37`
(`let request: PlayRequest`), and `PlayRequest` exposes the episode at `:81-84`:

```
81	    var episode: Episode? {
82	        if case .recording(let episode, _, _) = self { return episode }
83	        return nil
84	    }
```

`Episode.id` is `Models.swift:236` (`let id: String`). The same value is already
what the play session is created with — `PlayRequest.targetID`, `:35-41`:

```
38	        case .recording(let episode, _, _): return episode.id
```

and it is already used for exactly this kind of per-recording call: `markWatched`
builds `/api/library/recordings/\(recordingID)` from it
(`PlaybackSession.swift:117-118`), as does `ResumeStore` keying
(`PlayerModel.swift:449`, `:556`, `:619`).

§10.1 confirms it is the right id:

> `{id}` is the same recording id §2.1 already uses: `episodes[].id` from
> `GET /api/library/shows/{showId}`

So `model.request.episode?.id` at the moment a recording starts playing **is** the
id the commercials route needs. Nothing new is required to obtain it.

**The existing GET pattern.** `APIClient.get`, `ServerAPI.swift:71-75`:

```
71	    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
72	        var request = URLRequest(url: try url(path, query: query))
73	        request.httpMethod = "GET"
74	        return try await send(request, path: path)
75	    }
```

and `send`, `:112-132` — the whole of the decoding and error handling:

```
112	    private func send<T: Decodable>(_ request: URLRequest, path: String) async throws -> T {
        …
117	        } catch {
118	            throw APIError(kind: .transport, message: error.localizedDescription, path: path)
119	        }
120	        guard let http = response as? HTTPURLResponse else {
121	            throw APIError(kind: .badResponse, message: "not an HTTP response", path: path)
122	        }
123	        guard (200..<300).contains(http.statusCode) else {
124	            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
125	            throw APIError(kind: .http(status: http.statusCode), message: text, path: path)
126	        }
127	        do {
128	            return try decoder.decode(T.self, from: data)
129	        } catch {
130	            throw APIError(kind: .decoding, message: "\(error)", path: path)
131	        }
132	    }
```

Generic over any `Decodable`, one shared `JSONDecoder` with default settings
(`:63` — **no** key-decoding strategy, so JSON keys must match property names
exactly), a plain-text error body surfaced as `APIError.message`, and `httpStatus`
available for a 404 (`:42-45`). **`GET /api/library/recordings/{id}/commercials`
fits this as-is**: one `get` call with an interpolated path and no query items —
the same shape `api.schedule()` and the trash read already use.

**Strict versus lenient, and the one field that would break.** This app's decoders
are overwhelmingly **strict**: plain `Decodable` structs of non-optional `let`s, so
a missing key or a `null` throws. `TrashItem` says so deliberately —
`Models.swift:296-297`:

```
296	/// Decoding is strict on purpose: if the server's shape moves, the read should fail loudly
297	/// rather than draw a screen of blank rows.
```

The two places leniency was allowed are `TrashResponse.init(from:)`
(`Models.swift:327-331`, `decodeIfPresent … ?? []`) and `GuideNowItem`
(`:80`, `decodeIfPresent` for a nested `Program`) — both for a documented,
measured reason.

Comparing §10.2's table against that habit:

| §10 field | §10 says | Against a strict decoder |
|---|---|---|
| `id`, `state`, `count`, `from`, `detail` | always present | fine |
| `ranges` | "Always present; `[]` when there are none" | fine |
| `source` | "Always present; all three fields are `""` when it cannot be established" | fine, including its three inner strings |
| **`edl`** | "**Absent** when there is no markers file (`omitempty`)" | **breaks it.** A non-optional string property throws `keyNotFound` on every recording with no `.edl` — which §10.5 says is the normal `state: "unknown"` / `from: "none"` case |

**`edl` is the one field whose optionality would break a strict decoder.** It is
also the only one marked absent in the contract's own table.

**A second hazard that is about type rather than optionality.** §10.3 says:

> Switch on exactly these four and treat anything else as `"unknown"`.

Decoding `state` as a Swift enum would throw on any fifth value, which is the exact
opposite of what the contract instructs; decoded as a plain string it is safe and
the mapping happens after. Same for `from`. Naming this because it is the kind of
strictness this app's habits would otherwise walk straight into.

**No type was written this pass**, as instructed — the above is a comparison, not a
design.

---

## OPEN QUESTIONS

Raised, not acted on. Nothing was built, changed or worked around.

1. **A focusable view has never been placed over a running `AVPlayerViewController`
   in this app, and it may not need to be.** Step 1 found the drawing and the timer
   already exist; step 2 found the app already takes a press away from Apple
   without any focus involvement at all — `pressesBegan` fires regardless of what
   is focused. So the prompt may be able to be a plain non-focusable view plus a
   press claim, exactly like frame stepping, rather than a focusable button. **Which
   of those two shapes it should be is a real decision and this pass does not make
   it.** What breaks if it goes the focusable way untested: focus moving to an
   overlay may dismiss or fight Apple's transport bar, which nobody here has tried.

2. **§2.2 could not be re-read to confirm what session `duration` means**, because
   the Desktop reference vanished mid-pass. The app's own comment says "the whole
   recording (contract §2.2)" and every use treats it as absolute, but that is the
   app quoting the contract, not the contract. **If the value were ever relative to
   `start`, a clamp built on it after a `restart(at:)` would be wrong.** One line of
   the contract settles it.

3. **The prompt's trigger has to survive a pause, and `tick()` does not run while
   paused** (`PlayerModel.swift:349-350`, and the `guard phase == .playing` at
   `:204` is not the reason — the observer simply does not fire). If a break starts,
   the prompt appears, and the viewer pauses, nothing updates position until play
   resumes. Not a defect today because nothing depends on it; it would become one.

4. **§10's antenna caveat bears directly on step 6 and is the owner's call.** §10.6
   says comskip exits cleanly "commercials not found" on the owner's 720p HDHomeRun
   recordings and segfaults on the 1080i ones, so the server honestly records
   `state: "none"` for antenna recordings that almost certainly do have breaks, and
   the contract recommends treating a `"none"` from `type: "hdhomerun"` like
   `"unknown"`. **That is a behaviour decision, not a code fact**, and the brief
   scopes it out. Reported because it decides what the feature does on roughly the
   owner's whole antenna library.

5. **Nothing here was run.** Every answer is read from source. No build, no
   simulator, no device, no server call. The claims about what Apple's transport
   does with `.select` and the arrows rest on Pass 29's recorded device
   measurements (`PlayerHost.swift:23-31`); the claims about `.upArrow`,
   `.downArrow` and `.playPause` rest on **nothing but the absence of app code**,
   and are labelled as unmeasured rather than guessed.

6. **The `PlayInfo` model at `Models.swift:406-416` is dead code** — declared, never
   constructed, no caller. Noticed while answering step 5. **Not touched**, per the
   scope lock; named only so a later pass knows it is already there if
   `/api/play/info` is ever wanted.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `~/Xcode/Marlin DVR TV/reports/2026-09-08-pass37-commercial-skip-recon.md` | **written** (this file, the only write) | DELIVERABLE |
| `~/Xcode/Marlin DVR TV/COLD-START.md` | read | "WHAT TO READ FIRST"; step 4 (KNOWN AND UNFIXED) |
| `~/Xcode/Marlin DVR TV/DECISIONS.md` | read | "WHAT TO READ FIRST" |
| `~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md` | read (§10, lines 341-513) — **before it vanished** | the gate; steps 4, 5, 6 |
| `Marlin DVR TV/PlayerScreen.swift` | read (whole) | steps 1, 2 |
| `Marlin DVR TV/PlayerHost.swift` | read (whole) | steps 1, 2 |
| `Marlin DVR TV/PlayerModel.swift` | read (whole) | steps 1, 3, 4, 5, 6 |
| `Marlin DVR TV/PlaybackSession.swift` | read (whole) | steps 5, 6 |
| `Marlin DVR TV/PlayRequest.swift` | read (whole) | step 6 |
| `Marlin DVR TV/ServerAPI.swift` | read (whole) | step 6 |
| `Marlin DVR TV/Models.swift` | read (structure, and `:235-264`, `:294-416`) | steps 5, 6 |
| every `*.swift` in the repo | read via `grep` (press types, seek routes, `/api/play/info`, `mediainfo`, `commercial`, `onExitCommand`) | steps 2, 5, 6 |

**Exactly one file was written**, the report, and it is **left uncommitted** for
review. `git status --porcelain` was empty before it and `HEAD` is unchanged at
`18b4c53`.

**Not done, per the scope lock:** no Swift, model, API function or view written —
not a stub, not a disabled one, not a type for §10's response; the feature was not
redesigned and no alternative to the 5-second prompt was proposed; no setting or
auto-skip mode suggested; §10's antenna/comskip caveat reported only, under
OPEN QUESTIONS 4, because it bears on step 6; `COLD-START.md`, `DECISIONS.md` and
every other notebook file untouched; nothing fixed, including the two KNOWN AND
UNFIXED items step 4 touches on and the dead `PlayInfo` model; the server at
192.168.1.250 not called, probed or curled; `~/Xcode/marlin-dvr-reference` not read,
entered or fetched; `design/` not opened; nothing committed or pushed. The
Desktop reference folder was **read from, never written to**, and this pass did not
delete it. No processes left running, no half-written files.

**Credential scan.** Everything quoted was reviewed first. No tokens, passwords,
device ids or account identifiers appear. The only identifier reproduced is the LAN
address `192.168.1.250:8090`, which is already in `ServerAPI.swift:15` and
throughout the notebook. Recording ids quoted from §10's example response
(`5328bb632e76`) are the contract's own illustration, not the owner's data.

---

## CLOSING SUMMARY FOR THE OWNER

**(a) Can the app already put something on screen during playback?** Yes, and it
does it today. Every time you start a recording, the app draws its own panel over
the picture for six seconds and then takes it away on a timer. That is the same
mechanism a five-second prompt needs, already built and shipping. The one part that
is genuinely new is making that panel something you can *press* — everything
pressable the Player has ever drawn only appears once playback has stopped.

**(b) Can it tell when playback reaches a break?** Yes. The app already checks
where you are in the recording once every second, and it already counts that
position the same way the server counts commercial times, so the two line up without
any conversion. It does this for other reasons today; nothing new is needed to know
when a break arrives.

**(c) Can it jump past one?** Yes, with a caveat worth knowing. For an ordinary
finished recording, jumping forward a couple of minutes is an ordinary seek and lands
cleanly. There is a special case in the code for jumping past the part the server has
prepared, which tears the stream down and rebuilds it — that shows the "Preparing"
screen for a moment. For a recording that has finished, that path **cannot** trigger
at all, so a normal skip will not hit it. For something still being recorded, a skip
near the end could hit it, and that is the same area already listed as misbehaving.

**(d) Which buttons are free?** Honestly: none are sitting completely unused. The app
takes Menu. Apple's player takes the centre button and the left/right arrows —
those arrows do a ten-second skip today. Up, down and play/pause are untouched by
this app, but nobody here has ever measured what Apple does with them. The important
part is that the app already knows how to **take a button back** from Apple and hand
it straight back afterwards — that is exactly how frame-stepping works while paused,
proven on your Apple TV. So any of them can be claimed; the question is which one you
want, and that is yours to pick.

**(e) The three things I am least certain about.**

1. **The reference file vanished from your Desktop while I was working.** I had
   already read the commercials section in full, so this recon is complete — but if
   you did not move that folder deliberately, something else did, and one detail I
   wanted to double-check about recording length went unverified as a result.
2. **Whether the prompt should be a button you focus, or just a picture plus a
   claimed remote button.** The second is closer to how the app already works and
   avoids interfering with Apple's controls, but nobody has tried putting a
   focusable thing over a running player, so I cannot tell you what happens if we go
   the other way.
3. **What this will do on your antenna recordings.** The detector fails on that
   hardware and the server reports "no commercials found" for them, which is
   probably wrong rather than true. So the feature could look like it works
   perfectly on Philo recordings and does nothing at all on antenna ones. That is a
   decision about behaviour, not code, and it is yours.
