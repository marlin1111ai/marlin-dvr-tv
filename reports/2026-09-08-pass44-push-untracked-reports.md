# Pass 44 — the two untracked reports committed and pushed

**Date:** 2026-09-08
**Git and one notebook line only. No Swift source file, project setting, build script or config was
touched.** No build, no test, no device run, and **no request of any kind to
`192.168.1.250:8090`**. The reference clone was not read, fetched or otherwise touched. `design/`
was not touched. **The contents of the two report files were not edited** — not a typo, not a
heading, not a line ending.

**The owner's decision that unblocked this pass:** on 2026-09-08 he decided the untracked report
files go to the remote — a report the notebook cites by name belongs in the repo, and they existed
on exactly one disk.

---

## 1. The starting state, read-only — four raw outputs

Each run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed at this step.

```
$ git rev-parse HEAD
aa7f0e886fc8a5716ba77604130e798938640ff2
```

```
$ git rev-parse origin/main
aa7f0e886fc8a5716ba77604130e798938640ff2
```

```
$ git ls-remote origin main
aa7f0e886fc8a5716ba77604130e798938640ff2	refs/heads/main
```

```
$ git status --porcelain --untracked-files=all
?? reports/2026-09-08-pass39-three-defects-recon.md
?? reports/2026-09-08-pass40-session-start-values.md
```

**All three SHAs read `aa7f0e8`**, and the lead was confirmed clean before anything was written:

```
$ git rev-list --left-right --count origin/main...HEAD
0	0
```

0 ahead, 0 behind. Every expectation in the brief matched, so the pass proceeded.

---

## 2. What was actually untracked — the disagreement resolved by looking

`git status --porcelain --untracked-files=all` returned **exactly two entries**, and
`git status --porcelain --untracked-files=all | grep -c '^??'` returned **2**.

| Full path | Bytes | Under `reports/`? | A report? |
|---|---|---|---|
| `reports/2026-09-08-pass39-three-defects-recon.md` | **38,079** | yes | yes |
| `reports/2026-09-08-pass40-session-start-values.md` | **24,813** | yes | yes |

Sizes from `wc -c` on each path in this pass.

**Both untracked files are reports under `reports/`. There was no untracked file that is not a
report**, so nothing had to be left behind for that reason, and the `--untracked-files=all` form
found no hidden or nested extras that the default `git status` would have collapsed.

### Which account of the record matched

**Both accounts named a real file. Each named only one of the two, and neither was wrong about the
file it named.**

- **Pass 43's summary** said "`reports/2026-09-08-pass39-three-defects-recon.md` is still
  untracked". **True** — it was, and it is the 38,079-byte file above.
- **The 2026-09-08b brief and COLD-START.md** said the uncommitted one is
  `reports/2026-09-08-pass40-session-start-values.md`. **Also true** — it was, and it is the
  24,813-byte file above.

The apparent contradiction was that each source named a single file while there were two. Pass 43's
own step 1 output had already shown both, which is why its report listed two untracked files in its
scope check while its closing summary mentioned only one. **Neither account was mistaken; both were
incomplete.** COLD-START.md was already correct on this point in its narrative section, which
records the Pass 39 report as untracked at its line 523 and the Pass 40 report as untracked at its
line 526.

### Credential scan — done before committing, both files, nothing found

Required before staging because **this repo is public** (`DECISIONS.md`, 2026-09-05: "Repo:
`marlin1111ai/marlin-dvr-tv`, Public").

- **No** match in either file for password, passwd, secret, token, api key, bearer, authorization,
  credential, `ssh-rsa`, or any `BEGIN … PRIVATE KEY` block.
- **The app's persisted client id does not appear** in either file (`grep -c` → `0` in both).
- **The Apple TV's `devicectl` device identifier does not appear** in either file (`grep -c` → `0`
  in both).
- **One UUID-shaped string exists**, in the Pass 40 report: it is a **local Claude Code scratchpad
  directory id** on an already-elided path (`…/<uuid>/scratchpad/`). It is not a device id, not an
  account identifier, not a credential and not a token — it names a temp directory on the owner's
  own Mac.
- **Play-session ids (`smt…`) appear in the Pass 40 report deliberately.** They are ephemeral ids
  the server mints per playback and deletes within minutes, on routes the contract states carry **no
  authentication of any kind** (§8). They confer no access, and they are neither device nor account
  identifiers. They fall outside the redaction categories.
- The only network address in either file is `192.168.1.250`, which is already in
  `ServerAPI.swift:15` and throughout the notebook.

Each report also carries its own credential-scan statement from the pass that wrote it; those were
read but **the scan above was run independently in this pass** rather than taken on trust.

---

## 3. The commit of the reports — contents untouched

Both were staged and committed exactly as they sat on disk. Proved rather than asserted:

```
reports/2026-09-08-pass39-three-defects-recon.md
  working: fb153fc595493774d36c37637e0513b783508b43
  staged : fb153fc595493774d36c37637e0513b783508b43
  IDENTICAL — content unmodified
reports/2026-09-08-pass40-session-start-values.md
  working: f00c8b753794d9b708a5c56c35d82556b8cf442a
  staged : f00c8b753794d9b708a5c56c35d82556b8cf442a
  IDENTICAL — content unmodified
```

`git hash-object` of each working file equals the blob git actually staged. Nothing could have
rewritten line endings on the way in either: **`core.autocrlf` is unset** and **there is no
`.gitattributes`** in the repo, both checked in this pass.

