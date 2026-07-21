---
status: "accepted"
contact: "Yuchen Wang"
date: "2026-07-20"
deciders: "Yuchen Wang"
---

# Use SPI-built GHCR images as the service baseline

## Context and Problem Statement

The SPI engineering system now builds public service images in GHCR, while the
stack still resolves its service baseline from OSDU community GitLab images.
This prevents the stack from validating Microsoft SPI changes until equivalent
community images are published.

## Decision Drivers

- The stack baseline must represent the source in the SPI service repositories.
- The default must follow each service's latest successful `main` build.
- Release and feature selectors must resolve to immutable image digests.
- Community images must remain available as a migration fallback.

## Considered Options

- Keep community GitLab images as the only baseline.
- Deploy mutable GHCR branch tags.
- Use GHCR tags as discovery selectors and pin their OCI digests.

## Decision Outcome

Chosen option: "Use GHCR tags as discovery selectors and pin their OCI
digests." The default baseline is each `yuchen-osdu` service package's
`main-snapshot`, representing its latest successful `main` build. The CLI
resolves that tag once and stores the immutable OCI digest in
`osdu-image-lock`.

`--image-tag` selects a coordinated release tag. `--image-ref` remains an
advanced option for multi-repository feature validation: it resolves the Git ref
in each service repository, maps it to the engineering system's
`sha-<12-char-commit>` tag, and pins the resulting digest. Community GitLab
resolution remains available through `--image-source community`.

### Consequences

- Good, because a clean `spi up` follows the latest successful `main` build for
  each service without depending on non-code commits at the repository HEAD.
- Good, because the mutable discovery tag never reaches Kubernetes; the image
  lock and Helm releases use immutable digests.
- Good, because coordinated release tags are reusable and feature refs remain
  available when a fleet-wide branch test is genuinely needed.
- Bad, because all selected service packages and tags must exist publicly before
  provisioning begins.
- Bad, because the schema-load Job remains a separately managed community image.
