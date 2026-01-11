#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>

static void die(const char *msg) { perror(msg); exit(1); }

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <dev> <offset_hex> <value_hex>\n", argv[0]);
        fprintf(stderr, "Example: %s /dev/xdma0_user 0x4 0xA5A5A5A5\n", argv[0]);
        return 2;
    }

    const char *dev = argv[1];
    off_t off = (off_t)strtoull(argv[2], NULL, 0);
    uint32_t w = (uint32_t)strtoul(argv[3], NULL, 0);
    uint32_t r = 0;

    int fd = open(dev, O_RDWR | O_SYNC);
    if (fd < 0) die("open");

    if (pwrite(fd, &w, sizeof(w), off) != (ssize_t)sizeof(w)) die("pwrite");
    if (pread(fd, &r, sizeof(r), off)  != (ssize_t)sizeof(r)) die("pread");

    printf("Wrote 0x%08x, Read 0x%08x @ offset 0x%llx\n",
           w, r, (unsigned long long)off);

    close(fd);
    return (r == w) ? 0 : 1;
}
