/*
 * Copyright (c) 2023-2024 Robert Drehmel
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
package prism_sp_config;

/*
 * Various system-wide constants
 */
localparam int REAL_SYSTEM_ADDR_WIDTH = 48;
localparam int PHYSMEM_ADDR_WIDTH = 40;
localparam int SYSTEM_ADDR_WIDTH = PHYSMEM_ADDR_WIDTH;
localparam int FIFO_MIN_WIDTH = 16;
localparam int M_AXI_ACP_DATA_WIDTH = 128;

/*
 * RX puzzle configuration
 */
localparam int USE_RX_RING_ACQUIRE = 1;
localparam int USE_RX_RING_RELEASE = 1;
localparam int USE_RX_IRQ = 1;

/*
 * TX puzzle configuration
 */
localparam int USE_TX_HWCOHERENCY = 1;
localparam int USE_TX_RING_ACQUIRE = 1;
localparam int USE_TX_RING_RELEASE = 1;
localparam int USE_TX_IRQ = 1;

/*
 * Descriptor format:
 * 1. 32 bits addr: [addr] [ctrl]
 * 2. 64 bits addr: [addr-lsb] [ctrl] [addr-msb] [unused]
 */
localparam int DMA_DESC_ADDRL_BITN = 0;
localparam int DMA_DESC_ADDRL_WIDTH = 32;
localparam int DMA_DESC_CTRL_BITN = DMA_DESC_ADDRL_BITN + DMA_DESC_ADDRL_WIDTH;
localparam int DMA_DESC_CTRL_WIDTH = 32;
localparam int DMA_DESC_ADDRH_BITN = DMA_DESC_CTRL_BITN + DMA_DESC_CTRL_WIDTH;
localparam int DMA_DESC_ADDRH_WIDTH = 32;

// These are in the CTRL field.
localparam int DMA_DESC_RX_SIZE_BITN = 0;
localparam int DMA_DESC_RX_SIZE_WIDTH = 14;
// These are in the LSBs of the ADDRL field.
localparam int DMA_DESC_RX_VALID_BITN = 0;
localparam int DMA_DESC_RX_WRAP_BITN = 1;

// These are in the CTRL field.
localparam int DMA_DESC_TX_SIZE_BITN = 0;
localparam int DMA_DESC_TX_SIZE_WIDTH = 14;
localparam int DMA_DESC_TX_EOF_BITN = 15;
localparam int DMA_DESC_TX_NOCRC_BITN = 16;
localparam int DMA_DESC_TX_WRAP_BITN = 30;
localparam int DMA_DESC_TX_VALID_BITN = 31;

/*
 * Other GEM constants
 */
localparam int GEM_RX_W_STATUS_FRAME_LENGTH_WIDTH = 14;

/*
 * GEM DMA TX descriptor
 */
localparam int GEM_DMA_TX_DESC_ADDRL_WIDTH = 32;
localparam int GEM_DMA_TX_DESC_ADDRH_WIDTH = 32;
localparam int GEM_DMA_TX_DESC_SIZE_WIDTH = 14;
typedef struct packed {
	// unused
	logic [31:0] unused;
	// input
	logic [GEM_DMA_TX_DESC_ADDRH_WIDTH-1:0] addrh;
	// input/output
	logic valid;
	// input
	logic wrap;
	// output
	logic retry_limit;
	// reserved
	logic zero;
	// output
	logic frame_corr;
	// output
	logic late_coll;
	// reserved
	logic [1:0] res4;
	// reserved
	logic res3;
	// output
	logic [2:0] chksum_err;
	// reserved
	logic [2:0] res2;
	// input
	logic nocrc;
	// input
	logic eof;
	// reserved
	logic res1;
	// input
	logic [GEM_DMA_TX_DESC_SIZE_WIDTH-1:0] size;
	// input
	logic [GEM_DMA_TX_DESC_ADDRL_WIDTH-1:0] addrl;
} gem_dma_tx_desc_t;

/*
 * GEM DMA RX descriptor
 */
