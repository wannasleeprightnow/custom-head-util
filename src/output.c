#include "output.h"

#include <stdio.h>
#include <stdlib.h>

static char* read_line(FILE* file, int delimiter);

void process_stream(FILE* file, Options* options) {
  int delimiter = options->z ? '\0' : '\n';
  unsigned char buffer[4096];
  size_t bytes_read;

  long long count_n = options->n;
  long long count_c = options->c;

  if (count_c > 0) {
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
      size_t to_write =
          (bytes_read <= (size_t)count_c) ? bytes_read : (size_t)count_c;
      fwrite(buffer, 1, to_write, stdout);
      count_c -= (long long)to_write;
      if (count_c == 0) return;
    }
  } else if (count_n > 0) {
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
      for (size_t i = 0; i < bytes_read; i++) {
        if (buffer[i] == (unsigned char)delimiter) {
          count_n--;
        }
        if (count_n == 0) {
          fwrite(buffer, 1, i + 1, stdout);
          return;
        }
      }
      fwrite(buffer, 1, bytes_read, stdout);
    }
  } else if (options->c < 0) {
    size_t K = (size_t)(-options->c);
    unsigned char* window = malloc(K);
    if (!window) return;

    size_t pos = 0;
    int full = 0;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
      for (size_t i = 0; i < bytes_read; i++) {
        if (full) putchar(window[pos]);
        window[pos] = buffer[i];
        pos++;
        if (pos == K) {
          pos = 0;
          full = 1;
        }
      }
    }
    free(window);
  } else if (options->n < 0) {
    size_t K = (size_t)(-options->n);
    char** line_queue = calloc(K, sizeof(char*));
    if (!line_queue) return;

    size_t pos = 0;
    int full = 0;
    char* current_line;

    while ((current_line = read_line(file, delimiter)) != NULL) {
      if (full) {
        fputs(line_queue[pos], stdout);
        free(line_queue[pos]);
      }
      line_queue[pos] = current_line;
      pos++;
      if (pos == K) {
        pos = 0;
        full = 1;
      }
    }

    for (size_t i = 0; i < K; i++) {
      if (line_queue[i]) free(line_queue[i]);
    }
    free(line_queue);
  }
}

static char* read_line(FILE* file, int delimiter) {
  size_t capacity = 128;
  size_t pos = 0;
  char* buffer = malloc(capacity);
  if (!buffer) return NULL;

  int c;
  while ((c = fgetc(file)) != EOF) {
    if (pos + 1 >= capacity) {
      capacity *= 2;
      char* new_buf = realloc(buffer, capacity);
      if (!new_buf) {
        free(buffer);
        return NULL;
      }
      buffer = new_buf;
    }
    buffer[pos++] = (char)c;
    if (c == delimiter) break;
  }

  if (pos == 0) {
    free(buffer);
    return NULL;
  }

  buffer[pos] = '\0';
  return buffer;
}