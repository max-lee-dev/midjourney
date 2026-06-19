# CLAUDE.md

MidjourneyMedical — patient-facing iOS prototype (SwiftUI) for visualizing full-body scan results over time.

See [vision.md](./vision.md) for product context.

## Git workflow

After finishing any task that changes files, **always commit and push to `main`** before reporting the work complete.

1. Review what changed (`git status`, `git diff`).
2. Stage all relevant changes — do not commit build artifacts (`.derivedData/`, `build/`), secrets, or local-only config.
3. Write a short commit message that describes **why** the change was made (1–2 sentences).
4. Commit on `main`.
5. Push to `origin main`.

Do this at the end of every agent session where code or project files were modified, even for small changes. Do not leave uncommitted work behind.

If there is nothing to commit, skip this step.
