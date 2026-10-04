# Installing SolidGroundUX

SolidGroundUX uses a standalone `release-manager.sh` for installation, update,
rollback, reinstallation, and removal of the framework and separately packaged
SolidGroundUX products.

The release manager does not depend on an existing SolidGroundUX installation.
It can therefore be used on a clean machine or to recover an incomplete or
damaged installation.

## Download

Download the latest SolidGroundUX release bundle from:

https://github.com/Testadura-Mark/SolidGroundUX/releases

The framework release can be provided as an individual package or as a bundle
containing companion SolidGroundUX products. `prepare-release.sh` may produce both
forms in the same release run. Each product retains its own release-metadata policy,
while a combined bundle inherits Version and Build from its primary product.

Typical package names are:

* `SolidGroundUX-<version>.<build>-release.zip`
* `SolidGroundUX-bundled-<version>.<build>-release.zip`
* `<Product-Name>-<version>.<build>-release.zip`

Generated filenames use filesystem-safe product names (for example, spaces are
replaced with hyphens); the human-readable product name remains in package metadata.

The ZIP contains:

* `release-manager.sh`
* `SolidGroundUX-<version>.tar.gz`
* `SolidGroundUX-<version>.tar.gz.sha256`
* `SolidGroundUX-<version>.manifest`
* `SolidGroundUX-<version>.manifest.sha256`
* `SolidGroundUX-<version>.removed`
* `SolidGroundUX-<version>.removed.sha256`
* `SHA256SUMS`

## First-time Installation

A first installation can be started from any temporary directory.

For example:

```bash
cd /tmp
unzip SolidGroundUX-<version>-release.zip
chmod +x release-manager.sh
sudo ./release-manager.sh --install
```

The release manager then:

1. Creates the required release-management directories.
2. Detects the release files beside itself.
3. Verifies checksums and release paths.
4. Moves the validated release set into `/var/lib/solidgroundux/releases`.
5. Installs the release into the target filesystem.
6. Moves the installed release set into the versioned archive.
7. Copies itself to:

```text
/var/lib/solidgroundux/release-manager.sh
```

8. Removes only the known temporary bootstrap files after a successful install.

After the first installation, the temporary copy of the release manager is no
longer required.

## Release Storage

SolidGroundUX deliberately uses the filesystem itself as release state.

### Available releases

Downloaded/admitted or rolled-back releases are stored below:

```text
/var/lib/solidgroundux/releases
```

These releases are available for installation.

### Installed release history

Installed releases are stored below:

```text
/var/lib/solidgroundux/archive/<release>
```

For example:

```text
/var/lib/solidgroundux/archive/SolidGroundUX-1.8.2622102
```

The highest versioned directory in `archive/` represents the currently installed
release.

No separate current-version database is required.

## Interactive Release Manager

After installation, start the release manager with:

```bash
sudo /var/lib/solidgroundux/release-manager.sh
```

The interactive Release Manager discovers available bundled and individual
packages from their package metadata. Bundle identity follows the primary product,
while contained products retain their own product metadata. Selecting a package establishes its project,
product, Version, Build, managed release/archive directories, and GitHub repository.
Version and Build are therefore not entered manually in the Release Manager.

The interactive menu can:

* Select another available package.
* Check the selected project's GitHub repository for the latest release.
* Download the latest release.
* Update to the latest GitHub release.
* Install the newest locally available release.
* Reinstall or roll back to an archived release.
* Remove SolidGroundUX.

Archived releases are shown in a submenu with the current release marked
explicitly.

## Checking for Updates

To check GitHub without changing the local machine:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --check
```

The release manager checks the GitHub repository configured for the selected
project/package and compares its latest published release with releases already
present in that project's `archive/` or `releases/` state.

If the latest release is already installed or downloaded, it is not downloaded
again.

## Downloading Without Installing

To download and validate the latest release without installing it:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --download
```

Downloads are first staged in a temporary directory.

The ZIP is extracted and validated before its release files are admitted into:

```text
/var/lib/solidgroundux/releases
```

This prevents incomplete or malformed downloads from contaminating the local
release repository.

## Updating

To check GitHub, download the latest release when required, and install it:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --update
```

An update installs the complete new release archive and applies the incoming
`.removed` manifest.

The `.removed` manifest identifies paths that belonged to the previous release
but are no longer part of the new release.

Because each SolidGroundUX release contains a complete framework tree, updates
do not depend on incremental binary patching.

For unattended operation:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --update --auto
```

## Installing a Local Release

To install the newest release already available under `releases/`:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --install
```

To install a specific release:

```bash
sudo /var/lib/solidgroundux/release-manager.sh     --install     --release 1.8.2622102
```

## Rollback and Reinstallation

To roll back to the previous archived release:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --rollback
```

To install a specific archived release:

```bash
sudo /var/lib/solidgroundux/release-manager.sh     --rollback     --release 1.8.2621804
```

Rollback makes the active filesystem match the selected archived release.

Files that exist only in the newer release are removed, and the selected
complete release archive is installed again.

Newer archived versions are returned to `releases/`, so the highest remaining
archive directory continues to represent the active version.

## Removing SolidGroundUX

To remove the active SolidGroundUX installation:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --remove
```

The release manager removes framework-owned paths using the current release
manifest.

Archived release sets are returned to `releases/` rather than discarded, so
they remain available for later reinstallation.

## Dry Run

To preview filesystem changes without applying them:

```bash
sudo /var/lib/solidgroundux/release-manager.sh --update --dryrun
```

The same option can be used with install, rollback, and removal operations.

## Alternate Release Source

The default update source is the latest published GitHub release.

A specific ZIP file may also be used:

```bash
sudo /var/lib/solidgroundux/release-manager.sh     --update     --source /tmp/SolidGroundUX-release.zip
```

Or a direct URL:

```bash
sudo /var/lib/solidgroundux/release-manager.sh     --update     --source https://example.org/releases/SolidGroundUX-release.zip
```

## Testing With Alternate Roots

The release manager supports alternate target and state roots, which is useful
for testing installation behavior without modifying the live system:

```bash
sudo ./release-manager.sh     --install     --target-root /mnt/testroot     --state-root /mnt/testroot/var/lib/solidgroundux
```

## Development Deployment

Formal releases are created with `prepare-release.sh` and installed with
`release-manager.sh`.

During development, `deploy-workspace.sh` provides a faster path for deploying
selected workspace files directly to a local or remote test machine.

`deploy-workspace.sh` does not create an installed release record and does not
participate in archive-based rollback.

See the Deployment documentation for details.

## Documentation

Framework documentation is available online:

https://testadura-consultancy.github.io/SolidGroundUX/
