#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define XDMA_USER_DEV "/dev/xdma0_user"
#define XDMA_HBM_WRITE "/dev/xdma0_h2c_*"
#define XDMA_HBM_READ "/dev/xdma0_c2h_*"

#define MAP_SIZE      4096        // Matches AXI-Lite BAR size
#define REG_OFFSET    0x0         // slv_reg0

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("Usage: %s <pattern>\n", argv[0]);
        return 1;
    }

    uint32_t pattern = atoi(argv[1]);

    int fd = open(XDMA_USER_DEV, O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    void *map = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
                     MAP_SHARED, fd, 0);

    if (map == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }

    volatile uint32_t *regs = (volatile uint32_t *)map;

    // Write pattern to slv_reg0
    regs[REG_OFFSET / 4] = pattern;

    printf("Wrote pattern %u to AXI-Lite register 0x%x\n",
           pattern, REG_OFFSET);

    munmap(map, MAP_SIZE);
    close(fd);
    return 0;
}
