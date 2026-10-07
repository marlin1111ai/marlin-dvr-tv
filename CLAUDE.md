# How we work

## Who's in charge
You report to me and only me. There is no foreman or planner. What I say in this chat is final. If something I ask for conflicts with a file in the repo, ask me which one wins.

## How to talk to me
- I'm not a programmer. Talk to me in plain English. No code, file dumps, or jargon in your messages unless I ask to see them.
- Ask me one question at a time. Give me 2 or 3 options, say which one you recommend and why in one sentence, and I'll pick.
- If a choice doesn't really matter to me as the user of the app, just make the sensible choice and tell me what you picked.
- Collect your questions and ask them in one batch at a natural stopping point, not one at a time while you're working.

## Scope
- Build only what I asked for. No extra files, features, dependencies, "robustness" code, refactors, or config changes.
- If you think something extra is needed, stop and ask me as a decision before doing it.
- If I ask for something that won't work or will cause a problem, tell me plainly before building it.

## Plan first
For a new feature or anything with more than a couple of steps, give me a short plan in plain English and wait for my OK before writing code.

## Session start
Before anything else, read COLD-START.md and DECISIONS.md. Then tell me in a few lines where things stand and what's next.

## Testing
After every build, tell me exactly how to test it: what to open, what to click, what I should see. Step by step, like a checklist.

## Git
- Commit locally with clear messages whenever a piece of work is done.
- Never push until I say "push it."

## Scope check
End every work report with a list of every file you created or changed, and which task step required each one.

## Cleanup
Each pass, delete your own test files, scratch scripts, sample data, build folders, test results, and one-off logs. Keep only real tests that belong in the project.

## Wrapping up
When I say "wrap up" or type /wrap, run the full wrap-up routine in .claude/commands/wrap.md.

## Project basics
- Marlin DVR TV is the Apple TV app for the Marlin DVR server: it shows the guide, plays live channels, recordings and cameras, manages recordings and series passes, and has weather and radio screens. The server is a separate project (marlin-dvr) running on the Unraid host; this app is only its client.
- Native Swift/SwiftUI app for Apple TV (tvOS 18.0 and later).
- Builds on the Mac in Xcode (`Marlin DVR TV.xcodeproj`, scheme "Marlin DVR TV") and runs on the two Apple TVs, Home Theater and Master Bedroom ATV. The shared build folder is `build/` at the project root, which git ignores.
- Builds are signed with my Apple Developer account and installed straight onto the Apple TVs. Ask me before changing anything about signing or entitlements.
- The record of this project is COLD-START.md and DECISIONS.md at the project root, and per-pass reports live in reports/. What they settle is not re-derived.
- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.
- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
