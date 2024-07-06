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
package mmr_config;

typedef enum int {
	MMR_RW_REGN_CONTROL
} mmr_rw_n;

typedef enum int {
	MMR_R_REGN_IO_AXI_AXCACHE,
	MMR_R_REGN_DMA_AXI_AXCACHE,
	MMR_R_REGN_RESERVED0,
	MMR_R_REGN_RESERVED1,
	MMR_R_REGN_QP_LSB,
	MMR_R_REGN_QP_MSB,
	MMR_R_REGN_DATA_FIFO_SIZE,
	MMR_R_REGN_DATA_FIFO_WIDTH,
	MMR_R_REGN_INFO
} mmr_r_n;

localparam int SIZEOF_REG = 4;
// 8 = 2**8/256 bytes of MMR addresses
localparam int MMR_RANGE_WIDTH = 8;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_CONTROL			= 8'h000;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_STATUS			= 8'h004;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_INFO				= 8'h008;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_BRAM_ADDR			= 8'h010;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_BRAM_DATA			= 8'h014;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_IO_AXI_AXCACHE	= 8'h020;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_DMA_AXI_AXCACHE	= 8'h024;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_RESERVED0			= 8'h028;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_RESERVED1			= 8'h02c;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_QP_LSB			= 8'h030;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_QP_MSB			= 8'h034;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_TER				= 8'h040;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_TSR				= 8'h04c;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_IER				= 8'h050;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_IDR				= 8'h054;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_IMR				= 8'h058;
localparam logic [MMR_RANGE_WIDTH-1:0] REGOFF_ISR				= 8'h05c;

localparam int MMR_RW_NREGS = 1;
localparam int MMR_R_NREGS = 8;
localparam int MMR_R_BITN = 8;

endpackage
