/*
 * Copyright (c) 2021-2024 Robert Drehmel
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#include "mmio.h"
#include "csr.h"
#include "uart.h"
#include "gem.h"
#include "sp.h"

#define DEBUG

#define SYSTEM_ADDR_WIDTH				40
#define TX_COOKIE_ADDR_BITN				0
#define TX_COOKIE_ADDR_WIDTH			SYSTEM_ADDR_WIDTH
#define TX_COOKIE_DATA_ADDR_BITN		(TX_COOKIE_ADDR_BITN + TX_COOKIE_ADDR_WIDTH)
#define TX_COOKIE_DATA_ADDR_WIDTH		SYSTEM_ADDR_WIDTH
#define TX_COOKIE_SIZE_BITN				(TX_COOKIE_DATA_ADDR_BITN + TX_COOKIE_DATA_ADDR_WIDTH)
#define TX_COOKIE_SIZE_WIDTH			14
#define TX_COOKIE_WRAP_BITN				(TX_COOKIE_SIZE_BITN + TX_COOKIE_SIZE_WIDTH)
#define TX_COOKIE_WRAP_WIDTH			1
#define TX_COOKIE_EOF_BITN				(TX_COOKIE_WRAP_WIDTH + TX_COOKIE_WRAP_WIDTH)
#define TX_COOKIE_EOF_WIDTH				1
#define TX_COOKIE_NOCRC_BITN			(TX_COOKIE_NOCRC_WIDTH + TX_COOKIE_NOCRC_WIDTH)
#define TX_COOKIE_NOCRC_WIDTH			1

void prism_print_caching(void);
void load_tx_config(void);

int
main()
{
	int core_index = sp_load_reg(SP_REGN_INFO) & 0xf;

	/*
	 * Make sure that we reliably output on the peripheral uart.
	 */
	uart_init();

	printf("----\n");
	printf("Stream Processor/GEM TX AOHW24 firmware version 0.7\n");
	printf("Running on core=%d\n", core_index);
	printf("----\n");
	printf("Waiting for start signal.\n");

	/*
	 * Set Enable_snoops in the Snoop_Control_Register_S3.
	 */
	mmio_write((void *)0xfd6e0000, 0x4000, 0x1);

	uint32_t enable_bits = 1 << SP_CONTROL_ENABLE_BITN;
	uint32_t x;
	do {
		x = sp_load_reg(SP_REGN_CONTROL);
	} while ((x & enable_bits) != enable_bits);
	printf("Received start signal.\n");

	prism_print_caching();

	printf("----\n");
	printf("Fetching private DMA configuration.\n");
	load_tx_config();

	int pkt = 0;
	for (;;) {
		while (sp_puzzle_fifo_0_empty()) {
		}
		uint32_t x0 = sp_puzzle_fifo_0_pop_uint32();
		uint32_t x1 = sp_puzzle_fifo_0_pop_uint32();
		uint32_t x2 = sp_puzzle_fifo_0_pop_uint32();
		uint32_t x3 = sp_puzzle_fifo_0_pop_uint32();

		printf("[0x%08x %08x %08x %08x]\n", x3, x2, x1, x0);
		printf("TX job %06d: addr[%02x%08x] data_addr[%04x%06x] size[%03d]%s%s%s\n",
			pkt,
			x1 & 0xff, x0,
			x2 & 0xffff, (x1 >> 8),
			(x2 >> 16) & ((1 << TX_COOKIE_SIZE_WIDTH) - 1),
			((x2 >> (16 + TX_COOKIE_SIZE_WIDTH)) & 0x1) ? " wrap" : "",
			((x2 >> (16 + TX_COOKIE_SIZE_WIDTH)) & 0x2) ? " eof" : "",
			(x3 & 0x1) ? " nocrc" : "");
		pkt++;

		while (sp_puzzle_fifo_1_full()) {
		}
		sp_puzzle_fifo_1_push_uint32(x0);
		sp_puzzle_fifo_1_push_uint32(x1);
		sp_puzzle_fifo_1_push_uint32(x2);
		sp_puzzle_fifo_1_push_uint32(x3);
	}

	return 0;
}
