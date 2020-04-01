#ifndef __FIFO_H
#define __FIFO_H

#include <stdint.h>
#include <stdbool.h>

#define IRQ_DISABLE()
#define IRQ_ENABLE()

typedef struct {
  uint32_t first; // erstes Item
  uint32_t count; // aktuelle Anzahl in FIFO
  uint32_t len; // max. Anzahl in FIFO

  char *buf; // Buffer
} FIFO;

void fifo_init(FIFO *fifo, uint32_t len, char *buf, uint32_t item_size);

// fifo_push
// returns: true when item pushed into fifo
//          false when not pushed because fifo is full
bool fifo_push(FIFO *fifo, const char item);

// fifo_pop
// returns: true when an item was popped out of the fifo
//          false when no item was popped out of the fifo because it was empty
bool fifo_pop(FIFO *fifo, char *item);

// fifo_is_empty:
// returns: true when fifo is empty, otherwise false
bool fifo_is_empty(const FIFO *fifo);

// fifo_is_full:
// returns: true when fifo is full
bool fifo_is_full(const FIFO *fifo);








bool fifo_push(FIFO *fifo, const char item) {
	IRQ_DISABLE();

	bool res = false;

	if(fifo->count < fifo->len) {
		
		res = true;

		uint32_t idx = (fifo->first + fifo->count) % fifo->len;
		fifo->buf[idx] = item;

		++fifo->count;
	}

	IRQ_ENABLE();

	return res;
}

// Erste Nachricht aus FIFO entnehmen
bool fifo_pop(FIFO *fifo, char *item) {
	IRQ_DISABLE();

	bool res = false;
	if(fifo->count > 0) {

		res = true;

		*item = fifo->buf[fifo->first];

		--fifo->count;

		fifo->first = (fifo->first + 1) % fifo->len;
	}

	IRQ_ENABLE();

	return res;
}

bool fifo_is_empty(const FIFO *fifo) {
	bool empty;
	IRQ_DISABLE();

	empty = fifo->count == 0;

	IRQ_ENABLE();
	return empty;
}

bool fifo_is_full(const FIFO *fifo) {
	bool full;
	IRQ_DISABLE();


	full = fifo->count == fifo->len;

	IRQ_ENABLE();
	return full;
}

#endif
