<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniContainer

## Build & gates

```bash
nimble install -y
nimble testAll    # Nim debug + release + C ABI
nimble pyTest     # Cython + pytest (needs libUniContainer.so)
nimble example
nimble coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
nimble docs       # nimib book + API reference -> pages/ (needs nimib)
```

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: 3-OS Nim matrix + C ABI (linux/macOS) + Python.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. The C ABI never raises, and `{.raises: [].}` on every
  entry point proves it rather than leaving it to be remembered; input it
  cannot use is refused with a status, never guessed at.
- A postcondition is cheaper than the body: never re-derives the result by
  calling the function itself.
- C ABI: hand-written `include/UniContainer.h` kept in sync with
  `src/UniContainer/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`.
- C symbols carry the `ucnt_` prefix; lib `libUniContainer`; header `UniContainer.h`.
- `book/index.nim` is nimib: its code blocks are compiled and run at docs build,
  so prose that outlives its API breaks the build. `py/notebooks/quickstart.ipynb`
  plays the same role for Python and renders natively on GitHub.
- End covered sources with a blank line. Nim maps a trailing statement one line
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `nimble
  coverage` deliberately suppresses no error so the failure stays visible.

## Scope

Media container framing: the byte structure a format is wrapped in, never the
codec inside it. A module belongs here if it can be written without knowing
what the encapsulated bytes mean.

In scope: ISO base media boxes, and — as they are collected from the libraries
that duplicate them today — RIFF chunks, Ogg pages and packets, EBML and
Matroska, MPEG-TS packets.

Out of scope: every codec, and every domain model. No sample, no pixel, no
frame appears here.

- Maths comes from `UniMath`, never `std/math` — including the day this
  library first needs any.
- The bounds are the point. This is the layer that reads hostile input, so a
  size that lies must end a walk rather than raise, and nesting is capped.

Apache-2.0, DCO.
