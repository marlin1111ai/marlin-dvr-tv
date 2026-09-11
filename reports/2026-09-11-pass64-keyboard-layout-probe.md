# Pass 64 — keyboard layout probe — 2026-09-11

*Written up in Pass 65. Pass 64 required a clean working tree and so deferred its own report;
this is that report, unchanged in substance from what was reported to the owner on the day.*

**Verdict: SwiftUI's `.searchable` does exactly what the owner asked for, and it was the only
one of the three candidates that keeps the keyboard and the results list on screen together
throughout.** Pass 63 step 1's "the tvOS keyboard is a full-screen takeover" is true of a plain
`TextField` and **only** of a plain `TextField`.

Read-only as to the shipped app. Every probe file was deleted and every touched file restored
with `git checkout` before the pass reported; nothing of it was committed. The Apple TV was left
with a freshly built clean-HEAD build rather than the probe.

**Citation keys.** `<Header>.h:NN` = `AppleTVOS26.5.sdk/System/Library/Frameworks/UIKit.framework/Headers`.
`SwiftUI.swiftinterface:NN` = the same SDK's SwiftUI interface. Screenshots are
`reports/assets/pass64/`. Base commit: `1107b12` (Pass 63).

---

## 1. How it was measured

One temporary probe screen behind `MARLIN_KB_PROBE`, in place of On Later, with four variants,
and one temporary harness driving the real Siri Remote on Home Theater. The probe read **nothing**
from the server — twelve fixed rows filtered in memory — so the only thing under test was where
tvOS puts the keyboard.

**A methodological finding that governs everything below: the accessibility tree lies about this
question.** For the two inline variants the tree reported the probe's twelve rows *absent* at
moments when a screenshot of the same instant showed all twelve drawn. The screenshots are the
evidence; element frames and focus dumps are corroboration only.

**A harness trap worth recording**, because it cost three device runs: the first attempt never
left the rail, so `app.typeText` failed with "Neither element nor any descendant has keyboard
focus" and the variants looked broken when they were not. Crossing into the content is
`remote.press(.right)`, and on the inline variants that lands on the **results list** — the
keyboard strip is *above* it, so the walk to the keyboard is Right then Up.

---

## 2. 1a — SwiftUI `.searchable`, in this app's structure ✅

| Question | Answer |
|---|---|
| Keyboard full-screen? | **No.** A one-row alphabet strip at `(158, 164.5, 1760, 66)` — 66 pt tall, inline, under the search field. Nothing blurred; the rail stays visible. |
| List visible while typing? | **Yes, throughout.** Rows sit at y=437 and below and do not move. |
| Binding per keystroke? | **Yes** — `updates=4` for the four letters of "news", list 12 → 5 rows. |
| Remote reaches both without dismissing? | **Yes.** Right from the rail lands on the list; one Up reaches the keyboard; Down returns to the list with `keyboards=1` still reported and the strip still drawn; Up goes back. |

Screenshots `1a-01-on-open.jpg`, `1a-02-while-typing-news.jpg`,
`1a-03-focus-in-the-list-keyboard-stays.jpg`.

**It needs no `NavigationStack`.** Variant a2 ran the same probe inside one as a control and it
drew pixel-for-pixel the same (`1a-04-navigationstack-control.jpg`). This matters because the app
has no navigation container anywhere (Pass 62 §3.1) and adding one would have been a large change.

`.searchable` is tvOS 15.0 (`SwiftUI.swiftinterface:5492-5493`), under this app's tvOS 18.0
deployment target, and `.automatic` is its only tvOS placement — `.toolbar`, `.sidebar`,
`.navigationBarDrawer` and the rest are all `@available(tvOS, unavailable)` (`:8830-8852`). So
where the chrome lands is SwiftUI's decision and there is no placement choice to get wrong.

---

## 3. 1b — a `TextField` in a container pinned to the top ❌

Unchanged from Pass 63, and **the container's frame makes no difference**: the field was 190 pt
tall at the very top of the screen and pressing Select still produced the full-screen takeover —
app blurred out, field re-drawn centred, `done` button, nothing of the list visible
(`1b-02-while-typing-full-screen-takeover.jpg`).

The keyboard element's own frame is `(0, 462, 1920, 226)` — only the key rows — but the
*presentation* covers the screen, which is why the frame alone would have been misleading. Every
element behind it reported `hittable=false`.

