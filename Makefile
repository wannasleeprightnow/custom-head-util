CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c99 -pedantic -O2
SRC_DIR = src
ALL_FILES = $(SRC_DIR)/*.c $(SRC_DIR)/*.h
SOURCES = $(SRC_DIR)/main.c $(SRC_DIR)/options.c $(SRC_DIR)/errors.c $(SRC_DIR)/output.c
OBJECTS = $(SOURCES:.c=.o)
TARGET = head

.PHONY: all clean run re test test-verbose valgrind \
        format check_format edit_format help

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $(TARGET)

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(SRC_DIR)/*.o $(TARGET) $(TARGET)-debug *.txt 

run: $(TARGET)
	./$(TARGET) test_files/test1.txt

test: $(TARGET)
	@chmod +x test.sh
	./test.sh

test-verbose: $(TARGET)
	@chmod +x test.sh
	bash -x ./test.sh

valgrind: $(TARGET)
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes \
		--verbose ./$(TARGET) -n 5 test_files/large.txt

re: clean all

check_format:
	clang-format -style=Google -n $(ALL_FILES)

edit_format:
	clang-format -style=Google -i $(ALL_FILES)

format: check_format edit_format

help:
	@echo "Targets:"
	@echo "  all              Build the head utility (default)"
	@echo "  clean            Remove object files and binaries"
	@echo "  test             Run the test suite"
	@echo "  test-verbose     Run the test suite with bash -x"
	@echo "  valgrind         Run valgrind memory check"
	@echo "  format           Format source code with clang-format (Google style)"
	@echo "  re              Clean and rebuild"
	@echo "  help             Show this help"
