# --- Makefile Actualizado ---
TARGET = tms570_project
CC = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy

SRC_DIR = source
INC_DIR = include
BUILD_DIR = build

# Buscar archivos .c Y archivos .s (ensamblador)
SOURCES_C = $(wildcard $(SRC_DIR)/*.c)
SOURCES_S = $(wildcard $(SRC_DIR)/*.s)

OBJECTS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SOURCES_C))
OBJECTS += $(patsubst $(SRC_DIR)/%.s, $(BUILD_DIR)/%.o, $(SOURCES_S))

# Flags corregidos (softfp para evitar el error de VFP)
CFLAGS = -mcpu=cortex-r4f -marm -mfloat-abi=softfp -mfpu=vfpv3-d16 -I$(INC_DIR) -O0 -g -Wno-attributes
LDFLAGS = -T $(SRC_DIR)/sys_link.ld -Wl,--gc-sections -nostartfiles --specs=nosys.specs --specs=nano.specs -Wl,--no-warn-rwx-segments

all: $(BUILD_DIR)/$(TARGET).elf

# Regla para archivos .c
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Regla para archivos .S (NUEVA)
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@
	$(OBJCOPY) -O binary $@ $(BUILD_DIR)/$(TARGET).bin
	@echo --- COMPILACION EXITOSA ---

clean:
	@if exist $(BUILD_DIR) rd /s /q $(BUILD_DIR)