#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define CTRL_ADDR   0x0          // AXI-Lite register controlling device state
#define TMP_FILE    "/tmp/tfhe_c.bin"

#define DMA_TO_DEVICE "/home/fpga/Documents/dma_ip_drivers/XDMA/linux-kernel/tools/dma_to_device"

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("Usage: %s <pattern_id>\n", argv[0]);
        printf("Example: %s 3\n", argv[0]);
        return 1;
    }

    uint32_t pattern = (uint32_t)atoi(argv[1]);

    // Write pattern to temporary file
    FILE *f = fopen(TMP_FILE, "wb");
    if (!f) {
        perror("Cannot create temp file");
        return 1;
    }

    fwrite(&pattern, sizeof(pattern), 1, f);
    fclose(f);

    char cmd[256];
    snprintf(cmd, sizeof(cmd),
        "sudo  %s -d /dev/xdma0_user -a %u -f %s -s 4",
        DMA_TO_DEVICE, CTRL_ADDR, TMP_FILE);

    printf("Sending control instruction %u...\n", pattern);
    printf("CMD: %s\n", cmd);

    int ret = system(cmd);
    if (ret != 0) {
        printf("dma_to_device failed\n");
        return 1;
    }

    printf("Instruction sent successfully!\n");
    return 0;
}