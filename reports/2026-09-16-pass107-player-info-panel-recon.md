# Pass 107 — the Player's swipe-down info panel (read-only recon)

**Date:** 2026-09-16
**READ-ONLY.** No source file, test file, project file or asset was changed. No build, no device
run, neither Apple TV touched. `~/Xcode/marlin-dvr-reference` was not fetched, pulled or checked
out. **Every request to `http://192.168.1.250:8090/` was a GET on a read-only route** — 14 of them,
listed in §2.0 — and no POST, PUT, PATCH or DELETE was sent. `GET /api/settings` was not read.

**HEAD every `file:line` below was read at: `db38beb03aa7413dfcda3b63d682f3eff3847114`** (Pass 106),
with `git status --porcelain` showing only `?? icon-source/`. Line numbers drift and are never
rewritten afterwards (COLD-START, *Standing state of the devices*).

**Nothing here is built, proposed or ranked.** Where the notebook records no option, this report
says so and invents none.

## The owner's decisions this recon is for (2026-09-16), in substance

Modelled on a Channels DVR screenshot he showed (**that screenshot is not in this repo or in
`design/`**; the only upload there is the Home tiles screenshot): while watching a recording or a
live channel, **swiping down on the remote brings up an info panel** — the channel logo, the show's
title, the episode name with season and episode, HD / rating tags if the server provides them, and
the description; **no channel number**. Buttons:

- **Recording:** "Add to season pass"; "Edit pass" when the show already has one.
- **Live channel:** "Record"; "Add to pass" ("Edit pass" when a pass exists); "Favorite", or
  "Unfavorite" when the channel already is one. **Favorite is live channels only.**
- **"Record"** reports "● Recording" or "● Scheduled" when that airing already has that state, as
  the airing sheet's first control does (Pass 49).
- **Each button does what the app's existing control of the same kind does** (airing sheet, show
  detail, the Guide's hold on a channel).

## How each claim is labelled

| Thing | Version | Read how |
|---|---|---|
| The running server | **1.9.3** | `GET /api/status` at 22:17:09 −0400 → `{"name":"marlin-dvr","version":"1.9.3","uptime_seconds":4275,"port":8089}` |
| The reference clone | **1.8.1** | `HEAD` = `eb0c098de3efc8bb569e252b63e141aa10262918`, `cmd/marlin-dvr/main.go:38` `appVersion = "1.8.1"` |
| The contract `HLS-CLIENT-API.md` | **1.7.0** | its own header, lines 5–8 |
| The tvOS SDK header read for AVKit | **tvOS 27.0 SDK** (`xcrun --sdk appletvos --show-sdk-version`) | `AppleTVOS27.0.sdk/…/AVKit.framework/Headers/AVPlayerViewController.h`; both Apple TVs run tvOS 26.6, the app's deployment target is 18.0 (`project.pbxproj:250`, `:305`) |

- **[GET 1.9.3]** — answered 200 by the running server today, by a GET this pass sent.
- **[source 1.8.1]** — read from the clone's Go. Never called.
- **[contract 1.7.0]** — read from `HLS-CLIENT-API.md`. Never called.
- **[SDK]** — Apple's own header comment in the tvOS 27.0 SDK on this Mac. **Not observed on a
  television by this pass.**

**The running server is 1.9.3, not the 1.9.1 COLD-START records** (*The server*, `COLD-START.md:41`)
nor the 1.9.2 Pass 103 read. The clone is now **four releases behind** it (1.8.1 → 1.8.2 → 1.9.1 →
1.9.2 → 1.9.3). **COLD-START's server line was not edited** — this pass names only its *Next step*
— and it is open question 1.

---

## 1. What a swipe down does in the Player today

### 1.1 Nothing in the app handles a swipe down. It is AVKit's, on a recording and on live alike.

**No code path in the app branches on a swipe down, or on the down or up direction at all.**
`grep` over the app target for `downArrow`, `upArrow`, `onMoveCommand` inside the Player,
`UISwipeGestureRecognizer`, `UIPanGestureRecognizer`, `infoViewActions`, `customInfoViewControllers`,
`transportBarCustomMenuItems`, `contextualActions`, `customOverlayViewController`,
`playbackControlsIncludeInfoViews` and `MPNowPlayingInfo` finds nothing. The Player is
`AVPlayerViewController` hosted as a child with Apple's controls on:

