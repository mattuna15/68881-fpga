# Standalone CMakeLists for QEMU builds (no Vitis environment needed).
# Used by qemu_build_run.ps1 instead of the Vitis-specific src/CMakeLists.txt.

cmake_minimum_required(VERSION 3.16)
project(NeXT-68040 C ASM)

# Platform BSP paths
set(BSP_INCLUDE "C:/code/68881-fpga/validation/platform-68-linux/export/platform-68-linux/sw/standalone_psu_cortexa53_0/include")
set(BSP_LIB "C:/code/68881-fpga/validation/platform-68-linux/export/platform-68-linux/sw/standalone_psu_cortexa53_0/lib")
set(LINKER_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/src/lscript.ld")

# Compile flags: QEMU_MODE + debug
add_definitions(-DQEMU_MODE -DNEXT_IO_DEBUG)
add_compile_options(-Wall -O0 -g3)
include_directories(${BSP_INCLUDE})

# Source files — build as a static library so the linker can do
# multi-pass resolution (libxilstandalone crt0 references main).
set(SOURCES
    src/main.c
    src/next_memory.c
    src/next_devs.c
    src/next_rtc.c
    src/next_dsp.c
    src/next_kms.c
    src/next_video.c
    src/next_mon_stub.c
    src/fline_handler.c
    src/fpu_periph.c
    src/fp_regfile.c
    src/cir_periph.c
    src/text_fb.c
    src/dp_video.c
    src/gfx_fb.c
    src/platform.c
    src/musashi/m68kcpu.c
    src/musashi/m68kops.c
    src/musashi/softfloat/softfloat.c
)

add_library(next68040 STATIC ${SOURCES})

target_include_directories(next68040 PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/musashi
    ${BSP_INCLUDE}
)

# Dummy source for the executable target (real code is in libnext68040.a)
file(WRITE ${CMAKE_BINARY_DIR}/_dummy.c "/* empty */\n")
add_executable(NeXT-68040.elf ${CMAKE_BINARY_DIR}/_dummy.c)

target_link_directories(NeXT-68040.elf PRIVATE ${BSP_LIB})

# All archives in --start-group so circular references resolve:
#   crt0 (in xilstandalone) -> main (in next68040)
#   m68kops (in next68040) -> emu_int_ack_callback (in next68040)
target_link_libraries(NeXT-68040.elf
    -Wl,-T -Wl,${LINKER_SCRIPT}
    -Wl,--start-group
    next68040 xilstandalone xiltimer xil gcc c m
    -Wl,--end-group
)
