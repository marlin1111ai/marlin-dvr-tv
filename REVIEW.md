# REVIEW — Marlin DVR TV

**Reviewed at `e7dc4c8` (main = origin/main), 2026-09-23. Read-only:** nothing was built, run, installed or changed, no request of any kind went to the Marlin DVR server, and neither Apple TV was touched.

**72 findings: 1 critical, 16 should fix, 55 nice to have.**

**What was read.** Every tracked Swift file in the app target (51) and in the UI-test target (23) was read in full, along with the project file, the shared scheme, `Info.plist`, the entitlements, `.gitignore` and every asset-catalog `Contents.json`. The notebook was read for the records check. All of `reports/` (104 `.md`, 8 `.txt`) and the text files in `design/` were swept for secrets and personal data, and so was the full git history. The tracked images were checked for embedded location metadata, and the ones likely to show private scenes were viewed.

**How.** Sixteen independent reviewers each took one area of the app or one theme (crashes, dead code, lifecycle, security, fresh clone). Their 125 raw findings were merged into 75. Each of the 75 was then checked twice. One reviewer tried to disprove it against the code. Another searched `COLD-START.md`, `DECISIONS.md`, `COLD-START-HISTORY.md` and every report to see whether it was already recorded. Three were dropped: one was disproved, and two were already on the record. The Guide's per-press recompute is recorded in Passes 75 and 79, and the three copies of the seek clamp were Pass 95's own choice.

**What is left out on purpose.** Nothing here repeats anything the records hold as known, accepted, closed, deferred or decided. That covers COLD-START's *Closed by the owner's call of 2026-09-20*, *What is NOT built* and *Server behaviour this project measured*, DECISIONS 2026-09-20 (Pass 118), and the Pass 99 inventory. Where a finding sits next to a recorded item, the entry says what is new.

**Identifiers.** No credential, client id, device id, signing identity, address or coordinate is quoted anywhere in this file. Each entry says only where the value sits.

---

## Critical

### C1. The owner's home street address, and an exact fix of the house, are in the public repo
`reports/2026-09-06-pass13-weather-radar.md:388` · `reports/2026-09-06-pass14-noaa-radar.md:108` · related: `reports/2026-09-05-pass5-sweep1-foundation.md:74`, `reports/2026-09-05-pass6-sweep2-screens.md:48`, `reports/2026-09-13-pass88-bedroom-install.md:60`

The Pass 13 report quotes the address the reverse geocoder returned for this Apple TV: house number, road and town, followed by "the house". The Pass 14 report prints the NOAA catalog query as it was sent. Its `geometry=` value is the Apple TV's position to a tenth of a metre, and it is the same fix Pass 13 turned into that address. Three other reports quote the Xcode signing identity, which carries the owner's full name and a certificate id. DECISIONS.md:6 records the repo as Public, so anyone who browses or searches it can find the house. The secret scans in Passes 13 and 14 looked for tokens, team ids and UDIDs, not for addresses or coordinates. No record accepts this. Pass 118's "history is never rewritten" covers only the HDHomeRun device ID.

**Fix — this is the owner's call, and it runs into two standing rules.** Redacting the lines hides them from the current files only. They stay in git history, in `71b88d3` (Pass 13) and `68b05b5` (Pass 14), both on origin/main. Getting them out of history takes a history rewrite and a force-push, which CLAUDE.md forbids. The other way is to make the repository private. Even the redaction in the current files needs an exception, because reports are never rewritten (Pass 56).

---

## Should fix

### S1. Pressing ⌘U runs every harness against the live DVR, including the ones that write
`Marlin DVR TV.xcodeproj/xcshareddata/xcschemes/Marlin DVR TV.xcscheme:33` · `Marlin DVR TVUITests/DeleteRefreshUITests.swift:38-42`, `:141-143` · `StopRecordingUITests.swift:89`, `:102`, `:123` · `CommercialSkipUITests.swift:372-381`

The shared scheme's Test action includes the whole UI-test bundle with nothing skipped (`skipped = "NO"`, no skip list). So ⌘U in Xcode, or a plain `xcodebuild test` with no `-only-testing`, runs all 23 harnesses back to back against the server address compiled into the app. Three of them change real things. One moves an episode to the trash. One books whatever is on and then stops the recording. One plays a recording to its end, which marks it watched on both TVs. The fourth risk is in S2. The same run also sits through the hours-long waits in GuideRightEdge and GuideLiveRedraw. Every recorded run named one class with `-only-testing`, so this needs a slip, not everyday use, but a slip costs real recordings.
**Fix:** mark the test target skipped in the scheme, or put the classes that write behind an explicit opt-in, so a harness runs only when it is named.

