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
module prism_sp_processor
#(
	parameter int IBRAM_SIZE,
	parameter int DBRAM_SIZE,
	parameter int ACPBRAM_SIZE,
	parameter int USE_SP_UNIT_RX,
	parameter int USE_SP_UNIT_TX,
	parameter int NPUZZLEFIFOS
)
(
	input wire logic clock,
	input wire logic resetn,
	input wire logic cpu_reset,

	input wire logic [3:0] io_axi_axcache,
	axi_interface.master m_axi_io,

	local_memory_interface.slave instruction_bram_mmr,
	local_memory_interface.slave data_bram_mmr,

	// Interfaces used by the puzzle unit
	fifo_read_interface.master puzzle_sw_fifo_r_0,
	fifo_write_interface.master puzzle_sw_fifo_w_0,
	fifo_read_interface.master puzzle_sw_fifo_r_1,
	fifo_write_interface.master puzzle_sw_fifo_w_1,
	fifo_read_interface.master puzzle_sw_fifo_r_2,
	fifo_write_interface.master puzzle_sw_fifo_w_2,
	fifo_read_interface.master puzzle_sw_fifo_r_3,
	fifo_write_interface.master puzzle_sw_fifo_w_3,

	// Interfaces used by the RX unit
	memory_write_interface.master rx_data_mem_w,
	fifo_read_interface.master rx_meta_fifo_r,
	// Interfaces used by the TX unit
	fifo_write_interface.inputs tx_data_fifo_w,
	memory_read_interface.master tx_data_mem_r,
	fifo_write_interface.master tx_meta_fifo_w,

	// Interfaces used by the common unit
	mmr_readwrite_interface.master mmr_rw,
	mmr_read_interface.master mmr_r,
	mmr_trigger_interface.master mmr_t,
	mmr_intr_interface.master mmr_i,

	// Interfaces used by the ACP unit
	axi_write_address_channel.master m_axi_acp_aw,
	axi_write_channel.master m_axi_acp_w,
	axi_write_response_channel.master m_axi_acp_b,
	axi_read_address_channel.master m_axi_acp_ar,
	axi_read_channel.master m_axi_acp_r,

	output trace_outputs_t trace_proc,
	output trace_sp_unit_t trace_sp_unit,
	output trace_sp_unit_rx_t trace_sp_unit_rx,
	output trace_sp_unit_tx_t trace_sp_unit_tx
);
	localparam int IBRAM_DATA_WIDTH = 32;
	localparam int IBRAM_ADDR_WIDTH = $clog2(IBRAM_SIZE / (IBRAM_DATA_WIDTH/8));

	localparam int DBRAM_DATA_WIDTH = 32;
	localparam int DBRAM_ADDR_WIDTH = $clog2(DBRAM_SIZE / (DBRAM_DATA_WIDTH/8));

	// Port A is connected to the processor core
	localparam int ACPBRAM_A_DATA_WIDTH = 32;
	// Port B is connected to the ACP coprocessor
	localparam int ACPBRAM_B_DATA_WIDTH = 16*8;
	localparam int ACPBRAM_A_ADDR_WIDTH = $clog2(ACPBRAM_SIZE / ACPBRAM_A_DATA_WIDTH);
	localparam int ACPBRAM_B_ADDR_WIDTH = $clog2(ACPBRAM_SIZE / ACPBRAM_B_DATA_WIDTH);

	local_memory_interface instruction_bram();
	local_memory_interface data_bram();
	local_memory_interface acp_bram_a();
	xpm_memory_tdpram_port_interface#(
		.ADDR_WIDTH(ACPBRAM_B_ADDR_WIDTH),
		.DATA_WIDTH(ACPBRAM_B_DATA_WIDTH)
	) acp_bram_b();

	// These signals are inputs to the Taiga core and are
	// needed for now.
	l2_requester_interface l2();
	wire logic timer_interrupt;
	wire logic interrupt;

	taiga #(
		.USE_SP_UNIT_TX(USE_SP_UNIT_TX),
		.USE_SP_UNIT_RX(USE_SP_UNIT_RX),
		.NPUZZLEFIFOS(NPUZZLEFIFOS)
	) cpu(
		.clk(clock),
		.rst(cpu_reset),

		.instruction_bram,
		.data_bram,
		.acp_bram_a,
		.acp_bram_port_b_i(acp_bram_b),

		.l2(l2),
		.timer_interrupt,
		.interrupt,

		.io_axi_axcache,
		.m_axi_io,
		.tr(trace_proc),

	/*
	 * ---- Begin SP unit signals
	 */
		// Puzzle
		.puzzle_sw_fifo_r_0,
		.puzzle_sw_fifo_w_0,
		.puzzle_sw_fifo_r_1,
		.puzzle_sw_fifo_w_1,
		.puzzle_sw_fifo_r_2,
		.puzzle_sw_fifo_w_2,
		.puzzle_sw_fifo_r_3,
		.puzzle_sw_fifo_w_3,

		// Interfaces used by the RX unit
		.rx_data_mem_w,
		.rx_meta_fifo_r,

		// Interfaces used by the TX unit
		.tx_data_fifo_w,
		.tx_data_mem_r,
		.tx_meta_fifo_w,

		// Common
		.mmr_rw,
		.mmr_r,
		.mmr_t,
		.mmr_i,

		// ACP
		.m_axi_acp_aw,
		.m_axi_acp_w,
		.m_axi_acp_b,
		.m_axi_acp_ar,
		.m_axi_acp_r,

		// Trace
		.trace_sp_unit
	/*
	 * ---- End SP unit signals
	 */
	);

	xpm_memory_tdpram #(
		.ADDR_WIDTH_A(IBRAM_ADDR_WIDTH),
		.ADDR_WIDTH_B(IBRAM_ADDR_WIDTH),
		.AUTO_SLEEP_TIME(0),
		.BYTE_WRITE_WIDTH_A(8),
		.BYTE_WRITE_WIDTH_B(8),
		.CASCADE_HEIGHT(0),
		.CLOCKING_MODE("common_clock"),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),
		.MEMORY_INIT_PARAM("0"),
		.MEMORY_OPTIMIZATION("true"),
		.MEMORY_PRIMITIVE("auto"),
		.MEMORY_SIZE(IBRAM_SIZE*8),
		.MESSAGE_CONTROL(0),
		.READ_DATA_WIDTH_A(IBRAM_DATA_WIDTH),
		.READ_DATA_WIDTH_B(IBRAM_DATA_WIDTH),
		.READ_LATENCY_A(1),
		.READ_LATENCY_B(1),
		.READ_RESET_VALUE_A("0"),
		.READ_RESET_VALUE_B("0"),
		.RST_MODE_A("SYNC"),
		.RST_MODE_B("SYNC"),
		.SIM_ASSERT_CHK(0),
		.USE_EMBEDDED_CONSTRAINT(0),
		.USE_MEM_INIT(1),
		.WAKEUP_TIME("disable_sleep"),
		.WRITE_DATA_WIDTH_A(IBRAM_DATA_WIDTH),
		.WRITE_DATA_WIDTH_B(IBRAM_DATA_WIDTH),
		.WRITE_MODE_A("no_change"),
		.WRITE_MODE_B("no_change")
	)
	xpm_memory_tdpram_ibram (
		.clka(clock),
		.rsta(~resetn),
		.rstb(~resetn),
		.douta(instruction_bram.data_out),
		.doutb(instruction_bram_mmr.data_out),
		.addra(instruction_bram.addr[IBRAM_ADDR_WIDTH-1:0]),
		.addrb(instruction_bram_mmr.addr[IBRAM_ADDR_WIDTH-1:0]),
		.dina(instruction_bram.data_in),
		.dinb(instruction_bram_mmr.data_in),
		.ena(instruction_bram.en),
		.enb(instruction_bram_mmr.en),
		.wea(instruction_bram.be),
		.web(instruction_bram_mmr.be)
	);

	xpm_memory_tdpram #(
		.ADDR_WIDTH_A(DBRAM_ADDR_WIDTH),
		.ADDR_WIDTH_B(DBRAM_ADDR_WIDTH),
		.AUTO_SLEEP_TIME(0),
		.BYTE_WRITE_WIDTH_A(8),
		.BYTE_WRITE_WIDTH_B(8),
		.CASCADE_HEIGHT(0),
		.CLOCKING_MODE("common_clock"),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),
		.MEMORY_INIT_PARAM("0"),
		.MEMORY_OPTIMIZATION("true"),
		.MEMORY_PRIMITIVE("auto"),
		.MEMORY_SIZE(DBRAM_SIZE*8),
		.MESSAGE_CONTROL(0),
		.READ_DATA_WIDTH_A(DBRAM_DATA_WIDTH),
		.READ_DATA_WIDTH_B(DBRAM_DATA_WIDTH),
		.READ_LATENCY_A(1),
		.READ_LATENCY_B(1),
		.READ_RESET_VALUE_A("0"),
		.READ_RESET_VALUE_B("0"),
		.RST_MODE_A("SYNC"),
		.RST_MODE_B("SYNC"),
		.SIM_ASSERT_CHK(0),
		.USE_EMBEDDED_CONSTRAINT(0),
		.USE_MEM_INIT(1),
		.WAKEUP_TIME("disable_sleep"),
		.WRITE_DATA_WIDTH_A(DBRAM_DATA_WIDTH),
		.WRITE_DATA_WIDTH_B(DBRAM_DATA_WIDTH),
		.WRITE_MODE_A("no_change"),
		.WRITE_MODE_B("no_change")
	)
	xpm_memory_tdpram_dbram (
		.clka(clock),
		.rsta(~resetn),
		.rstb(~resetn),
		.douta(data_bram.data_out),
		.doutb(data_bram_mmr.data_out),
		.addra(data_bram.addr[DBRAM_ADDR_WIDTH-1:0]),
		.addrb(data_bram_mmr.addr[DBRAM_ADDR_WIDTH-1:0]),
		.dina(data_bram.data_in),
		.dinb(data_bram_mmr.data_in),
		.ena(data_bram.en),
		.enb(data_bram_mmr.en),
		.wea(data_bram.be),
		.web(data_bram_mmr.be)
	);

	xpm_memory_tdpram #(
		.ADDR_WIDTH_A(ACPBRAM_A_ADDR_WIDTH),
		.ADDR_WIDTH_B(ACPBRAM_B_ADDR_WIDTH),
		.AUTO_SLEEP_TIME(0),
		.BYTE_WRITE_WIDTH_A(8),
		.BYTE_WRITE_WIDTH_B(8),
		.CASCADE_HEIGHT(0),
		.CLOCKING_MODE("common_clock"),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),
		.MEMORY_INIT_PARAM("0"),
		.MEMORY_OPTIMIZATION("true"),
		.MEMORY_PRIMITIVE("auto"),
		.MEMORY_SIZE(2*64*8),
		.MESSAGE_CONTROL(0),
		.READ_DATA_WIDTH_A(ACPBRAM_A_DATA_WIDTH),
		.READ_DATA_WIDTH_B(ACPBRAM_B_DATA_WIDTH),
		.READ_LATENCY_A(1),
		.READ_LATENCY_B(1),
		.READ_RESET_VALUE_A("0"),
		.READ_RESET_VALUE_B("0"),
		.RST_MODE_A("SYNC"),
		.RST_MODE_B("SYNC"),
		.SIM_ASSERT_CHK(0),
		.USE_EMBEDDED_CONSTRAINT(0),
		.USE_MEM_INIT(0),
		.WAKEUP_TIME("disable_sleep"),
		.WRITE_DATA_WIDTH_A(ACPBRAM_A_DATA_WIDTH),
		.WRITE_DATA_WIDTH_B(ACPBRAM_B_DATA_WIDTH),
		.WRITE_MODE_A("no_change"),
		.WRITE_MODE_B("no_change")
	)
	xpm_memory_tdpram_acpbram (
		.clka(clock),
		.rsta(~resetn),
		.rstb(~resetn),
		.douta(acp_bram_a.data_out),
		.doutb(acp_bram_b.dout),
		.addra(acp_bram_a.addr[ACPBRAM_A_ADDR_WIDTH-1:0]),
		.addrb(acp_bram_b.addr),
		.dina(acp_bram_a.data_in),
		.dinb(acp_bram_b.din),
		.ena(acp_bram_a.en),
		.enb(acp_bram_b.en),
		.wea(acp_bram_a.be),
		.web(acp_bram_b.we)
	);
endmodule
