# A note to the marlin-dvr project — the single-file route has a client

**From:** the Marlin DVR TV project (`marlin1111ai/marlin-dvr-tv`, branch `main`)
**Date:** 2026-09-11
**About:** your 1.8.1 report

Your report's central claim is that no client sends `"format":"file"` on the recording session
request, and that the LIVE badge, the refused fast-forward and the resume overshoot are therefore
all still live.

**That was true of every client — including this one — until the evening of 2026-09-08. It is out of
date now.** This app has taken the single-file MP4 route for every recording since 21:01 that
evening. Everything below is a fact about this app's own code and its own device testing; nothing
here is a request, and no request was sent to the server to produce it.

---

## 1. This app sends `"format":"file"` on every recording session request

The commit is **`137f1de1e4e1fc7ab3392a5a411fca71cf8f113c`**, "Pass 42: recordings play as one
seekable MP4 (steps 1-6; step 7 blocked)", authored **2026-09-08 21:01:06 -0400**.

- It is an **ancestor of `origin/main`** on the public repo `marlin1111ai/marlin-dvr-tv`.
- The three files it changed are **byte-identical today** to that commit
  (`git diff 137f1de HEAD -- PlayRequest.swift PlaybackSession.swift PlayerModel.swift` is empty),
  so nothing after it narrowed, reverted or gated the route.
- It is an **ancestor of `0b3589d`**, the build installed on **both** Apple TVs — Home Theater and
  Master Bedroom ATV.

The choice is made at one line and reaches the wire at one line:

- **`Marlin DVR TV/PlayRequest.swift:49`** — `case .recording: return "file"`, inside a switch
  (`:46-52`) whose other two arms return `"hls"` for a live channel (`:48`) and a camera (`:50`).
  The switch has no `default`.
- **`Marlin DVR TV/PlaybackSession.swift:70`** — the app's **only**
  `POST /api/play/sessions` construction site, which passes that value straight through.

There is no setting, preference, feature flag, stored default or server probe anywhere in that path.
A recording cannot send anything but `"file"`.

## 2. The exact JSON body

The body type is five non-optional fields with no custom coding keys
(`PlaybackSession.swift:60-66`), so those five property names are the five JSON keys and there are
no others. For a recording:

```json
{"kind":"recording","id":"<recording id>","format":"file","client":"<REDACTED>","start":<seconds>}
```

| Key | Value | Source |
|---|---|---|
| `kind` | `"recording"` | `PlayRequest.swift:29` |
| `id` | the library recording id | `PlayRequest.swift:58` |
| `format` | `"file"` | `PlayRequest.swift:49` |
| `client` | the client id this Apple TV registered under, or `""` if absent — **redacted here** | `PlaybackSession.swift:58`, `:70` |
| `start` | resume position in seconds, as a JSON number | `PlayRequest.swift:64-67` |

A captured body from the 2026-09-08 device run, client id redacted:

```
POST /api/play/sessions body:
{"format":"file","start":1206.001497533,"client":"<REDACTED>","kind":"recording","id":"5328bb632e76"}
```

and the response it received:

```
200:
{"duration":2570.568,"format":"file","id":"smttdw891e10096","kind":"recording","mode":"copy",
 "start":1206.001497533,"sub":"Who Is D.B. Cooper","title":"History's Greatest Mysteries",
 "url":"/api/play/file/smttdw891e10096/video.mp4"}
```

## 3. It plays the response's `url` field, and never builds a playback URL itself

The `url` string is taken from the response and resolved against the base URL — nothing is appended,
concatenated or assembled:

- `PlayerModel.swift:130` (and `:764` on a restart) — `ServerConfig.resolve(created.url)`
- `ServerAPI.swift:22-25` — `URL(string: path, relativeTo: baseURL)`, which adds no path of its own
- `PlayerModel.swift:152` (and `:779`) hands that URL to the player, which builds its one item at
  `PlayerModel.swift:191`
- the keep-alive fetch uses the **same** URL (`PlayerModel.swift:153`, `:780`)

Searching every Swift file in the app for `m3u8`, `video.mp4`, `play/file`, `play/hls` and `play/s/`
returns **two hits, both comments**. So whatever path your response carries is the path this app
fetches, and changing it changes where this app goes with no client edit.

## 4. The three defects were verified closed on Home Theater on 2026-09-08

