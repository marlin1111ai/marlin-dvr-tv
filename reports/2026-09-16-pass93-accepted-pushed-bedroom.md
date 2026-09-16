# Pass 93 — Passes 91 and 92 accepted, pushed, and installed on the bedroom Apple TV

2026-09-16. **No app-target code changed in this pass.** One commit, pushed.

---

## 0. Result

The owner tested Passes 91 and 92 on Home Theater and accepted them — **"good to go"**. Their two
commits are pushed as a fast-forward, and the bedroom Apple TV is brought to the same build. This
pass's commit carries this report, the `DECISIONS.md` entry and the `COLD-START.md` paragraph, and
nothing else.

---

## 1. Step 1 — the state before anything was written

`git fetch`, then:

```
HEAD / main:  ab2570a7617220796bb565d15abe5e3d1089b96b   (Pass 92)
origin/main:  92a477071df7058942fe3895bd77166e50c3af00   (Pass 89)
git ls-remote origin main
              92a477071df7058942fe3895bd77166e50c3af00	refs/heads/main
git rev-list --left-right --count main...origin/main
              2	0
git log --oneline 92a4770..main
              ab2570a Pass 92: a progress bar on the Continue watching cards
              c633c9f Pass 91: Continue watching replaces the server's Recently Watched shelf
branch:       main
git status --porcelain
              ?? icon-source/
```

Exactly as the pass required: `origin/main` at `92a4770`, local `main` two ahead — `c633c9f` then
`ab2570a` — and nothing else waiting or dirty. **Pass 91's verified push SHA is `c633c9f` and
Pass 92's is `ab2570a`.**

---

## 2. Step 2 — the acceptance

**Owner, 2026-09-16, on Home Theater: "good to go".** It covers both passes together, because both
land on the same shelf:

- **Pass 91** — the Recordings screen draws **"Continue watching"** from **this Apple TV's
  `ResumeStore`** in place of the server's **"Recently Watched"** shelf: same position, same card,
  the recordings this Apple TV has an unfinished saved position on, newest position first, and no
  card for a recording with no saved position.
- **Pass 92** — a **6 pt `Nocturne.accent` progress bar** across the bottom of those cards, filled
  `position ÷ duration` from the two numbers already on the card, on a `Nocturne.bg`-at-0.7 track,
  and on no other shelf's cards.

**The focus ring covering 4 of the bar's 6 pt on a focused card was shown to him before he
accepted, and is accepted as built.** It is **not an open item and not deferred**: the ring is 4 pt
of the same `Nocturne.accent` drawn over the bar's bottom 4 pt, so only 2 pt of the bar is
distinguishable while a card holds focus, with the fill boundary still visible. Pass 92 measured it,
photographed it in `reports/assets/pass92/92b-continue-watching-card-focused.jpg`, listed three
possible fixes in its open question 1 and built none of them. The owner has now settled it by
accepting what is there, so it leaves the KNOWN AND UNFIXED list in `COLD-START.md`.

**Pass 92's other open questions are neither closed nor re-raised by this acceptance** — the
translucent track over a bright poster, 99 % versus 100 % watched, the bar's silence to VoiceOver,
the two progress views drawing the same number, and whether the other `activate()` harnesses should
move to `launch()`. They stand exactly as Pass 92 left them, and so do Pass 91's.

---

## 3. Steps 3 and 4 — the notebook and the push

The `COLD-START.md` "Next step" paragraph now records that nothing is unpushed as of Pass 93, that
`c633c9f` and `ab2570a` went out with this pass's commit as a fast-forward from `92a4770`, and that
both Apple TVs run this build. Pass 92's paragraph is kept below it as history, as this project
does. **This pass's own SHA is not written into the notebook and cannot be** — a commit cannot
contain its own SHA (`DECISIONS.md`, 2026-09-11 (Pass 68)); it is in the Pass 93 response.

One commit carries this report, the `DECISIONS.md` entry and that paragraph. **Nothing was forced,
rebased or amended**, and `92a4770` is still an ancestor of `origin/main`.

**Files touched in this pass:** `DECISIONS.md`, `COLD-START.md`, and this report. **No app-target
file, no test-target file, no asset.** The binary the owner accepted is Pass 92's, and the binary
pushed and installed on the bedroom Apple TV is the same one.

---

## 4. Step 5 — the bedroom Apple TV

Built **from the pushed head** by Pass 54's method to the same device, and installed with
`xcrun devicectl device install app`. The device identifier is redacted here as the standing rules
require.

**The build directory changed, deliberately and permanently.** Earlier passes each made a per-pass
tree — `build/p88` in Pass 88 — and that stops here. The bedroom build now goes to
`~/Library/Developer/Xcode/DerivedData/MarlinDVRTV-bedroom` and **that path is reused on every
future bedroom install** (owner, 2026-09-16), so the build can be incremental and the repo stops
accumulating one tree per pass.

**Install only.** Unlike Pass 88, the app was **not launched** on that television, **no UI-test
harness was run** there and **no screenshot was taken**. What the device itself reports about the
installed app is the whole of the evidence, and it is in the Pass 93 response rather than repeated
here.

**No request was made to the server in this pass**, of any kind.

---

## 5. What stayed local

Nothing. Every commit this project has is on `origin/main` at the end of this pass.
