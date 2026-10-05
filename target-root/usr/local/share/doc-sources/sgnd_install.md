# Installing SolidGroundUX

SolidGroundUX uses the standalone `sgnd-setup.sh` tool for installation, update,
rollback, reinstallation, removal, and recovery of the framework and separately
packaged SolidGroundUX products.

Setup does not depend on an existing working SolidGroundUX installation. It can
therefore be used on a clean machine or to recover an incomplete or damaged
installation.

## Download

Download the latest SolidGroundUX first-install package or individual product
release package from:

https://github.com/Testadura-Mark/SolidGroundUX/releases

Current releases use **one product ZIP per product**. A multi-product release run
does not create a combined product bundle. When SolidGroundUX itself is selected,
`prepare-release.sh` may additionally create a first-install transport ZIP.

Typical names are:

* `SolidGroundUX-<version>.<build>-release.zip`
* `SolidGroundUX-Management-Console-Modules-<version>.<build>-release.zip`
* `SolidGroundUX-SDK-<version>.<build>-release.zip`
* `SolidGroundUX-first-install-<version>.<build>.zip`

Each product release ZIP contains:

* `release-package.info`
* `<Product>-<version>.<build>.tar.gz`
* `<Product>-<version>.<build>.tar.gz.sha256`
* `<Product>-<version>.<build>.manifest`
* `<Product>-<version>.<build>.manifest.sha256`
* `<Product>-<version>.<build>.removed`
* `<Product>-<version>.<build>.removed.sha256`

The first-install transport ZIP is not itself a product release. It contains:

* `sgnd-setup.sh`
* the selected product release ZIPs

The first-install package replaces the former bundled-release concept. The product
ZIPs inside it retain their own project, product, Version, Build, and release
identity.

## First-time Installation

A first installation can be started from any temporary directory.

For example:

```bash
cd /tmp
unzip SolidGroundUX-first-install-<version>.<build>.zip
chmod +x sgnd-setup.sh
sudo ./sgnd-setup.sh
```

With no action specified, Setup recognizes product release ZIPs beside itself as a
first-install set. It then:

1. Creates the required Setup and release-state directories.
2. Installs a standalone Setup copy for recovery.
3. Validates the adjacent product ZIP metadata.
4. Admits the selected product ZIPs into managed release state.
5. Lets the operator select one, several, or all available products.
6. Extracts and validates each selected product release.
7. Installs each product through the normal release engine.
8. Archives the successfully installed original product ZIPs.
9. Verifies the canonical Setup copy and public wrappers.
10. Offers Setup, the Management Console, or return to the shell.

For a non-interactive first installation, `--auto` selects all adjacent product
packages and suppresses interactive selection:

```bash
sudo ./sgnd-setup.sh --auto
```

After installation, the canonical recovery copy is:

```text
/var/lib/solidgroundux/sgnd-setup.sh
```

The normal public command is:

```bash
sudo sgnd-setup
```


## Release Storage

SolidGroundUX deliberately uses filesystem state for the release lifecycle.

### Pending product packages

Downloaded, admitted, or otherwise locally available product release ZIPs are stored
below:

```text
/var/lib/solidgroundux/releases/
```

These ZIPs are available for installation.

### Installed original product packages

After successful installation, the original distributable product ZIP is retained
below:

```text
/var/lib/solidgroundux/releases/archive/<project>/
```

This store preserves the original package independently of the extracted release
history.

### Extracted release history

The release engine also keeps extracted archive/manifest history for rollback,
reinstallation, and removal.

SolidGroundUX itself uses:

```text
/var/lib/solidgroundux/archive/
```

Additional projects use project-specific state below:

```text
/var/lib/solidgroundux/projects/<project>/
```

including their release and archive state as required by the lifecycle engine.

The active release is derived from this filesystem release history; no separate
opaque current-version database is required.

## Interactive Setup

After installation, start Setup with:

```bash
sudo sgnd-setup
```

Setup discovers known products and locally available product packages from their
metadata. Product identity, Version, Build, release line, and repository settings
are derived from package/project state rather than re-entered as release metadata.

The interactive interface provides lifecycle actions including checking for online
releases, downloading, installing local packages, updating, rollback/reinstallation,
and removal.

## Checking for Updates

To check the configured GitHub release source without changing the installed
product:

```bash
sudo sgnd-setup --check
```

Setup compares the latest published release with locally downloaded and installed
release state for the selected project.

## Downloading Without Installing

To download and validate the latest product package without installing it:

```bash
sudo sgnd-setup --download
```

Downloads are staged and validated before they are admitted into:

```text
/var/lib/solidgroundux/releases/
```

This prevents incomplete or malformed downloads from contaminating managed release
state.

## Updating

To obtain and install the latest GitHub product package:

```bash
sudo sgnd-setup --update
```

Interactive operation can select the applicable project/product. For unattended
operation, select the project explicitly:

```bash
sudo sgnd-setup --update --auto --project solidgroundux
```

An update installs the complete incoming release and applies its `.removed`
manifest. Releases do not depend on incremental binary patching.

## Installing a Local Release

To install the newest locally available product package:

```bash
sudo sgnd-setup --install
```

To request a specific release identity:

```bash
sudo sgnd-setup --install --release <release>
```

Local package discovery includes product ZIPs beside the running Setup script and
those already admitted beneath the managed `releases/` directory.

## Rollback and Reinstallation

To roll back to the previous archived release:

```bash
sudo sgnd-setup --rollback
```

To select a specific archived release:

```bash
sudo sgnd-setup --rollback --release <release>
```

Rollback makes the installed filesystem match the selected archived release and
keeps the release-state model consistent for later reinstall or update operations.

## Removing SolidGroundUX

To remove the active selected project installation:

```bash
sudo sgnd-setup --remove
```

Setup uses the installed release manifests and ownership information to remove
managed product content while preserving release packages needed for later
reinstallation where the lifecycle contract requires it.

## Dry Run

To preview filesystem changes without applying them:

```bash
sudo sgnd-setup --update --dryrun
```

The same option can be used with install, rollback, removal, and other supported
lifecycle actions.

## Alternate Release Source

The default update source is the configured GitHub release.

A specific product release ZIP may also be used:

```bash
sudo sgnd-setup --update --source /tmp/SolidGroundUX-<version>.<build>-release.zip
```

Or a direct URL:

```bash
sudo sgnd-setup --update --source https://example.org/releases/SolidGroundUX-<version>.<build>-release.zip
```

`--source` is transient for the selected action and does not replace the persistent
release-source configuration.

## Testing With Alternate Roots

Setup supports alternate target and state roots, which is useful for testing
installation behavior without modifying the live system:

```bash
sudo ./sgnd-setup.sh \
    --install \
    --target-root /mnt/testroot \
    --state-root /mnt/testroot/var/lib/solidgroundux
```

## Development Deployment

Formal product releases are created with `prepare-release.sh` and installed with
`sgnd-setup.sh`.

During development, `deploy-workspace.sh` provides a faster path for deploying
selected workspace files directly to a local or remote test machine.

`deploy-workspace.sh` does not create an installed release record and does not
participate in archive-based rollback.

See the Deployment documentation for details.

## Documentation

Framework documentation is available online:

https://testadura-consultancy.github.io/SolidGroundUX/
