<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unicontainer

Python binding over the UniContainer C library: media container framing, never
the codec inside it.

```python
from unicontainer import find_box, is_isobmff

data = open("clip.m4a", "rb").read()
assert is_isobmff(data)

span = find_box(data, "moov/trak/mdia")   # (body, body_end), or None
```

A path names the way down a tree of boxes; every step is four characters. A box
that is absent answers `None`, because half the boxes a format defines are
optional and that is not an error.

The binding is thin: what the C ABI cannot reach, this cannot reach either.

## Build

```bash
nimble pyLib      # the library the extension links against
nimble pyTest     # extension + pytest
```

## License

Apache-2.0. See the repository's [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
