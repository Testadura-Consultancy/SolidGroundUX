# ==================================================================================
# SolidGroundUX - Deployment Boundary
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627700
#   Checksum    : 45bd67ba89586ee8bba11155e8f9acf91ff08a7106f2d1ea0c86dc5923188202
#   Source      : sux-deployment_preface.sh
#   Type        : documentation
#   Group       : Deployment
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - Deployment ----------------------------------------------------------------------
#
# > Deployment sits on the boundary between the installed SolidGroundUX Framework and
# > the SDK that creates and moves release artifacts. The Framework owns the runtime
# > entry point that can install, update, roll back, repair, or remove products. The SDK
# > owns release preparation, development deployment, and the tooling used to produce
# > those product packages.
#
# > Keeping that boundary explicit avoids two different deployment stories appearing in
# > the documentation. This Framework section therefore describes only the installed
# > lifecycle boundary. The detailed release-development workflow belongs to the
# > SolidGroundUX SDK documentation.
#
# -- Setup --------------------------------------------------------------------------
#
# > `sgnd-setup.sh` is the canonical setup and lifecycle entry point for current
# > SolidGroundUX installations. It is deliberately self-sufficient: it can bootstrap a
# > clean machine before the Framework exists and can continue to operate when an
# > installed Framework is incomplete or damaged.
#
# > Setup works with product release ZIPs. Each package identifies its owning product and
# > contains the complete release payload, manifest, removal manifest, and integrity
# > sidecars required to install or reconcile that product.
#
# > A first-install bundle places `sgnd-setup.sh` next to the release ZIPs required for a
# > clean installation. After the first install, the installed `sgnd-setup` entry point
# > remains available for normal lifecycle operations.
#
#
# -- SDK Ownership ------------------------------------------------------------------
#
# > The SDK owns the development side of deployment:
# >
# >     prepare-release.sh
# >         Builds and validates distributable product release packages.
# >
# >     deploy-workspace.sh
# >         Transfers a development workspace into a target root for testing. It is not
# >         an installer and does not define installed-release lifecycle state.
# >
# >     Documentation Generator
# >         Regenerates the documentation shipped or published with a release.
#
# > The SDK Deployment section documents those tools together with the Setup workflow
# > they feed. Framework reference pages document the installed scripts and APIs
# > themselves.
#
# -- Mental Model -------------------------------------------------------------------
#
# > The intended flow is:
# >
# >     source workspace
# >         -> SDK development/test deployment
# >         -> SDK release preparation
# >         -> product release ZIPs
# >         -> sgnd-setup
# >         -> installed products
#
# > Development deployment and installed-product lifecycle deliberately remain separate.
# > A workspace can be copied repeatedly during development without creating release
# > history, while Setup works only with release packages and their lifecycle metadata.
#
# -- Where to Continue --------------------------------------------------------------
#
# > For release creation, first installation, command-line Setup examples, GitHub
# > acquisition, workspace deployment, rollback, and recovery, continue with the
# > SolidGroundUX SDK Deployment documentation.
