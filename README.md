# bluettiB

Personal Home Assistant fork for Bluetti devices, based on the 0.1.6 codebase with a custom AC200MAX control fix. Display name in Home Assistant: BluettiB BT.

## Purpose

This repo is a personal build for Home Assistant custom integration use.
It starts from the working 0.1.6 implementation and keeps the AC200MAX control behavior targeted for reliable write-then-verify operation.

## Version

Version is managed in a single source file: `VERSION`.
Run `python3 scripts/sync_version.py` after changing it to keep the manifest and README in sync.
For a full release, use `./scripts/release.sh X.Y.Z` (or add `--dry-run` to preview the steps).

Current custom release: 0.1.8

Based on the original upstream project by Patrick762: `hassio-bluetti-bt` version `0.1.6`

## Release rule

Important: do not leave the repo ahead of its published release tag.

Before shipping any fix or new behavior:
- bump the number in `VERSION`
- sync the manifest and README
- cut and push a new git tag like `v0.1.9`
- install HACS from the tag/release, not from a moving branch head

The branch may be used for development, but the installed custom integration should always point to a tagged release. This avoids the HACS “commit SHA will be downloaded” drift that happens when a branch is newer than the published release.

## Notes

- Original author: `Patrick762`
- Original project: `hassio-bluetti-bt`
- Version used as the starting point: `0.1.6`
- This fork is a personal/custom build for AC200MAX reliability and control verification
- This project is intended for personal deployment and custom maintenance.

## Disclaimer
This integration is provided without any warranty or support by Bluetti (unfortunately). I do not take responsibility for any problems it may cause in all cases. Use it at your own risk.

## Installation
To install this integration, you first need [HACS](https://hacs.xyz/) installed.
Add this repository as a custom integration in HACS, then install it from the repository list.

For a personal/private repo, use the repository URL directly in HACS rather than the standard public badge flow.

### Supported devices:

- AC2A
- AC60 (tested with one external battery B80)
- AC60P (untested)
- AC70 (basic data)
- AC70P (untested)
- AC180 (basic data)
- AC180P (tested)
- AC200L (untested)
- AC200M
- AC200PL (untested)
- AC300 (tested)
- AC500 (tested)
- EB3A
- EP500
- EP500P
- EP600 (tested)
- EP760 
- EP800 (basic data)

### Available controls:
If enabled in the Integration options (you need to reload the integration if you change this option):
AC and DC outputs