- `PlayerHost.swift:5-6` — *"AVPlayerViewController hosted as a child of a container controller
  (standing call: Apple's transport UI as-is)."*
- `PlayerHost.swift:112-118` — `attach` sets only `player`, `showsPlaybackControls = true`,
  `requiresLinearPlayback` (cameras, `PlayerScreen.swift:36`) and
  `allowsPictureInPicturePlayback = false`.
- `PlayerHost.swift:197` — `preferredFocusEnvironments` is `[playerController]`, and `:199-207`
  forces a focus update on appear and again 0.5 s later.

**The one customisation of Apple's panel content is the item's `externalMetadata`**:
`PlayerModel.swift:200` sets it from `metadata(for:)` (`:240-251`), which supplies **two items and
no others** — `.commonIdentifierTitle` = `request.title` and `.iTunesMetadataTrackSubTitle` =
`request.subtitle`. No artwork, description, rating or genre is supplied. What those two strings are:

| | `request.title` | `request.subtitle` |
|---|---|---|
| Live | `"ch\(channel.number) \(channel.name)"` — `PlayRequest.swift:101` — **carries the channel number** | `"\(program.title) · until \(end)"`, or `""` with no programme — `:110-112` |
| Recording | `episode.show` — `:102` | `"S\(season) E\(episode) · \(episodeTitle) · \(episode.channel)"` — `:113-118` — `episode.channel` is `"9001 HISTORY"` on this server **[GET 1.9.3]**, so **it carries the channel number too** |

**What Apple's SDK says those properties do [SDK]** (`AVPlayerViewController.h`):

- `:255-259` `playbackControlsIncludeInfoViews` — *"Whether or not the receiver shows the views for
  video metadata, navigation markers, and playback settings when requested by the user. Default is
  YES."* The app never sets it.
- `:262-268` `transportBarIncludesTitleView` — *"The title view requires metadata … provided using
  externalMetadata … Supported keys are: AVMetadataCommonIdentifierTitle for title,
  AVMetadataIdentifieriTunesMetadataTrackSubTitle for subtitle."* Those are exactly the app's two.
- `:339-343` `customInfoViewControllers` (tvOS 15.0) — *"An array of view controllers to be
  displayed as tabs."* Never set.
- `:346-350` `infoViewActions` (tvOS 15.0) — *"Use this property to provide **up to 2** custom action
  controls displayed in the content info view. Default value is an array containing a single 'Play
  From Beginning' action."* Never set, so the default applies.
- `:271-275` `customOverlayViewController` (tvOS 13.0) — *"accessed by swiping **up** during playback
  … Clients should provide a view controller here rather than installing their own swipe gesture
  recognizer."* Never set.
- `:278-282` `transportBarCustomMenuItems` and `:303-308` `contextualActions` (tvOS 15.0) — never set.

**So, traced:** a swipe down on either kind reaches AVPlayerViewController's own info views, enabled
by default, fed only the two metadata strings above, with Apple's default "Play From Beginning"
action. **This project has never observed that panel**: no report, screenshot or notebook entry
mentions a swipe down in the Player (`grep` over `reports/`, `DECISIONS.md`, both COLD-START files).
What tvOS 26.6 actually draws from those two strings, and what "Play From Beginning" does to a live
HLS item, are unmeasured.

A swipe is not a `UIPress`, so none of the press-claiming code below can see it — the notebook
already records this for the arrows (DECISIONS.md, 2026-09-07 (frame-by-frame): *"a swipe on the
touch surface is not a `UIPress`"*; `PlayerHost.swift:20-21`).

### 1.2 Everything that claims the remote while the Player is up

| What | Where | Claims | When |
|---|---|---|---|
| Menu | `PlayerHost.swift:218-221` → `onMenu` → `PlayerScreen.swift:40` `dismiss()` (`:90-95`: `model.stop()` then `onDismiss`) | Menu | always; its release swallowed at `:243` |
| `.onExitCommand` | `PlayerScreen.swift:71` | Menu | the same `dismiss()`, for a Menu the container does not get |
| Frame step | `PlayerHost.swift:224-229` → `PlayerModel.frameStep` (`:420-442`) | left/right **click** | acts only while paused on a recording (`:422`); otherwise falls to `super` (`:239`) |
| **`armArrowOwnership`** | `PlayerHost.swift:134-146`, driven by `ownsArrows: model.isRecording && model.isPaused` (`PlayerScreen.swift:37`) | disables every enabled press recognizer in the player's view tree whose `allowedPressTypes` contains left **or** right (`:148-150`, `:178-188`) | paused on a recording |
| **`armSelectOwnership`** | `PlayerHost.swift:157-170`, driven by `ownsSelect: model.commercialPrompt != nil` (`PlayerScreen.swift:38`) | disables the player's `.select` press recognizers (`:172-174`) | only while the commercial-skip prompt is up |
| Commercial skip | `PlayerHost.swift:233-235` → `PlayerModel.skipCommercialBreak` (`:562-584`) | Select | only while the prompt is up; release swallowed `:248-251` |
| Pass 7C live pause | `PlayerHost.swift:236-238` → `handleShortWindowSelect` (`:257-283`) | Select, acted on 0.35 s later if the player's state did not change | live only (`shortWindowSelect: model.isLive`, `PlayerScreen.swift:36`), while the seekable window is under 60 s |
| Restore | `PlayerHost.swift:191-195` `viewWillDisappear` | returns both claims | on disappear |
| `RemoteHold` | window-level `UILongPressGestureRecognizer` on `.select` (`RemoteHold.swift:122-127`), installed by `ContentView.swift:48` | Select hold | **still installed while the Player is up**, but `hold.suspended = id != nil` (`ContentView.swift:51`) makes `fire` return at once (`RemoteHold.swift:54`) |
| Cover dismissal | `ContentView.swift:53-59` `.fullScreenCover` with `.interactiveDismissDisabled(true)` | — | always |
| Background | `PlayerScreen.swift:68-70` | — | `scenePhase == .background` dismisses |

**One interaction worth knowing before a build, traced from the code and Pass 29's own
measurement:** `PlayerHost.swift:26-27` records that *"Two `AVNonDigitizerTapRecognizer`s inside its
view claim `[up/down/left/right]`"*, and `arrowRecognizers` matches any recognizer claiming left
**or** right. **So while paused on a recording, the recognizers that also claim up and down clicks
are disabled with the arrows.** A touch-surface swipe is not affected by construction —
`recognizers(in:claiming:)` skips any recognizer with empty `allowedPressTypes` (`:181`). Whether
AVKit opens its info panel from a down *click* as well as a swipe, and so whether this matters, has
never been measured.

**Recording versus live, today:** the swipe-down path is identical — nothing kind-dependent touches
it. The kind-dependent differences are all in the table above: `ownsArrows` and `ownsSelect` are
recording-only, `shortWindowSelect` is live-only, `requiresLinearPlayback` is cameras-only.

### 1.3 What `design/` shows

- **No frame draws a swipe-down panel, an info panel, or any control on it.**
- `Marlin DVR TV.dc.html:856` — the Player section's own subtitle: *"Apple's player owns the
  transport; these are the states the app has to dress around it"*.
- Frame **6b** (*"Live playing — no scrubbing, ~12-second window"*, `:885`) draws a bottom card whose
  right side reads `❙❙`, **`Info`**, `Channels` (`:901-903`).
- Frame **6c** (*"Recording playing — the timeline grows as the server prepares it"*, `:920`) draws
  `❙❙`, **`Info`**, `Next episode` (`:932-934`).
- Those two `<span>Info</span>` labels (`:902`, `:933`) are **the only occurrences of the word "Info"
  in the file**. Neither is given a behaviour, a panel or content.
- The nearest drawn control set is frame **5c**, *"Airing detail over the guide — Record Now and
  Series Pass"* (`:541-544`), with `Watch live` at `:571` — the airing sheet, not the Player.

---

## 2. Each panel field: in hand, needs a read, or not provided

### 2.0 The GETs this pass sent (all 200, 22:17 −0400, server 1.9.3)

`/api/status`; `/api/library`; `/api/library/shows/{id}` for `history-s-greatest-mysteries`,
`hitler-s-dna`, `the-proof-is-out-there`, `the-food-that-built-america`; `/api/channels`;
`/api/art/feed?u=<the HISTORY channel's logo, escaped as GuideChannelTile.artFeedPath does>`
(`image/png`, 29,550 bytes); `/api/art/show?title=History's Greatest Mysteries` (`image/jpeg`);
`/api/guide/now`; `/api/guide?slots=4`; `/api/schedule`; `/api/passes`. **Fourteen, and nothing
else.** `GET /api/play/info` exists (`main.go:333`, `stream.go:577-613` **[source 1.8.1]**) and was
**not** called: no panel field needs it, and its `rec=` branch runs a media probe on the server.

### 2.1 What playback starts with

`PlayRequest` (`PlayRequest.swift:12-15`) is all the Player is given, and it is immutable for the
life of a `PlayerModel` (`PlayerModel.swift:37` `let request`):

- `.live(channel: MergedChannel, program: Program?)` — from On Now (`OnNowScreen.swift:146`), a
  Guide click on a current cell (`GuideScreen.swift:326`), the Guide sheet's Watch live (`:427`),
  On Later's sheet (`OnLaterScreen.swift:384`), Favorites (`FavoritesScreen.swift:118`). Search's
  Watch live does not play (`GuideSearchScreen.swift:262-267`).
- `.recording(episode: Episode, show: ShowResponse?, start:)` — from show detail only
  (`ShowDetailScreen.swift:211`, passing `model.detail`), and Play next (`PlayerScreen.swift:101`),
  which keeps the same `show`.

### 2.2 Recording

| Field | Status | Where |
|---|---|---|
| **Channel logo** | **Not provided by the server.** A recording carries a channel **string**, no channel id and no logo | `Episode.channel` `Models.swift:382`; `episodeView` `library.go:513-527` and `Channel: j.Number + " " + j.ChannelName` at `recorder.go:301` **[source 1.8.1]**; at 1.9.3 the episode keys are `aired, airedLabel, changedAt, channel, channelAbbr, dateLabel, description, detect, episode, episodeTitle, exists, ext, favorite, file, fileLabel, firstSeen, id, keep, meta, modTime, path, playUrl, remux, root, season, show, showId, size, sizeLabel, tags, thumb, trash, trashedAt, watched, watchedAt` — **no channel id, no logo** **[GET 1.9.3]**. Measured, not a link the server makes: all 11 recordings read `"9001 HISTORY"` or `"9002 FYI"`, and `GET /api/channels` holds a channel whose `number + " " + name` spells each (`philo:6044`, `philo:6045`), both with a `logo` **[GET 1.9.3]** |
| **Show's title** | **In hand** | `episode.show` `Models.swift:364`; equals the show detail title on every recording read **[GET 1.9.3]** |
| **Episode name** | **In hand** | `episode.episodeTitle` `Models.swift:366`. **Empty on `d9a4f5c76696`** (Hitler's DNA) **[GET 1.9.3]**; the server substitutes "Season N, Episode M" only when a season is known (`library.go:599-601` **[source 1.8.1]**) |
| **Season / episode** | **In hand** | `Models.swift:367-368`. **0 / 0 on `d9a4f5c76696`** **[GET 1.9.3]** — the same `S0 E0` Pass 103 left open |
| **HD tag** | **In hand, inside `tags`** | `Episode.tags` `Models.swift:381`. The server builds one array from the probe — `"HD"` at height ≥ 720, `"4K"` replacing it at ≥ 2000, the codec, `"5.1"`/`"Stereo"`/`"Mono"`, `"CC"` — **and only when a probe is cached** (`library.go:552-574` **[source 1.8.1]**). Every recording today: `["HD", "H264", "Stereo", "TV-PG"]` or `…"TV-14"` **[GET 1.9.3]** |
| **Rating tag** | **In hand, inside the same `tags`** | appended from `Meta.Rating` unless `"None"` (`library.go:589-591` **[source 1.8.1]**). The 1.9.3 response also carries `meta.rating` (`"TV-PG"` on `5328bb632e76`) **[GET 1.9.3]**, which the app does not decode (`Episode` has no `meta`, `Models.swift:360-389`) |
| **Description** | **In hand** | `episode.description` `Models.swift:380`; the server's default is `"No description available."` (`library.go:551` **[source 1.8.1]**); non-empty on all 11 today **[GET 1.9.3]** |
| **Pass state** (for the button) | **Needs a read** for the editor; a title is in hand | `ShowResponse.pass` `Models.swift:407` is the matching pass **title** — non-empty for 3 of the 4 shows today, `""` for Hitler's DNA **[GET 1.9.3]** — and it is as old as show detail's load. Opening `EditSeriesPassScreen` needs the `PassView`, so show detail reads **`GET /api/passes`** (`ShowDetailScreen.swift:327-337`) **[GET 1.9.3: 200, 8 passes, every `seriesId` `title:`-prefixed, every `channel` `""`]** |

### 2.3 Live channel

| Field | Status | Where |
|---|---|---|
| **Channel logo** | **In hand** as a URL; drawing it is a read | `channel.logo` `Models.swift:25`. The Guide draws it through `GET /api/art/feed?u=` (`GuideChannelTile`, `GuideScreen.swift:846-894`, escaping at `:887-894`) **[GET 1.9.3: 200 `image/png`]**. 96 of 97 channels have a logo **[GET 1.9.3]** |
| **Show's title** | **In hand when there is a programme**, as it was at the moment of tuning | `program?.title` `Models.swift:69`. **`program` is `nil`** when Favorites plays a favourite with no listing (`FavoritesScreen.swift:118`, `model.onNow[channel.id]?.program`); 9 of 97 channels have nothing on now **[GET 1.9.3]**, none of them among today's 4 favourites. **Nothing re-reads the programme during playback** — `request` is a `let` and the HUD's own line still says *"until"* the tuned programme's end (`PlayRequest.swift:112`). The only server reads of "what is on now" take the **whole lineup** — `GET /api/guide/now` accepts `source` and `filter` and no channel (`guide.go:726-750` **[source 1.8.1]**; `ChannelFilter.swift:52-59`) — or `GET /api/guide` (`:61-70`) **[both GET 1.9.3]** |
| **Episode name** | **In hand when the listing has one** | `program.episodeTitle` `Models.swift:70` — 68 of 88 programmes on now **[GET 1.9.3]** |
| **Season / episode** | **In hand when the listing has them** | `program.season`/`episode` `Models.swift:72-73` — 52 of 88; `episodeNum` (`:74`, e.g. `"S2E5"`, `"E185"`) — 56 of 88 **[GET 1.9.3]** |
| **HD tag** | **In hand**, from two fields | `channel.hd` `Models.swift:26` (93 of 97 channels) — what the airing sheet draws (`AiringSheet.swift:116`); and `program.video` `Models.swift:84`, `"HDTV"` on 59 of 88, absent on the rest, never drawn anywhere in the app. On now: 59 `hd && HDTV`, 26 `hd` with no `video`, 3 neither — **no programme is `HDTV` on a non-HD channel** **[GET 1.9.3]** |
| **Rating tag** | **In hand when the listing has one** | `program.rating` `Models.swift:82` — 66 of 88 (`TV-PG`, `TV-14`, `TV-G`, `R`, `PG-13`, `PG`) **[GET 1.9.3]**; the sheet appends it to its when-line (`AiringSheet.swift:129`) |
| **Description** | **In hand when there is a programme** | `program.desc` `Models.swift:71` — 88 of 88 **[GET 1.9.3]** |
| **Favorite state** (for the button) | **In hand, and possibly stale** | `channel.favorite` `Models.swift:29`, as of the screen's own read. **The Guide passes `cell.channel`** (`GuideScreen.swift:326`), whose flag is the fetch-time value, **while a hold's change lives only in `GuideModel.favouriteOverrides`** (`:253-262`) until the next fetch. `GET /api/channels` and `GET /api/guide/now` both carry `favorite` **[GET 1.9.3]**; 4 channels are favourites today |
| **Airing state** (for "Record") | **Needs a read** | the airing's `Job` from **`GET /api/schedule`** (`ChannelFilter.swift:107-116`), matched on `channelId` + `program.start` (`GuideScreen.swift:249-251`) **[GET 1.9.3: 200, 9 jobs, all `Queued`, none `manual`, none on now]** |
| **Pass state** (for "Add to pass") | **Needs a read** | **`GET /api/passes`**, matched by `AiringSheet.matchingPass(in:program:)` (`AiringSheet.swift:340-350`) **[GET 1.9.3]**. At 22:17 **no programme on now matched any of the 8 passes** — the nearest, `"Pawn Stars: Best Of"` on 9001 HISTORY, does not equal the pass title `"Pawn Stars"` under that rule |

---

## 3. Each button: what it would reuse, whether it is callable unchanged, its routes

**Callable unchanged from the Player** means: reachable from `PlayerScreen`, which already holds
`api` (`PlayerScreen.swift:18`), without editing the file it lives in. Every write route below is
from **source at 1.8.1** and the app's own call; **none was called, and none is confirmed at 1.9.3.**

### 3.1 Recording — "Add to season pass" / "Edit pass"

**The existing control:** show detail's series-pass button, Pass 103 — `ShowDetailScreen.swift:260-266`
(`pass == nil ? "Record the series" : "Edit series pass"`), fed by `loadPass()` (`:327-337`), the
write `recordSeries()` (`:356-380`), the footer `passFooter` (`:301-318`) and the editor block
(`:160-180`).

| Piece | Callable unchanged? |
|---|---|
| `ShowDetailScreen.matchingPass(in:showTitle:)` `:339-343` | **Yes** — `static` |
| `api.passes()` `ServerWrites.swift:229-232`; `api.createPass(title:seriesId:)` `:192-197` | **Yes** — `APIClient` extension |
| `AiringSheet.friendly(_:fallback:)` `AiringSheet.swift:434-443` | **Yes** — `static` |
| `EditSeriesPassScreen(pass:api:onChanged:onDeleted:onClose:)` `EditSeriesPassScreen.swift:28-34` | **Yes as a view** — but it is a focusable 980 pt card with its own `.focusSection()` and `.onExitCommand` (`:129-134`), and no focusable view has ever been put over a running player (§4.6) |
| `loadPass()`, `recordSeries()`, the `pass`/`busy`/`message`/`failed` state (`:113-117`), `action(_:id:run:)` (`:283-295`), `passFooter` | **No** — `private` members and `@State` of `ShowDetailScreen`. Reusing them means copying, the way Pass 103 copied `AiringSheet.recordSeries()` |

**The title to match on** is `episode.show` (§2.2), which equals show detail's `showTitle` on every
recording today. **Labels differ from the existing control's**: "Add to season pass" / "Edit pass"
against "Record the series" / "Edit series pass" — the owner named the panel's; see §5.7 for the
sentences.

| Route | Kind | Label |
|---|---|---|
| `GET /api/passes` | read | **[GET 1.9.3]** 200 |
| `POST /api/passes` `{title, seriesId?}` | write | **[source 1.8.1]** `passes.go:705-737`; 409 *"a pass for this series already exists: <title>"* at `:723` |
| `PUT /api/passes/{id}` (editor) | write | **[source 1.8.1]** `passes.go:740-796` |
| `DELETE /api/passes/{id}` (editor) | write | **[source 1.8.1]** `passes.go:799-824` |

### 3.2 Live — "Record" (● Recording / ● Scheduled)

**The existing control:** the airing sheet's first control, Pass 49 — `airingState`
(`AiringSheet.swift:83-88`: `"Recording"` → recording; `"Queued"`/`"Conflict"` → scheduled; else
unbooked), drawn at `:250-257` as `StateChip("● Recording")`, `StateChip("● Scheduled", detail:
job.status)` or the button "Record this airing", which runs `record()` (`:352-369`). The sheet
learns the job by calling `onScheduleChanged()` on open (`:161-172`) and after the write (`:361`);
the Guide supplies that closure as `refreshSchedule()` plus a job lookup (`GuideScreen.swift:429-432`,
`:249-251`, `:266-272`).

| Piece | Callable unchanged? |
|---|---|
| `api.recordNow(channelId:start:)` `ServerWrites.swift:183-187`; `api.schedule()` `ChannelFilter.swift:107-116` | **Yes** |
| `StateChip` `AiringSheet.swift:447-475` | **Yes** — internal struct |
| `AiringSheet.friendly` | **Yes** |
| `airingState`, `record()`, `firstFocusID` (`:185-187`) | **No** — `private` to `AiringSheet` |
| `GuideModel.job(channelId:programStart:)`, `refreshSchedule()` | **No** — instance methods on the Guide's model, which the Player does not have |
| `AiringSheet` itself | **As a view, yes, only with a non-`nil` `Program`** (`AiringSelection.program`, `:34`) — and it is the whole 1400 × 586 pt sheet (`:236`) with poster, flags, **"Watch live"** (drawn whenever `isAiringNow`, `:267-275`, which a live item always is) and **"Stop recording"** (`:276-280`), neither of which the owner named |

**What the write does on the server when the airing is on now** — which, from a live panel, it
always is: `handleRecordNow` finds the listing by `start` (`recorder.go:797-811`), refuses an airing
already ended with 400 (`:812-815`), refuses a duplicate with 409 *"that airing is already set to
record"* (`:837`), then calls `a.recorderTick() // starts it now if it is airing; otherwise the loop
picks it up` (`:847`) **[source 1.8.1]**. The recording therefore starts at once, alongside the
viewer's own live session.

| Route | Kind | Label |
|---|---|---|
| `GET /api/schedule` | read | **[GET 1.9.3]** 200 |
| `POST /api/record` `{channelId, start}` | write | **[source 1.8.1]** `recorder.go:781-855` |

### 3.3 Live — "Add to pass" / "Edit pass"

**The existing control:** the airing sheet's series button — `AiringSheet.swift:258-266`, `loadPass()`
`:328-338`, `recordSeries()` `:371-395` (`createPass(title: program.title, seriesId: program.seriesId)`
at `:376`, then `onScheduleChanged()` at `:379`), the 409 branch `:381-388`, the footer `:299-321`,
the editor block `:137-157`.

| Piece | Callable unchanged? |
|---|---|
| `AiringSheet.matchingPass(in:program:)` `:340-350` | **Yes** — `static`; needs a `Program` |
| `api.passes()`, `api.createPass(...)`, `AiringSheet.friendly` | **Yes** |
| `EditSeriesPassScreen` | **Yes as a view** — same focus caveat as §3.1 |
| `loadPass()`, `recordSeries()`, the sheet's state | **No** — `private` |

Routes: as §3.1 — `GET /api/passes` **[GET 1.9.3]**; `POST /api/passes`, `PUT` and `DELETE
/api/passes/{id}` **[source 1.8.1]**.

### 3.4 Live — "Favorite" / "Unfavorite"

**The existing control:** the Guide's hold on a channel cell — `HoldButton` with an empty click
(`GuideScreen.swift:769`), `handleHold()` (`:334-349`) opening `ChannelActionsMenu`
(`:409-419`), whose one row reads `isFavourite ? "Unfavorite" : "Favorite"`
(`ChannelActionsMenu.swift:29`, `:48-56`) and runs `apply()` (`:83-94`); the Guide then records the
new flag in `favouriteOverrides` (`GuideScreen.swift:414-415`, `:260-262`).

| Piece | Callable unchanged? |
|---|---|
| `api.setChannelFavourite(sourceId:guid:favourite:)` `ServerWrites.swift:221-225` | **Yes** |
| `WriteError.text` `ServerWrites.swift:271-279` | **Yes** |
| `ChannelActionsMenu(channel:isFavourite:api:onApplied:onClose:)` `ChannelActionsMenu.swift:17-23` | **Yes as a view** — a focusable 860 pt card with `.focusSection()` and `.onExitCommand` (`:69-74`); same focus caveat |
| `apply()` | **No** — `private` |
| **The trigger** — the hold | **No.** `RemoteHold` is suspended while the Player is up (`ContentView.swift:51`, `RemoteHold.swift:54`), and the Guide's `favouriteOverrides` belongs to `GuideModel` |

| Route | Kind | Label |
|---|---|---|
| `PUT /api/sources/{sourceId}/lineup/{guid}` `{"favorite": Bool}` | write | **[source 1.8.1]** `sources.go:985-1029`, answering the stored override (`:1028`); server-wide — the web UI and the other Apple TV see it (`ChannelActionsMenu.swift:11-12`) |
| `GET /api/channels`, `GET /api/guide/now` (the flag) | read | **[GET 1.9.3]** 200, both carry `favorite` |

---

## 4. Do-not-touch and fragile paths a build would cross

### 4.1 The Player teardown

- `PlayerModel.stop()` `:888-900` and `detachPlayer()` `:902-916` — detach, cancel keep-alive, HUD,
  prompt and countdown tasks, DELETE the session; `detachPlayer` also calls
  `dismissCommercialPrompt()` (`:915`) so no Select claim outlives its item.
- `PlayerScreen.dismiss()` `:90-95`, `.onDisappear { model.stop() }` `:74`, `scenePhase` `:68-70`.
- `playNext()` `PlayerScreen.swift:98-107` **replaces `model` wholesale** with a new `PlayerModel`.
- `playedToEnd()` `PlayerModel.swift:708-724`, `sessionExpired()` `:698-704`, `fail()` `:746-769`.
- **`PlayerHost` exists only while `phase == .playing`** (`PlayerScreen.swift:35-46`). Any phase
  change — Starting on a restart, Ended, Failed, Expired — removes the `PlayerContainerController`
  and its `AVPlayerViewController` from the tree; coming back to `.playing` builds new ones through
  `makeUIViewController` (`PlayerHost.swift:64-73`). **Anything set on either controller is set again
  or lost at each of those points.**
- The Player is a root `fullScreenCover` keyed on `PlayRequest.id` (`ContentView.swift:53`,
  `PlayRequest.swift:17-23`); the screens underneath keep their state and do not reload when it
  closes (COLD-START.md:99; Pass 8 Open Question 6, `reports/2026-09-06-pass8-sweep4-writes.md:360-361`).

### 4.2 The two `arm*Ownership` functions

- `armArrowOwnership` `PlayerHost.swift:134-146`; `armSelectOwnership` `:157-170`; the shared matcher
  `recognizers(in:claiming:)` `:178-188`; both restored in `viewWillDisappear` `:191-195`; both
  re-driven on **every** `updateUIViewController` (`:75-81`), i.e. on every SwiftUI update of
  `PlayerScreen`'s body — a no-op unless the value changed (`:135`, `:158`).
- **Known and unfixed:** *"`armArrowOwnership` depends on `AVPlayerViewController`'s internals and
  fails open to Apple's skip if a future tvOS changes them"* (COLD-START.md:86).
- The up/down side effect while paused on a recording — §1.2.
- Each walks `playerController.view`'s whole tree at the moment it arms. A view or view controller
  added **inside** that tree carries its own recognizers into the walk; one added beside it does not.

### 4.3 `restart(at:)`

- `PlayerModel.swift:825-847`; **`position = target` at `:845` is load-bearing** — it is how the
  target reaches `armResumeSeek` (`:229-238`) — and `startAgain(at:)` `:854-885`.
- Traced only, never driven on a television; no restart caller is reachable from the remote
  (COLD-START.md:93). `timeJumped()` `:657-671` is its other caller.

### 4.4 `PlaybackSession.swift`

- `create` `:69-82`, the app's only `POST /api/play/sessions` (`:70`); `firstFileByte` `:114-127`
  with its own 11-minute `URLSession` (`:37`, `:51-54`); `keepAlive` `:130-141`; `stop` `:144-155`;
  `markWatched` `:167-176`.
- **No panel field or button in §2–§3 needs anything from this file.**

### 4.5 Commercial skip's Select

- The claim: `PlayerHost.swift:233-235`, `ownsSelect` `PlayerScreen.swift:38`, `armSelectOwnership`.
- The prompt: `noticeCommercialBreak` `PlayerModel.swift:518-528` (only while not paused, `:519`),
  `armPromptTimeout` `:534-542`, `dismissCommercialPrompt` `:546-550`, dismissed on a pause (`:322`)
  and on detach (`:915`); `skipCommercialBreak` `:562-584`.
- The prompt view is deliberately not focusable — `PlayerScreen.swift:282-287`.
- **A break is offered at most once per playback** (`promptedRanges`, `:516-522`; COLD-START.md:95):
  anything that seeks backwards over a break — Apple's default "Play From Beginning" among them —
  spends it. Traced; not observed.
- Only `5328bb632e76` and `d9a4f5c76696` carry markers at all (Pass 94).

### 4.6 Focus over a running player

- **DECISIONS.md:473-475 (Pass 38):** *"No focusable view has ever been placed over a running
  `AVPlayerViewController` in this app (Pass 37 Open Question 1) and Pass 38 was told not to be the
  first."* The question itself: `reports/2026-09-08-pass37-commercial-skip-recon.md:614-621`.
- `PlayerContainerController` steers focus into the player: `preferredFocusEnvironments`
  (`PlayerHost.swift:197`) and two forced updates on appear, the second 0.5 s later (`:199-207`).

### 4.7 Pass 7C's Select on live

- `PlayerHost.swift:236-238`, `:257-283`: **any** Select that reaches the container's `pressesBegan`
  on a live item with a seekable window under 60 s schedules a pause or resume 0.35 s later, unless
  Apple's handler already changed the player's state. Whether a press on a panel control reaches
  that `pressesBegan` depends on where the control sits in the responder chain. **Never measured.**

---

## 5. Where building this needs the owner's call

Each with its file and quote. **No option is invented and nothing is proposed.**

**5.1 — Whose panel.** A swipe down already opens AVKit's own info views (§1.1), and the standing
call is Apple's transport as-is:

> `PlayerHost.swift:5-6` — *"AVPlayerViewController hosted as a child of a container controller
> (standing call: Apple's transport UI as-is)."*
> `design/Marlin DVR TV.dc.html:856` — *"Apple's player owns the transport; these are the states the
> app has to dress around it"*

The decisions say what the panel holds and that a swipe down brings it up; **the notebook records
nothing on how it relates to the panel AVKit already shows there.** One fact bears on it and is
stated only as a fact: the SDK documents `infoViewActions` as *"up to 2 custom action controls"*
(`AVPlayerViewController.h:346-350`), and the live panel names three buttons.

**5.2 — A focusable control over a running player.**

> DECISIONS.md:473-475 — *"No focusable view has ever been placed over a running
> `AVPlayerViewController` in this app (Pass 37 Open Question 1) and Pass 38 was told not to be the
> first."*

The panel's buttons, and the two existing screens they would open (`EditSeriesPassScreen`,
`ChannelActionsMenu`), are focusable. Nothing in the notebook lifts that instruction.

**5.3 — Which programme a live panel describes and acts on.** The request is fixed at tuning:

> `PlayerModel.swift:37` — `let request: PlayRequest`
> `PlayRequest.swift:112` — `return "\(program.title) · until \(TimeFormat.clock(unix: program.end))"`

Live playback runs on past that end, and the viewer can sit behind live in the time-shift buffer
(contract §4). "Record" and "Add to pass" each act on one airing. **The decisions do not say which
airing that is once the tuned programme has ended, or while the picture is behind live**, and the
notebook records nothing on it.

**5.4 — A live channel with no listing.**

> `FavoritesScreen.swift:118` — `onPlay(.live(channel: channel, program: model.onNow[channel.id]?.program))`
> `AiringSheet.swift:34` — `let program: Program`

A favourite with nothing on now plays with `program == nil` (Pass 26: Favorites *"lists and plays
every favourite channel whether or not the guide has a listing"*). The panel then has no title,
episode or description, and "Record" and "Add to pass" have no airing or title to act on. **Not
settled anywhere.** Today no favourite is in that state (§2.3).

**5.5 — A recording's channel logo.**

> `Models.swift:382` — `let channel: String`
> `library.go:520` **[source 1.8.1]** — `Channel     string   \`json:"channel"\``

The decisions put the channel logo on the recording panel; **the server gives a recording no
channel id and no logo** (§2.2, confirmed against the 1.9.3 response). The measured string match to
`GET /api/channels` is a fact of today's data, not a link the server makes, and the notebook records
no decision about it. Server changes are raised for marlin-dvr, not made here (`CLAUDE.md`).

**5.6 — "Stop recording" beside "● Recording".**

> `AiringSheet.swift:276-280` — `if recordingJob != nil { action(stopArmed ? "Stop recording — click again" : "Stop recording", id: "stop", …`

The airing sheet pairs "● Recording" with a Stop control. The decisions name "Record" reporting
"● Recording" and do not name Stop. Under the scope lock it is not built unless named; **it is
recorded here as the question the scope lock requires.**

**5.7 — The existing result sentences name the existing labels.**

> `AiringSheet.swift:387` and `ShowDetailScreen.swift:372` — *"This show already has a series pass —
> use Edit series pass."*
> `AiringSheet.swift:378` and `ShowDetailScreen.swift:363` — *"Series pass created · …"*

The panel's labels are "Add to season pass" / "Add to pass" / "Edit pass". "Each button does what the
existing control does" carries these sentences with it, and one of them tells the viewer to press a
button whose panel label is different. **Not settled.**

**5.8 — The screens underneath after a panel write.**

> `reports/2026-09-06-pass8-sweep4-writes.md:360-361` — *"Show detail does not reload after the
> Player closes"* (Pass 8 Open Question 6, still open per Pass 104)
> `GuideScreen.swift:429-432` — the Guide refreshes its ● / ◆ marks only through the sheet's
> `onScheduleChanged`
> `GuideScreen.swift:253` — *"Pass 9: a channel whose favourite flag this screen changed, until the
> next fetch."*

A Record, pass or favourite written from the Player would leave show detail's series-pass button,
the Guide's marks and its ★ as they were until those screens next load. **The decisions do not
say**, and the related Pass 8 question is unanswered.

**5.9 — Menu while the panel is up.**

> `PlayerScreen.swift:9` — *"Menu dismisses (and stops the session)"*
> `PlayerHost.swift:218-221` — every Menu that reaches the container calls `onMenu()`

Every overlay elsewhere in the app closes itself on Menu first (`EditSeriesPassScreen.swift:134`,
`ChannelActionsMenu.swift:74`). **What Menu should do with the panel up is not recorded**, and what
it does today with AVKit's own panel up has never been observed.

---

## 6. What a build pass must prove in one Home Theater run with no server write, and what is traced only

### 6.1 One run, no write — what it must show

State measured at 22:17 today; items marked *time-dependent* may not hold when the build runs.

1. **A swipe down on a recording** brings up the panel with the fields the owner named and **no
   channel number anywhere on it** — `episode.channel` and `request.title`/`subtitle` all carry one
   (§1.1).
2. **A swipe down on a live channel** does the same, including the channel logo through
   `/api/art/feed`.
3. **Both recording labels, against the server's real state** — "Add to season pass" on
   *Hitler's DNA* (no pass) and "Edit pass" on a show with one (3 of 4).
4. **"Edit pass" opens the editor and Menu leaves it with nothing sent** — the Pass 103 proof shape.
5. **"Record" in its unbooked state** — the only state reachable without a write today: all 9 jobs
   are `Queued` and none is on now.
6. **"Favorite" and "Unfavorite"** — 4 favourites and 93 others today, so both labels are reachable
   without a write.
7. **"Edit pass" on a live channel only if a programme on now matches a pass** — none did at 22:17
   (*time-dependent*).
8. **What Menu does with the panel up, and that the session is still ended by DELETE** when the
   Player closes.
9. **That frame stepping and commercial skip are unchanged after the panel has been opened and
   closed** — `[framestep]` still +0.033367 s a click at 29.97 fps with the same recognizer counts,
   and a Select landing on a break's `endSeconds` (only `5328bb632e76` and `d9a4f5c76696` can arm
   it) — because the panel crosses both claims (§4.2, §4.5).
10. **No write reached the server** — the app's launch ping is the only non-GET in `GET /api/logs`
    for the run, and the harness uses `launch()`, not `activate()` (COLD-START.md:101).

### 6.2 Code-traced only

- **Every press that writes**: "Record" (`POST /api/record`), "Add to season pass" / "Add to pass"
  (`POST /api/passes`) with their 409 and failure branches, "Favorite" / "Unfavorite"
  (`PUT …/lineup/{guid}`), and any change inside the editor (`PUT`/`DELETE /api/passes/{id}`).
- **Each label's change after its own write** — Add → Edit, Favorite → Unfavorite, Record →
  ● Scheduled / ● Recording.
- **"● Recording" and "● Scheduled" on the panel** — no airing on now is booked, and booking one is a
  write (the same limit Pass 49 had, COLD-START.md:102).
- **A live channel with `program == nil`** (§5.4) — no favourite is in that state today.
- **The tuned programme ending during playback** (§5.3) — needs a real programme boundary, and
  Pass 79's budget rule allows one at most.
- **The screens underneath after a write** (§5.8).
- **The panel across a restart, an Ended, Failed or Expired card, and Play next** — Expired and
  Failure cannot be reached from the remote (COLD-START.md:93).
- **The up/down recognizers disabled while paused on a recording** (§1.2) — unless the run happens
  to open the panel from a paused recording with a down click.
- **Pass 7C's Select during the first live minute with the panel up** (§4.7).
- **Every write route at 1.9.3** — none can be confirmed without calling it.

---

## Open questions

1. **The running server is 1.9.3** (`GET /api/status`, 22:17 today). COLD-START still records
   **1.9.1** (`COLD-START.md:41`) and Pass 103 read 1.9.2. The server line was not edited by this pass
   (not a named edit). Every write route in §3 rests on the **1.8.1** clone.
2. **The Channels DVR screenshot the owner showed is not in this repo or `design/`.** Everything
   above works from his decisions as written; nothing was matched against the picture.
3. **What AVKit's info panel draws today on tvOS 26.6** — from two metadata strings and the default
   "Play From Beginning" action — has never been seen by this project (§1.1).
4. **Whether AVKit opens its info views from a down click as well as a swipe** — it decides whether
   §1.2's up/down side effect ever matters.
5. **`episode.tags` is one array** holding HD/4K, codec, audio layout, CC and rating (§2.2); the
   decisions name HD and rating tags. Recorded as a fact of the data, not raised as a call.

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `reports/2026-09-16-pass107-player-info-panel-recon.md` | 1–6 (written in 7) | new — this report |
| `DECISIONS.md` | 7 | appended the Pass 107 entry |
| `COLD-START.md` | 7 | *Next step*: a new paragraph on top; Pass 106's kept as history |

**Nothing else was written.** No app-target file, test-target file, project file or `design/` file
changed; the reference clone was read only; `icon-source/` stays untracked and untouched. The GETs'
raw responses were kept in the session scratchpad, not in this repo. One source name returned by
`GET /api/channels` carries the HDHomeRun's device id and is not reproduced here.
