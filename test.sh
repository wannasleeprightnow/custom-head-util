#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TARGET="./head"
TEST_DIR="test_files"
ORIG_OUT="orig_out.txt"
MY_OUT="my_out.txt"

echo "--- Preparing test data ---"
mkdir -p $TEST_DIR
for i in {1..100}; do echo "Line $i - some random text for testing" >> "$TEST_DIR/large.txt"; done
head -c 10240 /dev/urandom > "$TEST_DIR/binary.dat"
printf "part1\0part2\0part3\0part4\0part5\0" > "$TEST_DIR/zero.dat"

run_test() {
    local args=$1
    local name=$2
    
    echo -n "Test $name ($args): "

    head $args > $ORIG_OUT 2>/dev/null
    $TARGET $args > $MY_OUT 2>/dev/null
    
    if diff $ORIG_OUT $MY_OUT > /dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "Check diff: diff $ORIG_OUT $MY_OUT"
    fi
}

echo -e "\n--- Functional Tests ---"
run_test "-n 5 $TEST_DIR/large.txt" "Simple lines"
run_test "-c 20 $TEST_DIR/large.txt" "Simple bytes"
run_test "-n 15 -q $TEST_DIR/large.txt $TEST_DIR/binary.dat" "Multiple files Quiet"
run_test "-v -n 3 $TEST_DIR/large.txt" "Verbose single file"
run_test "-c 1K $TEST_DIR/large.txt" "Suffixes (K)"
run_test "-c 1b $TEST_DIR/binary.dat" "Suffixes (b)"
run_test "-z -n 2 $TEST_DIR/zero.dat" "Zero terminated"

echo -e "\n--- Negative Values (GNU Style) ---"
run_test "-n -95 $TEST_DIR/large.txt" "All except last 95 lines"
run_test "-c -1000 $TEST_DIR/large.txt" "All except last 1000 bytes"

echo -e "\n--- STDIN Tests ---"
echo "Hello World" | $TARGET -n 1 > $MY_OUT
echo "Hello World" | head -n 1 > $ORIG_OUT
if diff $ORIG_OUT $MY_OUT; then echo -e "Stdin: ${GREEN}PASS${NC}"; else echo -e "Stdin: ${RED}FAIL${NC}"; fi

echo -e "\n--- Memory Leak Check (Valgrind) ---"
if command -v valgrind &> /dev/null; then
    valgrind --leak-check=full --error-exitcode=1 --quiet $TARGET -n -5 $TEST_DIR/large.txt > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}NO LEAKS FOUND${NC}"
    else
        echo -e "${RED}MEMORY LEAKS OR ERRORS DETECTED${NC}"
    fi
else
    echo "Valgrind not found, skipping..."
fi

rm -rf $TEST_DIR $ORIG_OUT $MY_OUT
echo -e "\n--- Cleanup done ---"