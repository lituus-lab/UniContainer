# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Build a small ISO base media tree, then find something inside it.
import UniContainer

proc bytesOf(text: string): seq[byte] =
  result = newSeq[byte](text.len)
  for index, character in text: result[index] = byte(character)

let file = box("ftyp", "isom") &
           box("moov", box("trak", box("mdia", "the payload")))
let data = bytesOf(file)

echo "isobmff: ", isIsobmff(data)
echo "boxes at the top level:"
for kind, body, bodyEnd in boxes(data, 0, data.len):
  echo "  ", kind, ", payload ", bodyEnd - body, " bytes"

let span = findBox(data, 0, data.len, ["moov", "trak", "mdia"])
var found = ""
for index in span.body ..< span.bodyEnd: found.add char(data[index])
echo "moov/trak/mdia: ", found

