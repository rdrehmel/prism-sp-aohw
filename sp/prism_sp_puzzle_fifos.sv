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
module prism_sp_puzzle_fifos
#(
	parameter int NFIFOS,
	parameter int FIFO_WRITE_DEPTH [NFIFOS]
)
(
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.slave fifo_r_0,
	fifo_write_interface.slave fifo_w_0,
	fifo_read_interface.slave fifo_r_1,
	fifo_write_interface.slave fifo_w_1,
	fifo_read_interface.slave fifo_r_2,
	fifo_write_interface.slave fifo_w_2,
	fifo_read_interface.slave fifo_r_3,
	fifo_write_interface.slave fifo_w_3
);

xpm_fifo_sync #(
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH[0]),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	.RD_DATA_COUNT_WIDTH(fifo_r_0.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(fifo_r_0.DATA_WIDTH),
	.READ_MODE("fwft"),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	.WR_DATA_COUNT_WIDTH(fifo_w_0.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(fifo_w_0.DATA_WIDTH)
) fifo_0 (
	.rst(~resetn),

	.wr_clk(clock),
	.wr_en(fifo_w_0.wr_en),
	.din(fifo_w_0.wr_data),
	.full(fifo_w_0.full),
	.almost_full(fifo_w_0.almost_full),
	.wr_data_count(fifo_w_0.wr_data_count),

	.rd_en(fifo_r_0.rd_en),
	.dout(fifo_r_0.rd_data),
	.empty(fifo_r_0.empty),
	.almost_empty(fifo_r_0.almost_empty),
	.rd_data_count(fifo_r_0.rd_data_count)
);

xpm_fifo_sync #(
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH[1]),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	.RD_DATA_COUNT_WIDTH(fifo_r_1.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(fifo_r_1.DATA_WIDTH),
	.READ_MODE("fwft"),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	.WR_DATA_COUNT_WIDTH(fifo_w_1.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(fifo_w_1.DATA_WIDTH)
) fifo_1 (
	.rst(~resetn),

	.wr_clk(clock),
	.wr_en(fifo_w_1.wr_en),
	.din(fifo_w_1.wr_data),
	.full(fifo_w_1.full),
	.almost_full(fifo_w_1.almost_full),
	.wr_data_count(fifo_w_1.wr_data_count),

	.rd_en(fifo_r_1.rd_en),
	.dout(fifo_r_1.rd_data),
	.empty(fifo_r_1.empty),
	.almost_empty(fifo_r_1.almost_empty),
	.rd_data_count(fifo_r_1.rd_data_count)
);

xpm_fifo_sync #(
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH[2]),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	.RD_DATA_COUNT_WIDTH(fifo_r_2.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(fifo_r_2.DATA_WIDTH),
	.READ_MODE("fwft"),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	.WR_DATA_COUNT_WIDTH(fifo_w_2.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(fifo_w_2.DATA_WIDTH)
) fifo_2 (
	.rst(~resetn),

	.wr_clk(clock),
	.wr_en(fifo_w_2.wr_en),
	.din(fifo_w_2.wr_data),
	.full(fifo_w_2.full),
	.almost_full(fifo_w_2.almost_full),
	.wr_data_count(fifo_w_2.wr_data_count),

	.rd_en(fifo_r_2.rd_en),
	.dout(fifo_r_2.rd_data),
	.empty(fifo_r_2.empty),
	.almost_empty(fifo_r_2.almost_empty),
	.rd_data_count(fifo_r_2.rd_data_count)
);

xpm_fifo_sync #(
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH[3]),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	.RD_DATA_COUNT_WIDTH(fifo_r_3.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(fifo_r_3.DATA_WIDTH),
	.READ_MODE("fwft"),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	.WR_DATA_COUNT_WIDTH(fifo_w_3.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(fifo_w_3.DATA_WIDTH)
) fifo_3 (
	.rst(~resetn),

	.wr_clk(clock),
	.wr_en(fifo_w_3.wr_en),
	.din(fifo_w_3.wr_data),
	.full(fifo_w_3.full),
	.almost_full(fifo_w_3.almost_full),
	.wr_data_count(fifo_w_3.wr_data_count),

	.rd_en(fifo_r_3.rd_en),
	.dout(fifo_r_3.rd_data),
	.empty(fifo_r_3.empty),
	.almost_empty(fifo_r_3.almost_empty),
	.rd_data_count(fifo_r_3.rd_data_count)
);

endmodule
