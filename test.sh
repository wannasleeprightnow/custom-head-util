#!/bin/bash
set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET="./head"
TEST_DIR="test_files"
ORIG_OUT="orig_out.txt"
MY_OUT="my_out.txt"
PASS=0
FAIL=0
TOTAL=0

setup_colors() {
  if [ ! -t 1 ]; then
    GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
  fi
}

generate_test_data() {
  mkdir -p "$TEST_DIR"

  for i in {1..100}; do
    echo "Line $i - some random text for testing purposes abcdefghijklmnopqrstuvwxyz 1234567890"
  done > "$TEST_DIR/large.txt"

  head -c 10240 /dev/urandom > "$TEST_DIR/binary.dat"

  printf "part1\0part2\0part3\0part4\0part5\0" > "$TEST_DIR/zero.dat"

  : > "$TEST_DIR/empty.txt"

  echo "This is the only line" > "$TEST_DIR/single_line.txt"

  printf "Single line with no trailing newline" > "$TEST_DIR/no_newline.txt"

  printf "Hello\nWorld\nПривет\nМир\n🌍\n" > "$TEST_DIR/unicode.txt"

  local chunk
  chunk=$(python3 -c "print('A' * 5000, end='')" 2>/dev/null || \
          perl -e "print 'A' x 5000" 2>/dev/null || \
          printf '%s' "$(dd if=/dev/zero bs=5000 count=1 2>/dev/null | tr '\0' 'A')")
  printf "First line\n%s\nLast line\n" "$chunk" > "$TEST_DIR/long_line.txt"

  printf "header1\ndata1\nheader2\ndata2\nheader3\ndata3\n" > "$TEST_DIR/multi_header.txt"

  for i in {1..10}; do
    printf "Record $i\0" >> "$TEST_DIR/zero_multi.dat"
  done
}

generate_large_test_data() {
  if command -v truncate &> /dev/null; then
    truncate -s 2G "$TEST_DIR/2g_sparse.dat"
  elif command -v dd &> /dev/null; then
    dd if=/dev/zero bs=1M count=0 seek=2048 of="$TEST_DIR/2g_sparse.dat" 2>/dev/null
  fi
}

cleanup() {
  rm -rf "$TEST_DIR" "$ORIG_OUT" "$MY_OUT"
}

compare_output() {
  local args=$1
  local name=$2

  TOTAL=$((TOTAL + 1))

  head $args > "$ORIG_OUT" 2>/dev/null
  local head_exit=$?
  $TARGET $args > "$MY_OUT" 2>/dev/null
  local target_exit=$?

  if [ "$head_exit" -ne "$target_exit" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] exit codes differ: head=$head_exit target=$target_exit"
    FAIL=$((FAIL + 1))
    return
  fi

  if ! diff -q "$ORIG_OUT" "$MY_OUT" > /dev/null 2>&1; then
    echo -e "  ${RED}FAIL${NC} [$name] ($args)"
    echo "    diff orig_out.txt my_out.txt"
    FAIL=$((FAIL + 1))
    return
  fi

  echo -e "  ${GREEN}PASS${NC} [$name]"
  PASS=$((PASS + 1))
}

run_test() {
  compare_output "$1" "$2"
}

run_stdin_test() {
  local input=$1
  local args=$2
  local name=$3

  TOTAL=$((TOTAL + 1))

  echo "$input" | head $args > "$ORIG_OUT" 2>/dev/null
  local head_exit=$?
  echo "$input" | $TARGET $args > "$MY_OUT" 2>/dev/null
  local target_exit=$?

  if [ "$head_exit" -ne "$target_exit" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] exit codes differ: head=$head_exit target=$target_exit"
    FAIL=$((FAIL + 1))
    return
  fi

  if ! diff -q "$ORIG_OUT" "$MY_OUT" > /dev/null 2>&1; then
    echo -e "  ${RED}FAIL${NC} [$name] ($args)"
    echo "    diff orig_out.txt my_out.txt"
    FAIL=$((FAIL + 1))
    return
  fi

  echo -e "  ${GREEN}PASS${NC} [$name]"
  PASS=$((PASS + 1))
}

