`timescale 1ns / 1ns

module uart_tx(
    i_clk,
    i_reset,
    i_dat,
    i_fifo_push,
    o_fifo_full,
    tx
);


input i_clk;
input i_reset;
input [7:0] i_dat;
input i_fifo_push;
output o_fifo_full;
output tx;

parameter SYS_CLK = 'd25_000_000;
parameter BAUDRATE = 'd115200;

localparam TICK = (SYS_CLK/BAUDRATE);

//---------------------------------------------
// fifo

wire [7:0] fifo_dat;
wire fifo_pop;
wire fifo_empty;

fifo8 #(.DEPTH(2)) fifo0(
    .i_clk(i_clk),
	.i_reset(i_reset),
    .i_dat(i_dat),
    .o_dat(fifo_dat),
    .i_push(i_fifo_push),
    .i_pop(fifo_pop),
	.o_empty(fifo_empty),
	.o_full(o_fifo_full)
);

//---------------------------------------------
// uart tx

// tx baudrate generator
reg [8:0] baud_tx;

wire tick_tx = (baud_tx[8:0] == TICK[8:0]);
wire start_tx = (state_tx == IDLE) && ~fifo_empty;

always @(posedge i_clk) begin
	if(tick_tx || start_tx) begin
		baud_tx <= 0;
	end else begin
		baud_tx <= baud_tx + 1;
	end
end


localparam
    SEND      = 4'd0,
    STOPBIT1  = 4'd8,
    STOPBIT2  = 4'd9,
    IDLE      = 4'd10,
    STARTBIT  = 4'd11;

reg [3:0] state_tx = IDLE;
wire [2:0] bit_idx = state_tx[2:0];

assign tx = (state_tx  < STOPBIT1) ? fifo_dat[ bit_idx ] :
            (state_tx == STARTBIT) ? 1'b0 : // start bit
                                     1'b1;  // idle & stop bit

assign fifo_pop = (state_tx == STOPBIT1);

always @(posedge i_clk)
begin
    case( state_tx )
        IDLE: // idle, wait for data in fifo
            if( ~fifo_empty ) begin
                state_tx <= STARTBIT;
            end
        STARTBIT: // start bit
            if( tick_tx ) begin
                state_tx <= SEND;
            end
        default:
            if( tick_tx ) begin
                state_tx <= state_tx + 1;
            end
    endcase

    if( i_reset ) begin
        state_tx <= IDLE;
    end
end

endmodule