### S2. ShowDetailSeriesPassUITests can press "Record the series" and create a real series pass
`Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift:248` · related `:62`, `:194-203`, `:246`; `Marlin DVR TV/ShowDetailScreen.swift:260-266`

The notebook says this harness "never presses Record the series". But it runs with `continueAfterFailure = true` (`:62`). When its check that focus is on "Edit series pass" fails (`:246`), it carries on and presses Select anyway (`:248`). If the show it expects to have a pass has lost that pass, the button reads "Record the series". Focus is almost certainly on it, so the Select sends the POST that creates a pass and queues recordings the owner never asked for.
**Fix:** stop the method when the focus check fails, before the Select.

### S3. Server-issued client ids and LAN addresses are unredacted in three early reports, and the app prints them on every launch
`reports/2026-09-05-pass5-sweep1-foundation.md:87`, `:95`, `:141`, `:142` · `reports/2026-09-05-pass6-sweep2-screens.md:78`, `:108`, `:120`, `:121` · `reports/2026-09-07-pass33-trash-restore.md:23` · `Marlin DVR TV/ClientSession.swift:71`, `:91`

The client ids the server issued to the living-room Apple TV, the Simulator and the owner's web browser appear in full in these reports, with the LAN addresses beside them. Every report from Pass 38 on redacts them. These three came earlier, and each pass's own scan checked only the files that pass added. The app also prints the id and the Apple TV's LAN address to the console on every launch (`ClientSession.swift:71`, `:91`). Any console pasted into a future report carries them again unless someone masks them by hand. The practical risk is small, because the server can only be reached from inside the house, but it breaks CLAUDE.md's redaction rule. The HDHomeRun device ID closed in Pass 118 is not part of this finding.
**Fix:** stop printing the id and address, or print a masked form. The old reports and git history have the same caveat as C1.

### S4. Turning Location off in Settings does not stop the app using, and sending, the saved home position
`Marlin DVR TV/WeatherLocation.swift:94` · related `:140-146`; `WeatherModel.swift:102-108`

`start()` returns the cached location fix before it checks the authorization status. If the owner allows location once and later sets Marlin DVR TV to "Never" in tvOS Settings, the app goes on as before. Home and Weather still show the house's weather, and the saved position still goes to Apple's WeatherKit and, through the radar, to NOAA. A withdrawn permission should stop that.
**Fix:** check the authorization status first, and drop the cached fix when access is denied or restricted.

### S5. "Try again" after a failed start wipes the saved resume position
`Marlin DVR TV/PlayerModel.swift:833` · related `:826`, `:832`, `:229-233`

If the owner presses Resume while the server is down or restarting, the error card appears. When he presses "Try again", `restart()` saves the current position before it retries. Playback never attached, so that position is 0, and it overwrites his real place in the recording. If the retry also fails, or he presses Menu while it says "Preparing the recording", the 0 stays. The Resume line, the progress bar and the Continue watching card for that recording disappear, and a spot 40 minutes in is lost for good. The records cover this path's restart target (closed in Pass 99), not this overwrite.
**Fix:** save nothing when playback never attached, or keep the stored entry until the retry lands.

### S6. A frame step in the first second of a recording can crash the app
`Marlin DVR TV/PlayerModel.swift:422` · related `:208`, `:429`, `:438`; `PlayerHost.swift:314-319`

`attach()` sets the Player to playing before the video item is ready (`:208`). Pass 96 measured the gap at 0.45–0.79 s. `frameStep`'s guard checks pause, phase and the item, but not that the item is ready. So pressing pause and then Left or Right in that gap sends a seek with a completion handler to an item that is not ready. AVFoundation is widely reported to raise an exception for that, which closes the app. A related effect: a click just after the item becomes ready cancels the resume seek that is still running (`cancelPendingSeeks`, `:429`), and the recording starts from the top instead of the saved spot.
**Fix:** add "item is ready and no resume seek is pending" to `frameStep`'s guard.

### S7. Empty Scheduled Recordings or Your Passes: Menu drops out of the app
`Marlin DVR TV/ScheduleManageView.swift:113` · `Marlin DVR TV/PassesManageView.swift:75` · related `ScheduleManageView.swift:51`, `:77`, `:98`; `PassesManageView.swift:39`, `:50`