localparam int GEM_DMA_RX_DESC_ADDRL_WIDTH = 32;
localparam int GEM_DMA_RX_DESC_ADDRH_WIDTH = 32;
localparam int GEM_DMA_RX_DESC_SIZE_WIDTH = 13;
typedef struct packed {
	// unused
	logic [31:0] unused;
	// input
	logic [GEM_DMA_RX_DESC_ADDRH_WIDTH-1:0] addrh;
	// output
	logic w_broadcast_frame;
	// output
	logic w_mult_hash_match;
	// output
	logic w_uni_hash_match;
	// output
	logic w_ext_match;
	// output
	logic w_add_match;
	// output
	logic [1:0] add_match;
	// reserved
	logic res2;
	// output
	logic [1:0] chksum_enc;
	// output
	logic rx_w_vlan_tagged;
	// output
	logic rx_w_prty_tagged;
	// reserved
	logic [2:0] res1;
	// output
	logic cfi;
	// output
	logic eof;
	// output
	logic sof;
	// output
	logic fcs;
	// output
	logic [GEM_DMA_RX_DESC_SIZE_WIDTH-1:0] size;
	// input
	logic [GEM_DMA_RX_DESC_ADDRL_WIDTH-2-1:0] addrl;
	// input
	logic wrap;
	// input/output
	logic valid;
} gem_dma_rx_desc_t;

localparam int DMA_DESC_64BITADDR = 1;

/*
 * Generic TX cookie
 */
localparam int TX_COOKIE_ADDR_WIDTH = SYSTEM_ADDR_WIDTH;
localparam int TX_COOKIE_DATA_ADDR_WIDTH = SYSTEM_ADDR_WIDTH;
localparam int TX_COOKIE_SIZE_WIDTH = 14;
typedef struct packed {
	logic nocrc;
	logic eof;
	logic wrap;
	logic [TX_COOKIE_SIZE_WIDTH-1:0] size;
	logic [TX_COOKIE_DATA_ADDR_WIDTH-1:0] data_addr;
	logic [TX_COOKIE_ADDR_WIDTH-1:0] addr;
} tx_cookie_t;
typedef tx_cookie_t dma_tx_cookie_t;

/*
 * Generic RX cookie
 */
localparam int RX_COOKIE_SIZE_WIDTH = 14;
localparam int RX_COOKIE_DATA_ADDR_WIDTH = SYSTEM_ADDR_WIDTH;
localparam int RX_COOKIE_ADDR_WIDTH = SYSTEM_ADDR_WIDTH;
typedef struct packed {
	logic w_broadcast_frame;
	logic w_mult_hash_match;
	logic w_uni_hash_match;
	logic w_ext_match;
	logic w_add_match;
	logic [1:0] add_match;
	logic [1:0] chksum_enc;
	logic rx_w_vlan_tagged;
	logic rx_w_prty_tagged;
	logic cfi;
	logic eof;
	logic sof;
	logic fcs;
	logic wrap;
	logic [RX_COOKIE_SIZE_WIDTH-1:0] size;
	logic [RX_COOKIE_DATA_ADDR_WIDTH-1:0] data_addr;
	logic [RX_COOKIE_ADDR_WIDTH-1:0] addr;
} rx_cookie_t;
typedef rx_cookie_t dma_rx_cookie_t;

/*
 * TX meta descriptor
 */
localparam int TX_META_DESC_SIZE_WIDTH = 14;
typedef struct packed {
	logic nocrc;
	logic [TX_META_DESC_SIZE_WIDTH-1:0] size;
} tx_meta_desc_t;

/*
 * RX meta descriptor
 */
localparam int RX_META_DESC_SIZE_WIDTH = 13;
typedef struct packed {
	logic w_broadcast_frame;
	logic w_mult_hash_match;
	logic w_uni_hash_match;
	logic w_ext_match;
	logic w_add_match;
	logic [1:0] add_match;
	logic res2;
	logic [1:0] chksum_enc;
	logic rx_w_vlan_tagged;
	logic rx_w_prty_tagged;
	logic [2:0] res1;
	logic cfi;
	logic eof;
	logic sof;
	logic fcs;
	logic [RX_META_DESC_SIZE_WIDTH-1:0] size;
} rx_meta_desc_t;

/*
 * ---- SP unit configuration ----------------------------------------
 */
localparam logic [4:0] SP_FUNC7_PUZZLE_FIFO_R_EMPTY = 5'b00000;
localparam logic [4:0] SP_FUNC7_PUZZLE_FIFO_R_POP = 5'b00001;
localparam logic [4:0] SP_FUNC7_PUZZLE_FIFO_W_FULL = 5'b00100;
localparam logic [4:0] SP_FUNC7_PUZZLE_FIFO_W_PUSH = 5'b00101;

