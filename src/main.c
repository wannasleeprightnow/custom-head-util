#include "errors.h"
#include "options.h"

int main(int argc, char *argv[]) {
  Options options = {.n = 10,
                     .c = 0,
                     .q = 0,
                     .v = 0,
                     .z = 0,
                     .count_filenames = 0,
                     .filenames = NULL};

  Status status = parsing_options(argc, argv, &options);

  if (status != SUCCESS) {
    return 1;
  }

  if (options.filenames != NULL) {
    free(options.filenames);
  }

  return SUCCESS;
}