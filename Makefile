CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c99 -pedantic -O2
SRC_DIR = src
ALL_FILES = $(SRC_DIR)/*.c $(SRC_DIR)/*.h
SOURCES = $(SRC_DIR)/main.c $(SRC_DIR)/options.c $(SRC_DIR)/errors.c $(SRC_DIR)/output.c
OBJECTS = $(SOURCES:.c=.o)
TARGET = head

DEPS_REQUIRED = gcc make bash diff head
DEPS_OPTIONAL = valgrind clang-format truncate

.PHONY: all clean run re test test-verbose \
        format check_format edit_format deps check-deps help

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $(TARGET)

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(SRC_DIR)/*.o $(TARGET) $(TARGET)-debug *.txt
	rm -rf test_files/

run: $(TARGET)
	./$(TARGET) test_files/test1.txt

test: check-deps $(TARGET)
	@chmod +x test.sh
	./test.sh

test-verbose: check-deps $(TARGET)
	@chmod +x test.sh
	bash -x ./test.sh

re: clean all

check_format:
	clang-format -style=Google -n $(ALL_FILES)

edit_format:
	clang-format -style=Google -i $(ALL_FILES)

format: check_format edit_format

deps:
	@echo "=== Required ==="
	@for dep in $(DEPS_REQUIRED); do \
		if command -v $$dep >/dev/null 2>&1; then \
			echo "  [OK]      $$dep"; \
		else \
			echo "  [MISSING] $$dep"; \
		fi; \
	done
	@echo ""
	@echo "=== Optional ==="
	@for dep in $(DEPS_OPTIONAL); do \
		if command -v $$dep >/dev/null 2>&1; then \
			echo "  [OK]      $$dep"; \
		else \
			echo "  [MISSING] $$dep"; \
		fi; \
	done

check-deps:
	@missing=0; \
	for dep in $(DEPS_REQUIRED); do \
		if ! command -v $$dep >/dev/null 2>&1; then \
			echo "ERROR: missing required dependency: $$dep"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo ""; \
		echo "Install missing dependencies and try again."; \
		exit 1; \
	fi
	@echo "All required dependencies are present."

help:
	@echo "Targets:"
	@echo "  all              Build the head utility (default)"
	@echo "  clean            Remove object files and binaries"
	@echo "  test             Run the test suite"
	@echo "  test-verbose     Run the test suite with bash -x"
	@echo "  format           Format source code with clang-format (Google style)"
	@echo "  deps             List and check required and optional dependencies"
	@echo "  check-deps       Verify all required dependencies are installed"
	@echo "  re               Clean and rebuild"
	@echo "  help             Show this help"
