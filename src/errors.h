#ifndef ERRORS_H
#define ERRORS_H

#include <stdio.h>

typedef enum {
  SUCCESS = 0,
  ERROR_PARSE_OPTS,
  ERROR_PARSE_OPTS_N,
  ERROR_PARSE_OPTS_C,
  ERROR_GENERAL_PARSE,
  ERROR_MEMORY_ALLOCATION,
  ERROR_FILE_OPEN
} Status;

void handle_error(Status status, const char* context);

#endif