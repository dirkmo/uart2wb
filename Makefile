.PHONY: all clean sim wave

UNAME := $(shell uname -s)

INCDIR=-I/usr/share/verilator/include

VFLAGS = -CFLAGS -std=c++11 -Wall -trace -cc --exe $(INCDIR) --Mdir $@.d
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

top: top.cpp top.v fifo8.v
	rm -rf $@.d/
	verilator -I$@ $(VFLAGS) top.v fifo8.v top.cpp
	make -C $@.d -j4 -f V$@.mk

sim: top
	$<.d/V$< -d -t

wave: sim
	gtkwave trace.vcd &

clean:
	rm -f trace.vcd
	rm -rf top.d/
