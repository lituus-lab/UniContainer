// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* Links include/UniContainer.h against the static library, so a header that
 * drifts from src/UniContainer/c_api.nim fails to compile rather than at a
 * caller's site.
 *
 * The tree is built here byte by byte: what the walk does with a size that
 * lies is the point, and no real file carries one.
 */
#include "UniContainer.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

/* Append a box: four big-endian length bytes, the kind, then the payload. */
static int put_box(unsigned char *out, int at, const char *kind,
                   const unsigned char *payload, int payload_len) {
  const int size = payload_len + 8;
  out[at + 0] = (unsigned char)((size >> 24) & 0xFF);
  out[at + 1] = (unsigned char)((size >> 16) & 0xFF);
  out[at + 2] = (unsigned char)((size >> 8) & 0xFF);
  out[at + 3] = (unsigned char)(size & 0xFF);
  memcpy(out + at + 4, kind, 4);
  if (payload_len > 0) memcpy(out + at + 8, payload, (size_t)payload_len);
  return at + size;
}

int main(void) {
  assert(ucnt_version() != NULL);
  assert(strlen(ucnt_version()) > 0);

  unsigned char tree[256];
  int length = 0;
  length = put_box(tree, length, "ftyp", (const unsigned char *)"isom", 4);

  /* moov { trak { mdia "here" } }, innermost first. */
  unsigned char inner[64];
  int inner_len = put_box(inner, 0, "mdia", (const unsigned char *)"here", 4);
  unsigned char middle[96];
  int middle_len = put_box(middle, 0, "trak", inner, inner_len);
  length = put_box(tree, length, "moov", middle, middle_len);

  assert(ucnt_is_isobmff(tree, length) == 1);
  assert(ucnt_is_isobmff((const unsigned char *)"RIFF____WAVE", 12) == 0);
  assert(ucnt_is_isobmff(NULL, 0) == 0);

  int body = 0, body_end = 0;
  assert(ucnt_find_box(tree, length, "moov/trak/mdia", &body, &body_end) ==
         UCNT_OK);
  assert(body_end - body == 4);
  assert(memcmp(tree + body, "here", 4) == 0);

  /* A path that is legitimately absent answers, rather than failing. */
  assert(ucnt_find_box(tree, length, "moov/udta", &body, &body_end) ==
         UCNT_ERR_NOT_FOUND);
  assert(body == -1 && body_end == -1);

  /* A step that cannot name a box is refused rather than matched loosely. */
  assert(ucnt_find_box(tree, length, "moo", &body, &body_end) ==
         UCNT_ERR_ARG);
  assert(ucnt_find_box(tree, length, "toolong", &body, &body_end) ==
         UCNT_ERR_ARG);

  /* Whatever the bad argument is, an output pointer the caller did give must
   * come back as the sentinel: the header promises that, and a caller reading
   * a stale value would take it for an offset. Seeded with something that is
   * not -1 so the assertion means something. */
  body = 7;
  body_end = 9;
  assert(ucnt_find_box(NULL, length, "moov", &body, &body_end) ==
         UCNT_ERR_ARG);
  assert(body == -1 && body_end == -1);

  body = 7;
  body_end = 9;
  assert(ucnt_find_box(tree, length, NULL, &body, &body_end) == UCNT_ERR_ARG);
  assert(body == -1 && body_end == -1);

  body = 7;
  body_end = 9;
  assert(ucnt_find_box(tree, 0, "moov", &body, &body_end) == UCNT_ERR_ARG);
  assert(body == -1 && body_end == -1);

  body = 7;
  body_end = 9;
  assert(ucnt_find_box(tree, length, "moo", &body, &body_end) == UCNT_ERR_ARG);
  assert(body == -1 && body_end == -1);

  /* A null output pointer is still refused, and must not be written through. */
  assert(ucnt_find_box(tree, length, "moov", NULL, &body_end) ==
         UCNT_ERR_ARG);

  printf("c abi: ok\n");
  return 0;
}
