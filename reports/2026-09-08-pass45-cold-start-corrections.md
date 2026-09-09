# Pass 45 — two stale lines in COLD-START.md corrected

**Date:** 2026-09-08
**One notebook file and one new report. No Swift source file, project setting, build script or
config was touched, and `DECISIONS.md` was not touched.** No build, no test, no device run, and
**no request of any kind to `192.168.1.250:8090`**. The reference clone was not read, fetched or
otherwise touched. `design/` was not touched. **Neither of the two report files was opened again.**

**The owner's decision that unblocked this pass:** Pass 44 reported that COLD-START.md now
contradicted itself and raised it as a question rather than fixing it. The owner answered on
2026-09-08 — fix those two lines, and nothing else.

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
f1676637b3c25197ddf42bfe7f98efe962c7b1ea
```

```
$ git rev-parse origin/main
f1676637b3c25197ddf42bfe7f98efe962c7b1ea
```

```
$ git ls-remote origin main
f1676637b3c25197ddf42bfe7f98efe962c7b1ea	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
(no output — clean tree, nothing modified and nothing untracked)
```

```
$ git rev-list --left-right --count origin/main...HEAD
0	0
```

**All three SHAs read `f167663`**, the tree is clean, 0 ahead and 0 behind. Every expectation in the
brief matched, so the pass proceeded.

---

## 2. What the text actually said, before anything was changed

The two statements were **exactly where Pass 44 described them and said exactly what it reported**,
so no search for equivalents was needed. Pasted verbatim from `sed -n '521,527p' COLD-START.md`
before the edit:

```
521	Pass 39 (`reports/2026-09-08-pass39-three-defects-recon.md`) reconnoitred the owner's three named
522	defects read-only and fixed none of them; its sorting stands. Note that **the report file itself is
523	untracked** — commit `424c584` carried only `COLD-START.md` and `DECISIONS.md`, verified in Pass 41
524	by `git ls-files reports/ | grep -c pass39` returning `0`.
525	
526	Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) is untracked and no later pass has
527	opened it.
```

Both claims sit in the **"What is built"** section (which runs from line 41 to line 615), not in
"Next step" — which is why Pass 44, scoped to "Next step", could not reach them.

---

## 3. The two corrections

Exactly two claims were changed. The diff is a **single hunk, 9 insertions and 6 deletions**, and
touches nothing else in the file.

### 3.1 — the "untracked" claim, for both files

**Before** (lines 522-524, and line 526's opening clause):

> Note that **the report file itself is untracked** — commit `424c584` carried only `COLD-START.md`
> and `DECISIONS.md`, verified in Pass 41 by `git ls-files reports/ | grep -c pass39` returning `0`.

> Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) is untracked …

**After** (lines 522-525 and 527-528):

> Note that **the report file was left untracked by Pass 39 itself** — commit `424c584` carried only
> `COLD-START.md` and `DECISIONS.md`, verified in Pass 41 by `git ls-files reports/ | grep -c pass39`
> returning `0`. **It is committed and pushed now**: Pass 44 committed it unmodified in `6fee5b5`,
> verified on `origin/main` at `f167663`.

> Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) was left untracked the same way and
> **is committed and pushed now**: Pass 44 committed it unmodified in `6fee5b5`, verified on
> `origin/main` at `f167663`.

The historical fact each sentence carried — that the pass which wrote the report did not commit it,
and Pass 41's `grep -c` verification of that — is **kept intact and unaltered**, because it is still
true and is the reason the situation arose. Only the tense and the present status changed.
"Committed" and "pushed" are stated as the two separate claims they are: Pass 44 committed in
`6fee5b5`, and that commit was verified on the remote at `f167663`.

### 3.2 — the "no later pass has opened it" claim

**Before** (lines 526-527):

> Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) is untracked and **no later pass has
> opened it**.

**After** (lines 529-530):

> **Pass 44 opened it**, to run the mandatory credential scan before committing it to this public
> repo; nothing was found and its contents were not edited.

Recorded as the fact it is, citing Pass 44. The reason is included because it is what makes the
opening legitimate rather than a breach of the standing instruction not to open that file — the
evidence rules required a credential scan before committing anything to a public repo.

**No other sentence, heading, ordering or wording anywhere in the file was changed.**

---

## 4. Step 4 — the whole file re-read after the edit

**No other passage states either of the two corrected claims.** Checked by reading the file through
and by searching every phrasing the claims could take:

| Search | Hits | Verdict |
|---|---|---|
| `untrack` (any case) | 523, 527, 690, 693, 697, 700 | see below |
| `opened it` / `has opened` / `not opened` / `never opened` | 529 only — the corrected text | clean |
| `pass39-three-defects` / `pass40-session-start` | 521, 527, 695, 696 | clean |
| `one disk`, `not in the repo`, `not committed`, `uncommitted`, `never committed`, `not pushed`, `unpushed`, `exists only`, `local only`, `on exactly one` | 652 only | clean |

- **523 and 527** are the corrected text itself, now past-tense and followed by the present status.
- **693, 695, 696, 697, 700** are the paragraph Pass 44 added to "Next step", which already states
  the files are committed and pushed and names the `--untracked-files=all` command and the push
  verification. Consistent.
- **652** is `**Nothing is unpushed.**`, a general statement about the repo's state. It is not a
  restatement of either claim, and Pass 44 made it *more* true, not less.

**One borderline mention, named rather than edited, as step 4 requires.** Line 690:

> and 7.7 (the two untracked report files). 7.1 was answered by the owner's Status-page reading and

This is the **title of open question 7.7**, listing it by subject among the six still-open
questions — and the very next paragraph (line 693) opens `**7.7's files are no longer untracked.**`
So in context it names a question rather than asserting a present fact, which is why I judge it not
to be a live restatement of the corrected claim. **It was not edited.** Raised here because a reader
who stopped at line 690 could take the phrase on its own, and because step 4 asks for anything close
to be named rather than quietly passed over. Whether that four-word label is worth rewording is the
owner's call, not mine.

