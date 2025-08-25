// FIFO -DUT (First In First Out)
module FIFO (input clk,rst, wr,rd,
             input [7:0] din, output reg[7:0] dout,
             output empty, full);
  
  reg [3:0] wptr = 0,rptr =0; //write pointer and read point 
  reg [4:0] cnt = 0; //counter 
  reg [7:0] mem [15:0]; //memory space to store the data.-- 16 locations
  
  always@(posedge clk)
    begin
      if(rst == 1'b1) //when reset is high 
        begin
          wptr <=0;  //write pointer is zero
          rptr <=0;  //read pointer is zero
          cnt  <=0;  //value on counter is zero
        end
      else if(wr && !full)  //write is enabled and fifo is not full
        begin
          mem[wptr] <=din; //write din in the address speciped by the write pointer
          wptr <= wptr+1;  //increment write pointer by 1
          cnt  <= cnt+1;   //counter is incremented
        end
      else if(rd && !empty)  //read is enabled and fifo is not empty
        begin
          dout <= mem[rptr]; //reading the data in the address pointed by the read pointer 
          rptr <= rptr +1;   // increment the read pointer by 1
          cnt <= cnt -1;    // derement the counter
        end
    end
  
  assign empty = (cnt == 0) ? 1'b1: 1'b0;  //when count is 0 empty is HIGH
  assign full  = (cnt == 16) ? 1'b1 : 1'b0;//when count is 16 full is HIGH
  
endmodule

//////////////////
// Interface

interface fifo_if;
  logic clock,rd,wr; //clock ,read and write signlas
  logic full, empty; //flags
  logic [7:0] data_in; // input
  logic [7:0] data_out; //output
  logic rst;		//reset
  
endinterface
