# TMS570LS1224 GCC Build Environment
 
A reproducible, containerised cross-compilation environment for the Texas Instruments TMS570LS1224 (Cortex-R4F, big-endian) on Linux.
 
 
## Background
 
The TMS570LS1224 runs in **big-endian mode**. Prebuilt `arm-none-eabi-gcc` distributions (from Arch, Ubuntu, ARM's own releases, etc.) ship runtime libraries compiled for little-endian only. Linking with `-mbig-endian` against those libraries fails with errors like:
 
```
crti.o: compiled for a little endian system and target is big endian
```
 
Our solution is to build a custom GCC toolchain whose runtime libraries (`libgcc`, `newlib`, `crt0`, etc.) are compiled big-endian from the start. This guide packages that toolchain inside a Docker image so the build environment is isolated, reproducible, and portable.
 
## Prerequisites
 
- Docker installed and running
- HalCoGen installed (Windows/Linux) to generate peripheral driver code
 
## Repository Layout
 
```
your-repo/
├── Dockerfile
├── source/
│   ├── *.c          ← HalCoGen generated + your own C files
│   ├── *.s          ← HalCoGen generated assembly (must be .s, not .asm)
│   └── sys_link.ld  ← HalCoGen generated linker script
├── include/
│   └── *.h          ← HalCoGen generated headers
└── Makefile
```

## HalCoGen Setup
 
Before generating code, in HalCoGen go to **Tools → GCC Tools** and make sure that option is selected. This ensures the assembler files are generated as `.s` (GCC syntax) rather than `.asm` (TI syntax). The `.asm` files will produce thousands of errors with GCC.
 
After selecting GCC Tools, regenerate all files.
 
## File Contents
 
### Dockerfile
 
Builds a two-stage Docker image. Stage 1 compiles binutils, GCC, and newlib from source with big-endian flags baked in. Stage 2 is a slim final image containing only the finished toolchain.

## Building the Docker Image
 
This is a one-time step. From the repo root:
 
```bash
docker build -t tms570-toolchain .
```
 
This takes **25–35 minutes** the first time. Docker caches every layer, so subsequent builds (e.g. after changing only the Makefile) are nearly instant.
 
## Compiling Your Project
 
From your repo root every time you want to build:
 
```bash
docker run --rm -v $(pwd):/project tms570-toolchain make
```
 
- `--rm` deletes the container after it exits, keeping things tidy
- `-v $(pwd):/project` mounts your local source tree into the container
- Your compiled `firmware.elf` and `firmware.bin` will appear in your repo root on the host
 
To clean build artifacts:
 
```bash
docker run --rm -v $(pwd):/project tms570-toolchain make clean
```
 
To drop into an interactive shell for debugging:
 
```bash
docker run --rm -it -v $(pwd):/project tms570-toolchain bash
```
 
## Verifying the Output
 
Before flashing, confirm the ELF is actually big-endian:
 
```bash
docker run --rm -v $(pwd):/project tms570-toolchain arm-none-eabi-readelf -h firmware.elf | grep Data
```
 
Expected output:
 
```
Data:                              2's complement, big endian
```
 
If it says little endian, something is wrong with your flags and you should not flash it — the MCU will jump to an undefined instruction immediately on boot.
 
## Key Compiler Flags
 
| Flag | Reason |
|---|---|
| `-mcpu=cortex-r4` | Exact CPU core on TMS570LS1224 |
| `-mfpu=vfpv3-d16` | FPU present on Cortex-R4F |
| `-mfloat-abi=hard` | Use FPU registers for float args/return values |
| `-mbig-endian` | TMS570 operates in big-endian mode |
| `-marm` | Reset vector executes in ARM state, not Thumb |
| `-nostartfiles` | HalCoGen provides its own startup/intvecs assembly |
 
## Notes
 
- **Do not use `-mthumb` at the top level.** The TMS570 boots in ARM state and HalCoGen's `sys_intvecs.s` is written in ARM state. Mixing ARM and Thumb without explicit interworking stubs causes the same "undefined instruction" crash as the endianness bug.
- **`-lnosys`** stubs out syscalls (`_write`, `_read`, `_sbrk`, etc.) so newlib links cleanly without a full OS. If you want `printf` output over SCI/UART, implement `_write` yourself to redirect to the SCI driver.
- The toolchain image is self-contained. You can push it to a registry (Docker Hub, GHCR, etc.) and pull it on any machine without rebuilding.
- Special thank you to [this repo](https://github.com/josepablo134/TMS570CTemplate?tab=readme-ov-file).
