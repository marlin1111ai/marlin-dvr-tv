# Pass 68 — the report goes in the commit — 2026-09-11

**Result: the ordering that kept leaving untracked reports behind is fixed, and the fix is
applied to this pass itself.** A pass now writes its report and commits it **before** pushing, so
the report is inside the commit it belongs to. The verified push SHA is not in the report — it
cannot be, and per DECISIONS.md 2026-09-09 (Pass 60) rule (b) it belongs in the pass response and
in the next pass's notebook entry.

**This report is in the commit it describes.** That is the whole point of the pass, and it is the
first time it is true.

`origin/main` was **`dabb5da`** when this pass began. The post-push SHA is recorded in the pass
response, not here.

Documentation and git only. No source file, asset, project setting, build, install or network
request; neither Apple TV was touched and neither was the server.

---

## 1. Step 1 — the starting point

`git fetch origin`, then three independent readings, **all identical**:

```
local main        dabb5da66b1790dce1c387b66e8c12ed65f5fbaa
origin/main       dabb5da66b1790dce1c387b66e8c12ed65f5fbaa
ls-remote origin  dabb5da66b1790dce1c387b66e8c12ed65f5fbaa   refs/heads/main
```

Nothing was unpushed. `git status --porcelain --untracked-files=all`, with the known
`icon-source/` baseline filtered out, showed exactly one entry —
`?? reports/2026-09-11-pass67-notebook-current.md` — the report Pass 67 left behind, and the last
one this pattern will produce.

**Everything was staged by name.** `git add -A` was never used, so `icon-source/` could not be
swept in.

---

## 2. Step 2 — the Pass 67 report, scanned

`reports/2026-09-11-pass67-notebook-current.md`, 9,558 bytes, 185 lines,
blob `e4b98ca3164ddc1e3104d553e488217bb807769c`.

**Nothing found.** Four checks:

| Check | Result |
|---|---|
| `password`, `secret`, `api_key`, `bearer`, `authorization`, `token`, `credential`, private-key headers, `ssh-rsa`, the team id, the client id, `udid`, `serial` | **three matches, none of them a credential.** All three are the Pass 67 report *describing its own scan of the Pass 66 report*: the table row listing the keywords it searched for, the row explaining the IP addresses, and its closing sentence "No credential, token or device id appears above." |
| UUID-shaped strings (`8-4-4-4-12` hex) | **none** — no device identifier of any kind |
| IP addresses | `192.168.1.250`, `192.168.1.245`, `192.168.1.105` — the do-not-touch LAN addresses the report names in order to state it did **not** contact them. Already throughout `COLD-START.md` and `CLAUDE.md`; not secrets. |
| every 40-hex string | `b028650…` and `dabb5da…` resolve with `git cat-file -t` to **commits** in this repo; `aec0df3…` resolves to a **blob** in this repo — it is the Pass 66 report's own object hash, which Pass 67 quoted to prove that file went in unmodified |

**A scan report quoting its own scan is the thing most likely to trip a keyword grep**, and it is
worth recording that this is what the three matches are, so no later pass re-investigates them.

**It went in unmodified**, as the step required — not a character edited.

---

## 3. Step 3 — the rule, in DECISIONS.md

One dated entry, **`## 2026-09-11 (Pass 68 — a pass's report goes in its own commit)`**, appended:
**26 insertions, 0 deletions.** It is written as a standing rule, not as an observation about
this pass.

**The rule.** A pass does the work, writes the report, commits everything together, pushes, then
verifies the push. The report is inside the commit. No pass leaves an untracked report for the
next one.

**Why the old ordering existed, and why dropping it costs nothing.** The report was written after
the push so it could carry the verified SHA — which meant it could not be in the commit, because
a commit cannot contain its own SHA. But Pass 60 rule (b) had already settled where that SHA
lives: the pass response and the next pass's notebook entry. So the report was never the right
home for it, and leaving it out removes the only reason to delay the commit.

**What the old ordering actually cost.** Not the reports — every one of them reached the repo
unmodified and byte-identical, one pass late. What it cost was a working tree that was never
clean at the end of a pass, and a standing task handed forward three times: **Pass 62's report
was committed by Pass 63, Pass 66's by Pass 67, and Pass 67's by this pass.** Each sweep-up was
correct under the ordering it inherited. The ordering was the defect.

