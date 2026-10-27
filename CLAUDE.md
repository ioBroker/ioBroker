# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **not** the ioBroker platform itself — it is the **installer/maintenance tooling** for it. The
ioBroker runtime lives in separate repos (`iobroker.js-controller`, `iobroker.admin`, …) and is pulled in
from npm at installation time.

One source tree feeds two delivery channels:

- **Linux/macOS/FreeBSD**: bash scripts, built into `dist/` and uploaded via SFTP to `https://iobroker.net/`.
  End users run `curl -sL https://iobroker.net/install.sh | bash -`.
- **Windows**: the `lib-npx/` Node.js package, published to npm as `@iobroker/install` (and, with a renamed
  `package.json`, as `@iobroker/fix`). End users run `npx @iobroker/install`.

## Commands

```bash
npm install                 # ~30 s
node tasks --create         # build dist/install.sh, dist/fix.sh, dist/diag.sh, dist/node-update.sh, dist/docker.sh
node tasks --deploy         # SFTP upload of dist/ (needs SFTP_HOST/PORT/USER/PASS env vars)
npm run deploy              # = create + deploy (what the release workflow runs)
npm run make-fix            # rewrites package.json name to @iobroker/fix, for the second npm publish
node test.js                # polls http://localhost:8081 for "<title>Admin</title>", 10x with 5 s waits
```

Useful env vars for `tasks.js`: `DEBUG=true` (verbose SFTP), `FAST_TEST=true` (connect but simulate the
upload instead of writing).

### Testing

There is **no unit test suite** and no test framework in `devDependencies` -- `mocha`/`chai` were
removed because no spec files ever existed. Verification is end-to-end only:

```bash
node tasks --create && bash ./installer.sh --silent   # 6-10 min; do not cancel, use 15+ min timeouts
bash .github/testFiles.sh                             # asserts ownership/permissions under $IOB_DIR
curl -s http://127.0.0.1:8081 | grep '<title>Admin</title>'
```

The service takes 1-2 minutes to come up after the installer finishes.

**`installer.sh` and `fix_installation.sh` download `installer_library.sh` from `master` at runtime**, so a
plain `bash ./installer.sh` does not exercise local library changes. To test them, build the self-contained
artifact first and run that:

```bash
node tasks --create && bash dist/install.sh --silent
```

CI does the same: `test.yml` builds `dist/` and runs `dist/install.sh`, so library changes on a branch are
what actually gets tested. (Until that was fixed, a `sed`-strip step that never worked meant CI ran
master's library, and a PR touching only `installer_library.sh` got a green run that executed none of its
changes.)

The same used to apply one level up, to `versions.json`, which the library downloads from `master` at
runtime: a PR editing it was exercised against master's values rather than its own, and contradicted the
matrix, which is built from the local file. `VERSIONS_URL` now falls back to the GitHub URL instead of
hardcoding it, and both `Install ioBroker` steps point at the checkout:

```yaml
env:
  VERSIONS_URL: file://${{ github.workspace }}/versions.json
```

So a change to `versions.json` is verified before it is merged. In `node-update.sh` the default is
applied *before* `readonly` — the other order silently discards a value from the environment.
The variable is for testing; end users have no reason to set it.

### Linting

There is no JavaScript linter. `eslint` and its ESLint 8-style `.eslintrc.json` were removed: the
config format is incompatible with ESLint 9, nothing ran it, and no `eslint.config.js` existed.
Re-adding it means a flat config plus a `lint` script, not just the dependency.

The shell scripts **are** linted. `shellcheck` runs in CI at severity `error`:

```bash
shellcheck -S error installer.sh installer_library.sh fix_installation.sh diag.sh node-update.sh docker.sh
```

Below `error` there are still plenty of findings (warning/info/style), so raising the severity means
fixing those first. `installer_library.sh` carries a `# shellcheck shell=bash` directive because it is
sourced and has no shebang.

## Architecture

### The bash build pipeline (`tasks.js`)

`installer.sh` and `fix_installation.sh` each contain a block delimited by
`# get and load the LIB => START` / `# get and load the LIB => END` that, at runtime, curls
`installer_library.sh` from GitHub and sources it. `node tasks --create` **replaces that block with the
literal contents of `installer_library.sh`**, producing self-contained `dist/install.sh` and `dist/fix.sh`.
`diag.sh`, `node-update.sh` and `docker.sh` have no library dependency and are copied verbatim.

