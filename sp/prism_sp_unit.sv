/*
 * Copyright (c) 2021-2023 Robert Drehmel
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
import prism_sp_config::*;

module prism_sp_unit #(
	parameter int USE_SP_UNIT_RX,
	parameter int USE_SP_UNIT_TX,
	parameter int NPUZZLEFIFOS
) (
	input wire logic clk,
	input wire logic rst,

	// Taiga-related signals
	input sp_inputs_t sp_inputs,
	unit_issue_interface.unit issue,
	unit_writeback_interface.unit wb,

	// Interfaces used by the puzzle unit
	fifo_read_interface.master puzzle_sw_fifo_r_0,
	fifo_write_interface.master puzzle_sw_fifo_w_0,
	fifo_read_interface.master puzzle_sw_fifo_r_1,
	fifo_write_interface.master puzzle_sw_fifo_w_1,
	fifo_read_interface.master puzzle_sw_fifo_r_2,
	fifo_write_interface.master puzzle_sw_fifo_w_2,
	fifo_read_interface.master puzzle_sw_fifo_r_3,
	fifo_write_interface.master puzzle_sw_fifo_w_3,

	// Interfaces driven from the RX unit
	memory_write_interface.master rx_data_mem_w,
	fifo_read_interface.master rx_meta_fifo_r,
	// Interfaces driven from the TX unit
	fifo_write_interface.inputs tx_data_fifo_w,
	memory_read_interface.master tx_data_mem_r,
	fifo_write_interface.master tx_meta_fifo_w,

	// For the Common subunit
	mmr_readwrite_interface.master mmr_rw,
	mmr_read_interface.master mmr_r,
	mmr_trigger_interface.master mmr_t,
	mmr_intr_interface.master mmr_i,

	// For the ACP subunit
	axi_write_address_channel.master m_axi_acp_aw,
	axi_write_channel.master m_axi_acp_w,
	axi_write_response_channel.master m_axi_acp_b,
	axi_read_address_channel.master m_axi_acp_ar,
	axi_read_channel.master m_axi_acp_r,
	xpm_memory_tdpram_port_interface.master acpram_port_i,

	output trace_sp_unit_t trace_sp_unit,
	output trace_sp_unit_rx_t trace_sp_unit_rx,
	output trace_sp_unit_tx_t trace_sp_unit_tx
);

localparam int SP_UNIT_ENABLE_TRACE = 1;

var id_t cur_id;
var logic [$bits(wb.rd)-1:0] puzzle_result;
var logic [$bits(wb.rd)-1:0] specific_result;
var logic [$bits(wb.rd)-1:0] common_result;
var logic [$bits(wb.rd)-1:0] acp_result;
var logic [$bits(wb.rd)-1:0] result;

/*
 * Binary to one-hot decoding of the current command.
 */
var logic [SP_UNIT_PUZZLE_NCMDS-1:0] puzzle_issue_cmd;
wire logic [SP_UNIT_PUZZLE_NCMDS-1:0] puzzle_cmds_busy;
wire logic [SP_UNIT_PUZZLE_NCMDS-1:0] puzzle_cmds_done;
var logic puzzle_issue_cmd_valid;

var logic [SP_UNIT_COMMON_NCMDS-1:0] common_issue_cmd;
wire logic [SP_UNIT_COMMON_NCMDS-1:0] common_cmds_busy;
wire logic [SP_UNIT_COMMON_NCMDS-1:0] common_cmds_done;
var logic common_issue_cmd_valid;

var logic [SP_UNIT_ACP_NCMDS-1:0] acp_issue_cmd;
wire logic [SP_UNIT_ACP_NCMDS-1:0] acp_cmds_busy;
wire logic [SP_UNIT_ACP_NCMDS-1:0] acp_cmds_done;
var logic acp_issue_cmd_valid;

var logic specific_issue_cmd_valid;