When either list is empty, the screen holds only plain text and nothing can take focus. By the trap Pass 33 measured, Menu then goes to the system, and the owner lands on the Apple TV Home screen instead of Manage DVR. That happens after cancelling the last scheduled recording, after deleting the last series pass, or when opening Scheduled Recordings with nothing booked. Pass 33 fixed the same trap in Trash by making its empty sentence focusable (`TrashManageView.swift:56`). These two lists never got that fix. The outcome is inferred from Pass 33's measurement; it was not run here.
**Fix:** make the empty sentence focusable, as Trash does.

### S8. Manage DVR shows a failed read as "no passes", "nothing scheduled" or "Reading the server…"
`Marlin DVR TV/ManageDVRScreen.swift:65` · related `:60`, `:70`, `:163`, `:209`; `PassesManageView.swift:75`; `ScheduleManageView.swift:113`

If the passes or disk-space read fails, the error only goes to the console. The screen then says "0 passes" and "No series passes yet", hides every "Manage pass" button, and the storage bar shows "Reading the server…" for as long as the screen is open. A failed schedule read does show an error, but the list underneath still says "Nothing is scheduled", and `refreshSchedule` never clears that error after a later success. After a server update, or during a brief outage, the owner would believe his passes were gone. The same file already tracks Trash's error separately so as not to "claim the trash is empty" (`:43-45`).
**Fix:** keep an error for each section, as Trash does, and show it.

### S9. After a Delete on a show's page, the Player still auto-plays the deleted episode as "next"
`Marlin DVR TV/ShowDetailScreen.swift:211` · related `:74-81`; `PlayRequest.swift:136`; `PlayerScreen.swift:83`

Show detail hands the Player the show exactly as it was first loaded (`model.detail`). A Keep or Delete updates only the episode list on screen (`:74-81`). Suppose the owner deletes a newer episode and then, without leaving the page, watches an older one to the end. The next-episode countdown offers the deleted episode, plays it after 10 seconds, and lands on a failure screen, because a trashed recording's id changes. It keeps happening until he leaves the show's page.
**Fix:** apply the Keep or Delete to the show that play requests are built from, too.

### S10. A programme title containing "+" or ";" cannot be opened from Search or On Later
`Marlin DVR TV/ChannelFilter.swift:102` · related `:93`, `:97-99`; `ServerAPI.swift:105`; `Models.swift:459`; `AiringSheet.swift:43`; `OnLaterScreen.swift:79`

The app builds its query strings with `URLComponents`, which leaves "+" and ";" as they are. The Go server reads a "+" as a space and drops any pair containing an unescaped ";". So a title such as "A + B" reaches the server as "A   B", and the whole-title search finds nothing. Search and On Later then say "The server no longer lists that airing", and the poster lookup misses as well. The Guide's logo path already escapes values the Go way (Pass 86). Whether the owner's listings contain any such title has not been measured.
**Fix:** percent-encode "+" and ";" in query values, reusing the Go-style escaper.

### S11. Guide reads that finish out of order can fill the grid with the wrong window
`Marlin DVR TV/GuideScreen.swift:234` · related `:140-144`, `:167-174`, `:213-222`, `:520-524`, `:767-775`

`fetch` stores whichever answer arrives last, without checking that it still belongs to the window and collection on screen. For example: press +12h a second time, then press Menu before that read comes back. The Guide snaps back to now but is filled with listings for 24 hours later. The grid is blank, the "↩ Now" pill is hidden, and it stays that way until the next half-hour roll or until the Guide is left. The opening lasts one server round trip, so this is rare, but when it happens the Guide looks broken with nothing to explain it.
**Fix:** tag each fetch, with a counter or by comparing the window and filter after the await, and discard stale answers.

### S12. An info panel left open across a programme change keeps the old show's pass and drops the new airing's status
`Marlin DVR TV/PlayerInfoPanel.swift:233` · related `:397-431`, `:453-463`, `:482-490`, `:494-506`

On live TV the panel's `.task(id: program?.end)` restarts itself when it loads the next airing, which cancels its own pass and schedule reads halfway through. So when one programme ends with the panel open, the panel shows the new title and description but keeps the old show's series-pass line and "Edit pass" button. It also loses the new airing's state: a show already Scheduled or Recording shows a plain "Record". "Edit pass" then opens the previous show's pass. Pass 108 lists this path as code-traced only; the defect in it is not recorded.
**Fix:** don't key the task on a value the task itself changes. Load the pass and schedule for the new airing in a task of their own.