So: shared bash helpers (platform detection, package install, user creation, Node.js install, permissions,
Redis) belong in `installer_library.sh`; each entry-point script keeps only its own flow.

### Interactive display (TUI)

The `tui_*` functions in the library give `installer.sh` and `fix_installation.sh` a full screen display:
logo, start menu (`tui_menu`), dialogs (`ask_yes_no`/`ask_text` fall back to the classic `read` prompts),
and a progress view. `tui_init` decides once at the start; every non-interactive case (no terminal,
`--silent`, `--classic`/`--no-tui`, `IOB_NO_TUI`, `CI`, `TERM=dumb`, < 70x24) keeps the classic output,
so **both paths must keep working** — branch on `$TUI`, never assume it. That is also why the library is
loaded at the very top of both scripts now: the early checks put their hints on the start screen via
`tui_note`.

- `tui_start_steps` redirects stdout/stderr into `~/iobroker-{install,fix}.log`; `print_step` drives the
  progress view. Anything a step echoes ends up in the log, not on screen.
- Keys come from `/dev/tty`, never stdin: under `curl ... | bash` stdin is the script itself.
- `tui_need_sudo` asks for the password before the steps and keeps the timestamp alive, otherwise sudo
  prompts would break into the screen.
- An EXIT trap restores the terminal; on failure it prints the log tail, then a box naming the step.
  Before an intentional `exit` from a dialog flow, call `tui_leave` so the message stays visible.
- bash 3.2 (macOS) and CP437 glyphs only: no `${x,,}`, namerefs, `mapfile` or `read -t 0.1`; no rounded
  corners, check marks or braille, which the Raspberry Pi console and PuTTY's default font lack.

### The deployment loop — why edits do not take effect locally

The installed `iob` wrapper does **not** call scripts from this repo. It downloads them from
`https://iobroker.net/` at invocation time (`FIXER_URL`, `DIAG_URL`, `NODE_UPDATER_URL`, `DOCKER_URL` in
`installer_library.sh`). A change to `fix_installation.sh`, `diag.sh`, `node-update.sh` or `docker.sh` reaches users only
after a GitHub release triggers `deploy.yml` → `npm run deploy` → SFTP. Test locally by running the script
directly (`./fix_installation.sh`), not via `iob fix`.

### `iob` / `iobroker` wrapper

`installer.sh` generates an executable at `$IOB_DIR/iobroker`, symlinked into `/usr/bin` (or
`/usr/local/bin`) as both `iob` and `iobroker`. It:

- routes `start`/`stop`/`restart` (exactly one argument) to `systemctl`, `launchctl`, or init.d;
- intercepts `fix`, `diag`, `nodejs-update`, `docker`, downloads the remote script as `$IOB_USER` and
  runs it with all remaining options (`"$@"`);
- refuses to run as root unless `--allow-root` is passed;
- passes everything else through to `node node_modules/iobroker.js-controller/iobroker.js`.

`$IOB_DIR` is `/opt/iobroker` on Linux **and FreeBSD**, `/usr/local/iobroker` on macOS — resolved by
`get_platform_params()` in the library. Never hardcode it.

### NPX package (`lib-npx/`)

`lib-npx/install.js` is the `bin` entry. On non-Windows it just shells out to
`curl -sL https://iobroker.net/{install,fix}.sh | bash -` — the Node code does nothing else there. On
Windows it runs the real work in sequence: `checkVersions.js` (rejects a Node.js major outside `nodeJsAccepted`,
read from the bundled `versions.json`) → `installCopyFiles.js` (copies the package into `cwd()`, synthesizes an
`iobroker.inst` `package.json` pinning js-controller/admin/discovery/backitup to `stable`) →
`npm install --production` → `installSetup.js` (writes `iob.bat`/`iobroker.bat`, installs `dotenv` +
`windows-shortcuts` + git via winget, registers the Windows service, starts it).

`install/windows/` holds the Windows service payload: `install.js` (WinSW3-based service registration),
`serviceIoBroker.bat` (UAC self-elevation + net start/stop), `controller.js`, `shortcuts.js`,
`uninstall.js`, `dockerStatus.js` (status-only `iob docker`, called from `iob.bat`). `installSetup.js` copies these into the install root.
Because of that, none of them may share its basename with a command: `cmd.exe` searches the current directory
with `PATHEXT` (which includes `.JS`) before `PATH`, so a `docker.js` there would shadow `docker.exe`.

