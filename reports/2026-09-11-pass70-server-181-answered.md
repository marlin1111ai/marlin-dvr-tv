# Pass 70 — the server's 1.8.1 report answered, and Pass 69's report landed

**Date:** 2026-09-11
**Documentation and git only. No Swift source file, project setting, build script, config or
dependency was touched.** No build, no test, no device run, no install. **Not one request of any
kind was sent to `192.168.1.250:8090`** — no GET, no POST, no `/api/system`, no `/api/settings`.
`~/Xcode/marlin-dvr-reference` was **not read, not fetched and not touched** this pass; neither was
`design/`, any other folder under `~/Xcode`, Unraid `192.168.1.250`, marlinpc `192.168.1.245`, the
HDHomeRun `192.168.1.105` or the UNAS4Pro share.

**Per Pass 60 rule (b) and Pass 68's ordering rule, the verified push SHA is not in this report** —
a commit cannot contain its own SHA. It is in this pass's response and belongs in the next pass's
notebook entry. The pre-pass state is recorded in §1.

---

## 0. Required reading — what was read

| Named in the brief | Present | Read |
|---|---|---|
| `COLD-START.md` | 1,088 lines at the start of the pass | in full |
| `DECISIONS.md` | 944 lines at the start of the pass | in full |
| `CLAUDE.md` | 14 lines | in full |
| Pass 69's report | **uncommitted, in the session scratchpad** | in full |

**Where Pass 69 left its report, as the brief asks to be reported:**

```
/private/tmp/claude-501/-Users-marlin1111-Xcode-Marlin-DVR-TV/
  9bad9fe7-6ff1-4220-9311-8968300950dc/scratchpad/
  2026-09-11-pass69-server-1-8-1-report-checked.md
```

That is this session's own scratchpad directory, outside the repo. Pass 69 put it there rather than
in `reports/` because its own end-state required a clean tree and forbade a commit, and its §0 says
so and leaves the question to the owner. **This pass is that answer.**

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
94451795f6c745f188c1dc56706dffd484658b71
```

```
$ git rev-parse origin/main
94451795f6c745f188c1dc56706dffd484658b71
```

```
$ git ls-remote origin main
94451795f6c745f188c1dc56706dffd484658b71	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all | wc -l
      32
$ git status --porcelain --untracked-files=all | grep -v 'icon-source/'
(no output)
```

**All three refs read `9445179`**, and every one of the 32 untracked entries is under
`icon-source/` — the 32 the notebook has recorded since Passes 51-55. No tracked file was modified.

---

## 2. Step 1 — Pass 69's report moved into `reports/`, unmodified

### 2.1 The credential scan, run before the file was moved

Required because **this repo is public** (`DECISIONS.md`, 2026-09-05). Run on the scratchpad copy,
in this pass, rather than taken on trust from Pass 69's own statement.

| Searched (case-insensitive) | Hits | Verdict |
|---|---|---|
| `password`, `passwd`, `secret`, `api key` / `api_key` / `api-key`, `bearer`, `authorization`, `ssh-rsa`, `BEGIN … PRIVATE KEY`, `aws_`, `x-api`, `cookie`, `session_id` | **0 each** | clean |
| `token` | 1 | **the report's own disclosure sentence**, line 505: "No credential, token, device id or client id appears in this report". Prose, not a value. |
| `credential` | 1 | the same sentence, line 505. Prose, not a value. |
| UUID-shaped strings (`8-4-4-4-12` hex) | **0** | clean — no device id, no scratchpad uuid |
| the literal string `marlinClientId` | 1 | line 79, **naming the `UserDefaults` key** in the body table. The key's *name*, never a value. |
| an actual client id | **0** | the one place the value would appear, line 85, reads `"client":"<REDACTED client id>"`. Pass 69 never read the value from any device. |
| play-session ids `smt…` | 3 (all `smttdw891e10096`) | **outside the redaction categories**, on the ruling Pass 44 §2 already made: ephemeral, minted per playback and deleted within minutes, on routes the contract states carry no authentication, conferring no access, and neither device nor account identifiers. **The same id is already committed** — `git grep -c` finds it **6 times** in `reports/2026-09-08-pass42-single-file-route.md` at `HEAD`. |
| IP addresses | `192.168.1.250:8090`, and `192.168.1.105` / `192.168.1.245` / `192.168.1.250` in the scope-check line | **already committed** — `git grep -l 192.168.1.105 HEAD -- CLAUDE.md` matches, and the server address is in `ServerAPI.swift:15` and throughout the notebook |

**Result: nothing found that required redaction, and nothing was redacted or edited.** The client id
was already redacted by Pass 69 and was never read.

### 2.2 The move, proved byte-identical

| | scratchpad, before | `reports/2026-09-11-pass69-server-181-check.md`, after |
|---|---|---|
| bytes | 32,344 | **32,344** |
| lines | 507 | **507** |
| `sha256` | `8084a7a772127d8754248b41ffe5e485e550ffbff29428b540b8e0ef17d9cc97` | **identical** |
| first line | `# Pass 69 — the server's 1.8.1 report, checked against this app` | **identical** |

