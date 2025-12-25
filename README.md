
# Open-Source TFHE Accelerator (tfhe-PU)

<img align="right" width="400" height="auto" alt="" src="images/tfhe-proc.png"/> This repository accompanies the paper [**“Towards a Functionally Complete and Parameterizable TFHE Processor”**]().  
The design is written in a mix of **VHDL** and **SystemVerilog**, compatible with **Vivado 2024.1**.
This is a fully fledged, parameterizable TFHE processor that connects via PCIe, enabling scalable, hardware-accelerated computation directly on encrypted data, achieving 240-480% higher bootstrapping throughput than current state-of-the-art designs. Hopefully, this will lay the foundation for the next generation of TFHE processors - moving us closer to practical, high-performance encrypted computing.   

All content is for **academic research only**, provided *as is* without warranty.



## Repository Structure

- **README.md** – Project documentation and setup instructions
- **host/** – Host-side software, including control scripts and drivers for PCIe communication
- **driver/** – DMA IP drivers (submodule from Xilinx)
- **images/** – Diagrams and images used in documentation
- **src/** – Main source code directory
  - **ntt_param_computation.ipynb** – Jupyter notebook to generate roots of unity and constants for custom primes
  - **core_logic/** – NTT and TFHE arithmetic modules
  - **tfhe/** – TFHE-specific components (PBS, key switching, etc.)
  - **processor/** – Top-level processor modules
  - **testbenches/** – Simulation testbenches for verification
  - **dma/** – DMA and memory management modules
  - **secondary_code/** – Additional utilities and constraints
- **vcu_128_xdc/** – FPGA constraints for VCU128 board



## Setup Your Own tfhe-PU

Clone this repositoty and initialize the sub-modules.

```sh
git clone https://github.com/Archfx/tfhe_pu
git submodule update --init #initilize the Xilinx dma drivers repo
```

Use Vivado with an appropriate license (specifically for HBM-supported FPGAs such as VCU128).

1. Create a new project for your FPGA and import all the Verilog/SystemVerilog/VHDL modules inside the `src` folder except the modules within `testbenches`, `secondary_code`, and `deprecated` folders.
2. Add two HBM IPs (left and right stacks) from the Vivado IP catalog and configure them with the following settings:
   - Disable switch 0/ global addressing on stack 0/1
   - Set the HBM memory freaquancy for the stack 0 to 500MHZ
   - Remove the option for external `apb interface`.
   - Under reorder, refresh and power saving options, set the traffic pattern to `LINEAR`
   - Under realibility options, disable debug interface and error correction options including the write data mask.
3. Import the `tfhe_pu_bd` block diagram by running the following command in the TCL console:
   ```
   source src/processor/tfhe_pu_bd.tcl
   ```
4. Set `tfhe_pu_top` as the top module and refresh the hierarchy.
5. Synthesize, implement, generate the bitstream, and program the FPGA.
6. Follow the instructions in the README in the `host` folder for the host-side setup.
7. Enjoy the accelerated TFHE!


## NTT Overview

To use the NTT, import all VHDL files from `core_logic/` into your project.  
See `testbenches/ntt_tb.vhd` for an example testbench.

### Key Modules

- **big_arithmetic/** – Parameterized adders and multipliers with retiming support  
- **modulo_specific/** – Prime-specific modular reduction logic  
- **ntt/** – Butterfly-level through full NTT implementation  
- **constants_and_utils/** – Datatypes, constants, and utility functions (not for synthesis)  

> Note: Custom 64-bit datatypes are used since Vivado 2024.1 supports only signed 32-bit integers.

### Configurability

Defined in `ntt_configuration.vhd` and `constants_utils.vhd`:

- NTT size (power of two up to 2¹⁵+)  
- Throughput (power of two ≤ N)  
- Mode (cyclic / negacyclic)  
- Multiplication algorithm (native, Karatsuba)  
- Prime and modulo solution  
- Retiming register depth  

### Adapting for New Primes

Use `ntt_param_computation.ipynb` to generate new constants, then update `ntt_params` accordingly.  
If changing bit widths or primes, define a matching reduction in `modulo_specific/` and verify correctness via simulation (`new_ntt_tb.vhd`).



## TFHE Processor

The repository implements major TFHE modules, including **programmable bootstrapping** and **key switching**, built upon the NTT engine.  
To use them, include all VHDL files from `core_logic/`, `tfhe/`, and `processor/`.

For details on architecture and performance, see the [paper](https://arxiv.org/abs/2510.23483).


## Measurements

When evaluating frequency or resource usage, review Vivado implementation warnings — especially for Karatsuba multipliers and mid-stage optimizations in the negacyclic NTT.


## Contributing

We welcome contributions that improve performance, clarity, or modularity.  
Please avoid hardcoded constants to maintain flexibility across parameter sets.



## Citation

```tex
@misc{häusler2025functionally,
      title={Towards a Functionally Complete and Parameterizable TFHE Processor}, 
      author={Valentin Reyes Häusler and Gabriel Ott and Aruna Jayasena and Andreas Peter},
      year={2025},
      eprint={2510.23483},
      archivePrefix={arXiv},
      primaryClass={cs.CR},
      url={https://arxiv.org/abs/2510.23483}, 
}
```

# License
This project is licensed under MIT.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.