// 4 bytes FIFO

`timescale 1ns / 1ps

module fifo8(
    i_clk,
	i_reset,
    i_dat,
    o_dat,
    i_push,
    i_pop,
	o_empty,
	o_full
);

input i_clk;
input i_reset;
input  [7:0] i_dat;
output [7:0] o_dat;
input i_push;
input i_pop;
output o_empty;
output o_full;

parameter DEPTH = 4;
parameter WIDTH = $clog2(DEPTH);

reg [7:0] buffer[0:DEPTH-1];
reg [WIDTH-1:0] rd_idx;
reg [WIDTH-1:0] wr_idx;
reg empty_n;

assign o_empty = ~empty_n;
assign o_full = ( wr_idx == rd_idx ) && ~o_empty;
assign o_dat[7:0] = buffer[rd_idx];

wire [WIDTH-1:0] rd_idx_next = rd_idx + 1;
wire [WIDTH-1:0] wr_idx_next = wr_idx + 1;

reg push_r, pop_r;
always @(posedge i_clk) begin
    push_r <= i_push;
    pop_r <= i_pop;
end

wire push_pe = ~push_r && i_push;
wire pop_pe = ~pop_r && i_pop;

always @(posedge i_clk) begin
    if( push_pe && ~o_full ) begin
        wr_idx <= wr_idx_next;
        buffer[wr_idx] <= i_dat[7:0];
        empty_n <= 1'b1;
    end else if( pop_pe && ~o_empty ) begin
        rd_idx <= rd_idx_next;
        empty_n <= (wr_idx != rd_idx_next);
    end
    if( i_reset ) begin
        rd_idx <= 'd0;
        wr_idx <= 'd0;
        empty_n <= 1'b0;
    end
end

endmodule
