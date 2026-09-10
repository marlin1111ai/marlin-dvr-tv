# Marlin DVR TV — standing rules for the builder

The record of this project is COLD-START.md and DECISIONS.md at the project root. Read both before any work and do not re-derive what they settle. Per-pass reports live in reports/.

- Recon before build.
- Scope lock: build only what the pass names. Anything extra is a question in the report, never built, not even disabled.
- No installs without owner authorization.
- Separate push gate for code the owner tests.
- Never force-push and never rewrite history.
- No secrets in the repo, logs, or reports. Redact tokens, credentials and device IDs before any commit or report.
- If anything blocks, stop and report. Do not work around it.
- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.
- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
