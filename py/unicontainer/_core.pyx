# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Cython binding over the UniContainer C ABI.

A thin wrapper, never a second implementation: what the ABI cannot reach, this
cannot reach either.
"""

cdef extern from "UniContainer.h":
    const char *ucnt_version()
    int ucnt_is_isobmff(const unsigned char *data, int length)
    int ucnt_find_box(const unsigned char *data, int length, const char *path,
                      int *body, int *body_end)


class UniContainerError(ValueError):
    """A call into the library refused its arguments."""


def version():
    """C library version string."""
    return ucnt_version()


def is_isobmff(data):
    """Whether the bytes open with an ftyp box."""
    cdef const unsigned char[::1] view = _as_bytes(data)
    if view.shape[0] == 0:
        return False
    return ucnt_is_isobmff(&view[0], view.shape[0]) == 1


def find_box(data, path):
    """The span of a box's payload, as (body, body_end), or None when absent.

    `path` is the box kinds to walk, e.g. ("moov", "trak", "mdia") or the
    equivalent "moov/trak/mdia". Every kind is four characters.
    """
    if not isinstance(path, str):
        path = "/".join(path)
    cdef bytes encoded = path.encode("ascii")
    cdef const unsigned char[::1] view = _as_bytes(data)
    if view.shape[0] == 0:
        raise UniContainerError("there are no bytes to search")
    cdef int body = -1
    cdef int body_end = -1
    cdef int status = ucnt_find_box(&view[0], view.shape[0], encoded,
                                    &body, &body_end)
    if status == 2:
        return None
    if status != 0:
        raise UniContainerError(
            "every step of the path must be four characters: " + path)
    return body, body_end


cdef object _as_bytes(data):
    """A contiguous read-only view, copying only what does not offer one."""
    try:
        return memoryview(data).cast("B")
    except (TypeError, ValueError, BufferError):
        return memoryview(bytes(data)).cast("B")
