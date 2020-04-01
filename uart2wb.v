// uart-to-wishbone bridge
// uart needs a 8-byte tx fifo
module uart2wb(
    i_wb_clk,
    i_wb_rst,
    i_wb_ack,
    i_wb_dat,
    o_wb_dat,
    o_wb_stb,
    o_wb_cyc,
    o_wb_addr,
    o_wb_we,

    i_uart_rx_dat,
    i_uart_received_strobe,
    
    o_uart_tx_dat,
    o_uart_tx_trigger,
    i_uart_tx_ready_to_send,

    o_reset
);

// wb interface
input i_wb_clk;
input i_wb_rst;
input i_wb_ack;
input [31:0] i_wb_dat;
output [31:0] o_wb_dat;
output [3:0] o_wb_stb;
output o_wb_cyc;
output [31:0] o_wb_addr;
output o_wb_we;

// uart interface
input [7:0] i_uart_rx_dat;
input i_uart_received_strobe;
output [7:0] o_uart_tx_dat;
output reg o_uart_tx_trigger;
input i_uart_tx_ready_to_send;

output reg o_reset;

//------------------------------------------------------------------------------
// uart rx char decoder
//
// . 0x2e           trigger reset
// a 0x61           select address register
// d 0x64           select data register
// w 0x77           trigger write
// r 0x72           trigger read
// 0-9 0x30-0x39    
// A-F 0x41-0x46

// input data evalutation, special r_decode meanings
localparam
    DECODE_RESET      = 5'h10, // reset machine
    DECODE_SEL_AR     = 5'h11, // select address register, starting with lowest nibble
    DECODE_SEL_DR     = 5'h12, // select data register
    DECODE_READ_DATA  = 5'h13, // perform read
    DECODE_WRITE_DATA = 5'h14, // perform write
    DECODE_INVALID    = 5'h1f; // invalid character

reg [4:0] r_decode;
reg next;
always @(posedge i_wb_clk)
begin
    next <= 'h0;
    if( i_uart_received_strobe ) begin
        next <= 'h1;
        case( i_uart_rx_dat )
            8'h2e: r_decode <= DECODE_RESET;
            8'h61: r_decode <= DECODE_SEL_AR;
            8'h64: r_decode <= DECODE_SEL_DR;
            8'h72: r_decode <= DECODE_READ_DATA;
            8'h77: r_decode <= DECODE_WRITE_DATA;

            8'h30: r_decode <= 'h0;
            8'h31: r_decode <= 'h1;
            8'h32: r_decode <= 'h2;
            8'h33: r_decode <= 'h3;
            8'h34: r_decode <= 'h4;
            8'h35: r_decode <= 'h5;
            8'h36: r_decode <= 'h6;
            8'h37: r_decode <= 'h7;
            8'h38: r_decode <= 'h8;
            8'h39: r_decode <= 'h9;
            8'h41: r_decode <= 'ha;
            8'h42: r_decode <= 'hb;
            8'h43: r_decode <= 'hc;
            8'h44: r_decode <= 'hd;
            8'h45: r_decode <= 'he;
            8'h46: r_decode <= 'hf;
            default: r_decode <= DECODE_INVALID;
        endcase
    end
end

//------------------------------------------------------------------------------

// register[] to keep address and data
reg [63:0] registers;
wire [31:0] data = registers[63:32];
wire [31:0] address = registers[31:0];

reg [3:0] r_nibble_idx;

localparam
    STATE_IDLE = 0,
    STATE_READ = 1,
    STATE_WRITE = 2;

always @(posedge i_wb_clk) begin
    if( next && ~r_decode[4] ) begin // r_decode[4] = 0: is number, else is special char
        case( r_nibble_idx )
            'h0: registers[ 3: 0] <= r_decode[3:0];
            'h1: registers[ 7: 4] <= r_decode[3:0];
            'h2: registers[11: 8] <= r_decode[3:0];
            'h3: registers[15:12] <= r_decode[3:0];
            'h4: registers[19:16] <= r_decode[3:0];
            'h5: registers[23:20] <= r_decode[3:0];
            'h6: registers[27:24] <= r_decode[3:0];
            'h7: registers[31:28] <= r_decode[3:0];
            'h8: registers[35:32] <= r_decode[3:0];
            'h9: registers[39:36] <= r_decode[3:0];
            'ha: registers[43:40] <= r_decode[3:0];
            'hb: registers[47:44] <= r_decode[3:0];
            'hc: registers[51:48] <= r_decode[3:0];
            'hd: registers[55:52] <= r_decode[3:0];
            'he: registers[59:56] <= r_decode[3:0];
            'hf: registers[63:60] <= r_decode[3:0];
        endcase
    end else if( i_wb_ack ) begin
        // auto-increment after read or write
        registers[31:0] <= registers[31:0] + 1'b1;
    end
end

/* verilator lint_off BLKSEQ */

