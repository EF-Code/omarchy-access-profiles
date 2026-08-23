# Release checklist

This checklist separates reproducible repository checks from evidence that
requires a real graphical Omarchy session or an external submission.

## Reproducible locally

- [x] `omarchy plugin validate .`
- [x] `qmllint -I "$OMARCHY_PATH/shell" qml/BarWidget.qml qml/Panel.qml qml/Service.qml qml/components/*.qml`
- [x] `qmlformat` validation for all QML files.
- [x] `bash tests/repository-check.sh`
- [x] `bash tests/run.sh` — 12 tests passed.
- [x] `tests/accessctl.bats` — 3 tests passed with Bats 1.14.0 from a temporary upstream checkout.
- [x] `node tests/model.test.js`
- [x] `bash -n scripts/accessctl tests/run.sh` and `git diff --check`.
- [x] Confirm `git status --short` is clean after the release commits.
- [x] Confirm no build guide or private state is in `git ls-files`.

## Real graphical session

- [x] Install from the public GitHub URL, enable the plugin, and verify the bar widget.
- [x] Verify shell IPC summon/hide, Escape, keyboard navigation, selection, preview, and apply paths.
- [ ] Verify pointer click and click-away paths — unverified because no usable Wayland mouse injector is available in this session.
- [x] Preview all four profiles, wait for timeout, Keep, and Revert now.
- [x] Apply and switch profiles, then restore the complete original baseline.
- [x] Restart `omarchy-shell` during an active preview and verify recovery.
- [x] Test keyboard-only flow at the live enlarged text scale (`gtk.text.scale=1.25`).
- [x] Test narrow and vertical-bar layouts and one-monitor behavior.
- [x] Test temporary second-output lifecycle with Hyprland `HEADLESS-1`; visual behavior on a second physical monitor remains unverified.
- [x] Restore original settings and return the bar to the top position before removal.

## External submission

- [ ] Recheck the live marketplace for naming/category overlap.
- [ ] Recheck the official competition deadline and timezone.
- [ ] Submit the exact tested public commit and record the issue URL/SHA.

Do not describe the plugin as submitted until the external issue/form exists.

## Evidence from 2026-08-23

- Public install tested from `https://github.com/EF-Code/omarchy-access-profiles.git`; the tested plugin implementation was `c32af3263fee230b8b14152090bf6cb4973c849d`.
- Live session: Omarchy 4.0.0, Hyprland 0.56.2, Quickshell 0.3.0, Wayland, one 1920x1080 display at scale 1.25.
- Reversible headless-output test created and removed `HEADLESS-1`; no persistent monitor change remained.
- Pointer click/click-away and visual two-physical-monitor behavior are the remaining graphical-session gaps.
