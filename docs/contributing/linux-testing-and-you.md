# Test Linux builds

This is an unofficial Linux port of GitHub Desktop. The port builds on
[Shiftkey's work](../../CREDITS.md). Download this fork's Linux packages from
[its releases](https://github.com/fluffy-furry/desktop/releases) after CI publishes
them. Shiftkey's package feeds and community packages are separate.

The [Linux build guide](linux-builds.md) lists the supported package formats,
architectures, local Docker/`act` commands and CI checks. Test the package on
your distribution and report the application version, CPU architecture,
distribution version, desktop environment, install method, and reproduction
steps in [this fork's issue tracker](https://github.com/fluffy-furry/desktop/issues).

Submit Linux fixes as pull requests to the `linux` branch. Run local CI before
pushing; GitHub-hosted CI repeats the native architecture and distribution
checks before publishing a release.