**The heading was already there, so nothing was added** — the brief's "except for a heading if it
lacks one" did not apply, and the file is unmodified in every byte. The scratchpad copy no longer
exists (it was moved, not copied).

**One consequence, disclosed rather than quietly fixed.** The landed file's §0 still says the report
"is this response and a copy sits in the session scratchpad outside the repo" and leaves its fate to
the owner. That is **superseded by this pass and was deliberately not edited**: reports are the
historical record and are never rewritten to match a later decision (`DECISIONS.md`, 2026-09-09
(Pass 56), and the same rule applied to the Pass 57 and Pass 33 corrections). The correction lives
in this pass's `DECISIONS.md` entry, which is what governs.

---

## 3. Step 2 — the note to the marlin-dvr project

`reports/2026-09-11-pass70-note-to-marlin-dvr.md`, addressed to them and written to be read by them.

**What it covers, in the brief's order:** the commit `137f1de` (2026-09-08 21:01:06 -0400) and the
three ways it is shown to have shipped — ancestor of `origin/main`, empty `git diff 137f1de HEAD`
over the three player files, ancestor of `0b3589d` which is on both Apple TVs; the exact JSON body,
key by key, with the client id redacted and one captured body and response from the 2026-09-08 run;
that the app resolves the response's `url` and builds no playback URL, with the two comment-only
`grep` hits as evidence; the three defects with **what each was verified by** — the badge and the
fast-forward wait on the owner's own Home Theater observation, the overshoot by measurement
(`start=1484.004768173`, a skip landing at `t=272.538500` while the app reported `position
1478.54 s`); the "Preparing the recording" state and the one-byte first fetch on an 11-minute
timeout; the three 410 paths and their two outcomes; the `§7` count change with the **two** places
the number is displayed; and the desync.

**It states plainly** that their central claim was true of every client — this one included — until
the evening of 2026-09-08, and is out of date now.

**What it deliberately does not do.** No request of any kind is made of them. No opinion is offered
about their code: the `format` switch's missing `default` arm, the contract file being byte-unchanged
and still declaring 1.7.0, and Pass 41 open question 7.6 (asking them to document the route) are
**all absent**, even though Pass 69 §3.4 and §VERDICT discuss them, because the brief confined the
note to what they asked about. Two facts about **this app** were also left out for the same reason
and are recorded here instead, so they are not lost:

1. **A silent degrade is impossible on this client.** `routeRefused`
   (`PlayerModel.swift:176-181`, called at `:135` and `:765`) fails loudly before anything is
   fetched if the response's `format` is not `"file"`, so a server that stopped honouring it would
   produce an error screen here, not the old EVENT playlist and not a LIVE badge.
2. **The keep-alive branches on 410 only.** Pass 41 §2.4 D8 records that the file route answers
   **404** once the session has left the server's map; a 404 is printed at `PlayerModel.swift:609`
   and nothing branches on it, so the loop keeps polling every 10 s. Never observed.

**Two limits are stated inside the note itself**: this project has not read their 1.8.1 report and
is working from the owner's summary of its central claim, and no request was sent to the server, so
everything in it is the app's own code plus the 2026-09-08 device run **against 1.8.0**.

---

## 4. Step 3 — what was written into `DECISIONS.md`