localparam logic [4:0] SP_FUNC7_RX_META_NELEMS = 5'b01000;
localparam logic [4:0] SP_FUNC7_RX_META_POP = 5'b01001;
localparam logic [4:0] SP_FUNC7_RX_META_EMPTY = 5'b01010;
localparam logic [4:0] SP_FUNC7_RX_DATA_DMA_START = 5'b01101;
localparam logic [4:0] SP_FUNC7_RX_DATA_DMA_STATUS = 5'b01110;

localparam logic [4:0] SP_FUNC7_TX_META_NFREE = 5'b01000;
localparam logic [4:0] SP_FUNC7_TX_META_PUSH = 5'b01001;
localparam logic [4:0] SP_FUNC7_TX_META_FULL = 5'b01010;
localparam logic [4:0] SP_FUNC7_TX_DATA_COUNT = 5'b01100;
localparam logic [4:0] SP_FUNC7_TX_DATA_DMA_START = 5'b01110;
localparam logic [4:0] SP_FUNC7_TX_DATA_DMA_STATUS = 5'b01111;

localparam logic [4:0] SP_FUNC7_COMMON_LOAD_REG = 5'b10000;
localparam logic [4:0] SP_FUNC7_COMMON_STORE_REG = 5'b10001;
localparam logic [4:0] SP_FUNC7_COMMON_READ_TRIGGER = 5'b10010;
localparam logic [4:0] SP_FUNC7_COMMON_INTR = 5'b10011;

localparam logic [4:0] SP_FUNC7_ACP_READ_START = 5'b11000;
localparam logic [4:0] SP_FUNC7_ACP_READ_STATUS = 5'b11001;
localparam logic [4:0] SP_FUNC7_ACP_WRITE_START = 5'b11010;
localparam logic [4:0] SP_FUNC7_ACP_WRITE_STATUS = 5'b11011;
localparam logic [4:0] SP_FUNC7_ACP_SET_LOCAL_WSTRB = 5'b11100;
localparam logic [4:0] SP_FUNC7_ACP_SET_REMOTE_WSTRB = 5'b11101;

localparam int CMD_PUZZLE_FIFO_R_EMPTY	= 0;
localparam int CMD_PUZZLE_FIFO_R_POP	= CMD_PUZZLE_FIFO_R_EMPTY + 1;
localparam int CMD_PUZZLE_FIFO_W_FULL	= CMD_PUZZLE_FIFO_R_POP + 1;
localparam int CMD_PUZZLE_FIFO_W_PUSH	= CMD_PUZZLE_FIFO_W_FULL + 1;
localparam int CMD_PUZZLE_FIRST			= CMD_PUZZLE_FIFO_R_EMPTY;
localparam int CMD_PUZZLE_LAST			= CMD_PUZZLE_FIFO_W_PUSH;

localparam int CMD_RX_META_NELEMS		= 0;
localparam int CMD_RX_META_POP			= CMD_RX_META_NELEMS + 1;
localparam int CMD_RX_META_EMPTY		= CMD_RX_META_POP + 1;
localparam int CMD_RX_DATA_DMA_START	= CMD_RX_META_EMPTY + 1;
localparam int CMD_RX_DATA_DMA_STATUS	= CMD_RX_DATA_DMA_START + 1;
localparam int CMD_RX_FIRST				= CMD_RX_META_NELEMS;
localparam int CMD_RX_LAST				= CMD_RX_DATA_DMA_STATUS;

localparam int CMD_TX_META_NFREE		= 0;
localparam int CMD_TX_META_PUSH			= CMD_TX_META_NFREE + 1;
localparam int CMD_TX_META_FULL			= CMD_TX_META_PUSH + 1;
localparam int CMD_TX_DATA_COUNT		= CMD_TX_META_FULL + 1;
localparam int CMD_TX_DATA_DMA_START	= CMD_TX_DATA_COUNT + 1;
localparam int CMD_TX_DATA_DMA_STATUS	= CMD_TX_DATA_DMA_START + 1;
localparam int CMD_TX_FIRST				= CMD_TX_META_NFREE;
localparam int CMD_TX_LAST				= CMD_TX_DATA_DMA_STATUS;

