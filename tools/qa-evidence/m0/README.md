# M0 verification evidence, 2026-10-17

Baseline: 26d8e4b47eef5d17fe2ca8385da3ddb58adce95e, contract v1.0.0.
Flutter 3.47.7 / Dart 3.13.5; see tools/flutter-toolchain.json.

These are actual synthetic-test logs, not production financial records.
`original-pub-get.log` records the unchanged M0 resolution failure.
Other logs were produced in the ASCII diagnostic clone with build_runner
changed from 2.17.1 to 2.16.2. Flutter pub also added `build/**` to analyzer
exclusions; the exact changes are in candidate-config.diff.

`pubspec.candidate.lock` is generated evidence for the owner to review. It is
not the project's active dependency lock and is not installed by any script
or CI workflow. Its SHA256 is
cbffdad20062a90a8987d6db776e9d8581a43394b8dd7f865f54b669c193f616.
After the owner approves the dependency change, they can promote this file
to root pubspec.lock and run `flutter pub get --enforce-lockfile` using the
pinned SDK in a fresh ASCII checkout. Do not silently install this candidate
over a subsequently changed pubspec.

The verification script stopped at analyze (six infos, exit 1). The 31-test
Flutter suite was then run separately and passed. The debug bundle build
failed because Android SDK was absent; no APK or kernel bundle was produced.
Tests only cover the current foundation, not a complete application lifecycle,
repository, migration, statistics or backup implementation.

validated-source-inputs.json records hashes after adding the real database
tests. Absolute Windows paths identify the test workspace; they are not
portable configuration values. See docs/qa-report.md for the complete plan,
findings, release checklist and limitations.
