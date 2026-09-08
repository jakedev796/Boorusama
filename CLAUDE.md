# Boorusama

A cross-platform Flutter client for booru imageboards (GPLv3). One app shell talks to ~17 different
imageboard engines — Danbooru, Gelbooru (v1/v2/0.2.5), e621ng, Moebooru, Sankaku, Szurubooru, Hydrus,
Philomena, Shimmie2, Zerochan, Nozomi, and others — each implemented under `lib/boorus/{engine}/`
against a shared core.

This is a fork of [khoadng/boorusama](https://github.com/khoadng/boorusama). See
**Fork divergence** at the bottom for what differs from upstream.

## Layout

```
lib/boorus/{engine}/   per-engine implementations + registry.dart
lib/core/{feature}/    cross-engine features (posts, downloads, settings, themes, premiums, …)
lib/foundation/        infra with no product logic (iap, loggers, filesystem, vendors/)
lib/main.dart          default entrypoint   (main_foss.dart / main_web.dart are variants)
packages/              16 workspace packages (kurumi = design system, booru_clients = HTTP clients,
                       i18n, foundation, boorusama_cli, codegen, …)
```

`QUICKSTART.md` is the authority on module conventions — barrel exports, `src/` privacy, and how to add
a new booru type or feature. Read it before adding anything structural.

## Commands
- `./init.sh` - Bootstrap: `pub get` for app + CLI, then codegen. **Run this first on a fresh clone.**
- `./gen.sh` - Generate i18n, language configs, and booru client configs
- `flutter test` - Run tests
- `flutter analyze` - Static analysis
- `./build.sh` - Build release artifacts (see `packages/boorusama_cli`)

Toolchain: Dart `^3.12.0`, Flutter `^3.44.0`. Verified on **Flutter 3.47.2 / Dart 3.13.2**.
`.fvmrc` pins the `stable` channel; `scripts/toolchain.sh` uses `fvm` when present and silently falls
back to system Flutter/Dart when it isn't, so either setup works.

## Environment gotchas

Read this before debugging a broken checkout. Most "the codebase is broken" symptoms are one of these.

**Codegen is mandatory and its output is gitignored.** `packages/i18n/lib/src/gen/*`,
`lib/boorus/registry.g.dart` and `packages/booru_clients/lib/src/generated/*` are generated. Skip
`./gen.sh` and `flutter analyze` reports **~1600 phantom errors** — mostly `The getter 't' isn't defined
for BuildContext` and `Undefined name 'BooruType'`. Those are not real; run codegen and they vanish. A
fresh `git worktree` has no generated files either, so codegen is per-worktree.

**Native assets cannot be disabled.** `cupertino_http`, `libavif`, `objective_c` and `sqlite3` all
require the dart assets feature, so `flutter config --no-enable-native-assets` just fails the build.
`flutter test` therefore compiles `libavif` — vendored dav1d and libyuv via CMake+meson, plus a Rust
crate — on every clean run. That needs `cmake`, `ninja`, `meson`, `nasm`, `pkg-config`, a C compiler,
and a Rust toolchain on PATH. `libavif`'s `hook/build.dart` pins Rust via `rust-toolchain.toml` and
rustup installs that version on demand.

**`flutter test` and `./gen.sh` do not work on Windows.** The libavif build blows the 260-char
MAX_PATH limit: Flutter's `.dart_tool/hooks_runner/...` tree is ~236 fixed characters before meson's
own subdirectories, and meson emits source paths as long `../` chains into the pub cache. Symptoms are
`FileTracker : error FTK1011`, `MSB8029`, `No CMAKE_C_COMPILER could be found`, or
`C1083: Cannot open source file: '../../../../...'`. Setting `LongPathsEnabled=1` does **not** help —
`cl.exe` and MSBuild's FileTracker are legacy MAX_PATH-bound and ignore it, and `subst`/junctions are
defeated because meson calls `realpath`. **Use WSL2 or Linux/macOS to run tests and codegen.** Editing
and `flutter analyze` are fine on Windows.

**Windows also needs Developer Mode** (`start ms-settings:developers`) or `flutter pub get` fails at
`Building with plugins requires symlink support`. Note it resolves dependencies and writes
`pubspec.lock` *before* that failure, so a partial success is easy to misread. Enabling it also makes
`./gen.sh` start failing, because build hooks then actually run and hit the MAX_PATH problem above.

**`flutter pub get` rewrites tracked files.** It prints
`Upgrading analysis_options.yaml to exclude build and platform directories` and edits the root plus 7
package `analysis_options.yaml` files, and it re-pins SDK-bundled packages (`intl`, `matcher`, `meta`,
`test`, `test_api`, `test_core`, `vector_math`) in `pubspec.lock`. This is normal. Commit it as its own
`chore:` change rather than letting it leak into an unrelated PR.

**Keep the checkout path short** on any platform. Deeply nested paths (e.g. nested git worktrees) make
the native-asset build fragile.

## Setup on WSL2 / Linux

```bash
sudo apt install -y cmake ninja-build meson nasm pkg-config unzip zip   # + git curl gcc make python3
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
# install Flutter 3.47.x, put flutter/bin and ~/.cargo/bin on PATH, then:
./init.sh
```

Clone onto the Linux filesystem (`~/…`), not `/mnt/c` — 9p is slow for builds and reintroduces
Windows path semantics. First `flutter test` takes several minutes while native assets build; once
cached the full suite runs in ~11 seconds.

## Runbook before opening a PR

Run all of this on Linux/WSL2 — steps 2 and 3 cannot pass on Windows.

1. **Codegen if types or translations changed** — `./gen.sh` (or `./init.sh` on a fresh tree).
2. **Format** — `dart format .`, or the touched files. CI has no formatting gate, so this is on you.
   Verify with `dart format --output=none --set-exit-if-changed <files>`.
3. **Analyze** — `flutter analyze`. Expect **0 errors**. There are ~30 pre-existing warnings/infos
   (deprecated `prefer_final_parameters` lint, some `unawaited_return_in_try_block`, and
   `prefer_initializing_formals` in the vendored `packages/extended_image`). Do not add errors; do not
   feel obliged to fix the pre-existing ones.
4. **Test** — there are **two layers**, and the second is easy to miss entirely.

   a. `flutter test` at the repo root — expect **659 passed / 1 failed of 660** (see Known failing
      test). This runs only the root `test/` tree.

   b. Root `flutter test` does **not** run any workspace package's own suite. Ten packages have one,
      ~553 tests between them, and none of it is covered by (a) — a package only reaches the root run
      through app-level tests that import it (e.g. `test/pawchive_test.dart` imports
      `package:booru_clients/pawchive.dart`). Run the suite for any package you touched:

      | Package | Command | Expect |
      |---|---|---|
      | `coreutils` | `dart test` | 190 |
      | `boorusama_cli` | `dart test` | 81 |
      | `dtext` | `dart test` | 59 |
      | `booru_clients` | `dart test` | 52 |
      | `flutter_sqlite3_migration` | `flutter test` | 45 |
      | `foundation` | `flutter test` | 45 |
      | `i18n_cli` | `dart test` | 32 |
      | `filename_generator` | `dart test` | 31 |
      | `retriable` | `dart test` | 11 |
      | `extended_image` | `flutter test` | 7 |

      The three `flutter test` ones depend on Flutter; the rest are pure Dart. Writing an acceptance
      check as "run `flutter test`" for work inside one of these packages is **vacuous** — the tests
      never execute.

   If anything else fails, re-run it against `master` before assuming you caused it — several failures
   here have been pre-existing.

   These counts go stale. Verify against `master` rather than trusting them; a stale hardcoded value
   in a test is what broke `image_url_resolver_test.dart`.
5. **Commit** — conventional commits, summary only, no body:
   `fix(posts): handle null tags`. One concern per commit.
6. **Branch off `master`** and open the PR with `gh pr create --base master`. Prefer independent
   branches off `master` over stacked ones when the changes touch disjoint files, so they can merge in
   any order. PRs merge with `--rebase` to keep history linear.

There is **no CI test or analyze workflow** — `.github/workflows/` only contains `github-release.yml`.
Nothing will catch a regression for you, so step 4 is not optional.

### Known failing test

`test/bulk_downloads/providers/downloads/skip_test.dart: Download Skipping should skip individual files
that already exist` fails on `master`. The production skip logic in
`lib/core/bulk_downloads/src/providers/dry_run.dart` is correct — it omits the `DownloadRecord`
entirely when `task.skipIfExists` and the file exists. The *test* is wrong: its mock keys on
`fileName.contains('test-original-url-1')`, but `exists()` receives the generated filename from
`dummyDownloadFileNameBuilder`, which has no token handlers and resolves every post to the literal
`'test-default-bulk-format'`, so the predicate can never match. Its sibling
`should skip all files when they all exist` passes only vacuously — with everything "existing",
`records` is empty and its `for` loop asserts nothing. Fixing it properly means giving the fixture a
per-post filename format, which touches `test/bulk_downloads/providers/downloads/common.dart` and so
every test in that suite.

## Cutting a release

Only the **repository owner** can run it — both jobs are gated
`if: github.actor == github.repository_owner`. Android is the only target built.

1. **Bump the version** in `pubspec.yaml` and add a matching `CHANGELOG.md` section. The heading has
   to equal the version name exactly: `Changelog(...).sectionFor(version.name)` feeds the release
   notes, so `# 4.6.0` for `version: 4.6.0+186`.
2. **Tag with a `v` prefix and push it.** The workflow does `checkout` with
   `ref: inputs.release_tag`, so **anything not in the tagged commit is not in the release** — a fix
   merged to `master` after tagging is invisible until the tag moves.
3. **Dispatch:**
   ```bash
   gh workflow run github-release.yml -f release_tag=vX.Y.Z -f prerelease=true -f recreate_release=false
   ```
   `recreate_release=true` deletes an existing release *and its tag* before republishing.

Logs are only downloadable per-job while a run is in progress
(`gh api repos/<owner>/<repo>/actions/jobs/<id>/logs --allow-escape-sequences`); `gh run view --log`
refuses until the whole run finishes.

### Release signing is required, and the key must never change

`android/app/build.gradle.kts:63` picks the release signing config only when `android/key.properties`
exists and its `storeFile` resolves; otherwise it **silently falls back to the debug config**. CI
runners generate their own throwaway debug keystore, so before this was fixed every release was signed
with a *different* key — meaning no APK could update another in place. Users got a bare
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` and had to uninstall, losing all their data, on every upgrade.

The `Set up Android signing key` step now materialises the keystore from secrets and **fails the build**
if they are absent, so a debug-signed APK can never be published again. Four repo secrets are required:

| Secret | Contents |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the `.jks` file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

One-time setup:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 -w0 release.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body upload
gh secret set ANDROID_KEY_PASSWORD
```

**Back the `.jks` up somewhere permanent and never commit it** (`android/.gitignore` already blocks
`*.jks` and `key.properties`). Losing it means no future build can ever update an installed app again —
every user would have to uninstall and reinstall one final time. Changing the key has the same effect,
so treat it as permanent.

Note the first properly-signed release still cannot update a previously debug-signed install: that one
upgrade needs an uninstall. Every upgrade after it is in place.

**`storeFile` in `key.properties` must be an absolute path.** `build.gradle.kts` loads
`key.properties` with `rootProject.file()`, which resolves against `android/`, but resolves
`storeFile` with a bare `file()`, which resolves against the `:app` project dir — `android/app/`. A
relative `storeFile` therefore misses, `hasValidKeystore` stays false, and the build **silently
debug-signs**. 4.7.2 shipped that way: the keystore was valid and the signing step passed, and the APK
was still `CN=Android Debug`.

The lesson is that a valid keystore on disk proves nothing about what Gradle did with it. The
`Verify APKs are release-signed` step therefore runs `apksigner verify --print-certs` on the built
artifacts and fails on `Android Debug` — that is the only check that catches a silent fallback. When
touching signing, verify the shipped APK, not the config:

```bash
apksigner verify --print-certs boorusama-*.apk | grep 'certificate DN'
```

### Four places have to agree about targets

Reducing or narrowing what gets built breaks the things that consume it. This caused three separate
release failures; they fail *late*, in packaging or publishing, after a long build:

| Place | Decides |
|---|---|
| `.github/workflows/github-release.yml` matrix | which targets are built |
| `_extraFlutterArgsFor` in `command/release/github/build.dart` | which Android ABIs |
| `splitAbisFor` in `package/android.dart` | which split APKs get packaged |
| `--target` on the publish step | which receipts are *required* |

`splitAbisFor` now derives ABIs from `--target-platform`, so it follows the build automatically. The
publish `--target` does **not** — left unset it requires a receipt for all six targets and fails for
every one the matrix no longer builds.

### CI needs meson and nasm

`package:libavif` builds vendored dav1d from source. The `ubuntu-24.04`, `windows-2025` and
`macos-26-arm64` runner images ship cmake, ninja, rustup and cargo but **not meson or nasm**, so the
workflow installs those two before `Initialize workspace` — `init.sh` runs `gen.sh`, which also
triggers build hooks. This is the same toolchain described under Environment gotchas.

### Windows cannot be released

`windows-zip` fails at `FileTracker : error FTK1011` on a **265-character path against MAX_PATH's
260** — `libavif`'s CMake `TryCompile` scratch directory, from a repo root of only 24 chars.
`LongPathsEnabled` does not help; MSBuild's FileTracker is legacy MAX_PATH-bound. Same root cause as
the local Windows limitation.

### Build time: cache the Gradle home, don't trim ABIs

Measured across three release runs:

| ABIs | Gradle cache | `assembleProdRelease` |
|---|---|---|
| 3 | none | 762s |
| arm64 only | none | 784s |
| arm64 only | restored | **310s** |

ABI count is close to free — narrowing to arm64 saved nothing and cost 32-bit and emulator support.
The win is restoring `~/.gradle`, which is why the workflow caches it and `org.gradle.caching=true` is
set in `android/gradle.properties`. Note `android/gradle.properties` is listed explicitly in the cache
key because the `android/**/*.gradle*` glob does **not** match it — the pattern needs a literal
`.gradle` substring.

Do not trust intuition about where the time goes here; measure with
`gh api repos/<owner>/<repo>/actions/jobs/<id> --jq '.steps[]'`. `Install Android SDK packages` looks
expensive and takes 1 second; Gradle separately downloads NDK 27 and CMake 3.22.1 mid-build even
though the workflow pre-installs NDK 28.2.

### Google Play is not automated

`github-release.yml` only ever publishes a GitHub release — no fastlane, no `upload-google-play`, no
App Store. `./release.sh` (`release all`) *does* include a Play draft step, but it needs
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` and `GOOGLE_PLAY_PACKAGE_NAME`, neither of which is configured, so
it throws before touching the API. `rollbackDraft` is deliberately a no-op — a committed Play draft
cannot be un-consumed — so wire credentials up only if you mean it.

## Fork divergence

**Plus / premium is unconditional.** Upstream gates premium features behind a RevenueCat entitlement,
a `PREMIUM_MODE` dart-define, and a FOSS-build exclusion. In this fork
`lib/core/premiums/src/providers/premium_providers.dart` returns `true` from `hasPremiumProvider` and
`showPremiumFeatsProvider` unconditionally, and `kForcePremium` is a `const true` — so every install is
Plus and the upsell entry points that guard on `!kForcePremium` never render. The `PREMIUM_MODE`
define, `PremiumMode` enum and `premiumManagementURLProvider` are gone.

`BuildRequirements.requiredEnv` returns nothing as a result. Upstream required a RevenueCat API key
for prod `apk`/`aab`/`ipa` builds; with no entitlement to read, that key only blocked releases.

The RevenueCat SDK, `lib/foundation/vendors/revenuecat/`, and the purchase pages are still present but
no longer consulted for entitlement, so RevenueCat is not initialised at startup. Free-user limit
enforcement in `bulk_download_notifier.dart` / `saved_task_lock_notifier.dart` also remains — it is
unreachable in production now, but still covered by `premium_test.dart` via provider overrides. Removing
either is unfinished cleanup, not an invariant to preserve.

# Code style
- For Riverpod, always use Notifier/AsyncNotifier. Manually declare providers, no codegen.
- Prefer using factory methods/constructors for creating instances with complex setup, move all constructor to the top of the class.
- Always put business logic into state classes or a dedicated file.
- Use `equatable` for value equality when necessary.
- Always use pattern matching to make code more readable, only use traditional if/else when it improves readability.
- When parsing data from external sources, always assume data is nullable and handle null cases explicitly in the code.
- Avoid writing comments that over-explain the code. Write comments only when necessary to explain complex logic or decisions that are not immediately clear from the code itself.

# Testing
- Focus on observable behavior, not implementation details.
- Use mocks/stubs only for external dependencies, avoid mocking internal logic.
- Keep tests minimal and logically grouped. For repeated scenarios, use loops with explicit test case records—one `test()` call per iteration, testing the same behavior with different inputs.
- Don't write tests for obvious language behavior, one-line getters/setters, or redundant validation. Each test should protect meaningful logic or edge cases only.
- Test names must be clear sentences describing behavior and outcome. Do not include function or class names
- Assertions must be able to fail. A loop over a collection that can legitimately be empty asserts nothing — see the vacuous test noted above.

Example of parameterized tests:
```dart
final cases = [
  (input: 'valid@email.com', isValid: true),
  (input: 'invalid-email', isValid: false),
];
for (final c in cases) {
  test('returns ${c.isValid} for ${c.input}', () {
    expect(validate(c.input), c.isValid);
  });
}
```

# Workflow
- Run `dart format` after each file creation, prefer batch formatting.
- Always take a look and sample related code before writing new code to understand the existing patterns.
- Use the GitHub CLI (`gh`) for all GitHub-related tasks.
- When committing, use conventional commits format, e.g. `fix(posts): handle null tags` and only write commit summaries, no descriptions.
- Don't hardcode a value in a test that the implementation is designed to change. Assert the behaviour instead — a stale
  hardcoded host is what broke `image_url_resolver_test.dart`.