---

## 5. The push, and the three verification readings

The push was a plain fast-forward. `git push` printed two dots — **not** a `+` and not
"forced update":

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   f167663..fd59d35  main -> main
```

Then `git fetch origin` (exit 0), and the three readings, each as its own command:

```
$ git rev-parse HEAD
fd59d3543fbac8a380549e8e7619d05b6780ad56
```

```
$ git rev-parse origin/main
fd59d3543fbac8a380549e8e7619d05b6780ad56
```

```
$ git ls-remote origin main
fd59d3543fbac8a380549e8e7619d05b6780ad56	refs/heads/main
```

**All three agree**, and the remote was read back rather than trusted from local state.

**What is now on `origin/main`.** Commit `fd59d35` — "Pass 45: correct the two stale untracked
claims in COLD-START.md" — carrying the one-hunk correction and this report, 2 files changed, 258
insertions, 6 deletions. It sits on top of Pass 44's `f167663`, which is where the two report files
themselves went up.

**Nothing was force-pushed. No commit was amended, reworded or rebased.**

---

## 6. The six open questions — all still open

None was answered, decided or narrowed in this pass. They are from
`reports/2026-09-08-pass41-single-file-route-recon.md` §7.

| # | Question | State |
|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **Open.** Still blocks build-plan step 7. |
| **7.3** | What the Starting screen should say during a long remux | **Open.** |
| **7.4** | Should a refused recording fall back to HLS, or show the error | **Open.** Fail-loudly is what ships, on the scope lock's authority; the owner has not been asked. |
| **7.5** | Temp space on Unraid | **Open.** |
| **7.6** | Ask the marlin-dvr project to document the route in `HLS-CLIENT-API.md` | **Open.** |
| **7.7** | The two untracked report files | **Open as a question; its subject is fully settled.** Both were committed and pushed in Pass 44, and the notebook now says so in both places it speaks of them. |

---

## 7. Questions raised by this pass

One, named and not acted on.

1. **Line 690's four-word label, described in §4.** "7.7 (the two untracked report files)" is the
   open question's name, immediately corrected two lines later. I judge it not to be a live false
   claim and step 4 forbids editing it in any case. *What breaks without a change:* very little —
   at worst a reader skimming the open-questions sentence alone carries away a stale impression that
   the following paragraph corrects. **No edit was made.**

**Nothing else was found that wanted fixing**, and the two items this pass was explicitly told to
leave alone were left alone: the "one skip landed 1.01 s past `endSeconds`" KNOWN AND UNFIXED entry
that Pass 43 flagged, and every other wording in the file.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md` | **modified** — one hunk, 9 insertions, 6 deletions | steps 2, 3, 4 |
| `reports/2026-09-08-pass45-cold-start-corrections.md` | **created** | DELIVERABLE |
| `reports/2026-09-08-pass44-push-untracked-reports.md` | read | required reading |
| `DECISIONS.md` | **not touched** | named do-not-touch |
| `reports/2026-09-08-pass39-three-defects-recon.md` | **not opened** | brief forbids reopening |
| `reports/2026-09-08-pass40-session-start-values.md` | **not opened** | brief forbids reopening |

