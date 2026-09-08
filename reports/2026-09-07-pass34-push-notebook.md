# Pass 34 — the backlog pushed, and the notebook caught up

**2026-09-07.** The owner tested Passes 31, 32, 32A and 33 on Home Theater and accepted all of them:
delete refresh, Stop recording from the Guide, the trash list off the new server endpoint, and
Restore. This pass pushed the backlog and wrote what those three passes settled into the notebook.

**No code was changed.** The only files touched are `COLD-START.md`, `DECISIONS.md` and this report.

---

## 1. The push

### Before

The working tree was clean and the branch was **5 commits ahead, 0 behind** — a fast-forward, with
nothing to reconcile:

```
$ git fetch origin
$ git rev-parse HEAD          93de29698dbb702f01f2a513d53be6bb9862d522
$ git rev-parse origin/main   108fdc29b2d9e3bd344e4c0cb7304aa09f340300
$ git rev-list --left-right --count origin/main...main
0       5
```

The five, oldest first:

| SHA | |
|---|---|
| `b774d8e` | Pass 31: a deleted recording leaves the Recordings shelves at once |
| `71d33b8` | Pass 31: the report, its device screenshots, and the notebook |
| `030e67a` | Pass 32A: stop a recording in progress from the Guide |
| `5b4b610` | Pass 32: the report, its device screenshots, and the notebook |
| `93de296` | Pass 33: the Trash screen reads GET /api/library/trash, and Restore works |