if (USE_SP_UNIT_RX) begin
	var logic [SP_UNIT_RX_NCMDS-1:0] rx_issue_cmd;
	wire logic [SP_UNIT_RX_NCMDS-1:0] rx_cmds_busy;
	wire logic [SP_UNIT_RX_NCMDS-1:0] rx_cmds_done;

	if (SP_UNIT_ENABLE_TRACE) begin
		assign trace_sp_unit_rx.rx_meta_pop = rx_cmds_busy[CMD_RX_META_POP];
		assign trace_sp_unit_rx.rx_meta_empty = rx_cmds_busy[CMD_RX_META_EMPTY];
		assign trace_sp_unit_rx.rx_data_dma_start = rx_cmds_busy[CMD_RX_DATA_DMA_START];
		assign trace_sp_unit_rx.rx_data_dma_status = rx_cmds_busy[CMD_RX_DATA_DMA_STATUS];
	end

	/* Using wb.ack with this results in a UNOPTFLAT warning from verilator:
	 *
	 *   Signal unoptimizable: Feedback to clock or circular logic:
	 *   'taiga_sim.cpu.register_file_and_writeback_block.unit_ack'
	 */
	assign issue.ready = ~|{acp_cmds_busy, common_cmds_busy, rx_cmds_busy, puzzle_cmds_busy};
	assign wb.done = |{acp_cmds_done, common_cmds_done, rx_cmds_done, puzzle_cmds_done};

	always_comb begin
		puzzle_issue_cmd = '0;
		rx_issue_cmd = '0;
		common_issue_cmd = '0;
		acp_issue_cmd = '0;

		case (sp_inputs.fn7[4:0])
		SP_FUNC7_PUZZLE_FIFO_R_EMPTY: puzzle_issue_cmd[CMD_PUZZLE_FIFO_R_EMPTY] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_R_POP: puzzle_issue_cmd[CMD_PUZZLE_FIFO_R_POP] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_W_FULL: puzzle_issue_cmd[CMD_PUZZLE_FIFO_W_FULL] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_W_PUSH: puzzle_issue_cmd[CMD_PUZZLE_FIFO_W_PUSH] = 1'b1;

		//SP_FUNC7_RX_META_NELEMS: rx_issue_cmd[CMD_RX_META_NELEMS] = 1'b1;
		SP_FUNC7_RX_META_POP: rx_issue_cmd[CMD_RX_META_POP] = 1'b1;
		SP_FUNC7_RX_META_EMPTY: rx_issue_cmd[CMD_RX_META_EMPTY] = 1'b1;
		SP_FUNC7_RX_DATA_DMA_START: rx_issue_cmd[CMD_RX_DATA_DMA_START] = 1'b1;
		SP_FUNC7_RX_DATA_DMA_STATUS: rx_issue_cmd[CMD_RX_DATA_DMA_STATUS] = 1'b1;

		SP_FUNC7_COMMON_LOAD_REG: common_issue_cmd[CMD_COMMON_LOAD_REG] = 1'b1;
		SP_FUNC7_COMMON_STORE_REG: common_issue_cmd[CMD_COMMON_STORE_REG] = 1'b1;
		SP_FUNC7_COMMON_READ_TRIGGER: common_issue_cmd[CMD_COMMON_READ_TRIGGER] = 1'b1;
		SP_FUNC7_COMMON_INTR: common_issue_cmd[CMD_COMMON_INTR] = 1'b1;

		SP_FUNC7_ACP_READ_START: acp_issue_cmd[CMD_ACP_READ_START] = 1'b1;
		SP_FUNC7_ACP_READ_STATUS: acp_issue_cmd[CMD_ACP_READ_STATUS] = 1'b1;
		SP_FUNC7_ACP_WRITE_START: acp_issue_cmd[CMD_ACP_WRITE_START] = 1'b1;
		SP_FUNC7_ACP_WRITE_STATUS: acp_issue_cmd[CMD_ACP_WRITE_STATUS] = 1'b1;
		SP_FUNC7_ACP_SET_LOCAL_WSTRB: acp_issue_cmd[CMD_ACP_SET_LOCAL_WSTRB] = 1'b1;
		SP_FUNC7_ACP_SET_REMOTE_WSTRB: acp_issue_cmd[CMD_ACP_SET_REMOTE_WSTRB] = 1'b1;
		default: begin end
		endcase
	end

	prism_sp_unit_rx#(
		.RESULT_WIDTH($bits(wb.rd))
	) prism_sp_unit_rx_0(
		.clk,
		.rst,

		.sp_inputs,
		.issue,
		.wb,

		.issue_cmd(rx_issue_cmd),
		.cmds_busy(rx_cmds_busy),
		.cmds_done(rx_cmds_done),
		.result(specific_result),

		.rx_data_mem_w,
		.rx_meta_fifo_r,

		.trace_sp_unit_rx
	);
end

