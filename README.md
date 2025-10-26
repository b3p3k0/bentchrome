# Bent Chrome – Developer Workspace

This repository hosts the collaboration artifacts for building **Bent Chrome**, a top-down vehicular combat title targeting Godot 4. The canonical high-level spec lives in `master_design.txt`; see `docs/requirements.md` for a distilled checklist while planning work.

## Repository Layout
- `master_design.txt` – original design document (keep untouched for reference).
- `docs/` – quick-reference notes, future diagrams, and planning artifacts.
- `prompts/` – space to archive Claude Code prompt iterations and plans.
- `scripts/` – helper scripts for local setup (see `RUNME.sh` once generated).
- `.gitignore` – tuned for Godot 4 so temporary imports/cache files stay out of version control.

## Development Environment
1. Install **Godot 4.2+** Standard build and ensure the `godot` binary is available on your `$PATH`.
2. Confirm **Python 3.10+**, `git`, and `rg` (ripgrep) for tooling and automation scripts.
3. Keep SDL2 development libraries handy if we later introduce native modules.
4. When unsure whether all prerequisites exist, run `./RUNME.sh` (generated as needed) to check/install missing pieces.

## Prompt-Driven Workflow
We will iterate on implementation by crafting structured prompts for Claude Code:
1. Draft the feature scope referencing `docs/requirements.md`.
2. Log prompts/responses under `prompts/` (e.g., `prompts/2024-09-08-arena.md`).
3. Review Claude’s plan, annotate changes needed, then execute locally.

This README will evolve alongside the project as we convert design beats into concrete tasks and Godot scenes.
