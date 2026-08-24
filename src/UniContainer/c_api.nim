# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniContainer. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniContainer.h; tests/c links the
## header against this lib, so a header that drifts fails to compile rather
## than at a caller's site.
##
## No Nim exception crosses this boundary: `{.raises: [].}` on every entry
## point is what proves it rather than a convention that has to be remembered.
import ../UniContainer

const UniContainerVersionC: cstring = "0.1.0"

type Status = enum
  ucntOk = 0
  ucntErrArg = 1      ## a null pointer, a bad length, or a malformed path
  ucntErrNotFound = 2 ## the path names a box the data does not carry

# Unmangled C symbols, C calling convention, exported from the shared lib.
# A shared library runs NimMain from DllMain (Windows) or an ELF constructor;
# a static one has neither, so nothing initializes the Nim runtime. Anything
# that reads the environment then faults — proven on Windows, where the Python
# extension is the one consumer that links the static build. The static-library
# tasks pass -d:staticNoAutoInit; shared builds must not, or NimMain runs twice.
when defined(staticNoAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE ucnt_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK ucnt_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void ucnt_runtime_ensure(void) {
  InitOnceExecuteOnce(&ucnt_runtime_once, ucnt_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t ucnt_runtime_once = PTHREAD_ONCE_INIT;
static void ucnt_runtime_init(void) { NimMain(); }
static void ucnt_runtime_ensure(void) {
  pthread_once(&ucnt_runtime_once, ucnt_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  ucnt_runtime_ensure();".}
else:
  template ensureRuntime() = discard

{.push exportc, cdecl, dynlib, raises: [].}

proc ucnt_version(): cstring =
  ## Static version string; do not free.
  ensureRuntime()
  UniContainerVersionC

proc ucnt_is_isobmff(data: ptr uint8; length: cint): cint =
  ## Whether the bytes open with an `ftyp` box. 1 yes, 0 no, and 0 for anything
  ## it cannot read rather than a status: the question has a truth value.
  ensureRuntime()
  if data == nil or length <= 0: return 0
  let bytes = cast[ptr UncheckedArray[uint8]](data)
  if isIsobmff(bytes.toOpenArray(0, int(length) - 1)): 1 else: 0

proc ucnt_find_box(data: ptr uint8; length: cint; path: cstring;
                   body: ptr cint; bodyEnd: ptr cint): cint =
  ## Walk a slash-separated path of box kinds, e.g. `"moov/trak/mdia"`, and
  ## report the span of the last one's payload.
  ##
  ## A path step is four characters; anything else is refused rather than
  ## matched loosely, because a shorter kind cannot exist and a longer one
  ## would silently never match.
  ensureRuntime()
  # Written before anything else is judged: the header promises both outputs
  # read -1 on any status but success, and a caller that trusted that while an
  # earlier argument was the bad one would read whatever it had left there.
  if body != nil: body[] = -1
  if bodyEnd != nil: bodyEnd[] = -1
  if data == nil or length <= 0 or path == nil or body == nil or
      bodyEnd == nil:
    return cint(ucntErrArg)
  try:
    var steps: seq[string]
    var step = ""
    for character in $path:
      if character == '/':
        steps.add step
        step = ""
      else:
        step.add character
    steps.add step
    for one in steps:
      if one.len != 4: return cint(ucntErrArg)

    let bytes = cast[ptr UncheckedArray[uint8]](data)
    let span = findBox(bytes.toOpenArray(0, int(length) - 1), 0, int(length),
                       steps)
    if span.body < 0: return cint(ucntErrNotFound)
    body[] = cint(span.body)
    bodyEnd[] = cint(span.bodyEnd)
    cint(ucntOk)
  except Exception:
    cint(ucntErrArg)

{.pop.}