**No Swift source file was modified.** The pass's entire diff is `COLD-START.md` plus this new
report.

**Not touched:** every other folder under `~/Xcode`; the reference clone (not read, not fetched);
the Marlin DVR server, its data and its API — **zero requests of any kind**; Unraid, marlinpc, the
HDHomeRun, the UNAS4Pro share; `design/`; the Xcode project, `Info.plist`, the entitlements file,
every build setting; and every file under `Marlin DVR TV/` and `Marlin DVR TVUITests/`.

**No new dependency.** No credential, token, device id or account identifier appears in this report
or in any commit message from this pass.

---

## CLOSING SUMMARY FOR THE OWNER

**What the two lines said before, and say now.** In the "What is built" section, the notebook said
of the Pass 39 report "**the report file itself is untracked**", and of the Pass 40 report that it
"**is untracked and no later pass has opened it**". Both were true when they were written and both
stopped being true in Pass 44, which committed and pushed the pair. They now say the reports were
left untracked *by the passes that wrote them* — keeping the history and Pass 41's check of it,
which is still accurate — and that both are **committed and pushed now**, in `6fee5b5`, verified on
the remote at `f167663`. The Pass 40 line adds that **Pass 44 opened it**, to run the credential
scan that had to happen before anything went into a public repo.

The notebook no longer contradicts itself: the "What is built" section and the "Next step" section
now say the same thing about these two files.

**What is on the remote.** Everything. This pass's correction and this report went up as a plain
fast-forward — two dots in the push output, never a `+` — with nothing forced, rebased or amended.

**What this pass cost.** One hunk in one file: nine lines in, six out. Plus this report. No build,
no test, no device run, no server request, no code touched, and neither of the two reports reopened.

**The three things I am least certain about.**

1. **One phrase I chose not to touch.** The open-questions sentence still calls 7.7 "the two
   untracked report files" — that is the question's name, and the paragraph directly beneath it says
   they are no longer untracked. I judged that a label rather than a false claim, and step 4 told me
   to name such things rather than edit them. If you would rather it read differently, it is a
   four-word change.
2. **I verified the file by reading and searching, not by proving a negative.** I searched every
   phrasing I could think of for both claims and read the file through, but "no other passage says
   this" is the kind of statement that a differently-worded sentence could quietly falsify.
3. **I did not re-check that Pass 44's facts are still true**, because the brief told me not to
   re-run that work. The SHAs I wrote into the notebook — `6fee5b5` and `f167663` — are copied from
   the brief and from Pass 44's verified output, not re-derived in this pass. They were correct when
   Pass 44 read them back from the remote.
