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
////////////////////////////////////////////////////////////////////////////////////////////////////////////
The design works on positive edge of the CLK , accompanied by the other global signal reset.
Control signals -- read  and write (mutually exclusive)
Input bus 8 bit --- Din
Output bus 8 bit --- Dout
Flags : Full (goes HIGH) when all 16 bits are full
        EMPTY (goes HIGH) on reset
        
UVM TESTBENCH:
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
Transaction class: 
Contains one random bit --operation ( when this is 0 its a READ and when 1 its a WRITE).
Bits for rd(read enable) and wr(write enable).(I/P of the DUT).
Flags for FULL and EMPTY ( present in the O/P od the DUT).
Constraint -- enables 50% write and 50% read operation.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Generator class:
Contains the instance of the transaction object.
Mailbox parameterized with the transaction object for communication
Count -- For number of times the stimulus has to be generated.
varialbe "i" -- for maintaining the iteration count.
Events -- next and done 
Next -- when to send in the next transaction
Done -- when the iterations are complete.
task : put the transaction objects in a randomized manner into the mailbox .
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Driver class:
Contains the virtual interface, mailbox (parameterized)
Place to store the data from the generator. 
There are 3+1 tasks :
        Reset -- where the reset signal is HIGH which results in all other signals and counters to be 0.
                Deassert the reset.
        Write -- Wrtie enable signal is HIGH .
                Randomize the data_in (values from 1 to 10)
                Deassert the write enable
        Read -- Read enable is HIGH.
                wait for a clk cycle and deassert the clk signal.
        ----------------------------------------------------------
        Run task : if the operation is 1 write if 0 read.
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Monitor class :
Contains the virtual interface.
mailbox (parameterized) , transaction instance for the DUT outputs.
In the run phase create a new space in the memory for the transaction 
assign the items in the transaction to the virtual interface equivalents.
Place the transaction in the mailbox.Print them.
NOTE : Sample the FIFO interface signals and assign them to the corresponding feilds in the transaction object.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Scoreboard class:
Contains the milbox , transaction instance , dynamic array.
temp data register .
In the run phase : Get the transaction items from the mailbox .
for write transaction  ,push the data into the array.
for read transaction , pop the data into temp and compare the output without with DUT O/P.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                
                
                




