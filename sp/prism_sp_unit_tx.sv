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

module prism_sp_unit_tx#(
	parameter int RESULT_WIDTH
)
(
	input wire logic clk,
	input wire logic rst,

	input sp_inputs_t sp_inputs,
	unit_issue_interface.unit issue,
	unit_writeback_interface.unit wb,

	input wire logic [SP_UNIT_TX_NCMDS-1:0] issue_cmd,
	output wire logic [SP_UNIT_TX_NCMDS-1:0] cmds_busy,
	output wire logic [SP_UNIT_TX_NCMDS-1:0] cmds_done,
	output var logic [RESULT_WIDTH-1:0] result,

	fifo_write_interface.inputs tx_data_fifo_w,
	memory_read_interface.master tx_data_mem_r,
	fifo_write_interface.master tx_meta_fifo_w,

	output trace_sp_unit_tx_t trace_sp_unit_tx
);

localparam int SP_UNIT_ENABLE_TRACE = 1;
if (SP_UNIT_ENABLE_TRACE) begin
	assign trace_sp_unit_tx.tx_dma_busy = tx_data_mem_r.busy;
end

var logic [SP_UNIT_TX_NCMDS-1:0] cmds_busy_ff;
var logic [SP_UNIT_TX_NCMDS-1:0] cmds_busy_comb;
var logic [SP_UNIT_TX_NCMDS-1:0] cmds_done_ff;
var logic [SP_UNIT_TX_NCMDS-1:0] cmds_done_comb;
assign cmds_busy = cmds_busy_ff;
assign cmds_done = cmds_done_ff;

/*
 * --------  --------  --------  --------
 * PL Clock Domain
 * --------  --------  --------  --------
 */
/*
 * Command "TX META PUSH"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_tx_meta_push(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_TX_META_PUSH]),
	.cmd_done(cmds_done[CMD_TX_META_PUSH]),
	.cmd_busy(cmds_busy[CMD_TX_META_PUSH])
);

always_ff @(posedge clk) begin
	tx_meta_fifo_w.wr_en <= 1'b0;

	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_TX_META_PUSH]) begin
			tx_meta_fifo_w.wr_en <= 1'b1;
			tx_meta_fifo_w.wr_data <= sp_inputs.rs1;
		end
	end
end

/*
 * Command "TX META FULL"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_tx_meta_full(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_TX_META_FULL]),
	.cmd_done(cmds_done[CMD_TX_META_FULL]),
	.cmd_busy(cmds_busy[CMD_TX_META_FULL])
);

/*
 * Command "TX DATA COUNT"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_tx_data_count(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_TX_DATA_COUNT]),
	.cmd_done(cmds_done[CMD_TX_DATA_COUNT]),
	.cmd_busy(cmds_busy[CMD_TX_DATA_COUNT])
);

var logic [$bits(tx_data_fifo_w.wr_data_count)+$clog2(tx_data_fifo_w.DATA_WIDTH/8)-1:0] tx_data_count_result_ff;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_TX_DATA_COUNT]) begin
			tx_data_count_result_ff <= 32'({ tx_data_fifo_w.wr_data_count, {($clog2(tx_data_fifo_w.DATA_WIDTH/8)){1'b0}} });
		end
	end
end

/*
 * Command "TX DATA DMA START"
 */
if (ENABLE_TX_SW_TX_DATA_MEM_R) begin
	prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_tx_data_dma_start(
		.clk(clk),
		.rst(rst),
		.issue(issue),
		.wb(wb),
		.issue_cmd(issue_cmd[CMD_TX_DATA_DMA_START]),
		.cmd_done(cmds_done[CMD_TX_DATA_DMA_START]),
		.cmd_busy(cmds_busy[CMD_TX_DATA_DMA_START])
	);

	always_ff @(posedge clk) begin
		tx_data_mem_r.start <= 1'b0;

		if (rst) begin
		end
		else begin
			if (issue.new_request & issue.ready & issue_cmd[CMD_TX_DATA_DMA_START]) begin
				tx_data_mem_r.start <= 1'b1;
				tx_data_mem_r.addr <= sp_inputs.rs1;
				tx_data_mem_r.len <= sp_inputs.rs2[15:0];
				tx_data_mem_r.cont <= sp_inputs.rs2[31];
			end
		end
	end
end

/*
 * Command "TX DATA DMA STATUS"
 */
var logic tx_data_dma_status_result_ff;

if (ENABLE_TX_SW_TX_DATA_MEM_R) begin
	prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_tx_data_dma_status(
		.clk(clk),
		.rst(rst),
		.issue(issue),
		.wb(wb),
		.issue_cmd(issue_cmd[CMD_TX_DATA_DMA_STATUS]),
		.cmd_done(cmds_done[CMD_TX_DATA_DMA_STATUS]),
		.cmd_busy(cmds_busy[CMD_TX_DATA_DMA_STATUS])
	);

	always_ff @(posedge clk) begin
		if (rst) begin
		end
		else begin
			if (issue.new_request & issue.ready & issue_cmd[CMD_TX_DATA_DMA_STATUS]) begin
				tx_data_dma_status_result_ff <= tx_data_mem_r.busy;
			end
		end
	end
end

var logic [SP_UNIT_TX_NCMDS-1:0] cur_cmd;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready) begin
			cur_cmd <= issue_cmd;
		end
	end
end

always_comb begin
	result = '0;

	// "Reverse case" statement for one-hot encoding.
	case (1'b1)
	//cur_cmd[CMD_TX_META_NFREE]: result = 32'(tx_meta_nfree_comb);
	cur_cmd[CMD_TX_META_FULL]: result[0] = tx_meta_fifo_w.full;
	cur_cmd[CMD_TX_DATA_COUNT]: result = 31'(tx_data_count_result_ff);
	cur_cmd[CMD_TX_DATA_DMA_STATUS]: result[0] = tx_data_dma_status_result_ff;
	endcase
end
endmodule
