CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c99
SRC_DIR = src
SOURCES = $(SRC_DIR)/main.c $(SRC_DIR)/options.c $(SRC_DIR)/errors.c
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

re: clean all

.PHONY: all clean run re