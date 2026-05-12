#!/bin/bash
set -o pipefail

TARGET="./head"
TEST_DIR="test_files"
ORIG="orig.txt"
MINE="mine.txt"

mkdir -p $TEST_DIR

for i in {1..100}; do
  echo "Line $i - some random text for testing"
done > $TEST_DIR/large.txt

head -c 10240 /dev/urandom > $TEST_DIR/binary.dat
printf "part1\0part2\0part3\0part4\0part5\0" > $TEST_DIR/zero.dat
: > $TEST_DIR/empty.txt
printf "Single line no newline" > $TEST_DIR/no_newline.txt
printf "L1\nL2\nL3\nL4\nL5\n" > $TEST_DIR/five_lines.txt

if command -v truncate &> /dev/null; then
  truncate -s 2G $TEST_DIR/2g_sparse.dat
elif command -v dd &> /dev/null; then
  dd if=/dev/zero bs=1M count=0 seek=2048 of=$TEST_DIR/2g_sparse.dat 2>/dev/null
fi

run_test() {
  head $1 > $ORIG 2>/dev/null
  local h_exit=$?
  $TARGET $1 > $MINE 2>/dev/null
  local m_exit=$?

  if [ "$h_exit" != "$m_exit" ]; then
    echo "FAIL: $2 (exit codes: head=$h_exit mine=$m_exit)"
    return
  fi

  if diff -q $ORIG $MINE > /dev/null 2>&1; then
    echo "PASS: $2"
  else
    echo "FAIL: $2 ($1)"
  fi
}

run_fail() {
  $TARGET $1 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "PASS: $2 (correctly failed)"
  else
    echo "FAIL: $2 (should have failed)"
  fi
}

cleanup() {
  rm -rf $TEST_DIR $ORIG $MINE
}

echo "Generating test data... done"
echo ""
echo "Running tests..."
echo ""

run_test "$TEST_DIR/large.txt" "default on large file"
run_test "$TEST_DIR/empty.txt" "default on empty file"
run_test "$TEST_DIR/no_newline.txt" "default on no-newline file"

run_test "-n 1 $TEST_DIR/large.txt" "-n 1"
run_test "-n 5 $TEST_DIR/large.txt" "-n 5"
run_test "-n 100 $TEST_DIR/large.txt" "-n 100 (all lines)"
run_test "-n 200 $TEST_DIR/large.txt" "-n 200 (more than file)"
run_test "-n 0 $TEST_DIR/large.txt" "-n 0"
run_test "--lines=5 $TEST_DIR/large.txt" "--lines=5 (long opt)"
run_test "--lines 5 $TEST_DIR/large.txt" "--lines 5 (long opt space)"

run_test "-c 1 $TEST_DIR/large.txt" "-c 1"
run_test "-c 50 $TEST_DIR/large.txt" "-c 50"
run_test "-c 0 $TEST_DIR/large.txt" "-c 0"
run_test "-c 999999 $TEST_DIR/large.txt" "-c more than file"
run_test "--bytes=20 $TEST_DIR/large.txt" "--bytes=20 (long opt)"

run_test "-c 1b $TEST_DIR/binary.dat" "suffix b (512 bytes)"
run_test "-c 1K $TEST_DIR/binary.dat" "suffix K (1024 bytes)"
run_test "-c 2K $TEST_DIR/binary.dat" "suffix 2K (2048 bytes)"
run_test "-c 1M $TEST_DIR/empty.txt" "suffix M on empty"
run_test "-c 1G $TEST_DIR/empty.txt" "suffix G on empty"

run_test "-n -5 $TEST_DIR/large.txt" "-n -5 (all but last 5)"
run_test "-n -1 $TEST_DIR/large.txt" "-n -1 (all but last line)"
run_test "-n -200 $TEST_DIR/large.txt" "-n -200 (more than file)"
run_test "-c -100 $TEST_DIR/large.txt" "-c -100 (all but last 100)"

