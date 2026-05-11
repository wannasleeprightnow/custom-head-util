#include "errors.h"
#include "options.h"
#include "output.h"

int main(int argc, char* argv[]) {
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

  int exit_status = SUCCESS;

  if (!options.count_filenames) {
    if (options.v) {
      printf("==> standard input <==\n");
    }
    process_stream(stdin, &options);
  } else {
    int filename_idx;
    for (filename_idx = 0; filename_idx < options.count_filenames;
         filename_idx++) {
      FILE* file = fopen(options.filenames[filename_idx], "rb");
      if (file == NULL) {
        handle_error(ERROR_FILE_OPEN, options.filenames[filename_idx]);
        exit_status = 1;
        continue;
      }
      if (filename_idx > 0 && !options.q && file != NULL) {
        printf("\n");
      }
      if ((options.count_filenames > 1 && !options.q) || options.v) {
        printf("==> %s <==\n", options.filenames[filename_idx]);
      }
      process_stream(file, &options);
      fclose(file);
    }
  }

  if (options.filenames != NULL) {
    free(options.filenames);
  }

  return exit_status;
}