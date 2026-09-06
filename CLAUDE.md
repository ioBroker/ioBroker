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
node tasks --create         # build dist/install.sh, dist/fix.sh, dist/diag.sh, dist/node-update.sh
node tasks --deploy         # SFTP upload of dist/ (needs SFTP_HOST/PORT/USER/PASS env vars)
npm run deploy              # = create + deploy (what the release workflow runs)
npm run make-fix            # rewrites package.json name to @iobroker/fix, for the second npm publish
node test.js                # polls http://localhost:8081 for "<title>Admin</title>", 10x with 5 s waits
```

Useful env vars for `tasks.js`: `DEBUG=true` (verbose SFTP), `FAST_TEST=true` (connect but simulate the
upload instead of writing).

### Testing

There is **no unit test suite**. `mocha`/`chai` are devDependencies but no spec files exist — CI installs
them and never runs them. Verification is end-to-end only:

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

`test.yml` and `.cirrus.yml` contain a step that looks like it strips the LIB block, but it does not work —
the `sed` has no `-i` so it writes to stdout, and the `source` runs in a different step's shell than the
installer. **CI therefore tests master's library, not the branch's.** A PR touching only
`installer_library.sh` gets a green run that executed none of its changes. Do not trust CI for library work;
verify locally via `dist/`.

### Linting

`npx eslint` does **not** work. The repo has an ESLint 8-style `.eslintrc.json` and no `eslint.config.js`,
while `eslint` 9.x is the installed devDependency. Do not add lint steps expecting it to run.

## Architecture

### The bash build pipeline (`tasks.js`)

`installer.sh` and `fix_installation.sh` each contain a block delimited by
`# get and load the LIB => START` / `# get and load the LIB => END` that, at runtime, curls
`installer_library.sh` from GitHub and sources it. `node tasks --create` **replaces that block with the
literal contents of `installer_library.sh`**, producing self-contained `dist/install.sh` and `dist/fix.sh`.
`diag.sh` and `node-update.sh` have no library dependency and are copied verbatim.

So: shared bash helpers (platform detection, package install, user creation, Node.js install, permissions,
Redis) belong in `installer_library.sh`; each entry-point script keeps only its own flow.

### The deployment loop — why edits do not take effect locally

The installed `iob` wrapper does **not** call scripts from this repo. It downloads them from
`https://iobroker.net/` at invocation time (`FIXER_URL`, `DIAG_URL`, `NODE_UPDATER_URL` in
`installer_library.sh`). A change to `fix_installation.sh`, `diag.sh` or `node-update.sh` reaches users only
after a GitHub release triggers `deploy.yml` → `npm run deploy` → SFTP. Test locally by running the script
directly (`./fix_installation.sh`), not via `iob fix`.

### `iob` / `iobroker` wrapper

`installer.sh` generates an executable at `$IOB_DIR/iobroker`, symlinked into `/usr/bin` (or
`/usr/local/bin`) as both `iob` and `iobroker`. It:

- routes `start`/`stop`/`restart` (exactly one argument) to `systemctl`, `launchctl`, or init.d;
- intercepts `fix`, `diag`, `nodejs-update` and downloads + runs the remote script as `$IOB_USER` —
  forwarding only `"$2"`, so **only the first option reaches the script**: `iob diag --de --unmask` silently
  drops `--unmask`;
- refuses to run as root unless `--allow-root` is passed;
- passes everything else through to `node node_modules/iobroker.js-controller/iobroker.js`.

`$IOB_DIR` is `/opt/iobroker` on Linux, `/usr/local/iobroker` on FreeBSD — resolved by
`get_platform_params()` in the library. Never hardcode it.

### NPX package (`lib-npx/`)

`lib-npx/install.js` is the `bin` entry. On non-Windows it just shells out to
`curl -sL https://iobroker.net/{install,fix}.sh | bash -` — the Node code does nothing else there. On
Windows it runs the real work in sequence: `checkVersions.js` (Node/npm minimums, hardcoded there
separately from `versions.json`) → `installCopyFiles.js` (copies the package into `cwd()`, synthesizes an
`iobroker.inst` `package.json` pinning js-controller/admin/discovery/backitup to `stable`) →
`npm install --production` → `installSetup.js` (writes `iob.bat`/`iobroker.bat`, installs `dotenv` +
`windows-shortcuts` + git via winget, registers the Windows service, starts it).

`install/windows/` holds the Windows service payload: `install.js` (WinSW3-based service registration),
`serviceIoBroker.bat` (UAC self-elevation + net start/stop), `controller.js`, `shortcuts.js`,
`uninstall.js`. `installSetup.js` copies these into the install root.

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
  `nodeJsAccepted` (`get_accepted_node_majors`, downloaded once per run via `fetch_versions_json`), and
  `lib-npx/checkVersions.js` plus `lib-npx/installCopyFiles.js` read the bundled copy — which is why
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

- `test.yml` — installs on `ubuntu`/`MacOS X` Node 18/20/22/24, then permission and admin-reachable checks.
- `npx_install.yml` / `deploy_windows.yml` — `npm link` + `npx iobroker` on windows-latest; the `deploy` job
  publishes both `@iobroker/install` and `@iobroker/fix` on version tags.
- `deploy.yml` — on GitHub release, runs `npm run deploy` (SFTP to iobroker.net).
- `.cirrus.yml` — FreeBSD 14 install + fixer round-trip; the only FreeBSD coverage.
- Releases are cut with `@alcalzone/release-script` (`npm run release-patch|minor|major`).
