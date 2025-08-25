// UVM testbench
////////////////////////////////////////////////////////
//Transaction class -- contains the elemts whichare IP & OP's
class transaction;
  rand bit oper; // radnom value for operation -- 0 (read) 1(write).
   bit rd,wr;
   
  bit [7:0] data_in;
  bit full,empty;
  bit [7:0] data_out;
  
  constraint oper_ctrl {
    oper dist {1:/50,0:/50};
  }
  
endclass

///////////////////////////////////////////////////
// generator -- generates random stimuli and communicate it to the driver using mailbox
class generator;
  
  transaction tr; // instance of the transaction object
  mailbox #(transaction) mbx; // mailbox 
  
  int count = 0;
  int i =0;
  
  event next; // know when to send next transaction
  event done; /// when all trnasactions are complete
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx; // initialize the mailbox
    tr= new();      // creating a new transaction object
  endfunction
  
  task run();  
    repeat(count)  // count value from tb-top
      begin
        assert(tr.randomize) else $error("Randomization failed !");
        i++; // inrement "i" after every value randomly generated.
        mbx.put(tr);//putting a transaction in the mailbox
        $display("[GEN] : Oper is %0d , iteration : %0d", tr.oper,i);
        @(next); //wait for SB to complete its operations
      end
    ->done; //completion of the requested generations.
    
  endtask
  
  
endclass

//////////////////////////////////////////////////////////////////////////
// driver-- drives the inputs to the interface of the DUT.
class driver;
  
  virtual fifo_if fif;
  mailbox#(transaction) mbx;
  transaction datac; //stores the data from the generator.
  
  function new (mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  // reset the DUT
  task reset();
    fif.rst <= 1'b1;
    fif.rd  <= 1'b0;
    fif.wr  <= 1'b0;
    fif.data_in <= 1'b0;
    repeat(5) @(posedge fif.clock)
      fif.rst <= 1'b0;  // de assert the reset.
    $display("[DRV] : DUT reset is DONE");
    $display("-------------------------");
    
  endtask
  
  // write the data
  task write();
    @(posedge fif.clock)
    fif.rst <= 1'b0;
    fif.rd  <= 1'b0;
    fif.wr  <= 1'b1;
    fif.data_in <= $urandom_range(1,10);
    @(posedge fif.clock);
    fif.wr  <= 1'b0; // de-assert the write signal
    $display("[DRV] : DUT write data : %0d", fif.data_in);
    @(posedge fif.clock); // wait for one clk edge
  endtask
  
  // read the data
  task read();
    @(posedge fif.clock)
    fif.rst <= 1'b0;
    fif.rd  <= 1'b1;
    fif.wr  <= 1'b0;
    @(posedge fif.clock); //waiting for one clk edge 
    fif.rd <= 1'b0; // deassert the read signal
    $display("[DRV] : Data Read ");
    @(posedge fif.clock); // wait for one clock cycle
  endtask
  
  //apply random stimulus-- for operations
  task run();
    forever begin
      mbx.get(datac);
      if(datac.oper == 1'b1)
        write();
      else
        read();
    end
  endtask
  
endclass

//////////////////////////////////////////////////////////////////////////////////////
//monitor -- recives the DUT outputs , the read data
class monitor;
  virtual fifo_if fif; //virtual interface for communcation
  mailbox #(transaction) mbx; // to recive data from the DUT
  transaction tr;   // transaction object for monitor
  
  function new (mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run(); // assigns all the vlaues on the interface to the transaction instance.
    tr = new();
    forever begin
      repeat(2) @(posedge fif.clock);
      tr.wr = fif.wr;
      tr.rd = fif.rd;
      tr.data_in = fif.data_in;
      tr.full = fif.full;
      tr.empty = fif.empty;
      @(posedge fif.clock);
      tr.data_out = fif.data_out;
      
      mbx.put(tr); // put this transaction objects in the mailbox
      $display("[MON] : Wr = %0d rd = %0d din = %0d dout= %0d full= %0d empty =%0d", tr.wr,tr.rd,tr.data_in, tr.data_out,tr.full, tr.empty);
      
    end
  endtask
  
endclass
////////////////////////////////////////////////////////////////////////////////////////
//scoreboard 
class scoreboard;
  
  mailbox #(transaction) mbx; // for reciving the data from the monitor
  transaction tr;//instance of the transaction object
  event next;
  bit [7:0] din[$]; //dynamic array to store the written data.
  bit [7:0] temp;   // temp data storage
  int err =0;       // error count
  
  function new (mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    forever begin;
      mbx.get(tr) ; //get the tranaction item on the 
      $display("[SCO] : Wr = %0d rd = %0d din = %0d dout= %0d full= %0d empty =%0d", tr.wr,tr.rd,tr.data_in, tr.data_out,tr.full, tr.empty);
      
      if(tr.wr == 1'b1) begin  // block1 write transaction
        if(tr.full == 1'b0)begin
          din.push_front(tr.data_in); // push transaction data_in into array din.
          $display("[SCO] Data scored in the queue : %0d ", tr.data_in);
        end
     
      else begin
        $display("[SCO] FIFO is full");
      end
      $display("------------------------------------");
     end
      
      if(tr.rd == 1'b1) begin  // block2  read transaction 
        if(tr.empty == 1'b0) begin // when there is some data inside the FIFO
          temp = din.pop_back();// pop the data into the temp register.
          if(tr.data_out == temp) // when the output is equal to the dat in temp.
            $display("[SCO] : Data Match");
          else begin
            $error("[SCO] : Data Mismatched");
            err++;
        end
      end
        else begin
          $display("[SCO] : FIFO is empty");
        end
        
        $display("-------------------------------");
      end
      ->next;
    end
  endtask
      
      
endclass
//////////////////////////////////////////////////////////////////////////////////
class environment;
  generator gen; // instance for the generator
  driver drv; // instance for the driver
  monitor mon; //instance for the monitor
  scoreboard sco; // instance for the scoreboard
  mailbox #(transaction) gdmbx; // gen-> drv mailbox
  mailbox #(transaction) msmbx; // mon-> sco mailbox
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
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $display("-------------------------------------");
    $display("ERROR count : %0d",sco.err);
    $display("-------------------------------------");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
              
endclass
/////////////////////////////////////////////////////////////////////////////////////////////

 module tb;
   
   fifo_if fif();
   FIFO dut(fif.clock,fif.rst,fif.wr,fif.rd,fif.data_in,fif.data_out,fif.empty,fif.full);
   
   initial begin
     fif.clock <= 0;
   end
   
   always #10 fif.clock <= ~fif.clock;
   
   environment env;
   
   initial begin
     env = new(fif);
     env.gen.count = 10;
     env.run();
   end
   
   initial begin
     $dumpfile("dump.vcd");
     $dumpvars;
   end
 endmodule
