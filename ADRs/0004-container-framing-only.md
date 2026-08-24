<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: Framing only, never the codec

- Status: Accepted
- Date: 2026-08-24
- Scope: UniContainer

## Decision

A module belongs in this library if it can be written **without knowing what
the encapsulated bytes mean**.

Finding the `mdia` box inside an MP4 is in scope. Decoding the samples it
points at is not. Reading a RIFF chunk header is in scope; interpreting a `fmt`
chunk as an audio format is not.

In scope, as they are collected from the libraries that duplicate them today:
ISO base media boxes, RIFF chunks, Ogg pages and packets, EBML and Matroska,
MPEG-TS packets.

Out of scope: every codec, and every domain model — no sample, no pixel, no
frame appears here.

## Why the boundary is written down

Without it this becomes the place to put anything two libraries happen to
share, and a library that is "the common parts" has no scope at all. The test
above is mechanical enough to settle an argument: if the module needs to know
what the bytes mean, it belongs to the consumer.

## Implementation

The bounds are the substance, not a detail. This is the layer that reads
hostile input, so:

- a box claiming to be smaller than its own header, or to run past the parent
  it sits in, ends a walk rather than raising — trailing garbage after a valid
  box should not cost a caller what it already parsed;
- nesting is capped by `MaxBoxDepth`, because a file whose sizes describe a
  cycle would otherwise recurse until the stack runs out, and a stack overflow
  is a signal no `try/except` catches;
- a walk is bounded by the caller's limit rather than the buffer's, so a
  nested walk cannot escape its parent.

Those three properties are what the tests exercise: every case is built byte by
byte, because the point is what the walk does with a size that lies and no real
file carries one.

## Alternatives considered

**Leaving the framing where it was.** Three libraries had written it three
times. The duplication is three chances to get a bounds check wrong, and a fix
applied three times or forgotten twice.

**A single module inside one of them, imported by the others.** That is what
the family tried: UniMovie owned ISOBMFF muxing and UniAudio reached for it.
The result was a sideways edge between two libraries of the same layer, and a
clone of UniAudio that did not build on its own.