reg [2:0] r_state;
always @(posedge i_wb_clk)
begin
    o_reset <= 0;

    case(r_state)
        STATE_IDLE: if( next ) begin
            if( r_decode == DECODE_SEL_AR ) begin
                r_nibble_idx <= 'h0;
            end else if( r_decode == DECODE_SEL_DR ) begin
                r_nibble_idx <= 'h8; // data register[31:0] = registers[63:32]
            end else if( ~r_decode[4] ) begin
                r_nibble_idx <= r_nibble_idx + 'h1;
            end else if( r_decode == DECODE_READ_DATA ) begin
                r_state <= STATE_READ;
            end else if( r_decode == DECODE_WRITE_DATA ) begin
                r_state <= STATE_WRITE;
            end else if( r_decode == DECODE_RESET ) begin
                o_reset <= 1;
            end
        end
        STATE_READ: begin r_state <= STATE_IDLE; end
        STATE_WRITE: begin r_state <= STATE_IDLE; end // no need to wait for wb transaction. go to IDLE immediately
    endcase

    if( i_wb_rst || r_decode == DECODE_RESET ) begin
        r_state <= STATE_IDLE;
        r_nibble_idx <= 'h0;
    end
end

//------------------------------------------------------------------------------
// ascii encoder for uart-tx

reg [31:0] r_wb_read_data;

wire [3:0] nibble;
reg [7:0] nibble_ascii;
reg [2:0] nibble_sel;

assign nibble = nibble_sel == 0  ? r_wb_read_data[31:28] :
        		nibble_sel == 1  ? r_wb_read_data[27:24] :
        		nibble_sel == 2  ? r_wb_read_data[23:20] :
        		nibble_sel == 3  ? r_wb_read_data[19:16] :
        		nibble_sel == 4  ? r_wb_read_data[15:12] :
        		nibble_sel == 5  ? r_wb_read_data[11: 8] :
        		nibble_sel == 6  ? r_wb_read_data[ 7: 4] :
                				   r_wb_read_data[ 3: 0] ;

always @(nibble)
begin
    case( nibble )
        4'h0: nibble_ascii = 8'h30;
        4'h1: nibble_ascii = 8'h31;
        4'h2: nibble_ascii = 8'h32;
        4'h3: nibble_ascii = 8'h33;
        4'h4: nibble_ascii = 8'h34;
        4'h5: nibble_ascii = 8'h35;
        4'h6: nibble_ascii = 8'h36;
        4'h7: nibble_ascii = 8'h37;
        4'h8: nibble_ascii = 8'h38;
        4'h9: nibble_ascii = 8'h39;
        4'ha: nibble_ascii = 8'h41;
        4'hb: nibble_ascii = 8'h42;
        4'hc: nibble_ascii = 8'h43;
        4'hd: nibble_ascii = 8'h44;
        4'he: nibble_ascii = 8'h45;
        4'hf: nibble_ascii = 8'h46;
    endcase
end

//------------------------------------------------------------------------------
// wb access

wire do_read = r_state == STATE_READ;
wire do_write = r_state == STATE_WRITE;

reg r_do_read, r_do_write;

assign o_wb_cyc = r_do_read | r_do_write;
assign o_wb_we = r_do_write;
assign o_wb_addr = address;
assign o_wb_stb = o_wb_cyc ? 4'b1111 : 4'b0000;

wire wb_read_done = i_wb_ack && r_do_read;

// read data
always @(posedge i_wb_clk)
begin
    if( do_read )
        r_do_read <= 1;

    if( wb_read_done ) begin
        r_wb_read_data <= i_wb_dat[31:0];
    end

    if( i_wb_rst || i_wb_ack ) begin
        r_do_read <= 0;
    end
end

// write data
assign o_wb_dat[31:0] = data[31:0];

always @(posedge i_wb_clk)
begin
    if( do_write ) begin
        r_do_write <= 1;
    end
    if( i_wb_rst || i_wb_ack ) begin
        r_do_write <= 0;
    end
end


//------------------------------------------------------------------------------
// uart send data read from wb

assign o_uart_tx_dat = nibble_ascii;
reg send_word; // if 1, then send 8 nibbles via uart

always @(posedge i_wb_clk)
begin
    o_uart_tx_trigger <= 1'b0;
    send_word <= 0;
    
    if( ~o_wb_we && i_wb_ack ) begin
        // word has been read from wb, start sending first nibble
        nibble_sel <= 0;
        send_word <= 1;
    end
    
    if( send_word ) begin
        if( ~o_uart_tx_trigger && i_uart_tx_ready_to_send ) begin
            o_uart_tx_trigger <= 1;
        end
        
    	if( o_uart_tx_trigger ) begin
    		nibble_sel <= nibble_sel + 1;
    	end
    	send_word <= (nibble_sel != 7) || ~o_uart_tx_trigger;
    end
    
end

endmodule

