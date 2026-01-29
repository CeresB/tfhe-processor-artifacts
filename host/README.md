### Compile the driver

```sh
cd driver/dma_ip_drivers/XDMA/linux-kernel/xdma/
sudo make install
sudo modprobe xdma # will need to execute on reboot if not added permanently to the kernel
cd ../tools/
make
```

## Setting the control register

First compile the controller

```sh
cd ../../../../../ # navigate to top level folder
make
```

Then configure the processor controller
```sh
sudo ./control /dev/xdma0_user 0x0 0x00000000 # See section "Control and Status Register" below. Host has access to HBM stacks or change the register value accordig to the above register map
```

Please remember to restart your computer (not the fpga) after programming the fpga, such that the fpga can be detected as a pcie device. Furthermore, execute "sudo modprobe xdma" beforehand in case you did not add it to the kernel permanently.

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

### Write/ Read for HBM <--> TFHE processor
Via PCIe you have write-only access to all hbm ports. The read ports are physically not connected to PCIe.
There is one exception to this: the result channel is read-only via PCIe, the write ports are physically not connected to PCIe.
This construction allows arbiter-free usage of the HBM by PCIe host and the accelerator engine.

### Reserved for future use
- Bits 31:8 : Reserved (must be written as 0)