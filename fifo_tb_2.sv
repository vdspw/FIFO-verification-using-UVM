// UVM testbench
////////////////////////////////////////////////////////////////////////////////////
// Transaction
class transaction;
  rand bit oper; //randomized bit for operation 1- write 0- read
  bit wr, rd;    //write and read enables
  bit [7:0] data_in; //input t the DUT
  bit full,empty;//flags
  bit [7:0] data_out; // output of the DUT
  
  constraint oper_ctrl {
    oper dist {1:/50, 0:/50}; //probablity of 1 is 50 % and 0 is 50%.
  }
endclass

///////////////////////////////////////////////////////////////////////////////////
//generator
class generator;
  transaction tr; //instance of the transaction.
  mailbox #(transaction) mbx; // mailbox for communication.
  int count =0;  //no. of transactions to generate
  int i =0;		//no. of iterations.
  
  event next; //when to send the next 
  event done; //when to signal completion of the generator sending no. of transactions.
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error (" Randomization failed");
      i++;
      mbx.put(tr); // placing the generated value in the Mailbox.
      $display("[GEN] : Oper : %0d --- Iteration : %0d ", tr.oper, i); 
      @(next);
    end
    ->done;
  endtask
  
endclass
/////////////////////////////////////////////////////////////////////////////////////
//driver
class driver;
  virtual fifo_if fif; // virtual interface
  mailbox #(transaction) mbx; //mailbox for communication
  transaction datac; // to store the generated data.
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  //reset the UDT
  task reset();
    fif.rst <= 1'b1; // asserting the reset signal
    fif.rd  <= 1'b0;
    fif.wr  <= 1'b0;
    fif.data_in <= 1'b0;
    repeat(5) @(posedge fif.clock); //some clk cycles gap
    fif.rst <= 1'b0; // deassertion of the reset signal
    $display("[DRV] : DUT reset is done");
    $display("---------------------------");
  endtask
  
  //write task
  task write();
    @(posedge fif.clock);
    fif.rst <= 1'b0;
    fif.rd  <= 1'b0;
    fif.wr <= 1'b1; // assert the write enable to High
    fif.data_in <= $urandom_range(1,10);
    @(posedge fif.clock);
    fif.wr <= 1'b0; //deasserting the write signal
    $display("[DRV] : DATA WRITE data : %0d",fif.data_in);
    @(posedge fif.clock);
  endtask
  
   //read 
  task read();
    @(posedge fif.clock);
    fif.rst <= 1'b0;
    fif.wr <= 1'b0;
    fif.rd <= 1'b1; // assert the read enable signal
    @(posedge fif.clock);
    fif.rd <= 1'b0; // deassert the read enable signal
    $display("[DRV] : DATA READ ");
    @(posedge fif.clock);
  endtask
  
  // write till the full flag is high
  task write_full();
    while(fif.full == 1'b0)begin
    	@(posedge fif.clock);
   		 fif.rst <= 1'b0;
    	fif.rd  <= 1'b0;
    	fif.wr  <= 1'b1; //assert the write enable to HIGH
    	fif.data_in <= $urandom_range(1,10);
    	@(posedge fif.clock);
    	fif.wr <= 1'b0; //deasserting the write enable signal
   		 $display("[DRV] : Data to all locations : %d", fif.data_in);
    end
   	 @(posedge fif.clock);
    	$display("[DRV] : FIFO is full");
   	    $display("--------------------");
    
  endtask
  
  //read full fifo 
  task read_full();
    while(fif.empty == 1'b0) begin
      @(posedge fif.clock);
      fif.rst <= 1'b0;
      fif.wr<= 1'b0;
      fif.rd <= 1'b1;//assert the read signal
      @(posedge fif.clock);
      fif.rd <= 1'b0;
      $display("[DRV]: FIFO full read complete");
    end
    @(posedge fif.clock);
    $display("[DRV] : FIFO is empty");
    $display("-----------------------");
  endtask
  
 // apply random stimulus -- for operations
  task run();
    forever begin
      mbx.get(datac);
      if(datac.oper == 1'b1)
        write();
        
      else
        read();
        
    end
  endtask
  
  // to run full tests
  task run_full();
    forever begin
      mbx.get(datac);
      if(datac.oper == 1'b1)
        write_full;
      else
        read_full();
    end
  endtask
    
endclass
///////////////////////////////////////////////////////////////////////////////////
//  monitor
class monitor;
virtual fifo_if fif; // virtual interface
mailbox #(transaction) mbx; //mailbox for communication
transaction tr; // instance of the transaction

function new(mailbox #(transaction) mbx);
  this.mbx = mbx ; // initializing the mailbox
endfunction

task run();
  tr = new(); // new transaction object to hold the values observed
  
  forever begin
    repeat(2) @(posedge fif.clock);
    tr.wr = fif.wr;
    tr.rd = fif.rd;          // assigning the interface values to the transaction object
    tr.data_in = fif.data_in;
    tr.full = fif.full;
    tr.empty = fif.empty;
    @(posedge fif.clock);
    tr.data_out = fif.data_out;
    
    mbx.put(tr); // place the transaction obj in the mailbox
    $display("[MON] : WRITE : %0d -- READ : %0d -- Data_in : %0d -- Data_out : %0d -- FULL: %0d --EMPTY: %0d",
             tr.wr,tr.rd,tr.data_in, tr.data_out,tr.full,tr.empty);
  end
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////
//scoreboard
class scoreboard;
  
  mailbox #(transaction) mbx;  // Mailbox for communication
  transaction tr;          // Transaction object for monitoring
  event next;
  bit [7:0] din[$];       // Array to store written data
  bit [7:0] temp;         // Temporary data storage
  int err = 0;            // Error count
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;     
  endfunction;
 
  task run();
    forever begin
      mbx.get(tr);
      $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
      
      if (tr.wr == 1'b1) begin
        if (tr.full == 1'b0) begin
          din.push_front(tr.data_in);
          $display("[SCO] : DATA STORED IN QUEUE :%0d", tr.data_in);
        end
        else begin
          $display("[SCO] : FIFO is full");
        end
        $display("--------------------------------------"); 
      end
    
      if (tr.rd == 1'b1) begin
        if (tr.empty == 1'b0) begin  
          temp = din.pop_back();
          
          if (tr.data_out == temp)
            $display("[SCO] : DATA MATCH");
          else begin
            $error("[SCO] : DATA MISMATCH");
            err++;
          end
        end
        else begin
          $display("[SCO] : FIFO IS EMPTY");
        end
        
        $display("--------------------------------------"); 
      end
      
      -> next;
    end
  endtask
  
endclass
 
///////////////////////////////////////////////////////
 
class environment;
 
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;  // Generator + Driver mailbox
  mailbox #(transaction) msmbx;  // Monitor + Scoreboard mailbox
  event nextgs;
  virtual fifo_if fif;
  
  function new(virtual fifo_if fif);
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    this.fif = fif;
    drv.fif = this.fif;
    mon.fif = this.fif;
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      drv.reset();
      drv.run_full();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.err);
    $display("---------------------------------------------");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass
 
///////////////////////////////////////////////////////
 
module tb;
    
  fifo_if fif();
  FIFO dut (fif.clock, fif.rst, fif.wr, fif.rd, fif.data_in, fif.data_out, fif.empty, fif.full);
    
  initial begin
    fif.clock <= 0;
  end
    
  always #10 fif.clock <= ~fif.clock;
    
  environment env;
    
  initial begin
    env = new(fif);
    env.gen.count = 20;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
endmodule
