TOOLCHAIN = arm-none-eabi
CC        = $(TOOLCHAIN)-gcc
AS        = $(TOOLCHAIN)-gcc
LD        = $(TOOLCHAIN)-gcc
OBJCOPY   = $(TOOLCHAIN)-objcopy
SIZE      = $(TOOLCHAIN)-size

CPU_FLAGS = \
    -mcpu=cortex-r4 \
    -mfpu=vfpv3-d16 \
    -mfloat-abi=hard \
    -mbig-endian \
    -marm

CFLAGS  = $(CPU_FLAGS) -Os -Wall -Wextra -ffunction-sections -fdata-sections -g3
ASFLAGS = $(CPU_FLAGS) -x assembler-with-cpp
LDFLAGS = $(CPU_FLAGS) \
    -nostartfiles \
    -Wl,--gc-sections \
    -Wl,-Map=$(TARGET).map \
    -T $(LDSCRIPT)

TARGET   = firmware
LDSCRIPT = source/sys_link.ld

SRCS_C := $(wildcard source/*.c)
SRCS_S := $(wildcard source/*.s)
OBJS   := $(SRCS_C:.c=.o) $(SRCS_S:.s=.o)
DEPS   := $(OBJS:.o=.d)

INCLUDES = -Iinclude

.PHONY: all clean verify

all: $(TARGET).elf $(TARGET).bin
	$(SIZE) $(TARGET).elf

$(TARGET).elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ -lgcc -lc -lnosys

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -MMD -MP -c -o $@ $<

%.o: %.s
	$(AS) $(ASFLAGS) $(INCLUDES) -c -o $@ $<

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

verify: $(TARGET).elf
	arm-none-eabi-readelf -h $< | grep -E 'Data:|Machine:'

clean:
	rm -f $(OBJS) $(DEPS) $(TARGET).elf $(TARGET).bin $(TARGET).map

-include $(DEPS)
