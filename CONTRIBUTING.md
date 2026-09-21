# Contributing to File Picker

:+1: :tada: First off, thanks for taking the time to contribute to _File Picker_! :tada: :+1:

The following is a first version of guidelines for contributing to _File Picker_. Feel free to propose changes to this document in a pull request.

## Issue a Pull Request

* **Dart code only:** before creating a pull request, please **write unit tests** if you added changes to Dart code under `lib/` (Java/Objective-C/Swift/Kotlin/C++ native code is currently not tested). Please ensure that the **code analysis** via `dart analyze` throws no errors. Please also make sure that your **code is formatted correctly** via `dart format`. You can take a look into our CI pipeline at `.github/workflows/main.yml` for further details. The CI pipeline is triggered automatically when you create a pull request on GitHub. All steps in our pipeline must run without errors.

* **This repository is a federated Melos workspace:** the `file_picker` package under `packages/file_picker` only contains the platform-agnostic Dart API. Each platform implementation lives in its own package with its own `pubspec.yaml` and `CHANGELOG.md` (`packages/file_picker_platform_interface`, `packages/file_picker_android`, `packages/file_picker_darwin`, `packages/file_picker_linux`, `packages/file_picker_windows`, `packages/file_picker_web`). Only bump the version and update the changelog of the package(s) you actually changed, not every package in the workspace.

* Please **update the package version** in the `pubspec.yaml` of every package you changed. We use [semantic versioning (SemVer)](https://semver.org/). TL;DR: increase the patch version when your pull request contains a bug fix. Increase the minor version when a new feature is added. Breaking changes to a package's public API should result in an increase in the major version. If a package's currently listed version is already published on pub.dev, bump to the next unpublished version rather than editing the published one.

* Please **update the changelog** in the `CHANGELOG.md` of every package you changed. Add a new level two heading with the updated package version to the top of the document, e.g. `## major.minor.patch`, and describe your changes below it. If your pull request is associated with an issue, please reference it. Each package's changelog is shown on its own pub.dev page (e.g. <https://pub.dev/packages/file_picker/changelog>, <https://pub.dev/packages/file_picker_darwin/changelog>).

* If your pull request **removes or renames** a public class, method, or parameter, the changelog entry must say what to use instead, not just what was removed (e.g. "Removed `FilePickerResult`. `pickFiles()` now returns `Future<List<PlatformFile>>` directly" rather than just "Removed `FilePickerResult`."). If there is no direct replacement, say so explicitly.

## Releasing

There is no single version number for the whole repository, each package releases independently whenever its own version is bumped.

pub.dev's Automated Publishing only accepts a publish request from a GitHub Actions run that was triggered by pushing a git tag matching that package's configured tag pattern, it rejects a run triggered by manually clicking "Run workflow" (`workflow_dispatch`), with no way to opt out. So releasing is a two-step process, both handled by the "Publish to pub.dev" workflow (`.github/workflows/publish.yml`):

1. **Prepare**: run the workflow via "Run workflow" with `dry_run` left at its default (`true`) first, and check the job log, it lists exactly which packages and versions would be released. Once you're confident, run it again with `dry_run` set to `false`. This does not talk to pub.dev, it only creates and pushes a git tag for each package with an unpublished local version, named `<package_name>-v<version>` (e.g. `file_picker_darwin-v1.0.2`), one push at a time (GitHub does not deliver push events for tags when more than three are pushed together, so batching them would silently drop some releases).
2. **Publish**: each pushed tag triggers its own separate run of the same workflow, this time via the `push` event, which is what pub.dev actually requires. That run publishes only the one package named in its tag.

A release touching several packages at once produces several tags and several parallel, independent publish runs, one per package, not one run publishing everything.

The `prepare` job needs the `RELEASE_PAT` repository secret (a personal access token with `repo`/"Contents: Read and write" access to this repository) to push tags with. GitHub does not trigger other workflows off a push made with the default `GITHUB_TOKEN`, so without it the pushed tags would never fire step 2 above.

To check whether a given change made it into a published version of a package, find the tag for that version and see whether your commit is an ancestor of it (`git merge-base --is-ancestor <commit> <package_name>-v<version>`).

## Security

Found something exploitable? Do not open an issue or a pull request for it. Report it privately, see [`SECURITY.md`](SECURITY.md).

## Contributors

Everyone who has contributed code is listed in [`CONTRIBUTORS.md`](CONTRIBUTORS.md). It is generated from the git history, so opening a pull request is all it takes to end up there.
