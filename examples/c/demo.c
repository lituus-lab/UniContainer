// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* The same walk from C: build a tree, then find a box inside it. */
#include "UniContainer.h"

#include <stdio.h>
#include <string.h>

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
  printf("UniContainer %s\n", ucnt_version());

  unsigned char inner[64];
  int inner_len = put_box(inner, 0, "mdia",
                          (const unsigned char *)"the payload", 11);
  unsigned char middle[128];
  int middle_len = put_box(middle, 0, "trak", inner, inner_len);
  unsigned char file[256];
  int len = put_box(file, 0, "ftyp", (const unsigned char *)"isom", 4);
  len = put_box(file, len, "moov", middle, middle_len);

  printf("isobmff: %d\n", ucnt_is_isobmff(file, len));

  int body = 0, body_end = 0;
  if (ucnt_find_box(file, len, "moov/trak/mdia", &body, &body_end) == UCNT_OK)
    printf("moov/trak/mdia: %.*s\n", body_end - body, file + body);
  else
    printf("moov/trak/mdia: not found\n");
  return 0;
}
