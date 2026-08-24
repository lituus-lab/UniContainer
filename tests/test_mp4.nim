# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Writing an MP4, checked by reading it back through the box layer beside it.
##
## Nothing here decodes a sample: what this library promises is that the boxes
## an ISO base media file needs are present, in the right nesting, carrying the
## bytes they were handed. Whether those bytes decode is the consumer's
## question, and the consumer's test.
import std/[unittest, streams]
import UniContainer

proc bytesOf(text: string): seq[byte] =
  result = newSeq[byte](text.len)
  for index, character in text:
    result[index] = byte(character)

proc audioTrack(): TrackParams =
  TrackParams(kind: tkAudio, codec: "alac", timescale: 44100, channels: 2,
              sampleRate: 44100, configKind: "alac", config: "\0\0\0\0cookie")

proc writtenFile(samples: seq[string]): seq[byte] =
  var sink = newStringStream()
  var writer = newMp4Writer(sink, [audioTrack()])
  for one in samples:
    writer.writeSample(0, bytesOf(one), 1024)
  writer.close()
  bytesOf(sink.data)

suite "what a written MP4 carries":
  let file = writtenFile(@["first", "second", "third"])

  test "it opens with an ftyp box":
    check isIsobmff(file)

  test "the boxes an ISO base media file needs are all there":
    for path in [@["ftyp"], @["moov"], @["mdat"],
                 @["moov", "mvhd"], @["moov", "trak"],
                 @["moov", "trak", "tkhd"],
                 @["moov", "trak", "mdia", "mdhd"],
                 @["moov", "trak", "mdia", "minf", "stbl", "stsd"],
                 @["moov", "trak", "mdia", "minf", "stbl", "stsz"],
                 @["moov", "trak", "mdia", "minf", "stbl", "stco"]]:
      check findBox(file, 0, file.len, path).body >= 0

  test "the sample entry is named after the codec it was given":
    let stsd = findBox(file, 0, file.len,
                       ["moov", "trak", "mdia", "minf", "stbl", "stsd"])
    check stsd.body >= 0
    var found = false
    # `stsd` is a full box: four bytes of version and flags, then a count,
    # then the entries themselves.
    for kind, _, _ in boxes(file, stsd.body + 8, stsd.bodyEnd):
      if kind == "alac": found = true
    check found

  test "the samples reach mdat unexamined":
    let mdat = findBox(file, 0, file.len, ["mdat"])
    check mdat.body >= 0
    var payload = ""
    for index in mdat.body ..< mdat.bodyEnd: payload.add char(file[index])
    check payload == "firstsecondthird"

  test "it counts what it was given":
    var sink = newStringStream()
    var writer = newMp4Writer(sink, [audioTrack()])
    check writer.trackCount == 1
    check writer.sampleCount(0) == 0
    writer.writeSample(0, bytesOf("one"), 1024)
    writer.writeSample(0, bytesOf("two"), 1024)
    check writer.sampleCount(0) == 2
    writer.close()

  test "a file with no sample at all is refused rather than written":
    # A container declaring a track it never fills is a file no reader can do
    # anything with, so `close` says so instead of producing one.
    expect ContainerError:
      discard writtenFile(@[])

suite "what the writer refuses":
  # The track count is a precondition, so it raises a Defect in a debug build
  # and compiles away under -d:release. Asserting it only where it exists is
  # what keeps this suite honest in both builds.
  when not defined(release):
    test "more tracks than it will allocate for":
      var many: seq[TrackParams]
      for _ in 0 .. MaxWriterTracks:
        many.add audioTrack()
      var sink = newStringStream()
      expect Defect:
        discard newMp4Writer(sink, many)

    test "no track at all":
      var sink = newStringStream()
      expect Defect:
        discard newMp4Writer(sink, [])

  test "a frame past any real dimension":
    var sink = newStringStream()
    expect ContainerError:
      discard newMp4Writer(sink, [TrackParams(kind: tkVideo, codec: "avc1",
        timescale: 1000, width: MaxDimension + 1, height: 1080)])

  test "a sample for a track it does not have":
    var sink = newStringStream()
    var writer = newMp4Writer(sink, [audioTrack()])
    expect ContainerError:
      writer.writeSample(3, bytesOf("nowhere"), 1024)

suite "writing a fragment at a time":
  test "a fragment appears once flushed, and the file opens before it ends":
    var sink = newStringStream()
    var writer = newFragmentedMp4Writer(sink, [audioTrack()])
    check writer.trackCount == 1
    writer.writeSample(0, bytesOf("first"), 1024)
    check writer.pendingSamples(0) == 1
    writer.flushFragment()
    check writer.pendingSamples(0) == 0
    check writer.fragmentCount == 1
    # The initialisation segment is written up front, which is what lets a
    # reader start on a stream the writer has not finished.
    let sofar = bytesOf(sink.data)
    check isIsobmff(sofar)
    check findBox(sofar, 0, sofar.len, ["moov", "mvex"]).body >= 0
    check findBox(sofar, 0, sofar.len, ["moof"]).body >= 0
    writer.close()

  test "flushing nothing writes no fragment":
    var sink = newStringStream()
    var writer = newFragmentedMp4Writer(sink, [audioTrack()])
    writer.flushFragment()
    check writer.fragmentCount == 0
    writer.close()

