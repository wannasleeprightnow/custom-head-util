#include "errors.h"

void handle_error(Status status, const char *context) {
  switch (status) {
  case ERROR_PARSE_OPTS_N:
    fprintf(stderr, "head: invalid number of lines: '%s'\n", context);
    break;
  case ERROR_PARSE_OPTS_C:
    fprintf(stderr, "head: invalid number of bytes: '%s'\n", context);
    break;
  case ERROR_GENERAL_PARSE:
    if (context && *context != '\0') {
      fprintf(stderr, "head: invalid option -- '%s'\n", context);
    }
    fprintf(stderr, "Try 'head --help' for more information.\n");
    break;
  case ERROR_MEMORY_ALLOCATION:
    fprintf(stderr, "head: memory exhausted\n");
    break;
  case ERROR_FILE_OPEN:
    fprintf(stderr, "head: cannot open '%s' for reading: ", context);
    perror("");
    break;
  default:
    break;
  }
}