### The push

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   108fdc2..93de296  main -> main
```

**A fast-forward.** `108fdc2..93de296` with two dots and no `+` is git's own notation for one; a
forced update prints `+` and `(forced update)`. **Nothing was forced, and no flag beyond the branch
name was passed.**

### Verification — all three agree

Fetched again first, so `origin/main` is what the remote actually holds rather than what the push
left cached:

| Source | SHA |
|---|---|
| `git rev-parse HEAD` (local) | `93de29698dbb702f01f2a513d53be6bb9862d522` |
| `git rev-parse origin/main` | `93de29698dbb702f01f2a513d53be6bb9862d522` |
| `git ls-remote origin refs/heads/main` | `93de29698dbb702f01f2a513d53be6bb9862d522` |

```
$ git rev-list --count origin/main..main            0
$ git rev-list --left-right --count origin/main...main   0    0
```

**Identical, and the branch is level in both directions.** `git ls-remote` is the one that matters —
it asks GitHub over the network rather than reading a local ref.

---

## 2–6. What was written into the notebook

Passes 31–33 each wrote their own entry as they went, so this pass was mostly **status, consolidation
and the things only acceptance could settle**. Every edit, and why:

### `COLD-START.md`

**The three passes are marked accepted and pushed.** Each heading now carries *"accepted by the owner
on Home Theater and pushed in Pass 34"*, matching how Passes 5–10 are recorded. Pass 32's heading also
says **item B is closed by Pass 33**, and its item-B block is prefixed **"Superseded — this is history
now"**, kept only as a record of what the API looked like before 1.6.0. Without that, a later pass
reading "the server exposes no trash listing" would believe it.

**The server version, at the top of "What is built"** — new, and the first thing a cold start should
know:

- **marlin-dvr 1.6.0** (`GET /api/system` → `version 1.6.0`, `build 2026.09.05`).
- **`GET /api/library/trash` exists**, and Manage DVR → Trash is built on it.
- **Automatic pruning is gone server-side: a series pass never trashes anything on its own** (owner).
  Nothing reaches the trash unless a person put it there — from this app, the web UI, or the other
  Apple TV. The keep rule in the Edit series pass screen no longer causes deletions by itself.
- And the standing warning that **the reference clone is stale at 1.2.1** and has none of this, so
  server facts get measured against the running server.

**Pass 31's substance** was already recorded by that pass and is unchanged, including the part the
brief asks for: **Pass 8 Open Question 11 is overturned** — a show whose last episode is trashed does
*not* linger showing "0 episodes"; `shows` went 1 → 0 and all three sections emptied at `limit=6` and
`limit=500` alike. **The card disappears outright.** Same for Pass 32's Stop recording (two-click
confirm, shown only on `Job.status == "Recording"`, proven on device for a one-off Record Now) and
Pass 33's trash rebuild (the endpoint instead of the per-show walk, Restore proven on device for the
first time since Pass 10, sizes on the trash header and the hub row).

**`KNOWN AND UNFIXED after Pass 33` was rewritten** to hold everything that survived acceptance, with
a line at the top saying none of it is a regression:

1. **The series-pass sheet chip.** A pass-driven recording shows **"Record this airing" beside "Stop
   recording"**; pressing it would earn a 409. The gating is split — Stop turns on
   `Job.status == "Recording"` and correctly ignores `passId`, while the chip and the Record button
   are still on `passId == "manual"` (`AiringSheet.swift`, `manualJob` `:71-74`). **Never driven on
   the device. Unfixed.**
2. **Stopping a pass's airing was never exercised on the device** — only the one-off case. Same code
   path, deliberately not gated on `passId`, but that is reasoning rather than evidence.
3. **Old-form (pre-1.6.0) trash entries are untested and now untestable.** The owner's four were
   deleted before they could be used, and 1.6.0 always moves the file, so no old-form entry can be
   made again. Whether the server restores a file that never moved is server behaviour.
4. **The id rule is an inference.** "The id follows the file path, so it changes on trash and back on
   restore" rests on **two files, three cycles each**, plus the server's log line `id X -> Y`.
5. **Resume survival was reasoned, never watched** — from the id round trip plus `ResumeStore.clear`
   having one call site (`PlayerModel.swift:449`). Nobody has watched a "22 min in" label survive one.
6. **`trashedAt` does not update on a second trash of the same file.**
7. **End-of-range erratic frame stepping remains open**, unchanged since Pass 29.

**The "built but never exercised live" list** gains **Stop recording on a pass's airing**, and
records that **Restore has left that list** — Pass 33 drove it twice on Home Theater.

**The four deleted recordings** keep their own section, `THE OWNER'S FOUR TRASHED RECORDINGS ARE
GONE — do not go looking for them`: **20:51:50 on 2026-09-07, `POST /api/library/trash/empty` from
the owner's own web-UI session, 3.80 GB freed, 0 failed**, per the server's log; `6007a13f0b46`
(Hazardous History S2 E20), tracked since Pass 31, no longer exists. One word changed — "this pass"
became "Pass 33", which is ambiguous once it is history.

**A new section, `Raised for the marlin-dvr project`**, for server behaviour this project measured
and does not own — recorded, not acted on, per the standing rule:

- **`trashedAt` does not update when the same file is trashed twice**, so a row can read "Trashed
  today at 9:09 PM" during a 9:16 PM session. The app shows the server's value unaltered.
- **Empty Trash has no confirmation step server-side.** `POST /api/library/trash/empty` deletes every
  trashed file the moment it arrives — no are-you-sure, no dry run. Each client has to invent its own
  guard; this app arms on the first click and sends on the second. On 2026-09-07 that call took
  3.80 GB of the owner's recordings in one request.

**"Next step" rewritten**: nothing is unpushed, `origin/main` is `93de296`, and the recommended next
thing is **the series-pass chip** — it is a wrong control the owner can press today.

### `DECISIONS.md`

A new `2026-09-07 (pass 34)` block, and one line added to the Pass 32 block noting the acceptance.
The two decisions the brief asks for are written so they cannot be quietly reopened:

- **The Trash list comes from `GET /api/library/trash` and from nothing else**, with both rejected
  alternatives named on the record: **a per-show walk** (cannot see a recording whose show has left
  the library — most of the trash — and under 1.6.0 finds nothing at all) and **caching show ids the
  app has seen** (a client-side guess at server state that misses anything deleted from the web UI or
  the other Apple TV).
- **Empty Trash stays unexercised from the app** — wired since Pass 10, never sent from an Apple TV,
  because it deletes files permanently for every client and the server offers no confirmation of its
  own. Two-click arming stays; it is out of scope until the owner asks for it by name.

Also recorded there: the acceptance and the pushed SHA, **automatic pruning gone in 1.6.0**, and a
pointer to the two marlin-dvr notes.

---

## 7. The notebook commit, and its push

A commit cannot record its own SHA, so this follows the shape Pass 30 used: the notebook work and
this report go up in one commit, and a second small commit writes the verification of that push back
into this section. **The values below are filled in after the push, never before it** — the table is
empty until `git ls-remote` has answered.

<!-- PASS34-VERIFY -->

## SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `COLD-START.md` | **modified** — acceptance and push status on Passes 31/32/33; Pass 32 item B marked superseded; server 1.6.0 and no automatic pruning; `KNOWN AND UNFIXED after Pass 33` rewritten with all seven entries; the never-exercised-live list; the four-deleted section reworded by one word; new `Raised for the marlin-dvr project` section; `Next step` rewritten | 2, 3, 4, 6 |
| `DECISIONS.md` | **modified** — new `2026-09-07 (pass 34)` block; one line on the Pass 32 block | 5, 6 |
| `reports/2026-09-07-pass34-push-notebook.md` | **new** — this report | deliverable |

**Not done, as scoped.** **No code was changed** — no file under `Marlin DVR TV/` or
`Marlin DVR TVUITests/` is touched by diff, and no build or test was run, because there was nothing
to build. **No work on any known defect**: the series-pass chip, the pass-airing stop, the old-form
trash, the id-rule inference and the end-of-range stepping were **written down and left alone**. **No
server-side change** was made or attempted, and the two marlin-dvr items are recorded rather than
acted on. Nothing was force-pushed; both pushes were fast-forwards. Nothing outside this folder was
written; `design/`, the reference clone, Unraid, marlinpc, the HDHomeRun and the UNAS4Pro share were
not touched, and no HTTP call of any kind was made to the DVR this pass. `GET /api/settings` was not
read, per the owner's standing instruction from Pass 31.
