#include "regez.h"
#include <regex.h>

// The C compiler sees the real regex_t, so we just cast.
int regez_comp(regex_t_opaque *preg, const char *regex, int cflags) {
  return regcomp((regex_t *)preg, regex, cflags);
}

int regez_exec(const regex_t_opaque *preg, const char *string, size_t nmatch,
               rezmatch_t pmatch[], int eflags) {
  return regexec((const regex_t *)preg, string, nmatch, (regmatch_t *)pmatch,
                 eflags);
}

size_t regez_error(int errcode, const regex_t_opaque *preg, char *errbuf,
                   size_t errbuf_size) {
  return regerror(errcode, (const regex_t *)preg, errbuf, errbuf_size);
}

void regez_free(regex_t_opaque *preg) { regfree((regex_t *)preg); }

int regez_alloc_regex_t(regex_t_opaque **preg) {
  *preg = (regex_t_opaque *)malloc(sizeof(regex_t));
  if (*preg == NULL) {
    return -1;
  }

  return 0;
}

void regez_free_regex_t(regex_t_opaque *preg) { free(preg); }

size_t regez_nsub(regex_t_opaque *preg) { return ((regex_t *)preg)->re_nsub; }

// --- Constants: use extern to access. ---
const int REGEZ_EXTENDED = REG_EXTENDED;
const int REGEZ_ICASE = REG_ICASE;
const int REGEZ_NEWLINE = REG_NEWLINE;
const int REGEZ_NOSUB = REG_NOSUB;

const int REGEZ_NOMATCH = REG_NOMATCH;

size_t regez_sizeof_regex_t(void) { return sizeof(regex_t); }

size_t regez_alignof_regex_t(void) {
  // _Alignof is the modern C standard way
  return _Alignof(regex_t);
}