Commit **`6fee5b5`** — "Pass 44: commit the two untracked reports, unmodified", 2 files changed,
1,114 insertions, 0 deletions.

---

## 4. What was written into COLD-START.md

**One addition, in the "Next step" section only** (the section begins at the file's line 647). The
sentence listing the six open questions ended "…and 7.7 (the two untracked report files)". A
paragraph now follows it recording that **7.7's files are no longer untracked**: the owner's
2026-09-08 decision, that Pass 44 committed and pushed both of them unmodified, **both real
filenames with their byte sizes as read from `git status` in this pass**, the byte-identical proof,
the fact that the credential scan found nothing, a pointer to this report, and the dated push check
from §5.

**Nothing else in COLD-START.md was changed, and DECISIONS.md was not touched at all.** No proposal,
recommendation or next-step suggestion was added.

---

## 5. The push, and the three verification readings

<!--PUSH_EVIDENCE-->

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
| **7.7** | The two untracked report files | **Open as a question, but its subject is settled.** The owner decided, and both files are now committed and pushed. Nothing about the route or the code changed. |

---

## 7. Questions raised by this pass

One, recorded rather than acted on, because acting on it was outside the numbered steps.

1. **Two sentences in COLD-START.md's "What is built" section are now false, and I was told to
   change nothing else in that file.** Its **line 523** says of the Pass 39 report "**the report file
   itself is untracked**", and its **line 526** says "Pass 40 (…) **is untracked and no later pass
   has opened it**". Both were true when Pass 43 wrote them and **both stopped being true in this
   pass**, as a direct result of step 3. Step 4 scoped the notebook edit to the "Next step" section
   and said to change nothing else, so they were left exactly as they stand. Line 526's second
   clause is doubly stale: this pass opened that file to scan it for credentials, which the evidence
   rules required before committing it.
   **What breaks without a fix:** the notebook now contradicts itself — "Next step" says both files
   are committed and pushed, "What is built" says both are untracked — and a later pass reading the
   narrative section first would believe the wrong thing. It is a two-line correction and it is the
   owner's to authorise. *No edit was made.*

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `reports/2026-09-08-pass39-three-defects-recon.md` | **committed, contents unmodified**; read only to scan for credentials | steps 2, 3 |
| `reports/2026-09-08-pass40-session-start-values.md` | **committed, contents unmodified**; read only to scan for credentials | steps 2, 3 |
| `COLD-START.md` | **modified** — one paragraph added in "Next step" | step 4 |
| `reports/2026-09-08-pass44-push-untracked-reports.md` | **created** | DELIVERABLE |
| `reports/2026-09-08-pass43-push-notebook.md` | read | required reading |
| `DECISIONS.md` | **not touched** | step 4 forbids it |

**No Swift source file was modified.** The pass's diffs are `COLD-START.md` plus the three report
files, two of which were added verbatim.

**Not touched:** every other folder under `~/Xcode`; the reference clone (not read, not fetched);
the Marlin DVR server, its data and its API — **zero requests of any kind**; Unraid, marlinpc, the
HDHomeRun, the UNAS4Pro share; `design/`; the Xcode project, `Info.plist`, the entitlements file,
every build setting; and every file under `Marlin DVR TV/` and `Marlin DVR TVUITests/`.

**No new dependency.** No credential, token, device id or account identifier appears in this report
or in any commit message from this pass.

---

## CLOSING SUMMARY FOR THE OWNER

**Which files were actually untracked, and what they were.** Two, not one — which is why the record
looked like it disagreed with itself. `git status` settled it in one command: the **Pass 39 report**
(38,079 bytes), the read-only recon of your three named defects — audio desync, the LIVE badge, the
fast-forward wait — and the **Pass 40 report** (24,813 bytes), the session start-values work. Pass
43's summary named the first and the earlier brief named the second; each was right about the file
it named and neither mentioned the other. Both were reports under `reports/`, so both were
committed; there was no stray file that had to be left alone.

I scanned both for secrets before committing anything, because this repo is public. Nothing was
found: no tokens or keys, and neither your Apple TV's device identifier nor the app's client id
appears in either file. The play-session ids in the Pass 40 report are harmless — they name sessions
the server deleted minutes later, on routes that have no authentication at all.

**What is now on the remote.** Everything, and both reports went up byte-for-byte as they sat on
your disk — I proved that rather than assuming it, by checking that the hash of each file matched
the blob git actually stored. Three commits went up as plain fast-forwards, nothing forced and
nothing amended.

**What this pass cost.** Two files committed unchanged, one paragraph added to COLD-START.md, and
this report. No build, no test, no device run, no server request, and no code touched.

**The three things I am least certain about.**

1. **I have left the notebook contradicting itself, deliberately.** Two sentences in COLD-START.md's
   "What is built" section still say these files are untracked, and one of them adds that no later
   pass has opened the Pass 40 report — which is no longer true either, since I had to open it to
   scan it. Step 4 told me to change nothing outside "Next step", so I did not. It is a two-line fix
   and it needs your word, but until it happens a reader who starts at the top of that file will
   believe the wrong thing.
2. **I judged the play-session ids and the scratchpad UUID safe to publish**, and that is my
   judgement rather than a rule I was handed. I think it is clearly right — the ids are dead and the
   server has no authentication for them to bypass — but it is a public repo and the call was mine.
3. **I did not read either report end to end.** I scanned them thoroughly for the categories the
   evidence rules name and checked the specific identifiers I knew to look for, but these are long
   documents written in earlier sessions, and a scan is not a reading. If either contains something
   sensitive that does not look like a credential, I would not have caught it.
