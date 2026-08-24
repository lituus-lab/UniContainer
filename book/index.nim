# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
nb.title = "UniContainer"

nbText: """
# UniContainer

The byte structure a media format is wrapped in, and nothing about the codec
inside it.

This page is a nimib book: every Nim block below is compiled and run when the
book is built, and the output shown is what the code actually produced. A
change that breaks the API breaks the docs build, so the two cannot drift
apart.

## A box is a length, a kind and a payload

MP4, MOV, HEIF, AVIF and an ALAC `.m4a` are the same structure. What differs
between them is which boxes they carry, never how a box is shaped — which is
why one module walks all of them.
"""

nbCode:
  import UniContainer

  proc bytesOf(text: string): seq[byte] =
    result = newSeq[byte](text.len)
    for index, character in text: result[index] = byte(character)

  let file = box("ftyp", "isom") &
             box("moov", box("trak", box("mdia", "the payload")))
  let data = bytesOf(file)

  echo "bytes: ", data.len
  echo "isobmff: ", isIsobmff(data)

nbText: """
`box` builds one, and the same structure reads back through `boxes`. Walking
yields each box with the span of its payload, not the payload itself: nothing
here copies bytes a caller may not want.
"""

nbCode:
  for kind, body, bodyEnd in boxes(data, 0, data.len):
    echo kind, ": payload ", bodyEnd - body, " bytes"

nbText: """
## Reaching a box by name

Boxes nest, so a path names the way down. A step that is missing answers with
`-1` rather than raising — a box being absent is ordinary, not exceptional, and
half the boxes a format defines are optional.
"""

nbCode:
  let span = findBox(data, 0, data.len, ["moov", "trak", "mdia"])
  var found = ""
  for index in span.body ..< span.bodyEnd: found.add char(data[index])
  echo "moov/trak/mdia: ", found
  echo "moov/udta (absent): ", findBox(data, 0, data.len, ["moov", "udta"]).body

nbText: """
## What a file is allowed to claim

This is the layer that reads hostile input, so the bounds are the substance
rather than a detail. A box that claims to be smaller than its own header, or
to run past the parent it sits in, ends the walk instead of raising: trailing
garbage after a valid box should not cost a caller what it already parsed.
"""

nbCode:
  var lying = ""
  lying.putBE(4, 4) # a header is eight bytes; four is a lie
  lying.add "junk"
  var counted = 0
  for _, _, _ in boxes(bytesOf(lying), 0, lying.len): inc counted
  echo "boxes read from a lying size: ", counted

  let truncated = bytesOf(box("ftyp", "isom") & "\x00\x00")
  var kinds: seq[string]
  for kind, _, _ in boxes(truncated, 0, truncated.len): kinds.add kind
  echo "kept from a truncated file: ", kinds

nbText: """
Nesting is capped at `MaxBoxDepth`. A file whose sizes describe a cycle would
otherwise recurse until the stack runs out, and a stack overflow is a signal no
`try/except` catches.

## The other two surfaces

The same walk is reachable from C through `include/UniContainer.h`
(`ucnt_is_isobmff`, `ucnt_find_box`) and from Python through the `unicontainer`
package (`is_isobmff`, `find_box`). Both are thin: what the C ABI cannot reach,
the Python binding cannot reach either.
"""

nbSave