localparam int CMD_COMMON_LOAD_REG		= 0;
localparam int CMD_COMMON_STORE_REG		= CMD_COMMON_LOAD_REG + 1;
localparam int CMD_COMMON_READ_TRIGGER	= CMD_COMMON_STORE_REG + 1;
localparam int CMD_COMMON_INTR			= CMD_COMMON_READ_TRIGGER + 1;
localparam int CMD_COMMON_FIRST			= CMD_COMMON_LOAD_REG;
localparam int CMD_COMMON_LAST			= CMD_COMMON_INTR;

localparam int CMD_ACP_READ_START		= 0;
localparam int CMD_ACP_READ_STATUS		= CMD_ACP_READ_START + 1;
localparam int CMD_ACP_WRITE_START		= CMD_ACP_READ_STATUS + 1;
localparam int CMD_ACP_WRITE_STATUS		= CMD_ACP_WRITE_START + 1;
localparam int CMD_ACP_SET_LOCAL_WSTRB	= CMD_ACP_WRITE_STATUS + 1;
localparam int CMD_ACP_SET_REMOTE_WSTRB	= CMD_ACP_SET_LOCAL_WSTRB + 1;
localparam int CMD_ACP_FIRST			= CMD_ACP_READ_START;
localparam int CMD_ACP_LAST				= CMD_ACP_SET_REMOTE_WSTRB;

localparam int SP_UNIT_PUZZLE_NCMDS = CMD_PUZZLE_LAST - CMD_PUZZLE_FIRST + 1;
localparam int SP_UNIT_RX_NCMDS = CMD_RX_LAST - CMD_RX_FIRST + 1;
localparam int SP_UNIT_TX_NCMDS = CMD_TX_LAST - CMD_TX_FIRST + 1;
localparam int SP_UNIT_COMMON_NCMDS = CMD_COMMON_LAST - CMD_COMMON_FIRST + 1;
localparam int SP_UNIT_ACP_NCMDS = CMD_ACP_LAST - CMD_ACP_FIRST + 1;

localparam int SP_RX_IRQ_DONE_BITN = 0;
localparam int SP_RX_IRQ_NODESC_BITN = 1;
localparam int SP_TX_IRQ_DONE_BITN = 0;

/*
 * ---- RX portion ---------------------------------------------------
 */
/*
 * Main FIFOs configuration
 */
localparam int RX_META_FIFO_WIDTH = 32;
localparam int RX_META_FIFO_DEPTH = 2048;
localparam int RX_META_FIFO_DATA_COUNT_WIDTH = $clog2(RX_META_FIFO_DEPTH) + 1;

localparam int RX_DATA_FIFO_WIDTH = 128;
localparam int RX_DATA_FIFO_SIZE = 2**16;
localparam int RX_DATA_FIFO_DEPTH = RX_DATA_FIFO_SIZE / (RX_DATA_FIFO_WIDTH/8);
localparam int RX_DATA_FIFO_DATA_COUNT_WIDTH = $clog2(RX_DATA_FIFO_DEPTH) + 1;

localparam int ENABLE_RX_SW_MMR_I = 0;
localparam int ENABLE_RX_SW_MMR_T = 0;
/*
 * The write interface of the RX data DMA module is driven by Sw.
 */
localparam int ENABLE_RX_SW_RX_DATA_MEM_W = 0;
/*
 * The read interface of the RX meta FIFO is driven by Sw.
 */
localparam int ENABLE_RX_SW_RX_META_FIFO_R = 0;

localparam int ENABLE_RX_RISCV_PROCESSOR = 0;

/*
 * RX Puzzle FIFO configuration.
 */
localparam int NRXPUZZLEFIFOS = 4;

localparam int ENABLE_RX_PUZZLE_SW_FIFO_R [NRXPUZZLEFIFOS] = {
	0,
	0,
	0,
	0
};
localparam int ENABLE_RX_PUZZLE_SW_FIFO_W [NRXPUZZLEFIFOS] = {
	0,
	0,
	0,
	0
};

localparam int RX_PUZZLE_FIFO_R_DATA_WIDTH [NRXPUZZLEFIFOS] = {
	FIFO_MIN_WIDTH,
	$bits(dma_rx_cookie_t),
	$bits(rx_cookie_t),
	FIFO_MIN_WIDTH
};

localparam int RX_PUZZLE_FIFO_W_DATA_WIDTH [NRXPUZZLEFIFOS] = {
	FIFO_MIN_WIDTH,
	$bits(dma_rx_cookie_t),
	$bits(rx_cookie_t),
	FIFO_MIN_WIDTH
};

