# Copyright (C) 2023-2025 Advanced Micro Devices, Inc.  All rights reserved.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
enable_language(C ASM CXX)

###    USER SETTINGS  START    ###
set(USER_COMPILE_DEFINITIONS
"SDT"
)

set(USER_UNDEFINED_SYMBOLS
"__clang__"
)

set(USER_INCLUDE_DIRECTORIES
"${CMAKE_SOURCE_DIR}"
"${CMAKE_SOURCE_DIR}/musashi"
"${CMAKE_SOURCE_DIR}/fatfs"
)

set(USER_COMPILE_SOURCES
"main.c"
"next_memory.c"
"next_devs.c"
"next_rtc.c"
"next_dsp.c"
"next_kms.c"
"next_mon_stub.c"
"next_video.c"
"fline_handler.c"
"fpu_periph.c"
"fp_regfile.c"
"cir_periph.c"
"text_fb.c"
"dp_video.c"
"gfx_fb.c"
"platform.c"
"musashi/m68kcpu.c"
"musashi/m68kops.c"
"musashi/softfloat/softfloat.c"
"next_esp.c"
"next_scsi.c"
"next_scsi_dma.c"
"fatfs/ff.c"
"fatfs/diskio.c"
"fatfs/ffsystem.c"
"fatfs/ffunicode.c"
)

set(USER_COMPILE_WARNINGS_ALL -Wall)
set(USER_COMPILE_WARNINGS_EXTRA -Wextra)
set(USER_COMPILE_WARNINGS_AS_ERRORS )
set(USER_COMPILE_WARNINGS_CHECK_SYNTAX_ONLY )
set(USER_COMPILE_WARNINGS_PEDANTIC )
set(USER_COMPILE_WARNINGS_PEDANTIC_AS_ERRORS )
set(USER_COMPILE_WARNINGS_INHIBIT_ALL )

set(USER_COMPILE_OPTIMIZATION_LEVEL -O0)
set(USER_COMPILE_OPTIMIZATION_OTHER_FLAGS )

set(USER_COMPILE_DEBUG_LEVEL -g3)
set(USER_COMPILE_DEBUG_OTHER_FLAGS )

set(USER_COMPILE_VERBOSE )
set(USER_COMPILE_ANSI )
set(USER_COMPILE_RELAXATION "-Wl,--no-relax")
set(USER_COMPILE_GARBAGE "")
set(USER_COMPILE_OTHER_FLAGS )

set(USER_LINK_NO_START_FILES )
set(USER_LINK_NO_DEFAULT_LIBS )
set(USER_LINK_NO_STDLIB )
set(USER_LINK_OMIT_ALL_SYMBOL_INFO )

set(USER_LINK_LIBRARIES
"m"
)

set(USER_LINK_DIRECTORIES
)

set(USER_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/lscript.ld")

set(USER_LINK_OTHER_FLAGS
)

###   END OF USER SETTINGS SECTION ###
###   DO NOT EDIT BEYOND THIS LINE ###

set(USER_COMPILE_OPTIONS
    " ${USER_COMPILE_WARNINGS_ALL}"
    " ${USER_COMPILE_WARNINGS_EXTRA}"
    " ${USER_COMPILE_WARNINGS_AS_ERRORS}"
    " ${USER_COMPILE_WARNINGS_CHECK_SYNTAX_ONLY}"
    " ${USER_COMPILE_WARNINGS_PEDANTIC}"
    " ${USER_COMPILE_WARNINGS_PEDANTIC_AS_ERRORS}"
    " ${USER_COMPILE_WARNINGS_INHIBIT_ALL}"
    " ${USER_COMPILE_OPTIMIZATION_LEVEL}"
    " ${USER_COMPILE_OPTIMIZATION_OTHER_FLAGS}"
    " ${USER_COMPILE_DEBUG_LEVEL}"
    " ${USER_COMPILE_DEBUG_OTHER_FLAGS}"
    " ${USER_COMPILE_VERBOSE}"
    " ${USER_COMPILE_ANSI}"
    " ${USER_COMPILE_OTHER_FLAGS}"
)
foreach(entry ${USER_UNDEFINED_SYMBOLS})
    list(APPEND USER_COMPILE_OPTIONS " -U${entry}")
endforeach()

if(USER_LINK_DIRECTORIES)
    string(REPLACE ";" "\" -L\"" _formatted_dirs "${USER_LINK_DIRECTORIES}")
    set(USER_LINK_DIRECTORIES "${_formatted_dirs}")
endif()

set(USER_LINK_OPTIONS
    " ${USER_LINKER_NO_START_FILES}"
    " ${USER_LINKER_NO_DEFAULT_LIBS}"
    " ${USER_LINKER_NO_STDLIB}"
    " ${USER_LINKER_OMIT_ALL_SYMBOL_INFO}"
    " ${USER_LINK_OTHER_FLAGS}"
)
if(("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "microblaze") OR ("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "microblaze_riscv"))
	if(USER_COMPILE_RELAXATION)
		string(FIND "${CMAKE_C_LINK_FLAGS}" "-Wl,--no-relax" POSITION)
		if(POSITION EQUAL -1)
		    set(CMAKE_C_LINK_FLAGS "  -Wl,--no-relax ${CMAKE_C_LINK_FLAGS}" CACHE STRING "CMAKE C LINK FLAGS" FORCE)
		    set(CMAKE_ASM_LINK_FLAGS "  -Wl,--no-relax ${CMAKE_ASM_LINK_FLAGS}" CACHE STRING "CMAKE ASM LINK FLAGS" FORCE)
		    set(CMAKE_CXX_LINK_FLAGS "  -Wl,--no-relax ${CMAKE_CXX_LINK_FLAGS}" CACHE STRING "CMAKE CXX LINK FLAGS" FORCE)
		endif()
	else()
		string(REPLACE "-Wl,--no-relax" "" CMAKE_C_LINK_FLAGS "${CMAKE_C_LINK_FLAGS}")
		string(REPLACE "-Wl,--no-relax" "" CMAKE_ASM_LINK_FLAGS "${CMAKE_ASM_LINK_FLAGS}")
		string(REPLACE "-Wl,--no-relax" "" CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS}")
	endif()
	if(USER_COMPILE_GARBAGE)
		string(FIND "${CMAKE_C_FLAGS}" "-ffunction-sections -fdata-sections" POSITION)
		if(POSITION EQUAL -1)
		    set(CMAKE_C_FLAGS " -ffunction-sections -fdata-sections ${CMAKE_C_FLAGS}" CACHE STRING "CMAKE C FLAGS" FORCE)
		    set(CMAKE_CXX_FLAGS " -ffunction-sections -fdata-sections ${CMAKE_CXX_FLAGS}" CACHE STRING "CMAKE CXX FLAGS" FORCE)
		    set(CMAKE_ASM_FLAGS " -ffunction-sections -fdata-sections ${CMAKE_ASM_FLAGS}" CACHE STRING "CMAKE ASM FLAGS" FORCE)
		endif()
	else()
		string(REPLACE "-ffunction-sections -fdata-sections" "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
		string(REPLACE "-ffunction-sections -fdata-sections" "" CMAKE_CXX_FLAGS "${CMAKE_ASM_FLAGS}")
		string(REPLACE "-ffunction-sections -fdata-sections" "" CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS}")
	endif()
endif()
