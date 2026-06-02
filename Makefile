SHELL := cmd

TARGET ?= tms570_debug_test.out
BUILDDIR ?= .dist
TI_CGT_ARM ?= C:/ti/ti-cgt-arm_20.2.7.LTS

CC := armcl
HEX := armhex

DEVICE := 7R4
ENDIAN := big

INCLUDE_DIRS := $(TI_CGT_ARM)/include include source
INCLUDES := $(foreach dir,$(INCLUDE_DIRS),--include_path=$(dir))
RTS_LIB := $(TI_CGT_ARM)/lib/rtsv7R4_T_be_v3D16_eabi.lib

COMMONFLAGS := --silicon_version=$(DEVICE) --code_state=32 --endian=$(ENDIAN) --float_support=vfpv3d16 --abi=eabi --display_error_number --diag_wrap=off
CFLAGS := $(COMMONFLAGS) $(INCLUDES) --compile_only
ASFLAGS := $(COMMONFLAGS) $(INCLUDES)
LDFLAGS := --rom_model --heap_size=0x400 --entry_point=_c_int00 --map_file=$(BUILDDIR)/$(basename $(TARGET)).map

C_SOURCES := $(wildcard source/*.c)
ASM_SOURCES := $(wildcard source/*.asm)

OBJECTS := $(patsubst source/%.c,$(BUILDDIR)/%.obj,$(C_SOURCES)) $(patsubst source/%.asm,$(BUILDDIR)/%.obj,$(ASM_SOURCES))

.PHONY: all clean hex

all: $(TARGET)

$(BUILDDIR):
	@if not exist "$(BUILDDIR)" mkdir "$(BUILDDIR)"

$(BUILDDIR)/%.obj: source/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) --output_file=$@ $<

$(BUILDDIR)/%.obj: source/%.asm | $(BUILDDIR)
	$(CC) $(ASFLAGS) --compile_only --output_file=$@ $<

$(TARGET): $(OBJECTS) source/sys_link.cmd
	$(CC) $(COMMONFLAGS) $(OBJECTS) --run_linker $(LDFLAGS) source/sys_link.cmd --library=$(RTS_LIB) --output_file=$@

hex: $(TARGET)
	$(HEX) -o $(BUILDDIR)/$(basename $(TARGET)).hex $(TARGET)

clean:
	@if exist "$(BUILDDIR)" rmdir /s /q "$(BUILDDIR)"
	@if exist "$(TARGET)" del /q "$(TARGET)"