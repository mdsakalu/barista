<div align="center">

# Barista

A menu bar app that wraps `/usr/bin/caffeinate` for quick keep-awake control

[<img src="https://img.shields.io/github/actions/workflow/status/mdsakalu/barista/ci.yml?label=build&logo=github" />](https://github.com/mdsakalu/barista/actions)
[<img src="https://img.shields.io/github/v/release/mdsakalu/barista?label=release&logo=github" />](https://github.com/mdsakalu/barista/releases/latest)
[<img src="https://img.shields.io/github/downloads/mdsakalu/barista/total?label=downloads&logo=github" />](https://github.com/mdsakalu/barista/releases)
[<img src="https://img.shields.io/badge/Homebrew-mdsakalu/tap/barista-orange?logo=homebrew" />](https://github.com/mdsakalu/homebrew-tap/blob/main/Casks/barista.rb)
[<img src="https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white" />](https://swift.org)
[<img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?logo=apple" />](https://www.apple.com/macos)
[<img src="https://img.shields.io/github/license/mdsakalu/barista?logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNCAxNiI%2BPHBhdGggZmlsbD0id2hpdGUiIGZpbGwtcnVsZT0iZXZlbm9kZCIgZD0iTTcgNGMtLjgzIDAtMS41LS42Ny0xLjUtMS41UzYuMTcgMSA3IDFzMS41LjY3IDEuNSAxLjVTNy44MyA0IDcgNHptNyA2YzAgMS4xMS0uODkgMi0yIDJoLTFjLTEuMTEgMC0yLS44OS0yLTJsMi00aC0xYy0uNTUgMC0xLS40NS0xLTFIOHY4Yy40MiAwIDEgLjQ1IDEgMWgxYy40MiAwIDEgLjQ1IDEgMUgzYzAtLjU1LjU4LTEgMS0xaDFjMC0uNTUuNTgtMSAxLTFoLjAzTDYgNUg1YzAgLjU1LS40NSAxLTEgMUgzbDIgNGMwIDEuMTEtLjg5IDItMiAySDJjLTEuMTEgMC0yLS44OS0yLTJsMi00SDFWNWgzYzAtLjU1LjQ1LTEgMS0xaDRjLjU1IDAgMSAuNDUgMSAxaDN2MWgtMWwyIDR6TTIuNSA3TDEgMTBoM0wyLjUgN3pNMTMgMTBsLTEuNS0zLTEuNSAzaDN6Ii8%2BPC9zdmc%2B" />](LICENSE)

<table>
  <tr>
    <td><a href="assets/screenshot-inactive.png"><img src="assets/screenshot-inactive.png" alt="Barista inactive" width="400" /></a></td>
    <td><a href="assets/screenshot-active.png"><img src="assets/screenshot-active.png" alt="Barista active" width="400" /></a></td>
  </tr>
  <tr>
    <td align="center"><sub>Inactive</sub></td>
    <td align="center"><sub>Active with countdown</sub></td>
  </tr>
</table>

</div>

## Features

- Toggle caffeinate assertions with plain-English hints
- Session modes: Manual, Duration (with countdown), Wait for PID, Command
- PID picker with running process names
- Settings persist via `@AppStorage`
- Live menu bar countdown while running a timed session

## Install

### Homebrew

```sh
brew tap mdsakalu/tap
brew install --cask barista
```

> **Tip:** To install without sudo, add `--appdir=~/Applications`

### Manual

Download `Barista-macos.zip` from [Releases](https://github.com/mdsakalu/barista/releases), unzip, and drag `Barista.app` to Applications.

## Build

```sh
swift build -c release
scripts/package_app.sh build
```

The packaged app will be at `build/Barista.app`.

## Development

```sh
open Package.swift
```

Select the `Barista` scheme and Run. Requires macOS 13+ and Xcode 15+.

## License

MIT License - see [LICENSE](LICENSE) for details.

Background image is [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) - see [ATTRIBUTION.md](ATTRIBUTION.md).
