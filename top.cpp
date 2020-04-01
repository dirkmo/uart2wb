#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "Vtop.h"
#include "verilated.h"
#include "fifo.h"

VerilatedVcdC *pTrace;
Vtop *pCore;
uint64_t tickcount;

enum UART_CONSTANTS {
    CLK = 25000000,
    BAUDRATE = 115200,
    TICK = CLK / BAUDRATE,
    HALF_TICK = TICK / 2
};
 
char fifo_buf[256];
FIFO fifo_uart_rx = { .first = 0, .count = 0, .len = sizeof(fifo_buf), .buf = fifo_buf};

void debug() {
    pCore->debug_wire = !pCore->debug_wire;
}

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

char rx() { return pCore->uart_tx; }

// uart_handle() needs to be called every clock cycle
void uart_handle(void) {
   static enum state_t { IDLE = 0, STARTBIT = 1, BYTE = 2, STOPBIT = 10 } state = IDLE;
    static uint32_t counter = 0;
    static unsigned char recbyte = 0;
    counter++;
    switch( state ) {
        case IDLE:
            if( rx() == 0 ) {
                counter = 0;
                state = STARTBIT;
            }
            break;
        case STARTBIT:
            if( counter >= HALF_TICK ) {
                debug();
                if( rx() == 0 ) {
                    counter = 0;
                    recbyte = 0;
                    state = BYTE;
                } else {
                    // error
                    state = IDLE;
                }
            }
            break;
        case STOPBIT:
            if( counter >= TICK ) {
                debug();
                if( rx() == 1 ) {
                    fifo_push(&fifo_uart_rx, recbyte);
                    //printf("rec: %c\n", recbyte);
                }
                state = IDLE;
            }
            break;
        default:
            if( counter >= TICK ) {
                debug();
                recbyte = (recbyte >> 1) | (rx() << 7);
                counter = 0;
                state = (state_t)((int)state + 1);
            }
            break;
    }
}

void tick() {
    pCore->i_clk = 0;
    pCore->eval();
    if(pTrace) {
        pTrace->dump(static_cast<vluint64_t>(tickcount));
    }
    tickcount++;
    pCore->i_clk = 1;
    pCore->eval();
    if(pTrace) {
        pTrace->dump(static_cast<vluint64_t>(tickcount));
    }
    tickcount++;
    uart_handle();
}


void clkcycles(int count = 1) {
    while( count-- ) {
        tick();
    }
    pTrace->flush();
}

void reset() {
    pCore->i_reset = 1;
    pCore->i_clk = 0;
    tick();
    pCore->i_reset = 0;
    pCore->uart_rx = 1;
    tick();
}

void uart_halftick() {
    uint32_t counter = 0;
    while(counter++ < CLK / BAUDRATE / 2) {
        tick();
    }
}

void uart_tick() {
    uart_halftick();
    uart_halftick();
}

void uart_send( char c ) {
    // start bit
    pCore->uart_rx = 0;
	uart_tick();
    for( int i = 0; i < 8; i++ ) {
        pCore->uart_rx = (c >> i)&1;
        uart_tick();
    }
    // stop bit
    pCore->uart_rx = 1;
	uart_tick();
}

void uart_sendstr( const char *s ) {
    while(*s) {
        uart_send(*s++);
    }
}

void uart_receivestr( int len, char *str ) {
    // adds null termination. str[] must have length > len
    while( fifo_uart_rx.count < len ) {
        clkcycles();
    }
    while( len-- ) {
        fifo_pop( &fifo_uart_rx, str++ );
    }
    *str = 0;
}

#define nibble(val,idx) ((val >> 4*idx) & 0xf)
#define reverse(val) ((nibble(val,0) << 28) | (nibble(val,1) << 24) | (nibble(val,2) << 20) | (nibble(val,3) << 16) | \
                      (nibble(val,4) << 12) | (nibble(val,5) <<  8) | (nibble(val,6) <<  4) | (nibble(val,7) << 0) )

void write(uint32_t addr, uint32_t data) {
    char s[20];
    sprintf(s, "a%08Xd%08Xw", reverse(addr), reverse(data));
    //printf("sending: %s\n", s);
    uart_sendstr(s);
    assert( pCore->top__DOT__ram[addr] == data);
}

uint32_t read(uint32_t addr) {
    char s[12];//,s2[20];
    sprintf(s, "a%08Xr", reverse(addr));
    //printf("sending: %s\n", s);
    uart_sendstr(s);
    uart_receivestr( 8, s );
    //printf("read: %s\n", s);
    uint32_t data;
    sscanf(s, "%8X", &data);
    return data;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vtop();
    opentrace("trace.vcd");

    reset();

    clkcycles();

    for( uint32_t i = 0; i < 16; i++ ) {
        write(i, i * 0x1234567);
    }

    for( uint32_t i = 0; i < 16; i++ ) {
        assert(read(i) == i * 0x1234567);
    }

    if (pTrace) {
        pTrace->close();
        pTrace = NULL;
    }
    return 0;
}
