## Summary
Describe what changed and why. Link the issue/task and explain visible behavior.

## Today and pending — required for every change
- [ ] `README.md` **Today** section updated (current date, done / doing / blocked), or an explicit **Docs-only / no status change** reason is provided below.
- [ ] `README.md` **Pending** table reviewed for added, completed, blocked or reprioritized tasks.
- [ ] `changes.md` updated: PR/branch, affected files and approximate line ranges, validation, limitations.
- [ ] Detailed entry created under `docs/change-notes/` for multi-file behavior changes.
- [ ] PR title and description distinguish **implemented**, **CI passed**, **field-tested** and **merged**.
- [ ] Any previously outstanding work carried forward with clear evidence requirements.

**If any README checkbox is unchecked, explain why:**

## Testing and verification
- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Android build check (where applicable)
- [ ] iOS build check (where applicable)
- [ ] Physical-device checks, when needed (document hardware, OS and evidence)
- [ ] Offline, GPS, and BLE safety behavior unaffected or explicitly tested

**Links to Actions runs / field-test notes:**

## Safety / known limitations
- Describe GPS uncertainty, BLE background/silent-mode constraints, new permissions, map attribution or provider usage changes when relevant.
- Do **not** claim a safety-critical capability is validated solely because the code compiled.

## Rollout / review
- Related PR / issue:
- Branch:
- Ready to merge? Why:
- Remaining follow-ups:
