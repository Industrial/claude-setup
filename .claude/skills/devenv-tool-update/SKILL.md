---
name: devenv-tool-update
description: Update a tool defined in the nix/devenv-modules feature (e.g., moon).
version: 1
---

# Devenv Tool Update

## Overview
Update a tool (e.g., moon) defined in the nix/devenv-modules feature.

## Steps
1. Identify the feature Nix file (e.g., nix/devenv-modules/features/program-moon.nix).
2. Update the version and SHA256:
   - Fetch the new tarball URL.
   - Compute SHA256 with `nix-prefetch-url --type sha256 <URL>`.
   - Replace version and sha256 in the file.
3. Commit the change in the repo itself (the modules are vendored per repo,
   so there is no submodule to push first):
   - `git add nix/devenv-modules/features/<feature>.nix`
   - `git commit -m "feat: update <tool> to <version>"`
   - `git push`
4. Other repos vendor their own copy of the module: repeat the bump there if
   they should move too (see `release-engineering` for fleet-wide rollouts).
5. Verify the tool version through the devenv env:
   - `bin/with-devenv <tool> --version` where the repo ships `bin/with-devenv`
     (entering a devenv shell runs the repo's git hooks); `devenv shell -- <tool> --version` otherwise.

## Pitfalls
- Bumping one repo's vendored copy and assuming the others follow — each repo's `nix/devenv-modules/` is independent.
- Not updating the SHA256, leading to hash mismatch.
- Release-tarball tools (e.g. the assay-style `program-assay.nix` feature) pin an SRI hash, not a nix-prefetch SHA256: download the release tarball and use `nix hash file --sri --type sha256 <tarball>`. Wrapper-style variants of such features keep `releaseHash = null` deliberately — do not treat a null hash as stale.
- Fleet-wide rollout across repos (lockfiles, static pins, functional proof per consumer, commit policy) is governed by `devops/release-engineering` Part 3 — follow it instead of improvising a per-repo sweep.
- When devenv shell fails to start due to integration errors (e.g., dotenv integration requiring C-Nix devenv CLI), check `nix/devenv-modules/features/` for problematic feature flags and consider disabling them temporarily to isolate the issue.
- If MCP servers are unreachable, falling back to regular terminal commands (outside devenv shell) for inspection and basic fixes is acceptable when MCP tools persistently fail due to connectivity issues.

## Troubleshooting Common Devenv Issues
### Dotenv Integration Errors
If you see errors like:
```
error: The dotenv integration requires the C-Nix devenv CLI. It is not available through the flake integration or another standalone Nix evaluation.
```
This indicates the dotenv feature is enabled but the environment doesn't support it. Fix by disabling:
```nix
local.features.dotenv.enable = false;
```
in your `devenv.nix` file.

### MCP Server Connectivity Issues
When MCP servers (like lean-ctx) are persistently unreachable:
1. Verify the devenv environment is functional with `devenv shell -- true`
2. For file inspection/editing, use regular terminal commands (`cat`, `sed`, etc.) as a fallback
3. Restart the devenv environment: `devenv restart`
4. Check MCP server logs if available

### Specific Fix from Session
In the solana-yield-optimizer repository, the dotenv integration error was resolved by:
1. Setting `local.features.dotenv.enable = false;` in `devenv.nix`
2. Removing problematic definitively package references from `devenv.nix` that were causing evaluation errors

## Verification
Run the verification script (see references/verify-moon-version.sh) or manually check the version.