run_stdin_redirect_test() {
  local file=$1
  local args=$2
  local name=$3

  TOTAL=$((TOTAL + 1))

  head $args < "$file" > "$ORIG_OUT" 2>/dev/null
  local head_exit=$?
  $TARGET $args < "$file" > "$MY_OUT" 2>/dev/null
  local target_exit=$?

  if [ "$head_exit" -ne "$target_exit" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] exit codes differ: head=$head_exit target=$target_exit"
    FAIL=$((FAIL + 1))
    return
  fi

  if ! diff -q "$ORIG_OUT" "$MY_OUT" > /dev/null 2>&1; then
    echo -e "  ${RED}FAIL${NC} [$name] ($args)"
    echo "    diff orig_out.txt my_out.txt"
    FAIL=$((FAIL + 1))
    return
  fi

  echo -e "  ${GREEN}PASS${NC} [$name]"
  PASS=$((PASS + 1))
}

run_large_test() {
  local args=$1 name=$2

  TOTAL=$((TOTAL + 1))

  local e1 e2 h1 h2

  ( head $args 2>/dev/null; echo $? > "$TEST_DIR/.ec1" ) \
    | md5sum | cut -d' ' -f1 > "$TEST_DIR/.hash1"
  ( $TARGET $args 2>/dev/null; echo $? > "$TEST_DIR/.ec2" ) \
    | md5sum | cut -d' ' -f1 > "$TEST_DIR/.hash2"

  e1=$(cat "$TEST_DIR/.ec1")
  e2=$(cat "$TEST_DIR/.ec2")
  h1=$(cat "$TEST_DIR/.hash1")
  h2=$(cat "$TEST_DIR/.hash2")

  rm -f "$TEST_DIR/.ec1" "$TEST_DIR/.ec2" "$TEST_DIR/.hash1" "$TEST_DIR/.hash2"

  if [ "$h1" = "$h2" ] && [ "$e1" = "$e2" ]; then
    echo -e "  ${GREEN}PASS${NC} [$name]"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [$name] ($args)"
    [ "$e1" != "$e2" ] && echo "    exit codes: head=$e1 target=$e2"
    [ "$h1" != "$h2" ] && echo "    hashes differ"
    FAIL=$((FAIL + 1))
  fi
}

run_expect_fail() {
  local args=$1
  local name=$2

  TOTAL=$((TOTAL + 1))

  $TARGET $args > "$MY_OUT" 2>/dev/null
  local target_exit=$?

  if [ "$target_exit" -eq 0 ]; then
    echo -e "  ${RED}FAIL${NC} [$name] expected non-zero exit, got 0"
    FAIL=$((FAIL + 1))
    return
  fi

  echo -e "  ${GREEN}PASS${NC} [$name] (correctly failed)"
  PASS=$((PASS + 1))
}

section() {
  echo ""
  echo -e "${CYAN}==== $1 ====${NC}"
}