localparam int RX_PUZZLE_FIFO_WRITE_DEPTH [NRXPUZZLEFIFOS] = {
	16,
	16,
	16,
	16
};

localparam int RX_PUZZLE_FIFO_READ_DEPTH [NRXPUZZLEFIFOS] = {
	RX_PUZZLE_FIFO_WRITE_DEPTH[0] * RX_PUZZLE_FIFO_W_DATA_WIDTH[0] / RX_PUZZLE_FIFO_R_DATA_WIDTH[0],
	RX_PUZZLE_FIFO_WRITE_DEPTH[1] * RX_PUZZLE_FIFO_W_DATA_WIDTH[1] / RX_PUZZLE_FIFO_R_DATA_WIDTH[1],
	RX_PUZZLE_FIFO_WRITE_DEPTH[2] * RX_PUZZLE_FIFO_W_DATA_WIDTH[2] / RX_PUZZLE_FIFO_R_DATA_WIDTH[2],
	RX_PUZZLE_FIFO_WRITE_DEPTH[3] * RX_PUZZLE_FIFO_W_DATA_WIDTH[3] / RX_PUZZLE_FIFO_R_DATA_WIDTH[3]
};

localparam int RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH [NRXPUZZLEFIFOS] = {
	$clog2(RX_PUZZLE_FIFO_READ_DEPTH[0]) + 1,
	$clog2(RX_PUZZLE_FIFO_READ_DEPTH[1]) + 1,
	$clog2(RX_PUZZLE_FIFO_READ_DEPTH[2]) + 1,
	$clog2(RX_PUZZLE_FIFO_READ_DEPTH[3]) + 1
};

localparam int RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH [NRXPUZZLEFIFOS] = {
	$clog2(RX_PUZZLE_FIFO_WRITE_DEPTH[0]) + 1,
	$clog2(RX_PUZZLE_FIFO_WRITE_DEPTH[1]) + 1,
	$clog2(RX_PUZZLE_FIFO_WRITE_DEPTH[2]) + 1,
	$clog2(RX_PUZZLE_FIFO_WRITE_DEPTH[3]) + 1
};

/*
 * ---- TX portion ---------------------------------------------------
 */
/*
 * Main FIFOs configuration
 */
localparam int TX_META_FIFO_WIDTH = 32;
localparam int TX_META_FIFO_DEPTH = 2048;
localparam int TX_META_FIFO_DATA_COUNT_WIDTH = $clog2(TX_META_FIFO_DEPTH) + 1;

localparam int TX_DATA_FIFO_WIDTH = 128;
localparam int TX_DATA_FIFO_SIZE = 2**16;
localparam int TX_DATA_FIFO_DEPTH = TX_DATA_FIFO_SIZE / (TX_DATA_FIFO_WIDTH/8);
localparam int TX_DATA_FIFO_DATA_COUNT_WIDTH = $clog2(TX_DATA_FIFO_DEPTH) + 1;

localparam int TX_CSUM_FIFO_WIDTH = 2 + 16 + 2 + 16;
localparam int TX_CSUM_FIFO_DEPTH = TX_META_FIFO_DEPTH;
localparam int TX_CSUM_FIFO_DATA_COUNT_WIDTH = TX_META_FIFO_DATA_COUNT_WIDTH;

localparam int ENABLE_TX_SW_MMR_I = 0;
localparam int ENABLE_TX_SW_MMR_T = 0;
/*
 * The read interface of the TX data DMA module is driven by Sw.
 */
localparam int ENABLE_TX_SW_TX_DATA_MEM_R = 0;
/*
 * The write interface of the TX meta FIFO is driven by Sw.
 */
localparam int ENABLE_TX_SW_TX_META_FIFO_W = 0;
/*
 * The write interface of the TX data FIFO is driven by Sw.
 * But it's also -- always -- driven by the GEM RX module.
 * Danger, Will Robinson, DANGER.
 */
localparam int ENABLE_TX_SW_TX_DATA_FIFO_W = 0;

localparam int ENABLE_TX_RISCV_PROCESSOR = 1;

/*
 * TX Puzzle FIFO configuration.
 */
localparam int NTXPUZZLEFIFOS = 4;

localparam int ENABLE_TX_PUZZLE_SW_FIFO_R [NTXPUZZLEFIFOS] = {
	1,
	0,
	0,
	0
};

localparam int ENABLE_TX_PUZZLE_SW_FIFO_W [NTXPUZZLEFIFOS] = {
	0,
	1,
	0,
	0
};

