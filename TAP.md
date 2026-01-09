# Homebrew Tap Setup

This repo can act as a Homebrew tap once you publish releases.

## 1) Update the cask
Edit `Casks/barista.rb` if your repo name differs from `mdsakalu/barista`.
- Set `version` to your release tag (for example, `0.1.0`).
- Set `sha256` to the SHA-256 of the release zip.

## 2) Publish a release
Tag and push:
```
git tag v0.1.0
git push origin v0.1.0
```
The release workflow will build `Barista-macos.zip`.

## 3) Compute the SHA-256
After the release asset is available:
```
shasum -a 256 Barista-macos.zip
```
Paste the hash into the cask.

## 4) Install via Homebrew
```
brew tap mdsakalu/barista
brew install --cask barista
```
