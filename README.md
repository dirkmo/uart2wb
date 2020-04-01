# uart2wb
uart-to-wishbone bridge

UART acts as a wishbone master. Currently, only 32-bit addr/data bus only.

## How to use
The uart2wb has an internal 32-bit address register and an 32-bit data register.

It accepts the following characters (case sensitive):

- . (0x2e)         trigger reset line
- a (0x61)         select address register
- d (0x64)         select data register
- w (0x77)         trigger write
- r (0x72)         trigger read
- 0-9 (0x30-0x39)  interpreted as hex nibble
- A-F (0x41-0x46)  interpreted as hex nibble

Nibble order is from low to higher. This is done to only transmit the lower byte of the address, if the upper stay the same.

## Examples

    a1000000A
Sets address register to 0xA0000001

    a51
Changes only the two lowest nibble of address. new address is 0xA0000015.

    d10012002
Changes data register to 0x20021001

    d7
Changes only lowest nibble: 0x20021007

    w
Write data to address. Address is auto-incremented after write.

    r
Read data from address and output to UART (in human readable order).
Address is auto-incremented after read.

    a76543210dFEDCBA98w
Sets address register to 0x01234567, sets data register to 0x89ABCDEF. Then writes the data reg to the address.
Address register will auto-increment.

    a76543210r
Sets address register to 0x01234567 and then reads data from this address. Data is then written to UART.
Address register will auto-increment.

    .
Triggers reset line (this just sets the line high for one clock cycle).