if (USE_SP_UNIT_TX) begin
	var logic [SP_UNIT_TX_NCMDS-1:0] tx_issue_cmd;
	wire logic [SP_UNIT_TX_NCMDS-1:0] tx_cmds_busy;
	wire logic [SP_UNIT_TX_NCMDS-1:0] tx_cmds_done;

	if (SP_UNIT_ENABLE_TRACE) begin
		assign trace_sp_unit_tx.tx_meta_push = tx_cmds_busy[CMD_TX_META_PUSH];
		assign trace_sp_unit_tx.tx_meta_full = tx_cmds_busy[CMD_TX_META_FULL];
		assign trace_sp_unit_tx.tx_data_dma_start = tx_cmds_busy[CMD_TX_DATA_DMA_START];
		assign trace_sp_unit_tx.tx_data_dma_status = tx_cmds_busy[CMD_TX_DATA_DMA_STATUS];
	end

	assign issue.ready = ~|{acp_cmds_busy, common_cmds_busy, tx_cmds_busy, puzzle_cmds_busy};
	assign wb.done = |{acp_cmds_done, common_cmds_done, tx_cmds_done, puzzle_cmds_done};

	always_comb begin
		puzzle_issue_cmd = '0;
		tx_issue_cmd = '0;
		common_issue_cmd = '0;
		acp_issue_cmd = '0;

		case (sp_inputs.fn7[4:0])
		SP_FUNC7_PUZZLE_FIFO_R_EMPTY: puzzle_issue_cmd[CMD_PUZZLE_FIFO_R_EMPTY] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_R_POP: puzzle_issue_cmd[CMD_PUZZLE_FIFO_R_POP] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_W_FULL: puzzle_issue_cmd[CMD_PUZZLE_FIFO_W_FULL] = 1'b1;
		SP_FUNC7_PUZZLE_FIFO_W_PUSH: puzzle_issue_cmd[CMD_PUZZLE_FIFO_W_PUSH] = 1'b1;

		//SP_FUNC7_TX_META_NFREE: tx_issue_cmd[CMD_TX_META_NFREE] = 1'b1;
		SP_FUNC7_TX_META_PUSH: tx_issue_cmd[CMD_TX_META_PUSH] = 1'b1;
		SP_FUNC7_TX_META_FULL: tx_issue_cmd[CMD_TX_META_FULL] = 1'b1;
		SP_FUNC7_TX_DATA_COUNT: tx_issue_cmd[CMD_TX_DATA_COUNT] = 1'b1;
		SP_FUNC7_TX_DATA_DMA_START: tx_issue_cmd[CMD_TX_DATA_DMA_START] = 1'b1;
		SP_FUNC7_TX_DATA_DMA_STATUS: tx_issue_cmd[CMD_TX_DATA_DMA_STATUS] = 1'b1;

		SP_FUNC7_COMMON_LOAD_REG: common_issue_cmd[CMD_COMMON_LOAD_REG] = 1'b1;
		SP_FUNC7_COMMON_STORE_REG: common_issue_cmd[CMD_COMMON_STORE_REG] = 1'b1;
		SP_FUNC7_COMMON_READ_TRIGGER: common_issue_cmd[CMD_COMMON_READ_TRIGGER] = 1'b1;
		SP_FUNC7_COMMON_INTR: common_issue_cmd[CMD_COMMON_INTR] = 1'b1;

		SP_FUNC7_ACP_READ_START: acp_issue_cmd[CMD_ACP_READ_START] = 1'b1;
		SP_FUNC7_ACP_READ_STATUS: acp_issue_cmd[CMD_ACP_READ_STATUS] = 1'b1;
		SP_FUNC7_ACP_WRITE_START: acp_issue_cmd[CMD_ACP_WRITE_START] = 1'b1;
		SP_FUNC7_ACP_WRITE_STATUS: acp_issue_cmd[CMD_ACP_WRITE_STATUS] = 1'b1;
		SP_FUNC7_ACP_SET_LOCAL_WSTRB: acp_issue_cmd[CMD_ACP_SET_LOCAL_WSTRB] = 1'b1;
		SP_FUNC7_ACP_SET_REMOTE_WSTRB: acp_issue_cmd[CMD_ACP_SET_REMOTE_WSTRB] = 1'b1;
		default: begin end
		endcase
	end

	prism_sp_unit_tx#(
		.RESULT_WIDTH($bits(wb.rd))
	) prism_sp_unit_tx_0(
		.clk,
		.rst,

		.sp_inputs,
		.issue,
		.wb,

		.issue_cmd(tx_issue_cmd),
		.cmds_busy(tx_cmds_busy),
		.cmds_done(tx_cmds_done),
		.result(specific_result),

		.tx_data_fifo_w,
		.tx_data_mem_r,
		.tx_meta_fifo_w,

		.trace_sp_unit_tx
	);