run_tests() {
  local D="$TEST_DIR"

  # ── Default behaviour ──
  section "Default behaviour"
  run_test "$D/large.txt" "default -n 10 on large.txt"
  run_test "$D/single_line.txt" "default on single line"
  run_test "$D/empty.txt" "default on empty file"
  run_test "$D/no_newline.txt" "default on file without trailing newline"
  run_test "$D/binary.dat" "default on binary file"

  # ── -n flag ──
  section "-n / --lines flag"
  run_test "-n 1 $D/large.txt" "-n 1"
  run_test "-n 5 $D/large.txt" "-n 5"
  run_test "-n 99 $D/large.txt" "-n 99 (nearly all lines)"
  run_test "-n 100 $D/large.txt" "-n 100 (exactly all lines)"
  run_test "-n 200 $D/large.txt" "-n 200 (more lines than file has)"
  run_test "-n 0 $D/large.txt" "-n 0 (zero lines)"
  run_test "--lines=5 $D/large.txt" "--lines=5 (long option)"
  run_test "--lines 5 $D/large.txt" "--lines 5 (long option space)"

  # ── -c flag ──
  section "-c / --bytes flag"
  run_test "-c 1 $D/large.txt" "-c 1 (single byte)"
  run_test "-c 10 $D/large.txt" "-c 10 (small read)"
  run_test "-c 500 $D/large.txt" "-c 500"
  run_test "-c 0 $D/large.txt" "-c 0 (zero bytes)"
  run_test "-c 999999 $D/large.txt" "-c large (more bytes than file)"
  run_test "--bytes=20 $D/large.txt" "--bytes=20 (long option)"
  run_test "--bytes 20 $D/large.txt" "--bytes 20 (long option space)"

  # ── Suffixes ──
  section "Suffixes (b, K, k, M, m)"
  run_test "-c 1b $D/binary.dat" "suffix b (512 bytes)"
  run_test "-c 2b $D/binary.dat" "suffix b x2 (1024 bytes)"
  run_test "-c 1K $D/binary.dat" "suffix K (1024 bytes)"
  run_test "-c 2K $D/binary.dat" "suffix 2K (2048 bytes)"
  run_test "-c 1k $D/binary.dat" "suffix k (lowercase)"
  run_test "-c 1M $TEST_DIR/empty.txt" "suffix M (empty file)"
  run_test "-c 1G $TEST_DIR/empty.txt" "suffix G"

  # ── Negative values ──
  section "Negative values (print all but last N)"
  run_test "-n -5 $D/large.txt" "-n -5 (all but last 5 lines)"
  run_test "-n -1 $D/large.txt" "-n -1 (all but last line)"
  run_test "-n -99 $D/large.txt" "-n -99 (all but last 99 lines)"
  run_test "-n -200 $D/large.txt" "-n -200 (negative larger than file)"
  run_test "-c -100 $D/large.txt" "-c -100 (all but last 100 bytes)"
  run_test "-c -1 $D/binary.dat" "-c -1 (all but last byte, binary)"

  # ── Multiple files ──
  section "Multiple files"
  run_test "$D/large.txt $D/binary.dat" "two files default"
  run_test "$D/large.txt $D/binary.dat $D/empty.txt" "three files (middle empty)"
  run_test "-n 3 $D/large.txt $D/binary.dat" "two files -n 3"
  run_test "-q -n 3 $D/large.txt $D/binary.dat" "two files quiet"
  run_test "--quiet -n 3 $D/large.txt $D/binary.dat" "two files --quiet"
  run_test "--silent -n 3 $D/large.txt $D/binary.dat" "two files --silent"
  run_test "-v -n 2 $D/large.txt" "verbose single file"
  run_test "-v -n 2 $D/large.txt $D/binary.dat" "verbose two files"
  run_test "--verbose -n 2 $D/large.txt" "--verbose single file"
  run_test "-q -v -n 2 $D/large.txt $D/binary.dat" "-q with -v (v wins)"
  run_test "-v -q -n 2 $D/large.txt $D/binary.dat" "-v with -q (last wins)"

  # ── Zero-terminated ──
  section "Zero-terminated (-z)"
  run_test "-z -n 2 $D/zero.dat" "-z -n 2"
  run_test "-z -n 3 $D/zero.dat" "-z -n 3"
  run_test "-z -n 10 $D/zero.dat" "-z -n 10 (more records than exist)"
  run_test "-z -n 0 $D/zero.dat" "-z -n 0"
  run_test "-z -c 10 $D/zero.dat" "-z -c 10"
  run_test "-z -n -2 $D/zero.dat" "-z -n -2 (negative with zero-term)"
  run_test "--zero-terminated -n 2 $D/zero.dat" "--zero-terminated long option"
  run_test "-z -n 5 $D/zero_multi.dat" "-z on 10-record file -n 5"
  run_test "-z -n -3 $D/zero_multi.dat" "-z negative on 10-record file"

  # ── STDIN ──
  section "STDIN tests"
  run_stdin_test "Hello World" "-n 1" "stdin pipe -n 1"
  run_stdin_test "Line1\nLine2\nLine3\nLine4\nLine5" "-n 3" "stdin pipe -n 3"
  run_stdin_test "Hello World" "-c 5" "stdin pipe -c 5"
  run_stdin_test "A\0B\0C\0D\0E\0" "-z -n 3" "stdin pipe -z -n 3"
  run_stdin_test "Line1\nLine2\nLine3" "" "stdin pipe default"
  run_stdin_redirect_test "$D/large.txt" "-n 5" "stdin redirect -n 5"
  run_stdin_redirect_test "$D/binary.dat" "-c 100" "stdin redirect -c 100"
  run_stdin_redirect_test "$D/empty.txt" "-n 1" "stdin redirect empty file"

  # ── Edge cases ──
  section "Edge cases"
  run_test "-n 5 -c 100 $D/large.txt" "both -n and -c (last wins: -c)"
  run_test "-c 100 -n 5 $D/large.txt" "both -c and -n (last wins: -n)"
  run_test "-- $D/large.txt" "-- then file"
  run_test "$D/no_newline.txt" "file without trailing newline (default)"
  run_test "-n 1 $D/no_newline.txt" "-n 1 on file without trailing newline"
  run_test "$D/unicode.txt" "unicode file default"
  run_test "-n 3 $D/unicode.txt" "-n 3 on unicode file"
  run_test "$D/long_line.txt" "very long line default"
  run_test "-n 1 $D/long_line.txt" "-n 1 on file with very long line"
  run_test "-n 2 $D/long_line.txt" "-n 2 on file with very long line"
  run_test "$D/single_line.txt" "single line file default"
  run_test "-c 5 $D/single_line.txt" "-c 5 on single line"
  run_test "-c 5 $D/no_newline.txt" "-c 5 on no-newline file"

  # ── Large files (multi-GB via sparse file) ──
  section "Large files (multi-GB)"
  if [ -f "$D/2g_sparse.dat" ]; then
    run_large_test "-c 100M $D/2g_sparse.dat" "-c 100M on 2GB sparse"
    run_large_test "-c 500M $D/2g_sparse.dat" "-c 500M on 2GB sparse"
    run_large_test "-c -1G $D/2g_sparse.dat" "-c -1G from 2GB sparse (last 1G neg)"
  else
    echo -e "  ${YELLOW}SKIP${NC} large file section (truncate/dd not available)"
  fi

  # ── Error handling ──
  section "Error handling"
  run_expect_fail "-x" "invalid option"
  run_expect_fail "--unknown" "unknown long option"
  run_expect_fail "-n" "-n without argument"
  run_expect_fail "-c" "-c without argument"
  run_expect_fail "-n abc $D/large.txt" "-n with non-numeric argument"
  run_expect_fail "-c xyz $D/large.txt" "-c with non-numeric argument"
  run_expect_fail "-n 5x $D/large.txt" "-n with invalid suffix"
  run_expect_fail "-c 5z $D/large.txt" "-c with invalid suffix"
  run_expect_fail "nonexistent.txt" "non-existent file"
  run_expect_fail "-n -5 nonexistent.txt" "non-existent file with options"

  # ── Memory check (Valgrind) ──
  section "Memory leak check"
  if command -v valgrind &> /dev/null; then
    TOTAL=$((TOTAL + 1))
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET -n 5 $D/large.txt > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "  ${GREEN}PASS${NC} [valgrind -n 5 large.txt]"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [valgrind -n 5 large.txt]"
      FAIL=$((FAIL + 1))
    fi

    TOTAL=$((TOTAL + 1))
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET -c 1K $D/binary.dat > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "  ${GREEN}PASS${NC} [valgrind -c 1K binary.dat]"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [valgrind -c 1K binary.dat]"
      FAIL=$((FAIL + 1))
    fi

    TOTAL=$((TOTAL + 1))
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET -n -5 $D/large.txt > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "  ${GREEN}PASS${NC} [valgrind -n -5 (negative)]"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [valgrind -n -5 (negative)]"
      FAIL=$((FAIL + 1))
    fi

    TOTAL=$((TOTAL + 1))
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET -z -n 2 $D/zero.dat > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "  ${GREEN}PASS${NC} [valgrind -z -n 2 zero.dat]"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [valgrind -z -n 2 zero.dat]"
      FAIL=$((FAIL + 1))
    fi

    TOTAL=$((TOTAL + 1))
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET $D/large.txt $D/binary.dat $D/empty.txt > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "  ${GREEN}PASS${NC} [valgrind multiple files]"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [valgrind multiple files]"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "  ${YELLOW}SKIP${NC} [valgrind not found]"
  fi
}

main() {
  setup_colors

  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   custom-head-util test suite          ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"

  echo -e "\n${YELLOW}Generating test data...${NC}"
  generate_test_data
  generate_large_test_data

  echo -e "\n${YELLOW}Running tests...${NC}"
  run_tests

  echo -e "\n${YELLOW}Cleaning up...${NC}"
  cleanup

  echo ""
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "  ${GREEN}PASS: $PASS${NC}"
  echo -e "  ${RED}FAIL: $FAIL${NC}"
  echo -e "  TOTAL: $TOTAL"
  echo -e "${CYAN}════════════════════════════════════════${NC}"

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
