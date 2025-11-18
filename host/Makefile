# Compiler and flags
CC      = gcc
CFLAGS  = -Wall -O2

# Target program
TARGET  = control

# Source files
SRCS    = control.c

# Build rule
$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRCS)

# Clean rule
clean:
	rm -f $(TARGET)

.PHONY: clean