end

always_comb begin
	puzzle_issue_cmd_valid = 1'b0;
	specific_issue_cmd_valid = 1'b0;
	common_issue_cmd_valid = 1'b0;
	acp_issue_cmd_valid = 1'b0;

	case (sp_inputs.fn7[4:3])
	2'b00: puzzle_issue_cmd_valid = 1'b1;
	2'b01: specific_issue_cmd_valid = 1'b1;
	2'b10: common_issue_cmd_valid = 1'b1;
	2'b11: acp_issue_cmd_valid = 1'b1;
	endcase
end

if (SP_UNIT_ENABLE_TRACE) begin
	assign trace_sp_unit.acp_read_start = acp_cmds_busy[CMD_ACP_READ_START];
	assign trace_sp_unit.acp_read_status = acp_cmds_busy[CMD_ACP_READ_STATUS];
	assign trace_sp_unit.acp_write_start = acp_cmds_busy[CMD_ACP_WRITE_START];
	assign trace_sp_unit.acp_write_status = acp_cmds_busy[CMD_ACP_WRITE_STATUS];
end

/*
 * Response muxing.
 */
var logic cur_puzzle;
var logic cur_specific;
var logic cur_common;
var logic cur_acp;

assign wb.id = cur_id;
assign wb.rd = result;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready) begin
			cur_id <= issue.id;

			cur_puzzle <= puzzle_issue_cmd_valid;
			cur_specific <= specific_issue_cmd_valid;
			cur_common <= common_issue_cmd_valid;
			cur_acp <= acp_issue_cmd_valid;
		end
	end
end

always_comb begin
	result = '0;
	case (1'b1)
	cur_puzzle: result = puzzle_result;
	cur_specific: result = specific_result;
	cur_common: result = common_result;
	cur_acp: result = acp_result;
	endcase
end

prism_sp_unit_puzzle#(
	.RESULT_WIDTH($bits(wb.rd)),
	.RX_INSTANCE(USE_SP_UNIT_RX),
	.TX_INSTANCE(USE_SP_UNIT_TX),
	.NFIFOS(NPUZZLEFIFOS)
) prism_sp_unit_puzzle_0(
	.clk,
	.rst,

	.sp_inputs,
	.issue,
	.wb,

	.issue_cmd(puzzle_issue_cmd),
	.cmds_busy(puzzle_cmds_busy),
	.cmds_done(puzzle_cmds_done),
	.result(puzzle_result),

	.puzzle_fifo_r_0(puzzle_sw_fifo_r_0),
	.puzzle_fifo_w_0(puzzle_sw_fifo_w_0),
	.puzzle_fifo_r_1(puzzle_sw_fifo_r_1),
	.puzzle_fifo_w_1(puzzle_sw_fifo_w_1),
	.puzzle_fifo_r_2(puzzle_sw_fifo_r_2),
	.puzzle_fifo_w_2(puzzle_sw_fifo_w_2),
	.puzzle_fifo_r_3(puzzle_sw_fifo_r_3),
	.puzzle_fifo_w_3(puzzle_sw_fifo_w_3)
);

prism_sp_unit_common#(
	.RESULT_WIDTH($bits(wb.rd))
) prism_sp_unit_common_0(
	.clk,
	.rst,

	.sp_inputs,
	.issue,
	.wb,

	.issue_cmd(common_issue_cmd),
	.cmds_busy(common_cmds_busy),
	.cmds_done(common_cmds_done),
	.result(common_result),

	.mmr_rw,
	.mmr_r,
	.mmr_t,
	.mmr_i
);

prism_sp_unit_acp#(
	.RESULT_WIDTH($bits(wb.rd))
) prism_sp_unit_acp_0(
	.clk,
	.rst,

	.sp_inputs,
	.issue,
	.wb,

	.issue_cmd(acp_issue_cmd),
	.cmds_busy(acp_cmds_busy),
	.cmds_done(acp_cmds_done),
	.result(acp_result),

	.acpram_port_i(acpram_port_i),
	.m_axi_acp_aw,
	.m_axi_acp_w,
	.m_axi_acp_b,
	.m_axi_acp_ar,
	.m_axi_acp_r
);

endmodule
