# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""The Python surface over the C ABI, on trees built byte by byte."""
import pytest

from unicontainer import UniContainerError, find_box, is_isobmff, version


def box(kind, payload=b""):
    size = len(payload) + 8
    return size.to_bytes(4, "big") + kind.encode("ascii") + payload


TREE = box("ftyp", b"isom") + box("moov", box("trak", box("mdia", b"here")))


def test_version_is_reported():
    assert version()


def test_an_ftyp_box_at_the_front_marks_the_file():
    assert is_isobmff(TREE)
    assert not is_isobmff(b"RIFF____WAVEfmt ")
    assert not is_isobmff(b"")


def test_a_path_reaches_the_payload_of_its_last_step():
    body, body_end = find_box(TREE, "moov/trak/mdia")
    assert TREE[body:body_end] == b"here"


def test_a_path_may_be_given_as_a_sequence():
    assert find_box(TREE, ("moov", "trak")) == find_box(TREE, "moov/trak")


def test_a_box_that_is_absent_answers_none():
    assert find_box(TREE, "moov/udta") is None


def test_a_step_that_cannot_name_a_box_is_refused():
    with pytest.raises(UniContainerError):
        find_box(TREE, "moo")
    with pytest.raises(UniContainerError):
        find_box(TREE, "toolong")


def test_searching_nothing_is_refused_rather_than_answered():
    with pytest.raises(UniContainerError):
        find_box(b"", "moov")


def test_a_memoryview_is_read_without_a_copy():
    assert find_box(memoryview(TREE), "moov/trak/mdia") is not None