localparam int TX_PUZZLE_FIFO_R_DATA_WIDTH [NTXPUZZLEFIFOS] = {
	$bits(dma_tx_cookie_t),
	$bits(dma_tx_cookie_t),
	$bits(tx_cookie_t),
	FIFO_MIN_WIDTH
};

localparam int TX_PUZZLE_FIFO_W_DATA_WIDTH [NTXPUZZLEFIFOS] = {
	$bits(dma_tx_cookie_t),
	$bits(dma_tx_cookie_t),
	$bits(tx_cookie_t),
	FIFO_MIN_WIDTH
};

localparam int TX_PUZZLE_FIFO_WRITE_DEPTH [NTXPUZZLEFIFOS] = {
	16,
	16,
	16,
	16
};

localparam int TX_PUZZLE_FIFO_READ_DEPTH [NTXPUZZLEFIFOS] = {
	TX_PUZZLE_FIFO_WRITE_DEPTH[0] * TX_PUZZLE_FIFO_W_DATA_WIDTH[0] / TX_PUZZLE_FIFO_R_DATA_WIDTH[0],
	TX_PUZZLE_FIFO_WRITE_DEPTH[1] * TX_PUZZLE_FIFO_W_DATA_WIDTH[1] / TX_PUZZLE_FIFO_R_DATA_WIDTH[1],
	TX_PUZZLE_FIFO_WRITE_DEPTH[2] * TX_PUZZLE_FIFO_W_DATA_WIDTH[2] / TX_PUZZLE_FIFO_R_DATA_WIDTH[2],
	TX_PUZZLE_FIFO_WRITE_DEPTH[3] * TX_PUZZLE_FIFO_W_DATA_WIDTH[3] / TX_PUZZLE_FIFO_R_DATA_WIDTH[3]
};

localparam int TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH [NTXPUZZLEFIFOS] = {
	$clog2(TX_PUZZLE_FIFO_READ_DEPTH[0]) + 1,
	$clog2(TX_PUZZLE_FIFO_READ_DEPTH[1]) + 1,
	$clog2(TX_PUZZLE_FIFO_READ_DEPTH[2]) + 1,
	$clog2(TX_PUZZLE_FIFO_READ_DEPTH[3]) + 1
};

localparam int TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH [NTXPUZZLEFIFOS] = {
	$clog2(TX_PUZZLE_FIFO_WRITE_DEPTH[0]) + 1,
	$clog2(TX_PUZZLE_FIFO_WRITE_DEPTH[1]) + 1,
	$clog2(TX_PUZZLE_FIFO_WRITE_DEPTH[2]) + 1,
	$clog2(TX_PUZZLE_FIFO_WRITE_DEPTH[3]) + 1
};

/*
 * Trace structures
 */
typedef struct packed {
	logic rx_enable;
	logic rx_trigger;

	logic puzzle_fifo_r_0_empty;
	logic puzzle_fifo_r_0_rd_en;
	logic [RX_PUZZLE_FIFO_R_DATA_WIDTH[0] - 1:0] puzzle_fifo_r_0_rd_data;
	logic [RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0] - 1:0] puzzle_fifo_r_0_rd_data_count;
	logic puzzle_fifo_r_1_empty;
	logic puzzle_fifo_r_1_rd_en;
	logic [RX_PUZZLE_FIFO_R_DATA_WIDTH[1] - 1:0] puzzle_fifo_r_1_rd_data;
	logic [RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1] - 1:0] puzzle_fifo_r_1_rd_data_count;
	logic puzzle_fifo_r_2_empty;
	logic puzzle_fifo_r_2_rd_en;
	logic [RX_PUZZLE_FIFO_R_DATA_WIDTH[2] - 1:0] puzzle_fifo_r_2_rd_data;
	logic [RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2] - 1:0] puzzle_fifo_r_2_rd_data_count;
	logic puzzle_fifo_r_3_empty;
	logic puzzle_fifo_r_3_rd_en;
	logic [RX_PUZZLE_FIFO_R_DATA_WIDTH[3] - 1:0] puzzle_fifo_r_3_rd_data;
	logic [RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3] - 1:0] puzzle_fifo_r_3_rd_data_count;

	logic puzzle_fifo_w_0_full;
	logic puzzle_fifo_w_0_wr_en;
	logic [RX_PUZZLE_FIFO_W_DATA_WIDTH[0] - 1:0] puzzle_fifo_w_0_wr_data;
	logic [RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0] - 1:0] puzzle_fifo_w_0_wr_data_count;
	logic puzzle_fifo_w_1_full;
	logic puzzle_fifo_w_1_wr_en;
	logic [RX_PUZZLE_FIFO_W_DATA_WIDTH[1] - 1:0] puzzle_fifo_w_1_wr_data;
	logic [RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1] - 1:0] puzzle_fifo_w_1_wr_data_count;
	logic puzzle_fifo_w_2_full;
	logic puzzle_fifo_w_2_wr_en;
	logic [RX_PUZZLE_FIFO_W_DATA_WIDTH[2] - 1:0] puzzle_fifo_w_2_wr_data;
	logic [RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2] - 1:0] puzzle_fifo_w_2_wr_data_count;
	logic puzzle_fifo_w_3_full;
	logic puzzle_fifo_w_3_wr_en;
	logic [RX_PUZZLE_FIFO_W_DATA_WIDTH[3] - 1:0] puzzle_fifo_w_3_wr_data;
	logic [RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3] - 1:0] puzzle_fifo_w_3_wr_data_count;
} trace_rx_puzzle_t;

