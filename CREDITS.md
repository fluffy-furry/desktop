# Credits and Linux provenance

[GitHub Desktop and its contributors](https://github.com/desktop/desktop) provide the application and much of its cross-platform foundation. The original [MIT license](LICENSE) is retained.

[Brendan Forster (Shiftkey)](https://github.com/shiftkey) and the [shiftkey/desktop contributors](https://github.com/shiftkey/desktop/graphs/contributors) established and maintained the Linux distribution, packaging, desktop integration and Linux-specific adaptations that this fork carries forward. Making desktop/desktop the direct upstream does not remove that work or its credit.

The README below its fork notice is copied byte-for-byte from [Shiftkey's README at `cab1d2ca`](https://github.com/shiftkey/desktop/blob/cab1d2ca900ff21deb46539bd9501572d77da875/README.md). Its package feeds and release links refer to Shiftkey/community builds.

The [Docker packaging helper](.github/actions/package-linux) adapts Shiftkey's [amd64](https://github.com/shiftkey/desktop-ubuntu-amd64-packaging/tree/ea7b7a6a940a6b907b160b946439c5c7a516f9f1) and [ARM64](https://github.com/shiftkey/desktop-ubuntu-arm64-packaging/tree/9be09c4b945873e6509baaf690d457aae08cf901) packaging actions. Their [GPL-3.0 license](.github/actions/package-linux/LICENSE) is preserved for these helper files; the application retains its MIT license.

The Arch package follows the [github-desktop-bin AUR package](https://aur.archlinux.org/packages/github-desktop-bin), submitted by immackay and maintained by fanninpm for Shiftkey's releases. Our CI builds its own package from this fork's Linux binaries.

[mon-jai](https://github.com/mon-jai) authored the [native/custom title-bar contribution](https://github.com/shiftkey/desktop/commit/738b4465eb), with Brendan Forster credited as co-author in the original commit.

[Rodrigo Geller da Silva (digaovaa)](https://github.com/digaovaa) contributed the newer [Linux 3.5.12 port](https://github.com/shiftkey/desktop/pull/1312), which helped bridge Linux changes to the current official baseline. This integration preserves contributor links and source references; it does not claim authorship of their original work.

This fork adapts those contributions to official 3.6.5 and tests Linux packaging on current distributions. See [Linux build and test instructions](docs/contributing/linux-builds.md).
