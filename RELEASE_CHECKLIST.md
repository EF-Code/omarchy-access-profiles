# Release checklist

This checklist separates reproducible repository checks from evidence that
requires a real graphical Omarchy session or an external submission.

## Reproducible locally

- [ ] `omarchy plugin validate .`
- [ ] `qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml components/*.qml`
- [ ] `bash tests/repository-check.sh`
- [ ] `bash tests/run.sh`
- [ ] `node tests/model.test.js`
- [ ] Confirm `git status --short` is clean.
- [ ] Confirm no build guide or private state is in `git ls-files`.

## Real graphical session

- [ ] Install from a clean checkout and enable the bar widget.
- [ ] Verify click, Escape, click-away, and shell IPC open/close paths.
- [ ] Preview all four profiles, wait for timeout, Keep, and Revert now.
- [ ] Apply, switch profiles, restore, and resolve an external-drift conflict.
- [ ] Restart `omarchy-shell` during preview and verify recovery.
- [ ] Test keyboard-only flow at enlarged text scale.
- [ ] Test narrow, vertical-bar, one-monitor, and two-monitor layouts.
- [ ] Restore original settings before removing the plugin.

## External submission

- [ ] Recheck the live marketplace for naming/category overlap.
- [ ] Recheck the official competition deadline and timezone.
- [ ] Submit the exact tested public commit and record the issue URL/SHA.

Do not describe the plugin as submitted until the external issue/form exists.

