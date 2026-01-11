### Compile the driver

```sh
cd driver/dma_ip_drivers/XDMA/linux-kernel/xdma/
sudo make install
sudo modprobe xdma # will need to execute on reboot if not added permenanlty to the kernel
cd driver/dma_ip_drivers/XDMA/linux-kernel/tools/
make
```


## Control and Status Register

```sh
Control / Status Register (slv_reg0) — 32 bits
+----+----+----+----+----+----+----+----+----+----+----+-----+
| 31    ----      8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0  |                        
|----- RESERVED ----|RD1 |WR1 |RD0 |WR0 | RS |DONE|BUSY|START|
+----+----+----+----+----+----+----+----+----+----+----+-----+
```
### Control and Status
- Bit 0  : START  - Start PBS operation (write 1 to trigger)
- Bit 1  : BUSY   - PBS engine is busy (read-only)
- Bit 2  : DONE   - PBS operation completed (sticky, cleared on START)
- Bit 3  : RS     - Reserved

### Write/ Read select for HBM <--> TFHE processor (defaults to HOST)
- Bit 4  : WR0    - HBM write select, TFHE_PU if `1` vs Host if `0` (Stack 0)
- Bit 5  : RD0    - HBM read  select, TFHE_PU if `1` vs Host if `0` (Stack 0)
- Bit 6  : WR1    - HBM write select, TFHE_PU if `1` vs Host if `0` (Stack 1)
- Bit 7  : RD1    - HBM read  select, TFHE_PU if `1` vs Host if `0` (Stack 1)

### Reserved for future use
- Bits 31:8 : Reserved (must be written as 0)


## Setting the control register

First compile the controller

```sh
make
```

Then configure the processor controller
```sh
sudo ./reg_rw /dev/xdma0_user 0x0 0x00000000 # Host has access to HBM stacks or change the register value accordig to the above register map
```

## Test the HBM channles from host side

```sh
chmod +x dma_test.sh
sudo ./dma_test.sh
```