**Install vs. fix is selected by package name**: `install.js` and `installSetup.js` branch on
`pack.name.includes('fix')`. `npm run make-fix` flips the name to `@iobroker/fix` before the second publish,
so the same code serves both packages. When editing these files, keep both paths working.

`installSetup.js` creates `./instDone` at the end — the Windows MSI installer polls for that file.

`jsonltool/` is a separate micro-package (`@iobroker/jsonltool`) that compresses
`objects.jsonl`/`states.jsonl`; the Windows fix path invokes it via `npx`.

## Mandatory conventions

### Version variable + changelog per script

Any change to a shell script requires bumping its version variable to today's date (`YYYY-MM-DD`) **and**
adding a changelog entry:

| Script                 | Version variable    | Changelog                            |
|------------------------|---------------------|--------------------------------------|
| `installer.sh`         | `INSTALLER_VERSION` | `CHANGELOG_INSTALLER_LINUX.md`       |
| `installer_library.sh` | `LIBRARY_VERSION`   | (covered by the installer changelog) |
| `fix_installation.sh`  | `FIXER_VERSION`     | `CHANGELOG_FIXER_LINUX.md`           |
| `diag.sh`              | `SKRIPTV`           | `CHANGELOG_DIAG_LINUX.md`            |
| `node-update.sh`       | `VERSION`           | `CHANGELOG_NODE_UPDATER.md`          |
| `docker.sh`            | `VERSION`           | `CHANGELOG_DOCKER.md`                |

Changes to `lib-npx/` or `install/windows/` go in `CHANGELOG.md` (semver-versioned, the npm package).

Changelog entries go at the **top** of the file, newest first, as `## YYYY-MM-DD` followed by bullets. Keep
flags and technical names verbatim (`--no-update` stays `--no-update`, untranslated). Prefer one bullet per PR.

`installer.sh` calls the library's `get_lib_version` at runtime only to prove the library loaded and returns
a non-empty string — it does **not** compare the two dates. Bumping `INSTALLER_VERSION` without touching
`LIBRARY_VERSION` is therefore safe.

### Other

- Adding or changing a user-facing flag means updating `PARAMETERS.md`.
- **`versions.json` is a public interface of this repo for the rest of the ioBroker ecosystem**, not an
  internal config, and it is fetched from the `master` branch at runtime — so an edit goes live for every
  consumer immediately, without a release. Do not treat it as a local knob. Known consumers:
  - this repo: `nodeJsRecommended` (`installer_library.sh`, `node-update.sh`) and `nodeJsAccepted`
    (`node-update.sh`, `lib-npx/checkVersions.js`, `lib-npx/installCopyFiles.js`);
  - `ioBroker.admin` (`src/main.ts`, `src-admin/src/components/Adapters/Utils.ts`) — reads all three to tell
    users which Node.js/npm version is recommended and whether theirs is still accepted;
  - `ioBroker.repobuilder` (`types.d.ts`) and `ioBroker.build` (`build/windows/ioBroker.iss`).

  Inside this repo the enforced limits follow the file too: `node-update.sh` validates against
  `nodeJsAccepted` (`get_accepted_node_majors` via `fetch_versions_json`, which despite its caching
  variables re-downloads on every call — both call sites use it inside a command substitution, so the
  assignment never reaches the parent shell), and `lib-npx/checkVersions.js` plus
  `lib-npx/installCopyFiles.js` read the bundled copy — which is why
  `versions.json` is listed in `package.json` `files`. Each reader keeps a hardcoded fallback list for the
  case that the file is unreachable or missing; when you change the accepted set, update those fallbacks
  too, otherwise an offline installation silently applies the old policy.

  All three enforce it the same way — a major outside `nodeJsAccepted` is fatal. `checkVersions.js`
  briefly warned instead, on the assumption that such a setup is unsupported but working; the CI matrix
  then showed that `iobroker.admin` declares `node >= 22`, so npm fails with `EBADENGINE` regardless and
  the warning only delayed a worse error message. `installer.sh` is the one exception: under `brew` it
  reports the mismatch and continues, because `install_nodejs` cannot install through brew and would
  abort an installation that has no way to fix itself.
- `diag.sh` is bilingual (English/German, `--de`); help text and many messages exist in both languages.
- `.gitmodules` declares 134 adapter submodules under `adapterlist/` that are not checked out and are
  unrelated to the installer. Do not initialize them.
- `dist/` and `package-lock.json` are gitignored; `dist/` is a build artifact — never commit it.

## CI

