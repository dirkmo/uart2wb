module top(
    i_clk,
    i_reset,
    uart_rx,
    uart_tx,

    debug_wire,

    o_reset
);

input i_clk;
input i_reset;
input uart_rx;
output uart_tx;
output o_reset;

/* verilator lint_off UNUSED */
input debug_wire;
/* verilator lint_on UNUSED */

reg [31:0] ram[0:'hFFFF];

wire [7:0] rx_data;
wire [7:0] tx_data;
wire received;
wire send;
wire fifo_full;

parameter SYS_CLK = 'd25_000_000;
parameter BAUDRATE = 'd115200;

uart_rx #(.SYS_CLK(SYS_CLK), .BAUDRATE(BAUDRATE)) Uart0_rx(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .o_dat(rx_data),
    .rx(uart_rx),
    .received(received)
);

uart_tx #(.SYS_CLK(SYS_CLK), .BAUDRATE(BAUDRATE)) Uart0_tx(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_dat(tx_data),
    .i_fifo_push(send),
    .o_fifo_full(fifo_full),
    .tx(uart_tx)
);

/* verilator lint_off UNUSED */
wire [31:0] wb_addr;
/* verilator lint_on UNUSED */

wire [31:0] wb_dat;
wire [3:0] wb_stb;
wire wb_cyc;
wire wb_we;

wire [15:0] addr = wb_addr[15:0];

uart2wb uart2wb0(
    .i_wb_clk(i_clk),
    .i_wb_rst(i_reset),
    .i_wb_ack(wb_cyc),
    .i_wb_dat(ram[addr]),
    .o_wb_dat(wb_dat),
    .o_wb_stb(wb_stb),
    .o_wb_cyc(wb_cyc),
    .o_wb_addr(wb_addr),
    .o_wb_we(wb_we),
    
    .i_uart_rx_dat(rx_data),
    .i_uart_received_strobe(received),
    
    .o_uart_tx_dat(tx_data),
    .o_uart_tx_trigger(send),
    .i_uart_tx_ready_to_send(~fifo_full),
    
    .o_reset(o_reset)
);

always @(posedge i_clk)
begin
    if( wb_we && wb_cyc ) begin
        if(wb_stb[0]) begin
        	ram[addr][7:0] <= wb_dat[7:0];
        end
        if(wb_stb[1]) begin
        	ram[addr][15:8] <= wb_dat[15:8];
        end
        if(wb_stb[2]) begin
        	ram[addr][23:16] <= wb_dat[23:16];
        end
        if(wb_stb[3]) begin
        	ram[addr][31:24] <= wb_dat[31:24];
        end
    end
end

endmodule
