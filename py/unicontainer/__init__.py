# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unicontainer — Python binding over the UniContainer C library.

Media container framing, never the codec inside::

    from unicontainer import find_box, is_isobmff

    data = open("clip.m4a", "rb").read()
    assert is_isobmff(data)
    span = find_box(data, "moov/trak/mdia")
"""
from ._core import (UniContainerError, find_box, is_isobmff,
                    version as _version_c)

__version__ = _version_c().decode("ascii")


def version():
    """C library version string."""
    return _version_c().decode("ascii")


__all__ = ["UniContainerError", "find_box", "is_isobmff", "version",
           "__version__"]
