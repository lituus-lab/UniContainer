<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: No sibling dependency

- Status: Accepted
- Date: 2026-08-24
- Scope: UniContainer

## Decision

UniContainer depends on no other library of the family. Its only dependency,
`NimContracts`, is verification infra rather than domain code and compiles away
under `-d:release`, so a release build links nothing but the standard library.

That is what lets it sit under the libraries that need it. An image library, a
video library and an audio library all reach for the same container framing; a
framing layer that reached back for a codec, a pixel or a sample would close a
cycle. `vgraph.cfg` declares an empty `[engines]` list, and `nimble checkVGraph`
fails the build if a `requires` line ever names a sibling.

The rule that keeps it true: maths comes from `UniMath`, never `std/math`, on
the day this library first needs any. Until then it needs none — box framing is
integer arithmetic and bounds.

## Consequences

Everything here works on byte spans and integers only. Anything needing a
decoder, a colour model or a sample buffer belongs in the consumer, not here.

Inside `src/`, a format module imports nothing from another; only the C ABI
sits above them. `vgraph.cfg` records that order and `nimble checkVGraph`
rejects any import that climbs it.