- `test.yml` — seven jobs: `shellcheck` (see Linting); `node-versions` reads `nodeJsAccepted` and feeds the matrix;
  `versions-url` checks that the runtime download of `versions.json` from `master` still works and parses,
  which the installing jobs no longer cover because they read the checkout instead; `test-install`
  installs on `ubuntu`/`macos` for every accepted major, then checks permissions, admin reachability and
  that the service really resolves the matrix version (systemd expands `which node` at start, so a plain
  `setup-node` would not have covered it); `test-nodejs-install` purges Node.js first, so the installer
  has to run `install_nodejs` and the NodeSource path is exercised at all; `test-tui` runs installer and
  fixer under `script` through `.github/tuiDrive.sh`, which presses Enter whenever the screen stops
  changing (keys typed ahead get swallowed by sudo-rs, and the util-linux `script` only ends at EOF on
  its stdin), and `test-tui-macos` the installer under the bash 3.2 of `/bin/bash`,
  the only jobs where the interactive display is on (every other job has no terminal or passes
  `--silent`/`--no-tui`).
- `npx_install.yml` / `deploy_windows.yml` — `npm link` + `npx iobroker` on windows-latest; the `deploy` job
  publishes both `@iobroker/install` and `@iobroker/fix` on version tags.
- `deploy.yml` — on GitHub release, runs `npm run deploy` (SFTP to iobroker.net).
- `freebsd.yml` — FreeBSD install + fixer round-trip in a `vmactions/freebsd-vm`, driven by
  `.github/testFreeBSD.sh`. Replaces `.cirrus.yml`, which had silently stopped producing check runs in
  2024, leaving the platform uncovered for two years. It blocks like any other job; the defects that
  surfaced when it came back — rc.d pidfile path, `detect_ip_address`, GNU-form `sed -i`,
  `--unsafe-perm` under npm 12, and the missing `iobroker setup first` — are all fixed.

## Releasing

The two delivery channels are released separately, with different tags and different workflows. Nothing is
bumped at release time: version variables and changelog entries are maintained in each PR (see
Mandatory conventions).

### Shell scripts → iobroker.net

A GitHub release on `master` whose tag and title are the date, `YYYY-MM-DD`; a second one on the same day
gets `-2` (`2026-09-30-2`):

```bash
gh release create 2026-10-27 --target master --title 2026-10-27 --notes "see changelogs"
```

`deploy.yml` then builds `dist/` and uploads it. It triggers on `release: created` only, which a release
saved as a draft and published later never fires, so publish directly. Marking a release as pre-release
does not stop the upload. Check the run and the live files:

```bash
gh run list --workflow=deploy.yml --limit 1
curl -sL https://iobroker.net/install.sh | grep INSTALLER_VERSION=
```

### npm package → `@iobroker/install` and `@iobroker/fix`

Needs entries under `## **WORK IN PROGRESS**` in `CHANGELOG.md` and a clean `master` in sync with origin:

```bash
npm run release -- minor --dry   # preview
npm run release-minor            # or release-patch / release-major
```

`@alcalzone/release-script` bumps `package.json`, turns the WIP header into the version, commits
`chore: release vX.Y.Z` and pushes the commit and the annotated tag `vX.Y.Z`. Only that tag pattern starts
the `deploy` job in `deploy_windows.yml` (a date tag never publishes to npm): it publishes
`@iobroker/install`, runs `make-fix`, publishes `@iobroker/fix` and creates the GitHub release
`Release vX.Y.Z`.

That GitHub release is created with `GITHUB_TOKEN`, and events caused by `GITHUB_TOKEN` start no further
workflows — so an npm release does **not** update iobroker.net. When shell scripts changed as well, cut a
date release too.

Confirm that the tag really got a run and that npm moved:

```bash
gh run list --workflow=deploy_windows.yml --branch vX.Y.Z
npm view @iobroker/install version
```

`v7.0.0` (2026-10-01) got no workflow run at all and was never published, which went unnoticed for weeks.

Publishing uses npm **trusted publishing** (OIDC), not a token: on npmjs.com both packages name
`ioBroker/ioBroker` + `deploy_windows.yml` as their trusted publisher, and the `deploy` job has
`id-token: write`. So do not rename that file or move the publish into another workflow, and keep that job
on a Node.js whose npm is >= 11.5.1 (Node.js 24; 22 bundles npm 10). The org secret `NPM_TOKEN` was a
classic token from 2020 and is no longer used. The trust relationship can be inspected with
`npx npm@latest trust list @iobroker/install` (needs a login and 2FA).
