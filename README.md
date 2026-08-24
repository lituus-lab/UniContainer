<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniContainer

Media container framing for the `lituus-lab` `Uni*` family: the byte structure
a format is wrapped in, never the codec inside it.

## What's inside

- **ISO base media boxes** — `src/UniContainer/isobmff.nim`. Reading a tree of
  boxes and building one: MP4, MOV, HEIF, AVIF and an ALAC `.m4a` are the same
  structure, so one module walks all of them.

## The rule this library follows

A module belongs here if it can be written **without knowing what the
encapsulated bytes mean**. Finding the `mdia` box in an MP4 belongs here;
decoding the samples it points at does not.

That boundary is what keeps the library small and what makes it safe to depend
on from an image library, a video library and an audio library at once. A
codec, a pixel or a sample never appears in this repository.

## The Uni* family

UniContainer is layer 2 of `lituus-lab`'s `Uni*` family: a set of Nim
libraries, each with a C ABI and a Python binding, unified by a shared
dependency graph and documentation and testing conventions. See
[lituus-lab/.github](https://github.com/lituus-lab/.github) for the family's
purpose and philosophy.

It sits below `UniImage`, `UniMovie` and `UniAudio`, each of which had written
its own box walker before this existed. It depends on `NimContracts` alone; if
it ever needs arithmetic past the language's own operators, that comes from
`UniMath`, never from `std/math`.

## Provenance & development

The box layer is written from ISO/IEC 14496-12, the ISO base media file format
specification. It was first written inside `UniImage`, then written again in
`UniMovie` and a third time in `UniAudio` before being collected here — the
duplication is why the library exists.

The git history is short and linear although the design behind it is not: this
is an agent-assisted pass over code that already worked in three places, not a
container parser designed from a blank page at that speed.

## Build

```bash
nimble install -y
nimble testAll    # Nim debug + release + C ABI
nimble ctest      # C ABI tests
nimble docs       # nimib book + API reference -> pages/
```

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