### S13. After deleting a series pass from the airing sheet, the sheet still shows the deleted booking
`Marlin DVR TV/AiringSheet.swift:150` · related `:169`

After a write, the sheet re-reads the schedule and keeps its old copy of the booking "if the read fails". But the lookup returns nothing both when the read fails and when the booking is gone, so the old copy is kept in both cases. After "Edit series pass" → Delete, the sheet says "Series pass deleted." yet still shows "● Scheduled · Queued" and no "Record this airing", while the Guide behind it has already dropped its mark. The same fallback at `:169` brings back a booking that was cancelled elsewhere when the sheet opens.
**Fix:** fall back to the old copy only when the read actually throws.

### S14. Favorites never re-reads, so it goes stale and hands the Player a programme that has ended
`Marlin DVR TV/FavoritesScreen.swift:92` · related `:118`, `:139-142`; `PlayRequest.swift:112`

Favorites reads what is on now once, when it opens. Watch a channel for an hour and press Menu, and the rows still show the old programmes and end times. Pick another favourite and the Starting screen and the transport bar label it "‹old title› · until ‹a past time›". On Now avoids this by reloading every 60 s.
**Fix:** reload the way On Now does, or at least when the Player closes.

### S15. Every 45 seconds, every camera picture blinks out to the "snapshot.jpg" placeholder
`Marlin DVR TV/CamerasScreen.swift:48` · related `:36`, `:127-135`; `ServerImage.swift:19-30`

Each refresh gives every snapshot a new address, so that a fresh picture is fetched. The image view throws the old picture away as soon as the address changes. Until the new one arrives, each card shows a dark panel with the word "snapshot.jpg". So all the cameras blink at once on every refresh and come back one by one. How long they stay blank has not been measured.
**Fix:** keep drawing the previous picture until the new one has loaded.

### S16. On a fresh install, Weather's "Try again" after a location failure never asks again
`Marlin DVR TV/WeatherLocation.swift:118` · related `:65`, `:90-115`, `:166-173`

The first location request sets a "requested" flag that is never cleared. If that first request fails, or is not answered within 25 s, "Try again" never sends a new one. It shows "Finding this Apple TV's location…" for 25 s and reports a timeout, every time, until the app is quit. Allowing location in Settings after a denial that arrived as an error has the same result. Both Apple TVs already hold a cached fix, so this hits a new Apple TV, a reinstall or cleared app data.
**Fix:** clear the flag when a request fails or times out.

---

## Nice to have

### App behaviour

**N1. A failed Guide read leaves the header and the grid disagreeing, with no error.** `Marlin DVR TV/GuideScreen.swift:248` · related `:391`. After +12h, ↩ Now, a right-edge step or a collection pick, the header and the collections button already show the new time or collection. If the read then fails, the grid keeps the old listings, which are mostly blank against the new window, and no error appears, because the error line is only drawn when there are no rows at all. A second +12h jumps another 12 hours. After an outage the event stream's reconnect usually repairs it.

**N2. Search can open the wrong sheet on a quick second click, or open one after you have left.** `Marlin DVR TV/GuideSearchScreen.swift:140` · related `:338-340`; `AiringSheet.swift:56-64`. `open()` has no in-flight guard, although On Later's has one (`OnLaterScreen.swift:314`). Click a second result before the first opens and the sheet can show the second programme with the first one's recording state and buttons. "Stop recording" on it would stop the first programme's recording. Click and press Menu at once, and the sheet turns up uninvited on the next visit to Search.

**N3. Search keeps its channel list for the life of the app.** `Marlin DVR TV/GuideSearchScreen.swift:153` · related `:151-152`. The list is re-read only when a channel id is missing. A rename or renumber keeps the id, so the airing sheet opened from Search shows the old number and name until the app is quit. The comment at `:151-152` says renames are covered, but they are not. Recording is unaffected.

**N4. The Home Recordings tile says "0 recording now" when the schedule could not be read.** `Marlin DVR TV/HomeView.swift:76` · related `:65-73`. The count starts at 0 and stays there on failure, while the On Later tile beside it correctly says "unavailable".

**N5. Leaving Home mid-load writes "unavailable" into the tiles.** `Marlin DVR TV/HomeView.swift:132` · related `:53-57`, `:99-101`. Leaving cancels the reads still in flight, and each catch treats the cancellation as a failure. The Home model outlives the screen, so on return the affected tiles briefly say "unavailable" (Radio says "Stations"), and the console logs failures that never happened.

