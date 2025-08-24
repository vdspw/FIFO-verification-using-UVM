# FIFO-verification-using-UVM
UVM testbench for a FIFO

FIFO -- first in first out memory.
TEST STEPS:
1. Initialization of the FIFO
2. Writing the data on to the FIFO
3. Reading the data on to the FIFO
4. Order of operations
5. Overflow and Underflow scenarious.

first data written should be recived out of the FIFO

DESIGN SPECIFICATIONS:
The design works on positive edge of the CLK , accompanied by the other global signal reset.
Control signals -- read  and write (mutually exclusive)
Input bus 8 bit --- Din
Output bus 8 bit --- Dout
Flags : Full (goes HIGH) when all 16 bits are full
        EMPTY (goes HIGH) on reset




