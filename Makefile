CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c99 -pedantic -O2
SRC_DIR = src
ALL_FILES = src/*.c src/*.h
SOURCES = $(SRC_DIR)/main.c $(SRC_DIR)/options.c $(SRC_DIR)/errors.c $(SRC_DIR)/output.c
OBJECTS = $(SOURCES:.c=.o)
TARGET = head

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(SRC_DIR)/*.o $(TARGET)

run: $(TARGET)
	./$(TARGET) test_data/test1.txt

format: check_format edit_format

check_format:
	clang-format -style=Google -n $(ALL_FILES)

edit_format:
	clang-format -style=Google -i $(ALL_FILES)

test: $(TARGET)
	@chmod +x test.sh
	./test.sh

re: clean all

.PHONY: all clean run re test format edit_format check_format