**N6. On Now: a failed or late chip load leaves another chip's channels under the active chip.** `Marlin DVR TV/OnNowScreen.swift:87` · related `:137`, `:200-202`. On failure the list is left as it was, with no error, because the error line needs an empty list. An older answer arriving late can overwrite a newer one until the next minute's reload.

**N7. Favorites and Cameras show "0 favourite channels" / "0 of 0 online" above the error line.** `Marlin DVR TV/FavoritesScreen.swift:68` · `Marlin DVR TV/CamerasScreen.swift:68`. After a failed first read the header reads like a real answer. Radio and On Later already hide their counts on failure (`RadioScreen.swift:65`, `OnLaterScreen.swift:419`).

**N8. Favorites would crash if the server listed a channel twice.** `Marlin DVR TV/FavoritesScreen.swift:41`. `Dictionary(uniqueKeysWithValues:)` stops the app on a repeated key, and the surrounding do/catch cannot catch that. It has never been seen in `/api/guide/now`, but the Guide removes duplicates from collection results for exactly this reason (`GuideScreen.swift:229-234`).

**N9. On Now and Cameras keep polling while the Player covers them.** `Marlin DVR TV/CamerasScreen.swift:98` · `Marlin DVR TV/OnNowScreen.swift:167-179`. Cameras re-reads every 45 s, and re-fetches every snapshot, for the whole time a camera or channel plays. On Now does the same every 60 s. It is small, unseen traffic. The Guide's own beat behind the Player is recorded and is not part of this.

**N10. With the server down, Menu leaves a black Player for up to 15 s.** `Marlin DVR TV/PlayerScreen.swift:123` · related `PlayerModel.swift:763`, `:898`. Menu waits for the session DELETE (15 s timeout) before it closes the Player. A second Menu gets out at once. `fail()` has the same order, so the failure card also waits.

**N11. A session created just after Menu is never deleted.** `Marlin DVR TV/PlayerModel.swift:154` · related `:126`, `:747`, `:873`, `:888-900`. If Menu is pressed, or the app goes to the background, while the create request is in flight, `start()` stores the new session and returns without a DELETE. The server frees it after about 15 s idle. On live TV that tuner stays busy for those seconds.

**N12. The next episode can start twice.** `Marlin DVR TV/PlayerScreen.swift:129` · related `:376`; `PlayerModel.swift:708-724`. `playNext` has no re-entry guard. A second press, or the countdown firing during a press, while the redundant DELETE from N47 is outstanding starts two players. The discarded player's session never gets a DELETE.

**N13. A stale "Stopped … Starting the channel…" line stays on later failure cards.** `Marlin DVR TV/PlayerModel.swift:827` · related `:808`; `PlayerScreen.swift:425`, `:432`. After "Stop the recording and watch", that notice is never cleared. If the channel then fails, the new card still ends with it, and on another busy-tuner error the Stop button comes back beside it.

**N14. Menu pressed just after the info panel opens leaves the Player.** `Marlin DVR TV/PlayerScreen.swift:52` · related `PlayerHost.swift:307-311`; `ScreenChrome.swift:148-153`. The panel takes focus about 80 ms after it opens. A Menu in that gap goes to the player container, which always dismisses. The comment at `PlayerScreen.swift:89-91` says this moment is covered, but it is not.

**N15. Failure and Expired cards end with a stray " · " for a live channel with no listing.** `Marlin DVR TV/PlayerScreen.swift:430`, `:466`. An example is a favourite with no guide data that hits a busy tuner. The Starting screen already skips an empty subtitle.

**N16. A 25 fps recording is frame-stepped at 23.976 fps.** `Marlin DVR TV/PlayerModel.swift:396` · related `:388`. The rate is snapped to the first standard rate within 5 %, in list order, not to the nearest one, so an exact 25 becomes 23.976. The 5 % rule itself is recorded; the list-order effect is not. The owner's 29.97 fps recordings are unaffected.

**N17. The radar's tile watchdog is never started if the first catalog read failed and a refresh recovers.** `Marlin DVR TV/RadarScreen.swift:123` · related `:71-90`, `:147-164`. If the tiles then fail, you get a bare map with a moving frame counter and no warning.

**N18. NOAA's "error inside a 200" message can never be shown.** `Marlin DVR TV/RadarSource.swift:192` · related `:139-148`. `features` is required in the decoder, so a refusal body, which has no `features`, fails to decode before the error branch can run. The viewer sees the generic "could not read" text instead of NOAA's reason.

