#!/bin/bash
set -e

DMA_H2C=/dev/xdma0_h2c_0
DMA_C2H=/dev/xdma0_c2h_0

TEST_SIZE=$((100 * 1024 * 1024))   # 100 MB
CHANNEL_STRIDE=$((0x10000000))     # 256 MB per AXI channel
STACK_STRIDE=$((0x100000000))      # 4 GB per stack (16 * 256 MB)

CHANNELS_PER_STACK=16
NUM_STACKS=2

TMP_IN=/tmp/test_hbm.bin
TMP_OUT=/tmp/out_hbm.bin

OUT_XDMA=./driver/dma_ip_drivers/XDMA/linux-kernel/tools/dma_to_device
IN_XDMA=./driver/dma_ip_drivers/XDMA/linux-kernel/tools/dma_from_device

echo "Generating test pattern (${TEST_SIZE} bytes)"
head -c ${TEST_SIZE} /dev/urandom > ${TMP_IN}

for ((stack=0; stack<NUM_STACKS; stack++)); do
  echo "============================================"
  echo "Testing HBM Stack ${stack}"
  echo "============================================"

  for ((ch=0; ch<CHANNELS_PER_STACK; ch++)); do
    BASE_ADDR=$((stack * STACK_STRIDE + ch * CHANNEL_STRIDE))

    printf "\n--- Stack %d | AXI_%02d | Addr 0x%X ---\n" \
           ${stack} ${ch} ${BASE_ADDR}

    sudo ${OUT_XDMA} \
      -d ${DMA_H2C} \
      -a ${BASE_ADDR} \
      -f ${TMP_IN} \
      -s ${TEST_SIZE}

    sudo ${IN_XDMA} \
      -d ${DMA_C2H} \
      -a ${BASE_ADDR} \
      -s ${TEST_SIZE} \
      -f ${TMP_OUT}

    if cmp ${TMP_IN} ${TMP_OUT}; then
      echo "✅ PASS"
    else
      echo "❌ FAIL at Stack ${stack}, AXI_${ch}, Addr 0x$(printf "%X" ${BASE_ADDR})"
      exit 1
    fi
  done
done

echo
echo "🎉 ALL HBM CHANNELS PASSED SUCCESSFULLY 🎉"