typedef struct packed {
	logic meta_fifo_r_empty;
	logic meta_fifo_r_rd_en;
	logic [RX_META_FIFO_WIDTH-1:0] meta_fifo_r_rd_data;
	logic [RX_META_FIFO_DATA_COUNT_WIDTH-1:0] meta_fifo_r_rd_data_count;

	logic data_fifo_r_empty;
	logic data_fifo_r_rd_en;
	logic [RX_DATA_FIFO_WIDTH-1:0] data_fifo_r_rd_data;
	logic [RX_DATA_FIFO_DATA_COUNT_WIDTH-1:0] data_fifo_r_rd_data_count;

	logic meta_fifo_w_full;
	logic meta_fifo_w_wr_en;
	logic [RX_META_FIFO_WIDTH-1:0] meta_fifo_w_wr_data;
	logic [RX_META_FIFO_DATA_COUNT_WIDTH-1:0] meta_fifo_w_wr_data_count;

	logic data_fifo_w_full;
	logic data_fifo_w_wr_en;
	logic [RX_DATA_FIFO_WIDTH-1:0] data_fifo_w_wr_data;
	logic [RX_DATA_FIFO_DATA_COUNT_WIDTH-1:0] data_fifo_w_wr_data_count;
} trace_rx_fifo_t;

typedef struct packed {
	logic acp_read_start;
	logic acp_read_status;
	logic acp_write_start;
	logic acp_write_status;
} trace_sp_unit_t;

typedef struct packed {
	logic rx_meta_pop;
	logic rx_meta_empty;
	logic rx_data_dma_start;
	logic rx_data_dma_status;
	logic rx_dma_busy;
} trace_sp_unit_rx_t;

typedef struct packed {
	logic tx_meta_push;
	logic tx_meta_full;
	logic tx_data_dma_start;
	logic tx_data_dma_status;
	logic tx_dma_busy;
} trace_sp_unit_tx_t;

