CC=riscv32-unknown-elf-gcc
OBJCOPY=riscv32-unknown-elf-objcopy

STACK_SIZE=$$((4*1024))

# Use this for a single BRAM
# no special linker script is needed.
#BRAM_ADDR=0x00020000
#BRAM_SIZE=$$((64*1024))
#CFLAGS=-Xlinker --defsym=__mem_addr=$(BRAM_ADDR) \
#	-Xlinker --defsym=__mem_size=$(BRAM_SIZE)

# Use this for two separate BRAMs
IBRAM_ADDR=0x00020000
IBRAM_SIZE=$$((32 * 1024))
DBRAM_SIZE=$$((32 * 1024))
DBRAM_ADDR_DEC=$$(($(IBRAM_ADDR) + $(IBRAM_SIZE)))
DBRAM_ADDR=$(shell printf 0x%08x $(DBRAM_ADDR_DEC))

CFLAGS=-Xlinker --defsym=__ibram_addr=$(IBRAM_ADDR) \
	-Xlinker --defsym=__dbram_addr=$(DBRAM_ADDR) \
	-Xlinker --defsym=__ibram_size=$(IBRAM_SIZE) \
	-Xlinker --defsym=__dbram_size=$(DBRAM_SIZE) \
	-Ofast \
	-T separate-brams.ld -g

CFLAGS+=-Xlinker --defsym=__stack_size=$(STACK_SIZE) \
	--specs=picolibc.specs \
	-march=rv32ima \
	-mabi=ilp32 \
	-I/home/robert/Documents/src/rdDSP/xilinx/linux-kernel/linux-xlnx-2023.1/include/prism \
	-D__freestanding__

CFLAGS+=-D__prism_sp__
SP_CFLAGS=$(CFLAGS) -DPRISM_SP_IRQ_SPLITHARD
SP_RX_CFLAGS=-D__prism_sp_rx__ $(SP_CFLAGS)
SP_TX_CFLAGS=-D__prism_sp_tx__ $(SP_CFLAGS)

LDFLAGS=-Wl,--print-memory-usage

#
# dev variant
#
SP_RX_TARGET=prism-sp-rx-firmware
SP_RX_OBJDIR=obj/$(SP_RX_TARGET)
SP_TX_TARGET=prism-sp-tx-firmware
SP_TX_OBJDIR=obj/$(SP_TX_TARGET)

HEADERS:=src/sp.h \
	src/uart.h \
	src/uartlite.h \
	src/gem.h

SP_RX_C_SRCS=src/sp-common.c \
	src/sp-rx-demo.c \
	src/sp-rx.c \
	src/uart.c \
	src/uartlite.c \
	src/picolibc_support.c
SP_RX_OBJS=$(SP_RX_C_SRCS:src/%.c=$(SP_RX_OBJDIR)/%.o)

SP_TX_C_SRCS=src/sp-common.c \
	src/sp-tx-demo.c \
	src/sp-tx.c \
	src/uart.c \
	src/uartlite.c \
	src/picolibc_support.c
SP_TX_OBJS=$(SP_TX_C_SRCS:src/%.c=$(SP_TX_OBJDIR)/%.o)

#
# Top-level targets
#
.PHONY: all
all: sp-dev

.PHONY: sp-dev
sp-dev: objdirs $(SP_RX_TARGET).elf $(SP_TX_TARGET).elf

.PHONY: objdirs
objdirs:
	@mkdir -p $(SP_RX_OBJDIR)
	@mkdir -p $(SP_TX_OBJDIR)

#
# Make flat binary files from ELF files
# SP desc
$(SP_RX_TARGET).bin: $(SP_RX_TARGET).elf
	$(OBJCOPY) -O binary $< $@
$(SP_TX_TARGET).bin: $(SP_TX_TARGET).elf
	$(OBJCOPY) -O binary $< $@

#
# Make ELF file from object files
# SP desc
$(SP_RX_TARGET).elf: $(SP_RX_OBJS)
	echo $(SP_RX_OBJS)
	$(CC) -o $@ $(CFLAGS) $(LDFLAGS) $^
$(SP_TX_TARGET).elf: $(SP_TX_OBJS)
	$(CC) -o $@ $(CFLAGS) $(LDFLAGS) $^

#
# Make object files
#
# sp-rx
$(SP_RX_OBJDIR)/sp-rx-demo.o: src/sp-rx-demo.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
$(SP_RX_OBJDIR)/sp-common.o: src/sp-common.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
$(SP_RX_OBJDIR)/sp-rx.o: src/sp-rx.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
$(SP_RX_OBJDIR)/uart.o: src/uart.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
$(SP_RX_OBJDIR)/uartlite.o: src/uartlite.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
$(SP_RX_OBJDIR)/picolibc_support.o: src/picolibc_support.c $(HEADERS)
	$(CC) $(SP_RX_CFLAGS) -c -o $@ $<
# sp-tx
$(SP_TX_OBJDIR)/sp-tx-demo.o: src/sp-tx-demo.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<
$(SP_TX_OBJDIR)/sp-common.o: src/sp-common.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<
$(SP_TX_OBJDIR)/sp-tx.o: src/sp-tx.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<
$(SP_TX_OBJDIR)/uart.o: src/uart.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<
$(SP_TX_OBJDIR)/uartlite.o: src/uartlite.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<
$(SP_TX_OBJDIR)/picolibc_support.o: src/picolibc_support.c $(HEADERS)
	$(CC) $(SP_TX_CFLAGS) -c -o $@ $<

.PHONY: clean
clean:
	rm -rf obj/* *.elf