**N19. The radar's shared tile counters and failure text are written from background threads without a lock.** `Marlin DVR TV/RadarSource.swift:291` · related `:288-306`, `:341-375`; `RadarScreen.swift:154-157`. The main thread reads them every 5 s. Usually the only effect is lost counts. A read of the failure text at the moment it is being replaced could crash, and that is most likely exactly when tiles are failing. `RadarTileStore` already has an `NSLock` that could guard them.

**N20. A radio stream that stalls after it starts keeps saying NOW PLAYING over silence.** `Marlin DVR TV/RadioPlayer.swift:193` · related `:31-34`. The stall is only printed. That breaks the screen's own rule, "silence presented as playing is not allowed" (DECISIONS, Pass 19).

**N21. Show detail's size total disagrees with the episode sizes under it.** `Marlin DVR TV/ShowDetailScreen.swift:89` · related `:453`. The total uses the 1000-based formatter, while each row shows the server's 1024-based label, so the total reads 5–7 % high. Pass 33 added `SizeFormat.serverStyle` so the app would not contradict the web UI, but used it only for Trash: the rows and the Trash total on the Manage DVR hub.

### Privacy

**N22. The radar sends the Apple TV's position to NOAA to a tenth of a metre, and the location prompt says it is "used once, on the device".** `Marlin DVR TV/RadarSource.swift:114` · `Info.plist:6`. The position is sent on every radar open and every 5-minute refresh, when a rounded point would pick the same regional series. The purpose string does not mention that the location also goes to Apple (WeatherKit and the geocoder) and to NOAA.

**N23. Radar and weather screenshots place the house to about a kilometre.** `reports/assets/pass13/atv-06-radar-tiles-composite-diagnostic.png`, `atv-07-radar-loop-frame3-diagnostic.png`, `atv-08-radar-loop-frame1-diagnostic.png` show latitude and longitude to two decimals in the header. `reports/assets/pass22/atv-05-alert-card-staged-diagnostic.png` names the county. The town itself is already in the notebook's text. Once C1 is dealt with, these are the next-best clue. The C1 history caveat applies.

**N24. About a dozen screenshots show the outdoor camera's live picture.** `reports/assets/pass7/81-camera-playing.jpg` · also `pass6/40-cameras.png`, `pass7/80-camera-starting-6a.jpg`, `pass7/82-cameras-after-menu.jpg`, `pass7/97-7c-camera.jpg`, `pass25/atv-31-player-up.png`, `pass72/before-72h2-cameras.jpg`, `pass72/after-72h2-cameras.jpg`. They show field, fence, outbuildings and neighbouring houses, with a date-time stamp. On their own they name no place, but together with C1 they show a stranger the layout of the property.

### Leftover code and stale comments