One dated entry appended in the form every other entry uses,
**`## 2026-09-11 (Pass 70 — the server's 1.8.1 report checked and answered)`**, recording: that the
1.8.1 report was checked and its central claim does not hold here, with the git evidence and the
statement that the claim was true of every client until that evening; that the three defects stay
closed on the evidence already recorded and that **nothing was re-tested this pass**; that the
library-count change affects two display strings and needs no app change, naming both; that the note
was written and exactly what it was confined to, including that 7.6 was not re-raised; that the
desync is unchanged and their outstanding request is still the owner's to answer; and that Pass 69's
report landed byte-identical with its own §0 left deliberately stale.

`git diff --numstat` on `DECISIONS.md`: **49 insertions, 0 deletions** — an append only.

## 5. Step 4 — what was added to `COLD-START.md`

Two bullets at the end of **"Raised for the marlin-dvr project — recorded here, not acted on"**
(the section opens at line 865), immediately before `## Open questions`:

- **the 1.8.1 report answered and its central claim corrected** — the claim quoted, that it was true
  of every client until the evening of 2026-09-08, the commit and the three ways it is shown to have
  shipped, that the three defects stay closed on the evidence already recorded above, the note and
  the check cited by filename, that nothing was asked of them and no request was sent, and that 7.6
  was not re-raised and stays open;
- **the library-count change needing nothing from this app**, with the non-optional `Int` at
  `Models.swift:330` and the two display sites.

`git diff --numstat` on `COLD-START.md`: **19 insertions, 0 deletions.** **Additions only** — the
file was rebuilt by inserting after line 894 and `diff` reports **zero** removed lines, so no
existing sentence, heading or ordering was rewritten, reworded, moved or removed.

---

## 6. Open questions

1. **Nobody has read the marlin-dvr project's 1.8.1 report.** Pass 69 flagged this as its biggest
   risk and it is unchanged: this pass answered the central claim as the owner summarised it. If
   their report says something narrower — that *their* web UI sends no `format` (still true on their
   own Pass 87), or that no such session appeared in a particular log window — then the note
   answers a claim they did not make. **The note says so in its own closing paragraph**, but the fix
   is to put their report in front of a later pass.
2. **Pass 41 open question 7.6 is still open and was deliberately not re-raised.** Their contract
   file documents none of this route, which is the likeliest reason a 1.8.1 report could be written
   without knowing the route has a client. The note raises nothing; whether to ask them is the
   owner's call.
3. **If 1.8.1 genuinely logged no `format:"file"` session, something real is happening.** An older
   build on one Apple TV, a log window with no recording playback, or 1.8.1 making this app fail
   loudly instead of playing are all consistent with that, and **the code cannot tell them apart
   from here.** Distinguishing them needs one recording played on Home Theater with the console
   attached. Not done: this pass made no device run and sent the server nothing.
4. **The desync request is still the owner's to answer** — matching the sessions in which he
   observed it to individual session records. Nothing has been done about it here, and the note
   says it is outstanding.
5. **Pass 69's landed §0 is knowingly stale** (§2.2). Whether the repo should ever carry a correction
   note beside a landed report, rather than only in `DECISIONS.md`, is the owner's call; this project
   has always chosen the notebook.

---

## 7. SCOPE CHECK — every file touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `reports/2026-09-11-pass69-server-181-check.md` | **created by move**, byte-identical, unmodified | 1 |
| `reports/2026-09-11-pass70-note-to-marlin-dvr.md` | **created** | 2 |
| `DECISIONS.md` | **modified** — one appended dated entry, 49 insertions, 0 deletions | 3 |
| `COLD-START.md` | **modified** — 19 insertions, 0 deletions, additions only | 4 |
| `reports/2026-09-11-pass70-server-181-answered.md` | **created** — this file | 5 |
| `CLAUDE.md` | read | required reading |
| the session scratchpad | the moved-from location, and two working files for the additions-only edit | 1, 4 |

**Not touched:** every Swift source, the Xcode project, `Info.plist`, the entitlements file, every
build setting, `build/`, `icon-source/`, `design/`, `Marlin DVR TVUITests/`, every other report, the
reference clone (not read, not fetched), and the Marlin DVR server, its data and its API — **zero
requests of any kind.**

**No new dependency. No credential, token, device id or client id appears in this report, in either
notebook file, in the note, or in this pass's commit message.**
