#ifndef REGEZ_H
#define REGEZ_H

#include <stddef.h>
#include <stdlib.h>

/* Type for byte offsets within the string.  POSIX mandates this.  */
#ifdef _REGEX_LARGE_OFFSETS
/* POSIX 1003.1-2008 requires that regoff_t be at least as wide as
   ptrdiff_t and ssize_t.  We don't know of any hosts where ptrdiff_t
   is wider than ssize_t, so ssize_t is safe.  ptrdiff_t is not
   visible here, so use ssize_t.  */
typedef ssize_t regoff_t;
#else
/* The traditional GNU regex implementation mishandles strings longer
   than INT_MAX.  */
typedef int regoff_t;
#endif

/* POSIX specification for registers.  Aside from the different names than
   're_registers', POSIX uses an array of structures, instead of a
   structure of arrays.  */
typedef struct {
  regoff_t rm_so; /* Byte offset from string's start to substring's start.  */
  regoff_t rm_eo; /* Byte offset from string's start to substring's end.  */
} rezmatch_t;     /* Renamed to prevent name collision. */

// We can't translate regex_t, so we treat it as an opaque pointer in the API.
// Zig will see this as *anyopaque.
typedef void *regex_t_opaque;

// Wrappers around the regex.h functions.
int regez_comp(regex_t_opaque *preg, const char *regex, int cflags);
int regez_exec(const regex_t_opaque *preg, const char *string, size_t nmatch,
               rezmatch_t pmatch[], int eflags);
size_t regez_error(int errcode, const regex_t_opaque *preg, char *errbuf,
                   size_t errbuf_size);
void regez_free(regex_t_opaque *preg);
size_t regez_nsub(regex_t_opaque *preg);

int regez_alloc_regex_t(regex_t_opaque **preg);
void regez_free_regex_t(regex_t_opaque *preg);

extern const int REGEZ_EXTENDED;
extern const int REGEZ_ICASE;
extern const int REGEZ_NEWLINE;
extern const int REGEZ_NOSUB;
extern const int REGEZ_NOMATCH;

#endif