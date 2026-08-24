<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0003: The C ABI and the Python binding

- Status: Accepted
- Date: 2026-08-24
- Scope: UniContainer

## Decision

The Nim library is the source of truth. A hand-written C ABI
(`src/UniContainer/c_api.nim`) and a hand-written header
(`include/UniContainer.h`) expose it to non-Nim callers, built
`--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`. C symbols are
prefixed `ucnt_`; the library is `libUniContainer`.

`tests/c` compiles the header against the built library on every CI run, so the
two cannot drift apart silently.

The C ABI never raises, and `{.raises: [].}` on every entry point is what
proves it rather than a convention that has to be remembered: unwinding a Nim
exception across the boundary would be undefined behaviour.

The Python binding is a Cython extension over that same C ABI, shipped as a
self-contained wheel with the native library inside the package. It is thin by
construction: what the C ABI cannot reach, the binding cannot reach either.

## What crosses the boundary

A box tree is a structure inside bytes the caller already holds, so the ABI
hands back **spans**, not copies: `ucnt_find_box` writes two offsets into the
caller's own buffer. Nothing is allocated, so nothing has to be freed, and the
question of who owns what does not arise.

## What stays Nim-side

- **`boxes`** — an iterator, and C has no iterator protocol to bind to.
  `ucnt_find_box` answers the question a caller walking boxes is usually
  asking, and answers it without crossing the boundary once per box.
- **`box`, `fullBox`, `putBE`** — building a tree, which a C caller does with
  its own buffer and four bytes of length. Exposing them would move bytes
  across the boundary twice for no gain.
- **`readBoxHeader`, `beU32`, `beU64`** — the pieces the walk is built from.
  A consumer wants a box found, not a header decoded.
