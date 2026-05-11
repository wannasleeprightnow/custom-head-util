#include "options.h"

static long long apply_suffix(long long val, char suffix);

int parsing_options(int argc, char* argv[], Options* options) {
  opterr = 0;
  char* short_options = "c:n:qvz";
  struct option long_options[] = {{"lines", required_argument, NULL, 'n'},
                                  {"bytes", required_argument, NULL, 'c'},
                                  {"quiet", no_argument, NULL, 'q'},
                                  {"silent", no_argument, NULL, 'q'},
                                  {"verbose", no_argument, NULL, 'v'},
                                  {"zero-terminated", no_argument, NULL, 'z'},
                                  {NULL, 0, NULL, 0}};

  int current_option;

  while (((current_option = getopt_long(argc, argv, short_options, long_options,
                                        NULL)) != -1)) {
    switch (current_option) {
      case 'n':
      case 'c': {
        char* endptr;
        long long val = strtoll(optarg, &endptr, 10);

        if (endptr == optarg) {
          handle_error(
              current_option == 'n' ? ERROR_PARSE_OPTS_N : ERROR_PARSE_OPTS_C,
              optarg);
          return ERROR_PARSE_OPTS_N;
        }

        if (*endptr != '\0') {
          long long new_val = apply_suffix(val, *endptr);
          if (new_val == -1) {
            handle_error(
                current_option == 'n' ? ERROR_PARSE_OPTS_N : ERROR_PARSE_OPTS_C,
                optarg);
            return ERROR_PARSE_OPTS_N;
          }
          val = new_val;

          if (*(endptr + 1) != '\0') {
            handle_error(
                current_option == 'n' ? ERROR_PARSE_OPTS_N : ERROR_PARSE_OPTS_C,
                optarg);
            return ERROR_PARSE_OPTS_N;
          }
        }

        if (current_option == 'n') {
          options->n = val;
          options->c = 0;
        } else {
          options->c = val;
          options->n = 0;
        }
        break;
      }
      case 'q': {
        options->q = 1;
        options->v = 0;
        break;
      }
      case 'v': {
        options->v = 1;
        options->q = 0;
        break;
      }
      case 'z': {
        options->z = 1;
        break;
      }
      default: {
        char err_opt[2] = {(char)optopt, '\0'};
        handle_error(ERROR_GENERAL_PARSE, err_opt);
        return ERROR_GENERAL_PARSE;
      }
    }
  }

  options->count_filenames = argc - optind;
  if (options->count_filenames) {
    options->filenames = calloc(options->count_filenames, sizeof(char*));
    if (options->filenames == NULL) {
      handle_error(ERROR_MEMORY_ALLOCATION, NULL);
      return ERROR_MEMORY_ALLOCATION;
    }
    int i;
    for (i = 0; i < options->count_filenames; i++) {
      options->filenames[i] = argv[optind + i];
    }
  }
  return SUCCESS;
}

static long long apply_suffix(long long val, char suffix) {
  switch (suffix) {
    case 'b':
      return val * 512;
    case 'k':
    case 'K':
      return val * 1024;
    case 'm':
    case 'M':
      return val * 1024 * 1024;
    case 'g':
    case 'G':
      return val * 1024 * 1024 * 1024;
    default:
      return -1;
  }
}