**It is settled and is not to be re-raised.** Pass 67 §7.1 named the fix and left the decision to
the owner; the owner took it in this pass's brief.

---

## 4. Steps 4 and 5 — the report, and one commit

This file is step 4, and it is written **before** the commit rather than after the push. It
carries no post-push SHA, by design.

**One commit, three files, staged by name:**

| File | Why |
|---|---|
| `DECISIONS.md` | the standing rule, +26 / −0 |
| `reports/2026-09-11-pass67-notebook-current.md` | Pass 67's, unmodified — the last sweep-up |
| `reports/2026-09-11-pass68-report-ordering.md` | this report, in its own commit |

**`COLD-START.md` is deliberately untouched.** It carries what is built and the push history; the
report-ordering rule is a decision about how passes run, and DECISIONS.md is where those live.
"Next step" is current through Pass 66 (Pass 67) and the record of this pass's push belongs in
the next pass's notebook entry, not here.

---

## 5. Scope check — every path touched

| Path | What happened | Step |
|---|---|---|
| `DECISIONS.md` | one dated entry appended, **+26 / −0** | 3 |
| `reports/2026-09-11-pass68-report-ordering.md` | **new** — this file, committed with the rest | 4, 5 |
| `reports/2026-09-11-pass67-notebook-current.md` | **committed unmodified**, blob `e4b98ca` | 2, 5 |
| `COLD-START.md`, `CLAUDE.md` | **read only**, not written | — |
| `Marlin DVR TV/**`, `Marlin DVR TVUITests/**`, `*.xcodeproj`, `Info.plist`, entitlements | **not touched** | — |
| `design/`, `icon-source/`, every earlier report | **read only**, never written | — |
| `~/Xcode/marlin-dvr-reference` | **not touched at all** this pass | — |

No request was made to 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, no
build was run, nothing was installed on either Apple TV, and no other folder under `~/Xcode` was
read or written. No credential, token or device id appears above.

---

## 6. Open questions

1. **`icon-source/` is still the standing untracked baseline** — 32 entries, untouched by every
   pass since 51-55, its fate the owner's call and still undecided (DECISIONS.md 2026-09-08).
   After this pass it is the **only** thing `git status` reports, which makes it the one
   remaining item of housekeeping.
2. **"Next step" now opens with three paragraphs that each say nothing is unpushed** — as of
   Pass 66, Pass 58 and Pass 55. Each is true of its own moment. Whether the section should be
   consolidated is still the owner's call; Pass 59 raised it and Pass 67 raised it again.
3. **The open questions from Passes 63, 65 and 66 are untouched** and none is a defect: the two
   headings on the Search screen, the keyboard strip scrolling off the top, the duplicated prompt
   wording, silent DRM filtering, `Watch live` from a search result closing the sheet rather than
   playing, `/api/guide/search` being uncapped, and title-only matching.
4. **`GuideScreen` may carry the same latent focus defect** the Search screen has been fixed for
   twice. Raised in Pass 63 §9.1 and Pass 65 §9.4; still not investigated, still out of scope.

---

## 7. The things I am least sure of

1. **That nothing else depended on the report being written after the push.** The only thing it
   carried that a pre-push report cannot is the verified SHA, and Pass 60 rule (b) already
   rehomed that. If some future pass genuinely needs a post-push fact in its report — a push that
   was rejected and retried, say — the rule as written does not say what to do, and that pass
   should raise it rather than silently revert to the old ordering.
2. **That "no pass leaves an untracked report" is the right absolute.** A pass that is stopped
   part-way, or one that reports a blocker before doing any work, may still end with a report and
   no commit. The rule is about ordering within a pass that does commit, and it does not speak to
   a pass that stops early.
3. **Whether this entry belonged in `DECISIONS.md` alone.** It is a rule about how passes run,
   which is close to the territory `CLAUDE.md` owns. `CLAUDE.md` holds the standing builder rules
   and Pass 60 made it the single source of truth for them — but those are rules about conduct
   and scope, and this is a workflow ordering the notebook has always carried, so it went here.
   **If the owner would rather it were a `CLAUDE.md` bullet, moving it is a one-line change.**
