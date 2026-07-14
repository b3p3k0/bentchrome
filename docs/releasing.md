# Cutting a release (and how the in-game updater consumes it)

Testers get new builds through **Settings → CHECK FOR UPDATES**, not git. That
feature compares a tagged GitHub Release against the local `version.txt` and,
when newer, downloads the release's archive for the `PLAY` launcher to apply on
the next start. This doc is how you publish one of those releases.

## Cut a release

1. **Bump `version.txt`** at the repo root to the new tag, e.g. `v0.4.2`, and
   commit it. This is the sole runtime "what build am I" value — the archive
   carries it, so applying an update updates the tester's local version for free.
2. **Tag and push:**
   ```
   git tag v0.4.2
   git push origin HEAD
   git push origin v0.4.2
   ```
3. The **`.github/workflows/release.yml`** workflow fires on the `v*` tag. It:
   - verifies `version.txt` equals the tag (fails the release if you forgot the bump),
   - runs `git archive --format=zip` at the tag to build a **flat** `bentchrome-<tag>.zip`
     (tracked files at the zip root, `.git`/untracked caches excluded), and
   - publishes a GitHub Release with that zip attached and auto-generated notes.

Edit the release notes on GitHub if you want a friendlier changelog — the
updater shows the release `body` verbatim in the panel.

## Going live (one-time)

Until the first release exists, the **CHECK FOR UPDATES** row is ghosted
("COMING SOON") and inert. Once you've published that first release, flip the
master switch and the row lights up:

- `game/updater.gd` → `const RELEASES_LIVE := true`

That's the only edit needed to turn the feature on.

## Why the archive is built this way

- **Flat, no top-level dir.** The launcher extracts straight over the game folder
  (`unzip -o` / `Expand-Archive -Force`), so files must sit at the zip root.
  GitHub's auto-generated "Source code (zip)" nests everything under
  `bentchrome-<sha>/` and would **not** overlay correctly — never point testers at it.
- **`.godot/` import cache is not shipped.** It's untracked, so `git archive` omits
  it; the launcher regenerates it with `godot --headless --import` right after
  unpacking.
- **Integrity.** The in-game downloader records the release asset's `sha256`
  (GitHub's asset `digest`) into `.updates/apply.json`; the launcher verifies the
  zip against it before extracting. If GitHub didn't provide a digest, the
  launcher warns and applies without the check — nothing half-applies on mismatch.

## Things to tell testers

- **Always launch with `PLAY`** (`./PLAY.sh` / `PLAY.cmd`). Updates are applied by
  that launcher before the game boots; running `godot` directly skips the apply step.
- **Applying overwrites local edits** to tracked files (it's an overlay of the
  release). That's fine for testers; a dev working tree simply never presses the
  button (and a raw checkout reports version `dev`, which the updater treats as
  "older than any release").