The binding does update per keystroke (`updates=4`, rows 12 → 5) **behind a keyboard you cannot
see past**, and two Down presses never left `focused=Keyboard`: the list is unreachable without
dismissing.

---

## 4. 1c — `UISearchController` in a `UISearchContainerViewController` ⚠️

Two results, and the first is a trap.

**Contained directly in a `UIViewControllerRepresentable`: it draws perfectly and cannot be
focused at all.** Search bar, inline keyboard and results list all render
(`1c-01-bare-container-drawn-but-unfocusable.jpg`), but Right from the rail does nothing and four
Up presses simply walk the rail up to Home. Unusable as built.

**Wrapped in a `UINavigationController` with `isActive = true`** — the shape Apple's own tvOS
search takes — it works: the same inline layout, `updateSearchResults(for:)` firing per keystroke,
the remote reaching both (`1c-02-navcontroller-while-typing.jpg`).

**But it behaves differently from 1a in the way that decides the question: the moment focus moves
down into the results, the keyboard is dismissed** — `keyboards` 1 → 0 — and the list slides up
about 100 pt to fill the space (`1c-03-navcontroller-focus-in-list-keyboard-gone.jpg`). Up brings
it back. That is UIKit's deliberate tvOS behaviour, not a defect, but it is "the input goes away
when you browse" rather than "the input stays above the list".

The probe honoured both things the SDK requires of this route: a results controller, because
`UISearchController.h:61` says *"Pass nil if you wish to display search results in the same view
that you are searching. This is not supported on tvOS; please provide a results controller on
tvOS"*; and the container, because `UISearchContainerViewController.h:15` says *"Use this
container view controller for UISearchController containment or presentation on tvOS"*.

---

## 5. Step 2 — does tvOS offer a mechanism that keeps a list visible?

**Yes, two, and the better one is the one SwiftUI already gives this app.** No workaround was
invented and none was built. Both 1a and 1c(nav) produce the native tvOS inline search layout;
they differ only in whether the keyboard survives focus entering the results, and 1a's does.

---

## 6. Step 3 — what changing Pass 63's screen would involve

Reported as scope, not built. Contained to `GuideSearchScreen.swift`: replace the hand-built field
with `.searchable` on the screen's root and delete its chrome, glyph, focus treatment and ink fix;
drop `restoreFocusID`'s field arm; keep the 400 ms debounce; **re-measure** whether the
sheet-close focus rebuild is still needed, since `.searchable` changes the focus topology; and
update the harness, whose rows and count line have moved. Unchanged: the model, both decoders,
`ChannelFilter.swift`, `Destination.swift`, `ScreenShell.swift`, the count line, the row, the
sheet wiring and the rail entry.

**This is what Pass 65 built, and its report records what the re-measurement found.**

---

## 7. Scope check

| Path | What happened |
|---|---|
| `Marlin DVR TV/Pass64KeyboardProbe.swift`, `Marlin DVR TVUITests/Pass64KeyboardProbeUITests.swift` | **temporary, created and deleted** — never committed |
| `Marlin DVR TV/ScreenShell.swift` | a two-line temporary hook, **restored with `git checkout`** |
| everything else under `Marlin DVR TV/` | untouched |
| `design/`, `COLD-START.md`, `DECISIONS.md`, `CLAUDE.md` | **not read into and not written** |
| `~/Xcode/marlin-dvr-reference` | **not touched at all** this pass |
| `AppleTVOS26.5.sdk` headers | read only |

No request was made to 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share — the
probe had no network code — and no other folder under `~/Xcode` was read or written. The working
tree was proved clean apart from the known untracked `icon-source/` before the pass reported.

---

## 8. The things this pass was least sure of

1. **Whether `.searchable`'s inline chrome can be styled to the app's look at all.** It is
   Apple's — field, strip and divider all system-drawn — and the probe found no way in. The list
   below it is entirely the app's.
2. **Whether the keyboard strip is reachable by Up from any scroll position in a long list**, or
   only from the first row. The probe had five rows, all on screen at once. **Pass 65 measured
   this properly; see its §4.**
3. **Where `.searchable` puts the field once the screen has a `ScreenHeader` above it.** The
   probe's own title sat *below* the strip. **Pass 65 measured this; see its §3.**
4. **Why the bare `UISearchContainerViewController` cannot take focus.** That it does not is
   proven; the cause is not, so the navigation controller cannot be called the only fix.
