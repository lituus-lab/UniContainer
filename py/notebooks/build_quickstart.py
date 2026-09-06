# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ('md', '# UniContainer — Python quickstart\n\n`unicontainer` is a Cython extension over the UniContainer C ABI, shipped as a\nself-contained wheel: the native library travels inside the package, so\ninstalling it needs neither Nim nor a compiler.\n\n```\npip install lituus-unicontainer\n```\n\nCI executes this notebook against the wheel the release actually publishes, so\nthe outputs below are what the code produced, not what it was expected to.'),
    ('md', '## A box is a length, a kind and a payload\n\nMP4, MOV, HEIF, AVIF and an ALAC `.m4a` are the same structure. This library\nwalks that structure and hands over spans; it never decodes what is inside one.'),
    ('code', 'def box(kind, payload=b""):\n    size = len(payload) + 8\n    return size.to_bytes(4, "big") + kind.encode("ascii") + payload\n\ndata = box("ftyp", b"isom") + box("moov", box("trak", box("mdia", b"the payload")))\nlen(data)'),
    ('md', '## Recognising the format, and reaching a box by name'),
    ('code', 'import unicontainer\n\nunicontainer.is_isobmff(data)'),
    ('code', 'body, body_end = unicontainer.find_box(data, "moov/trak/mdia")\ndata[body:body_end]'),
    ('md', 'A path names the way down. A box that is absent answers `None` rather than\nraising: half the boxes a format defines are optional, and that is not an error.'),
    ('code', 'print(unicontainer.find_box(data, "moov/udta"))'),
    ('md', 'A step that cannot name a box is refused, though. A kind is four characters,\nso a shorter one cannot exist and a longer one would silently never match.'),
    ('code', 'try:\n    unicontainer.find_box(data, "moo")\nexcept unicontainer.UniContainerError as error:\n    print(error)'),
    ('md', '## Where to look next\n\nSee `include/UniContainer.h`, and the book for the full picture.'),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    # Execute from the repo root, never from py/: there, `import unicontainer`
    # would resolve to the py/unicontainer source tree instead of the installed
    # package, and the notebook would stop testing what it claims to test.
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    with open(OUT, "w") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