typedef struct packed {
	logic tx_enable;
	logic tx_trigger;

	logic puzzle_fifo_r_0_empty;
	logic puzzle_fifo_r_0_rd_en;
	logic [TX_PUZZLE_FIFO_R_DATA_WIDTH[0] - 1:0] puzzle_fifo_r_0_rd_data;
	logic [TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0] - 1:0] puzzle_fifo_r_0_rd_data_count;
	logic puzzle_fifo_r_1_empty;
	logic puzzle_fifo_r_1_rd_en;
	logic [TX_PUZZLE_FIFO_R_DATA_WIDTH[1] - 1:0] puzzle_fifo_r_1_rd_data;
	logic [TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1] - 1:0] puzzle_fifo_r_1_rd_data_count;
	logic puzzle_fifo_r_2_empty;
	logic puzzle_fifo_r_2_rd_en;
	logic [TX_PUZZLE_FIFO_R_DATA_WIDTH[2] - 1:0] puzzle_fifo_r_2_rd_data;
	logic [TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2] - 1:0] puzzle_fifo_r_2_rd_data_count;
	logic puzzle_fifo_r_3_empty;
	logic puzzle_fifo_r_3_rd_en;
	logic [TX_PUZZLE_FIFO_R_DATA_WIDTH[3] - 1:0] puzzle_fifo_r_3_rd_data;
	logic [TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3] - 1:0] puzzle_fifo_r_3_rd_data_count;

	logic puzzle_fifo_w_0_full;
	logic puzzle_fifo_w_0_wr_en;
	logic [TX_PUZZLE_FIFO_W_DATA_WIDTH[0] - 1:0] puzzle_fifo_w_0_wr_data;
	logic [TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0] - 1:0] puzzle_fifo_w_0_wr_data_count;
	logic puzzle_fifo_w_1_full;
	logic puzzle_fifo_w_1_wr_en;
	logic [TX_PUZZLE_FIFO_W_DATA_WIDTH[1] - 1:0] puzzle_fifo_w_1_wr_data;
	logic [TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1] - 1:0] puzzle_fifo_w_1_wr_data_count;
	logic puzzle_fifo_w_2_full;
	logic puzzle_fifo_w_2_wr_en;
	logic [TX_PUZZLE_FIFO_W_DATA_WIDTH[2] - 1:0] puzzle_fifo_w_2_wr_data;
	logic [TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2] - 1:0] puzzle_fifo_w_2_wr_data_count;
	logic puzzle_fifo_w_3_full;
	logic puzzle_fifo_w_3_wr_en;
	logic [TX_PUZZLE_FIFO_W_DATA_WIDTH[3] - 1:0] puzzle_fifo_w_3_wr_data;
	logic [TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3] - 1:0] puzzle_fifo_w_3_wr_data_count;
} trace_tx_puzzle_t;

typedef struct packed {
	logic stuffer_first;
	logic stuffer_i_valid;
	logic stuffer_i_sof;
	logic stuffer_i_eof;
	logic [3:0] stuffer_i_lsbyte;
	logic [3:0] stuffer_i_msbyte;
	logic [127:0] stuffer_i_data;

	logic axi_calc_i_valid;
	logic [127:0] axi_calc_i_address;
	logic [15:0] axi_calc_i_length;
	logic axi_calc_i_axhshake;
	logic axi_calc_o_valid;
	logic [127:0] axi_calc_o_axaddr;
	logic [7:0] axi_calc_o_axlen;

	logic stuffer_o_valid;
	logic [127:0] stuffer_o_data;

	logic [15:0] mem_r_len_plus_off;

	logic [15:0] _total_beats_comb;
	logic [15:0] total_beats_comb;
	logic [15:0] total_beats;

	logic [15:0] _total_bursts_comb;
	logic [15:0] total_bursts_comb;
	logic [15:0] total_bursts;

	logic [7:0] last_burst_beats;
	logic [3:0] last_beat_bytes;
} trace_atf_t;

typedef struct packed {
	logic poisoned;
	logic [127:0] stage0_data_shr_comb;
	logic [15:0] stage0_bytemask_comb;

	logic stage1_valid_ff;
	logic [127:0] stage1_data_ff;
	logic [3:0] stage1_size_ff;
	logic [15:0] stage1_bytemask_ff;
	logic stage1_sof_ff;
	logic stage1_eof_ff;
	logic [127:0] stage1_bitmask_comb;

	logic stage2_valid_ff;
	logic [127:0] stage2_data_ff;
	logic [4:0] stage2_size_ff;
	logic stage2_sof_ff;
	logic stage2_eof_ff;
	logic [128*2-8-1:0] stage2_data_shl_comb;

	logic stage3_valid_ff;
	logic stage3_sof_ff;
	logic stage3_sof_comb;
	logic stage3_eof_ff;
	logic [128*2-8-1:0] stage3_data_ff;
	logic [128*2-8-1:0] stage3_data_comb;
	logic [4:0] stage3_size_ff;
	logic [4:0] stage3_size_comb;
} trace_atf_bds_t;

localparam SP_CSUM_IP_SUM_WIDTH = 5+16;
localparam SP_CSUM_L4_SUM_WIDTH = 11+16;

typedef struct packed {
	logic [1:0] ip_state;
	logic [2:0] l4_state;
	logic p_valid;
	logic p_sof;
	logic p_eof;
	logic commit_checksum;
	logic [1:0] eth_type;
	logic [SP_CSUM_IP_SUM_WIDTH-1:0] ip_sum;
	logic [1:0] ip_proto;
	logic [SP_CSUM_L4_SUM_WIDTH-1:0] l4_sum;
} trace_checksum_t;

endpackage
