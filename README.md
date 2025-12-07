# RISC-V Vector Extension Implementation for Accelerating Vectorized Operations

This project focuses on extending the open-source [biRISC-V core](https://github.com/ultraembedded/biriscv) by implementing a subset of the RVVE (RISC-V Vector Extension) reducing the complexity. Given the complexity and resource demands of a full RVVE implementation, this project prioritizes fundamental vector operations. The project aims to show that vectorized calculations may be performed on hardware with limited resources while still being compatible with the RISC-V specifications. Work in progress. 

---

## Testing Phase  
To test the implementation follow these steps:  

### 1. Write RISC-V Assembly Code  
Create a `.s` file containing the RISC-V assembly code you want to test.  

### 2. Assemble the Code
Use the GNU RISC-V toolchain to assemble your .s file into an object file (.o). Ensure that RVVE support is enabled and compressed instructions are disabled.

```assembly
riscv32-unknown-elf-as -march=rv32gv -mno-relax your_test.s -o your_test.o
```
### 3. Link to Create an ELF File
Convert the object file (.o) into an ELF file (.elf) using the linker:

```assembly
riscv32-unknown-elf-ld your_test.o -o your_test.elf
```

### 4. Inspect the ELF File (Optional)
You can disassemble and inspect the ELF file to ensure it is generated correctly:

```assembly
riscv32-unknown-elf-objdump -d your_test.elf
```

### 5. Run the Testbench  

  The testbench folder includes the following fíles:
  1. **Verilog Testbench Files:** These simulate the behavior of the processor and verify its output against the expected results.
  2. **Makefile:** Automates the compilation and simulation process.
  3. **GTKWave Settings:** A pre-configured gtksettings file for viewing specific signals in the waveform.

The testbench requires these files for waveform visualization. Follow these steps:  

1. **Prepare the ELF File**  

   Place the `your_test.elf` file you generated into the appropriate testbench folder. For example, you can use `tb/tb_core_icarus` or another folder depending on the test scenario or you can create your own folder.  
2. **Update the Makefile**  

   Do not forget to update the `ELF_FILE` variable in the `Makefile` to match the name of your ELF file:
   ```makefile
   ELF_FILE ?= your_test.elf
   ```
3. **Clean Old Files** 

   Before running a new simulation clean up older files by running the following command:
   ```bash
   make clean
   ```
3. **Run the Simulation**  

   Use the `Makefile` in the testbench folder to compile the simulation and generate waveform files:  
   ```bash
   make
   ```
4. **View the Waveform** 

   After running the simulation, use GTKWave to analyze the generated .vcd waveform files. This can be done using the make view command:
   ```bash
   make view
   ```


