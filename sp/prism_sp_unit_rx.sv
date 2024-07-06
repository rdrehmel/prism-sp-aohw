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

module prism_sp_unit_rx#(
	parameter int RESULT_WIDTH
)
(
	input wire logic clk,
	input wire logic rst,

	input sp_inputs_t sp_inputs,
	unit_issue_interface.unit issue,
	unit_writeback_interface.unit wb,

	input wire logic [SP_UNIT_RX_NCMDS-1:0] issue_cmd,
	output wire logic [SP_UNIT_RX_NCMDS-1:0] cmds_busy,
	output wire logic [SP_UNIT_RX_NCMDS-1:0] cmds_done,
	output var logic [RESULT_WIDTH-1:0] result,

	memory_write_interface.master rx_data_mem_w,
	fifo_read_interface.master rx_meta_fifo_r,

	output trace_sp_unit_rx_t trace_sp_unit_rx
);

localparam int SP_UNIT_ENABLE_TRACE = 1;
if (SP_UNIT_ENABLE_TRACE) begin
	assign trace_sp_unit_rx.rx_dma_busy = rx_data_mem_w.busy;
end

var logic [SP_UNIT_RX_NCMDS-1:0] cmds_busy_ff;
var logic [SP_UNIT_RX_NCMDS-1:0] cmds_busy_comb;
var logic [SP_UNIT_RX_NCMDS-1:0] cmds_done_ff;
var logic [SP_UNIT_RX_NCMDS-1:0] cmds_done_comb;
assign cmds_busy = cmds_busy_ff;
assign cmds_done = cmds_done_ff;

/*
 * Command "RX META POP"
 */
var logic [31:0] rx_meta_fifo_read_rd_data;

prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_rx_meta_pop(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_RX_META_POP]),
	.cmd_done(cmds_done[CMD_RX_META_POP]),
	.cmd_busy(cmds_busy[CMD_RX_META_POP])
);

always_ff @(posedge clk) begin
	rx_meta_fifo_r.rd_en <= 1'b0;

	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_RX_META_POP]) begin
			rx_meta_fifo_r.rd_en <= 1'b1;
			rx_meta_fifo_read_rd_data <= rx_meta_fifo_r.rd_data;
		end
	end
end

/*
 * "RX META EMPTY" command
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_rx_meta_empty(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_RX_META_EMPTY]),
	.cmd_done(cmds_done[CMD_RX_META_EMPTY]),
	.cmd_busy(cmds_busy[CMD_RX_META_EMPTY])
);

/*
 * Command "RX DATA DMA START"
 */
if (ENABLE_RX_SW_RX_DATA_MEM_W) begin
	prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_rx_data_dma_start(
		.clk(clk),
		.rst(rst),
		.issue(issue),
		.wb(wb),
		.issue_cmd(issue_cmd[CMD_RX_DATA_DMA_START]),
		.cmd_done(cmds_done[CMD_RX_DATA_DMA_START]),
		.cmd_busy(cmds_busy[CMD_RX_DATA_DMA_START])
	);

	always_ff @(posedge clk) begin
		rx_data_mem_w.start <= 1'b0;

		if (rst) begin
		end
		else begin
			if (issue.new_request & issue.ready & issue_cmd[CMD_RX_DATA_DMA_START]) begin
				rx_data_mem_w.start <= 1'b1;
				rx_data_mem_w.addr <= sp_inputs.rs1;
				rx_data_mem_w.len <= sp_inputs.rs2[15:0];
			end
		end
	end
end

/*
 * Command "RX DATA DMA STATUS"
 */
var logic rx_data_dma_status_result_ff;

if (ENABLE_RX_SW_RX_DATA_MEM_W) begin
	prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_rx_data_dma_status (
		.clk(clk),
		.rst(rst),
		.issue(issue),
		.wb(wb),
		.issue_cmd(issue_cmd[CMD_RX_DATA_DMA_STATUS]),
		.cmd_done(cmds_done[CMD_RX_DATA_DMA_STATUS]),
		.cmd_busy(cmds_busy[CMD_RX_DATA_DMA_STATUS])
	);

	always_ff @(posedge clk) begin
		if (rst) begin
		end
		else begin
			if (issue.new_request & issue.ready & issue_cmd[CMD_RX_DATA_DMA_STATUS]) begin
				rx_data_dma_status_result_ff <= rx_data_mem_w.busy;
			end
		end
	end
end

var logic [SP_UNIT_RX_NCMDS-1:0] cur_cmd;

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
	//cur_cmd[CMD_RX_META_NELEMS]: result = 32'(rx_meta_nelems_comb);
	cur_cmd[CMD_RX_META_POP]: result = rx_meta_fifo_read_rd_data;
	cur_cmd[CMD_RX_META_EMPTY]: result[0] = rx_meta_fifo_r.empty;
	cur_cmd[CMD_RX_DATA_DMA_STATUS]: result[0] = rx_data_dma_status_result_ff;
	endcase
end

endmodule