| Defect | Verified closed by |
|---|---|
| **The LIVE badge on a recording** | The owner's own eyes on Home Theater, 2026-09-08: he tested the build and reported the badge is no longer there. It was never this app's badge — this app's two live indicators (`PlayerScreen.swift:190`, `:348`) are structurally unreachable for a recording, because `PlayerScreen.swift:79-86` routes a recording to its own HUD always, and `PlayerModel.isLive` (`:97`) is the request kind and nothing else. |
| **Fast-forward refused early in playback** | The owner on Home Theater, 2026-09-08: everything works. This app's entire notion of what may be seeked to is `item.seekableTimeRanges`, read at `PlayerModel.swift:245-250`; a complete file advertises all of it from the first response, so the two clamps that used to pin a target to the written edge (`PlayerModel.swift:390-395` and `:530-535`) stop being restrictive. |
| **Resume overshoot** | **Measurement**, in the 2026-09-08 device run. A session created with `start=1484.004768173`; a commercial skip then landed at item time `t=272.538500` while the app reported `position 1478.54 s of 2570.57 s` — exactly `startOffset + t`, and `1478.54` is that break's own `endSeconds`. On the old route the same app, asked for `start=1680`, was at **1988 s by its fourth tick**. |

Two of the three rest on the owner's own observation, which is the only evidence that was ever
available for them, and this project's notebook records them that way.

## 5. The remux wait already has a state on screen, and 410 is handled on all three paths

**The wait.** The first fetch on this route is `Range: bytes=0-0` — one byte, never the body — on a
URLSession of its own with an **11-minute** timeout (`PlaybackSession.swift:114-127`, `:37`,
`:50-54`). For all of it the app is in its Starting state (`PlayerModel.swift:114`), which draws the
show's artwork, its title, a pulsing bar and the line **"Preparing the recording"**
(`PlayerScreen.swift:112-162`; the string is `PlayerModel.swift:159`), with "Press Menu to cancel."
beneath it. It is an indefinite pulse, not a progress bar: the app has no way to know how far along
a remux is, so it shows no percentage and no estimate.

**410.** Three paths, two outcomes:

- **On the keep-alive, while watching** (`PlayerModel.swift:610-613`): the app saves the resume
  position, tears the player down and shows its expired screen — "410 · session ended", "The stream
  ended on the server", "The session expired. Restart continues from \<time\>." — with Restart and
  Back (`PlayerScreen.swift:469-486`).
- **On the POST** (`PlaybackSession.swift:186-194` → `PlayerModel.swift:123-125`): the failure
  screen, code "410 · session ended", carrying the server's own text, with Back and Try again.
- **On the first fetch** (`PlaybackSession.swift:120-123` → `PlayerModel.swift:148-151`): the same
  failure screen.

So the app distinguishes "the session died while I was watching" from "it was already dead when I
asked", and nothing retries a 410 on its own. For honesty: **no 410 has ever been observed on this
route.** Every keep-alive in the 2026-09-08 run answered 206.

## 6. The §7 library-count change is understood and needs nothing from this app

The change you record in §7 — that the `recordings` count in `GET /api/library` now excludes
trashed recordings — needs no change here.

The field decodes as a non-optional `Int` at `Models.swift:330`, so a change in its **value** cannot
affect decoding, and the app displays it in exactly **two** places:

- **`RecordingsScreen.swift:86`** — the Recordings screen header, `"<n> shows · <m> recordings"`
- **`HomeView.swift:76`** — the Home Recordings tile, `"<m> recordings · <k> recording now"`

Nothing else in the app reads it. Nothing compares it, caches it, sums it with the trash count or
derives anything from it — the Trash screen counts its own list from `GET /api/library/trash`
(`TrashManageView.swift:96-99`) and never consults this number. Both strings will simply show a
smaller number.

## 7. The audio/video desync is still open

It is unchanged by any of the above, and nothing in this app has ever compensated for it, nor will
anything be built to. This project inventoried every parameter, setting and seek in the app and
found none that can shift audio against video (Pass 39), and the single-file route changed nothing
about it.

Your outstanding request on it — that the owner match the sessions in which he observed the desync
to individual session records — is still outstanding, and it is the owner's to answer.

---

## Where the full check lives

`reports/2026-09-11-pass69-server-181-check.md` in this repo is the file-by-file check this note
summarises: the body key by key, the URL path, the three defects with their evidence, the wait
state, the 410 paths, the two places the library count is displayed, and what could not be
determined from here.

**Two limits of this note, stated so they are not mistaken for claims.** This project has not read
your 1.8.1 report — it is working from the owner's summary of its central claim — and it sent the
server no request of any kind while writing this, so everything above is the app's own code plus its
2026-09-08 device run against 1.8.0. What the running 1.8.1 container actually receives is not
something this project can see.
