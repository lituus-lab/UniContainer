// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNICONTAINER_H
#define UNICONTAINER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNICONTAINER_VERSION_MAJOR 0
#define UNICONTAINER_VERSION_MINOR 1
#define UNICONTAINER_VERSION_PATCH 0
#define UNICONTAINER_VERSION "0.1.0"

#define UNICONTAINER_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNICONTAINER_VERSION_MAJOR > (ma)) || \
   (UNICONTAINER_VERSION_MAJOR == (ma) && UNICONTAINER_VERSION_MINOR > (mi)) || \
   (UNICONTAINER_VERSION_MAJOR == (ma) && UNICONTAINER_VERSION_MINOR == (mi) && \
    UNICONTAINER_VERSION_PATCH >= (pa)))

/* Status codes every entry point returns. */
typedef enum {
  UCNT_OK = 0,
  UCNT_ERR_ARG = 1,      /* a null pointer, a bad length, or a malformed path */
  UCNT_ERR_NOT_FOUND = 2 /* the path names a box the data does not carry */
} ucnt_status;

/* Static version string; do not free. */
const char *ucnt_version(void);

/* Whether the bytes open with an ftyp box: 1 yes, 0 no. Anything it cannot
 * read reads as 0 rather than as a status — the question has a truth value. */
int ucnt_is_isobmff(const unsigned char *data, int length);

/* Walk a slash-separated path of box kinds, e.g. "moov/trak/mdia", and report
 * the span of the last one's payload as offsets into data. Each step is four
 * characters; anything else is UCNT_ERR_ARG rather than a loose match.
 *
 * On anything but UCNT_OK, every output pointer the caller passed is set to
 * -1 before any argument is judged — so a stale value is never mistaken for an
 * offset, whichever argument turned out to be the bad one. A null output
 * pointer is refused, not written through. */
int ucnt_find_box(const unsigned char *data, int length, const char *path,
                  int *body, int *body_end);

#ifdef __cplusplus
}
#endif

#endif /* UNICONTAINER_H */