**N25. Options no caller uses.** `Marlin DVR TV/ChannelFilter.swift:43-49` (`channels(source:filter:)`: all six callers pass nothing) · `Theme.swift:94` (`Color(hex:opacity:)`) · `ChannelActionsMenu.swift:103`, `:108`, `:114` (`MenuRow.enabled`: none of the 17 rows disables) · `ScreenChrome.swift:155-157` (`LoadingLine.text`) · `ScreenChrome.swift:69-73`, `:87-90` (`focusTreatment`'s `cornerRadius` and `lift`).

**N26. Leftovers of the removed per-show trash walk.** `Marlin DVR TV/ChannelFilter.swift:124-128`: `show(id:trash:)` has no caller passing `trash:`. `Models.swift:423-424`: `trashCount` and `showingTrash` are decoded as required and never read, so show detail would fail to open if the server dropped them. `EpisodeActionsMenu.swift:61`: the "In the trash" state is unreachable. `ManageDVRScreen.swift:19-21`: the header still gives the old reason, which was later corrected.

**N27. Values kept up to date and never read.** `Marlin DVR TV/ClientSession.swift:22` (`status`) · `HomeView.swift:19` (`loaded`) · `RadioScreen.swift:26` (`count`; its comment at `:25` promises a comparison that is never made) · `OnLaterScreen.swift:107` (`requestCount`) · `CommercialSegments.swift:141` (`CommercialPrompt.index`) · `EditSeriesPassScreen.swift:45-51` (the keep choices' labels).

**N28. `PlayerModel.clientName` has had no reader since Pass 110.** `Marlin DVR TV/PlayerModel.swift:38` · related `PlayerScreen.swift:27`, `:35-39`, `:135`; `ContentView.swift:54`. Its only reader was the deleted "Resume kept by …" line, but the name is still passed through three files.

**N29. `frameStep`'s two `frameRate <= 1` checks can never be true.** `Marlin DVR TV/PlayerModel.swift:423-424`. The rate starts at 30 and is only ever set to a standard rate of at least 23.976.

**N30. Radar leftovers from Passes 13–16.** `Marlin DVR TV/RadarScreen.swift:348`: `renderers` is filled and never read. `RadarSource.swift:229-230`, `:288`, `:292-293`: the store gauges and three tile counters are never read. `RadarSource.swift:74`, `:162`: two optionals that are always set, so the fallback at `RadarScreen.swift:80` is dead. `RadarScreen.swift:18-25`, `:36` and `RadarSource.swift:281`: comments that still describe the alpha-swap animation Pass 15 replaced. `RadarScreen.swift:382`: a leftover `PASS15 attempt 3` tag.

**N31. `PlaceholderScreen` and the content switch's `default` arm can no longer be reached.** `Marlin DVR TV/ScreenShell.swift:108` · related `:113-132`. The arm also hides a missing screen at compile time, and it would show the old "built in sweep 2" page instead.

**N32. The episode menu's removed options are still in the code.** `Marlin DVR TV/ServerWrites.swift:141-142`, `:148-149`, `:158-159`: `RecordingFlag.favorite` and `.watched` have not been constructed since the owner dropped those rows. The branch at `EpisodeActionsMenu.swift:120` goes with them. Comments at `ServerWrites.swift:199`, `ShowDetailScreen.swift:11-13` and `:418` still describe a four-row menu. Separately, `PlaybackSession.swift:166-176` builds the "mark watched" request by hand instead of reusing the existing one.

**N33. Unused declarations.** `Marlin DVR TV/Theme.swift:22` (`Nocturne.section`) · `Theme.swift:49-57` (the whole `Nocturne.Space` scale) · `ManageDVRScreen.swift:26-29` (`ManageSection`'s `Identifiable` conformance).

**N34. Comments that describe behaviour the code no longer has, in Manage DVR and Trash.** `Marlin DVR TV/ManageDVRScreen.swift:5-6` says the screen is reached from a row on Recordings; that row moved to the rail in Pass 10B. `TrashManageView.swift:191` promises a raw-date fallback the code does not do. `TrashManageView.swift:17-18` says trashing does not change a recording's id, but Pass 33 measured that it does.

**N35. Player comments that describe the HLS-era behaviour.** `Marlin DVR TV/PlaybackSession.swift:5-6` says sessions are created with `format: "hls"`, but recordings have used `"file"` since Pass 42. `PlayerModel.swift:5` says "one HLS session". `PlayerModel.swift:654-656` says a restart puts the player at 0.

### Simpler or faster

**N36. Programme text helpers are copied across three screens.** `Marlin DVR TV/AiringSheet.swift:105-131` · `OnNowScreen.swift:225-241` · `OnLaterScreen.swift:58-69`. The tags, the episode line and the day-and-time line are each written two or three times. The card and the sheet order the episode line differently, which may be the design's intent.

**N37. The action-overlay layout is copied three times.** `Marlin DVR TV/ChannelActionsMenu.swift:32` · `GuideCollections.swift:146-207` · `EpisodeActionsMenu.swift:39-90`. The backdrop, heading, card size and shadow, Menu handling and focus delay are all repeated.

**N38. The schedule join and refresh are copied into three screen models.** `Marlin DVR TV/GuideScreen.swift:267-269`, `:284-290` · `GuideSearchScreen.swift:170-182` · `OnLaterScreen.swift:278-298`. They all agree today, and one shared helper would keep it that way. The Player panel's copy is the recorded Pass 108 mirror and is not part of this.

**N39. `lastCell` always equals `lastGridFocus` at the one place it is read.** `Marlin DVR TV/GuideScreen.swift:321` · related `:501-502`, `:518`.

**N40. `overlayOpen` exists, but the same three-part condition is still written out four times.** `Marlin DVR TV/GuideScreen.swift:662` · related `:364`, `:422`, `:574`, `:630`.

**N41. The Home tile hand-codes the shared focus look.** `Marlin DVR TV/HomeView.swift:255-267` repeats `FocusTreatment` (`ScreenChrome.swift:69-91`) line for line.

**N42. There are two separate builders for the show-poster address.** `Marlin DVR TV/Models.swift:456-461` (Trash) and `AiringSheet.swift:39-45` (everything else). A fix for S10 could easily miss the Trash copy.

**N43. `start()` and `startAgain(at:)` duplicate the steps after the session is created, and the copies have drifted.** `Marlin DVR TV/PlayerModel.swift:863` · related `:124-160`. Given a playlist address it cannot resolve, `start()` fails loudly and deletes the session (`:137-139`). `startAgain` returns silently, leaving the Starting screen up and the session open.

**N44. The server address is typed twice.** `Marlin DVR TV/ServerAPI.swift:18` (`hostLabel`, the rail footer) repeats `baseURL` at `:15` by hand. The two could drift apart.

**N45. Show detail builds a new date parser for every episode row on every redraw, and re-reads saved positions about three times per episode on every remote move.** `Marlin DVR TV/ShowDetailScreen.swift:444` · related `:131-134`, `:182`, `:236`, `:402`. `ServerTime.date` (`Formatting.swift:98-116`) already does this parse and Trash uses it.

**N46. A new URLSession is made for every Guide visit and two for every Player start, and none is ever closed.** `Marlin DVR TV/PlaybackSession.swift:45`, `:54` · `ServerEvents.swift:59-68` · related `PlayerModel.swift:110`. The cost over days of uptime has not been measured. Sharing one session of each kind, or invalidating them on teardown, avoids it.

**N47. A recording played to its end sends its session DELETE twice.** `Marlin DVR TV/PlayerModel.swift:713` · related `:898`. `playedToEnd` keeps `session` set, so leaving the end card, or starting the next episode, sends a second DELETE and waits for it. `fail()` already clears it (`:766`).

**N48. Radio background observers pile up.** `Marlin DVR TV/RadioPlayer.swift:86` · related `:130`; `RadioScreen.swift:53`. Each `RadioPlayer` registers a background-notification observer that `stop()` never removes. A throwaway `RadioPlayer` is also built every time `RadioScreen` is initialised, which happens on each rail focus move while on Radio. So the registrations grow for as long as the app stays in memory.

### UI-test harnesses

**N49. Harness helpers are copy-pasted across 7–22 files, and one fix never reached the other copies.** `Marlin DVR TVUITests/CommercialSkipUITests.swift:55` · related `GuideRightEdgeUITests.swift:135-151`. `GuideRightEdgeUITests` learned that the expanded rail also says "Marlin", so seeing that word does not prove Home is on screen. The other seven `goHome()` copies still stop on it.

**N50. Four harnesses still steer by the old 10-entry rail or the removed Recordings row.** `Marlin DVR TVUITests/RailFocusRestoreUITests.swift:26-29` (`testEveryRailEntryLandsOnItself` fails at `:103`) · `RailManageUITests.swift:71-75` · `TrashRestoreUITests.swift:37-38`, `:109-124` · `ManageDVRUITests.swift:36-47`. Each stops at an early step, so none of them checks what it was written to check.

**N51. Two harnesses wait 40 s for an On Later subtitle that Pass 82 removed.** `Marlin DVR TVUITests/GuideSearchUITests.swift:32`, `:95` · `GuideCollectionsUITests.swift:35`, `:453`. Every method logs a false "On Later did not load".

**N52. Three Pass 76 methods remain whose premise the file itself calls meaningless since Pass 77.** `Marlin DVR TVUITests/GuideRightEdgeUITests.swift:1254`, `:1315`, `:1367` · related `:371-374`. The documented whole-class run includes them, and one presses Right 14 times and then fails by design.

**N53. Late in the evening, one harness crashes and another proves nothing.** `Marlin DVR TVUITests/GuideCollectionsUITests.swift:243-248` · `GuideLiveRedrawUITests.swift:124-128`. From 10:30 PM to midnight the Guide's window label uses "→" instead of "–". The first harness then force-unwraps a missing match (`:248`). The second compares "ABSENT" with "ABSENT", so its window-unmoved check always passes.

**N54. A force unwrap straight after a non-fatal assertion turns a missing element into a runner crash.** `Marlin DVR TVUITests/ContinueWatchingUITests.swift:148` · related `:47`, `:141`; `GuideCollectionsUITests.swift:245-248`, `:275`.

**N55. The Guide-collection harnesses can leave the Apple TV's Guide on "Local".** `Marlin DVR TVUITests/GuideCollectionsUITests.swift:371-402` never resets the collection pick. `GuideRightEdgeUITests.swift:1048` and `:1058` return early and skip the reset at `:1075`. Where a reset does run, it chooses All Channels rather than whatever the owner had picked before.
