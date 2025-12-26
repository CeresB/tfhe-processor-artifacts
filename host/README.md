### Compile the driver

```sh
cd driver/dma_ip_drivers/XDMA/linux-kernel/xdma/
sudo make install
sudo modprobe xdma
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
Bit 0  : START  - Start PBS operation (write 1 to trigger)
Bit 1  : BUSY   - PBS engine is busy (read-only)
Bit 2  : DONE   - PBS operation completed (sticky, cleared on START)
Bit 3  : RS     - Reserved

### Write/ Reas select for TFHE processor (defaults to HOST)
Bit 4  : WR0    - HBM write select, TFHE_PU vs Host (Stack 0)
Bit 5  : RD0    - HBM read  select, TFHE_PU vs Host (Stack 0)
Bit 6  : WR1    - HBM write select, TFHE_PU vs Host (Stack 1)
Bit 7  : RD1    - HBM read  select, TFHE_PU vs Host (Stack 1)

Bits 31:8 : Reserved (must be written as 0)
