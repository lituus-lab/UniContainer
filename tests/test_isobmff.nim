# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The box layer, checked against what a hostile file can claim.
##
## Every case here is built byte by byte rather than read from a fixture: the
## point is what the walk does with a size that lies, and a real file does not
## carry one.
import std/unittest
import UniContainer

proc bytesOf(text: string): seq[byte] =
  result = newSeq[byte](text.len)
  for index, character in text:
    result[index] = byte(character)

suite "reading a box":
  test "a header carries its kind and its size":
    let data = bytesOf(box("ftyp", "isom"))
    let header = readBoxHeader(data, 0)
    check header.kind == "ftyp"
    check header.size == 12
    check header.offset == 0

  test "a 64-bit size is read from where the escape value points":
    # Size 1 means the real size follows the kind, eight bytes wide.
    var data = ""
    data.putBE(1, 4)
    data.add "mdat"
    data.putBE(4_294_967_312'i64, 8) # past what 32 bits can hold
    let header = readBoxHeader(bytesOf(data), 0)
    check header.kind == "mdat"
    check header.size == 4_294_967_312'i64

  test "walking yields each box with the span of its payload":
    let data = bytesOf(box("ftyp", "isom") & box("free", "xx"))
    var seen: seq[string]
    for kind, body, bodyEnd in boxes(data, 0, data.len):
      seen.add kind
      if kind == "ftyp": check bodyEnd - body == 4
      if kind == "free": check bodyEnd - body == 2
    check seen == @["ftyp", "free"]

  test "a size of zero runs to the end of the enclosing box":
    var data = ""
    data.putBE(0, 4)
    data.add "mdat"
    data.add "payload"
    var spans: seq[int]
    for kind, body, bodyEnd in boxes(bytesOf(data), 0, data.len):
      check kind == "mdat"
      spans.add bodyEnd - body
    check spans == @[7]

  test "a box smaller than its own header ends the walk":
    var data = ""
    data.putBE(4, 4) # a header is eight bytes; four is a lie
    data.add "junk"
    var count = 0
    for _, _, _ in boxes(bytesOf(data), 0, data.len): inc count
    check count == 0

  test "a box running past its parent ends the walk":
    var data = ""
    data.putBE(999, 4)
    data.add "moov"
    data.add "short"
    var count = 0
    for _, _, _ in boxes(bytesOf(data), 0, data.len): inc count
    check count == 0

  test "a limit past the buffer never yields a span past the buffer":
    # A parent span may name more bytes than the data holds — a truncated
    # download, or a size copied from a header that lied. What is yielded is
    # read by the caller, so it must never point past what was handed in.
    var data = ""
    data.putBE(64, 4)
    data.add "mdat"
    data.add "only twelve"
    let bytes = bytesOf(data)
    for _, _, bodyEnd in boxes(bytes, 0, 64):
      check bodyEnd <= bytes.len

  test "a size no int can hold ends the walk rather than wrapping":
    var data = ""
    data.putBE(1, 4) # the escape value: a 64-bit size follows the kind
    data.add "mdat"
    data.putBE(high(int64), 8)
    data.add "payload"
    let bytes = bytesOf(data)
    var count = 0
    for _, _, _ in boxes(bytes, 0, bytes.len): inc count
    check count == 0

  test "trailing garbage does not cost what was already parsed":
    let data = bytesOf(box("ftyp", "isom") & "\x00\x00")
    var seen: seq[string]
    for kind, _, _ in boxes(data, 0, data.len): seen.add kind
    check seen == @["ftyp"]

suite "finding a box by path":
  let tree = bytesOf(box("ftyp", "isom") &
                     box("moov", box("trak", box("mdia", "here"))))

  test "a path reaches the payload of its last step":
    let span = findBox(tree, 0, tree.len, ["moov", "trak", "mdia"])
    check span.body >= 0
    var found = ""
    for index in span.body ..< span.bodyEnd: found.add char(tree[index])
    check found == "here"

  test "a missing step answers with -1 rather than raising":
    check findBox(tree, 0, tree.len, ["moov", "absent"]).body == -1
    check findBox(tree, 0, tree.len, ["nope"]).body == -1

  test "an empty path finds nothing":
    check findBox(tree, 0, tree.len, []).body == -1

  test "nesting past the cap stops rather than running the stack out":
    # Each level wraps the last, so the depth is the count. One past the cap
    # must answer -1 rather than recursing.
    var payload = "leaf"
    for _ in 0 .. MaxBoxDepth + 1: payload = box("moov", payload)
    let deep = bytesOf(payload)
    var path: seq[string]
    for _ in 0 .. MaxBoxDepth + 1: path.add "moov"
    check findBox(deep, 0, deep.len, path).body == -1

suite "building a box":
  test "what is written reads back":
    let data = bytesOf(box("ftyp", "isom"))
    let header = readBoxHeader(data, 0)
    check header.kind == "ftyp"
    check int(header.size) == data.len

  test "a full box carries its version and flags before the payload":
    let full = fullBox("mvhd", "rest")
    check full.len == 4 + 4 + 4 + 4
    for index in 8 .. 11: check full[index] == '\0'

  test "putBE drops the bits above the width it was given":
    var target = ""
    target.putBE(0x1234_5678, 2)
    check target == "\x56\x78"

  test "a written tree is found by path":
    let data = bytesOf(box("moov", box("trak", "inner")))
    let span = findBox(data, 0, data.len, ["moov", "trak"])
    var found = ""
    for index in span.body ..< span.bodyEnd: found.add char(data[index])
    check found == "inner"

suite "recognising the format":
  test "an ftyp box at the front is what marks the file":
    check isIsobmff(bytesOf(box("ftyp", "isom")))

  test "anything else is not, including something too short to tell":
    check not isIsobmff(bytesOf("RIFF____WAVEfmt "))
    check not isIsobmff(bytesOf("ftyp"))
    check not isIsobmff(@[])

