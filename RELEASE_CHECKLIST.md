# Release checklist

This checklist separates reproducible repository checks from evidence that
requires a real graphical Omarchy session or an external submission.

## Reproducible locally

- [x] `omarchy plugin validate .`
- [x] `qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml components/*.qml`
- [x] `qmlformat` validation for all QML files.
- [x] `bash tests/repository-check.sh`
- [x] `bash tests/run.sh` — 15 tests passed, including unmanaged-baseline, cross-profile drift, and safe-restore conflict regressions.
- [ ] `tests/accessctl.bats` — not rerun for the restore fix because Bats is unavailable in this environment; the portable runner passed.
- [x] `node tests/model.test.js`
- [x] `bash -n scripts/accessctl tests/run.sh` and `git diff --check`.
- [x] Confirm `git status --short` is clean after the release commits.
- [x] Confirm no build guide or private state is in `git ls-files`.

## Real graphical session

- [x] Install from the public GitHub URL, enable the plugin, and verify the bar widget.
- [x] Verify shell IPC summon/hide, Escape, keyboard navigation, selection, preview, and apply paths.
- [x] Verify pointer click and click-away paths — native Hyprland cursor movement plus `mouse:272` events selected Focus on `DP-2` and dismissed the panel from the other monitor.
- [x] Preview all four profiles, wait for timeout, Keep, and Revert now.
- [x] Apply and switch profiles, then restore the complete original baseline.
- [x] Restart `omarchy-shell` during an active preview and verify recovery.
- [x] Test keyboard-only flow at the live enlarged text scale (`gtk.text.scale=1.25`).
- [x] Test narrow and vertical-bar layouts and one-monitor behavior.
- [x] Test the physical two-monitor layout: panel rendered on both `eDP-1` and `DP-2`, and cross-monitor click-away dismissal worked in both directions.
- [x] Test reversible second-output lifecycle with Hyprland `HEADLESS-1`.
- [x] Restore original settings and return the bar to the top position before removal.

## External submission

- [ ] Recheck the live marketplace for naming/category overlap.
- [ ] Recheck the official competition deadline and timezone.
- [x] Submit the exact tested public commit and record the issue URL/SHA: [marketplace issue #1924](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/1924), public commit `ab15b9621b0ef7805c3c5fae15888ed9fa7749d6`.

The marketplace submission issue is open and records category `System` with tags `Bar`, `Hyprland`, and `Quickshell`. The naming/category-overlap and competition-deadline checks remain separate and are not inferred from submission.

## Evidence from 2026-08-23

- Public install tested from `https://github.com/EF-Code/omarchy-access-profiles.git` at `d69f3310f70faa5dc583ac46ac49eebf7a3c4d7a`; the subsequent public revisions are documentation-only.
- Marketplace submission issue [#1924](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/1924) was created for the tested public commit `ab15b9621b0ef7805c3c5fae15888ed9fa7749d6`.
- Live session: Omarchy 4.0.0, Hyprland 0.56.2, Quickshell 0.3.0, Wayland, `eDP-1` at 1920x1080 scale 1.25 plus `DP-2` at 1024x768 scale 1.
- Native Hyprland pointer events selected a profile on `DP-2`; click-away dismissal succeeded from both monitors.
- Reversible headless-output test created and removed `HEADLESS-1`; no persistent monitor change remained.
