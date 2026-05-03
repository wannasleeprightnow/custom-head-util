#ifndef OPTIONS_H
#define OPTIONS_H

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>

#include "errors.h"

typedef struct {
    int c, n, q, v, z;
    int count_filenames;
    char **filenames;
} Options;

int parsing_options(int argc, char *argv[], Options *options);

#endif