run_test "$TEST_DIR/large.txt $TEST_DIR/binary.dat" "two files default"
run_test "$TEST_DIR/large.txt $TEST_DIR/empty.txt $TEST_DIR/binary.dat" "three files"
run_test "-q $TEST_DIR/large.txt $TEST_DIR/binary.dat" "-q quiet"
run_test "--quiet $TEST_DIR/large.txt $TEST_DIR/binary.dat" "--quiet long opt"
run_test "--silent $TEST_DIR/large.txt $TEST_DIR/binary.dat" "--silent long opt"
run_test "-v $TEST_DIR/large.txt $TEST_DIR/binary.dat" "-v verbose"
run_test "-v $TEST_DIR/large.txt" "-v single file"
run_test "-q -v $TEST_DIR/large.txt $TEST_DIR/binary.dat" "-q -v (last wins)"
run_test "-v -q $TEST_DIR/large.txt $TEST_DIR/binary.dat" "-v -q (last wins)"

run_test "-z -n 2 $TEST_DIR/zero.dat" "-z -n 2"
run_test "-z -n 10 $TEST_DIR/zero.dat" "-z -n 10 (more than records)"
run_test "-z -n 0 $TEST_DIR/zero.dat" "-z -n 0"
run_test "-z -c 10 $TEST_DIR/zero.dat" "-z -c 10"
run_test "-z -n -2 $TEST_DIR/zero.dat" "-z -n -2 (negative)"
run_test "--zero-terminated -n 2 $TEST_DIR/zero.dat" "--zero-terminated long opt"

echo "Hello World" | head -n 1 > $ORIG 2>/dev/null
echo "Hello World" | $TARGET -n 1 > $MINE 2>/dev/null
diff -q $ORIG $MINE > /dev/null 2>&1 && echo "PASS: stdin pipe" || echo "FAIL: stdin pipe"

echo "Line1\nLine2\nLine3" | head -n 2 > $ORIG 2>/dev/null
echo "Line1\nLine2\nLine3" | $TARGET -n 2 > $MINE 2>/dev/null
diff -q $ORIG $MINE > /dev/null 2>&1 && echo "PASS: stdin -n 2" || echo "FAIL: stdin -n 2"

run_test "-n 5 -c 100 $TEST_DIR/large.txt" "both -n and -c (last wins)"
run_test "-c 100 -n 5 $TEST_DIR/large.txt" "both -c and -n (last wins)"
run_test "-- $TEST_DIR/large.txt" "-- separator"
run_test "-n 2 $TEST_DIR/five_lines.txt" "-n 2 on 5-line file"

if [ -f $TEST_DIR/2g_sparse.dat ]; then
  run_test "-c 100M $TEST_DIR/2g_sparse.dat" "100MB from 2GB sparse"
  run_test "-c -1G $TEST_DIR/2g_sparse.dat" "-c -1G from 2GB (last 1G)"
fi

run_fail "-x" "invalid option"
run_fail "--unknown" "unknown long option"
run_fail "-n" "-n without argument"
run_fail "-c" "-c without argument"
run_fail "-n abc $TEST_DIR/large.txt" "-n with non-numeric"
run_fail "-c xyz $TEST_DIR/large.txt" "-c with non-numeric"
run_fail "nonexistent.txt" "non-existent file"

if command -v valgrind &> /dev/null; then
  for t in "-n 5 $TEST_DIR/large.txt" "-c 1K $TEST_DIR/binary.dat" \
           "-n -5 $TEST_DIR/large.txt" "-z -n 2 $TEST_DIR/zero.dat"; do
    valgrind --leak-check=full --error-exitcode=1 --quiet \
      $TARGET $t > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "PASS: valgrind $t"
    else
      echo "FAIL: valgrind $t"
    fi
  done
fi

cleanup
echo ""
echo "Done."
