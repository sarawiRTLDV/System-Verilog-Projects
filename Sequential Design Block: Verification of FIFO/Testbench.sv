/*after understanding the design, we are ready to preceed with our verification process*/

// 1->first of all lets create our transaction class
/*
-> Add (2s/4s) variables for all ports (DUT) except globl signals 
-> add modifier for input ports
-> Constraints
-> methods: such as printing values, copy

*/

class transaction;
  
  rand bit rd, wr;
  rand bit[7:0] data_in;
  bit full, empty;
  bit [7:0] data_out;
  
  constraint wr_rd{
    wr dist {1:/ 50, 0:/ 50};
    rd dist {1:/ 50, 0:/ 50};
   /* wr == 1 <-> rd == 0;
    wr == 0 <-> rd == 1;*/
    // or we could just use this
    wr != rd;
  }
  constraint datain{
  	data_in > 1; data_in < 5;
  }
  
  // we have to create our display function which will be used by all the classes 
  
  function void display(string tag);
    $display("[%0s]:\t WR = %0b\t RD = %0b\t DATAWR = %0d\t DATARD = %0d\t FULL = %0b\t EMPTY = %0b\t at-> %0t",tag, wr, rd, data_in, data_out, full, empty, $time);
  endfunction
  
  // now we have to create the copy function since we want to use a deep copy
  
  function transaction copy();
    copy = new();
    copy.wr = this.wr;
    copy.rd = this.wr;
    copy.data_in = this.data_in;
    copy.data_out = this.data_out;
    copy.full = this.full;
    copy.empty = this.empty;
  endfunction
  
endclass

// to test our transaction class we use a tb example
/*
module tb;
  transaction tr;
  
  initial begin
    tr = new();
    tr.randomize();
    tr.display("TB");
  end
endmodule
*/

// lets create our generator class

/* the tasks for a generator are:
-> Randomize transaction
-> send transactions to the driver class
-> sense Event from SCO and driver before sending the next transaction
*/

class generator;
  
  transaction trans;
  mailbox #(transaction)mbx;
  
  int count = 0; // here we will specify how many transaction we want to generate 
  event next;// to know when to send next transaction
  event done;// to conveys the complition of requested number of transactions
  
  function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
    this.trans = new();
  endfunction
  
  
  task run();
    repeat(count) begin
      assert(trans.randomize)else $error("Randomization FAILED");
      mbx.put(trans.copy());
      trans.display("GEN");
      @(next);// here we are waiting to receive a flag from other classes
    end
    
    -> done;
  endtask
  
  
endclass

// lets test our generator class
/*
module tb;
  
  generator gen;
  
  mailbox #(transaction) mbx;
  
  initial begin
    mbx = new();
    
    gen = new(mbx);
    gen.count = 3;
    gen.run();
  end
  
endmodule

*/

/*lets create our Driver Class
 here are the tasks of a driver class
 
 -> Receive transaction from generator
 -> Apply reset to DUT
 -> Apply transaction to DUT with the help of an interface
 -> Notify Generator about the complition of interface trigger(it's better to notify the generator by using the scoreboard, but if we decided to use this we have to scinchronise all the trigger of the notification event
*/


class driver;
  virtual fifo_if interf;
  transaction datac;// this is our data container
  mailbox #(transaction) mbx;
  
  event next;
  
  function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
  endfunction
  //reset the DUT
  task reset();
    //bare in mind that when ever you are assigning values to an interface signals you should use non-blocking assignement(<=) not (=) to avoid dropping values
    interf.rst <= 1'b1;
    interf.wr <=  1'b0;
    interf.rd <= 1'b0;
    interf.data_in <= 8'h00;
    
    repeat(5) @(posedge interf.clock);
    interf.rst <= 1'b0;
  endtask
  // applying rundome stimulus to our dut
  task run();
    
    forever begin
      mbx.get(datac);
      datac.display("DRV");
      interf.wr <= datac.wr;
      interf.rd <= datac.rd;
      interf.data_in <= datac.data_in;
      repeat(2) @(posedge interf.clock);
      ->next;
    end
    
  endtask
  
endclass 

// here we are testing our driver class
/*
module tb;
  
  generator gen;
  driver drv;
  mailbox #(transaction) mbx;
  event next;
  fifo_if interf();
  
  fifo dut(interf.clock, interf.rd, interf.wr, interf.full, interf.empty, interf.data_in, interf.data_out, interf.rst);
  
  initial begin
    interf.clock <= 0;
  end
  
  always begin
    #10 interf.clock <= ~interf.clock;
  end
  
  initial begin
    mbx = new();
    gen = new(mbx);
    drv = new(mbx);
    drv.next = next;
    gen.next = next;
    drv.interf = interf;
    gen.count = 3;
   
  end
  
  initial begin
    fork
      gen.run();
      //drv.reset();
      drv.run();
    join
    
  end
  
  initial begin
    #400;
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
  
endmodule
*/

// now it's time to create our monitor class

/*
	here are the task that the monitor should perform
    
-> capture DUT
-> send response transaction to sco
-> also control  data to be send for specific operation (this is used incase of a bus protocol)
*/
class monitor;
  virtual fifo_if interf;
  transaction trans;
  mailbox #(transaction) mbx;
  
  function new(mailbox #(transaction)mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    trans = new();
    forever begin
      repeat(2) @(posedge interf.clock);
      trans.wr = interf.wr;
	  trans.rd = interf.rd;
      trans.data_in = interf.data_in;
      trans.data_out = interf.data_out;
      trans.full = interf.full;
      trans.empty = interf.empty;
      trans.empty = interf.rst;
      mbx.put(trans);
      trans.display("MON");
    end
  endtask
endclass


// here we create our scoreboard class
/*
	here are the tasks that score board class needs to perform
-> receive trnasactions from monitor
-> store transaction : array, queue, Associative array;
-> compare the responses with expected result and this is done by one of the following methods:
	1-> develop an algo inside the score board 
    2-> get expected data from other classes 
    3-> get expected data from other languages using (DPI)
*/

class scoreboard;
  
  transaction trans;
  mailbox #(transaction) mbx;
  event next;// to notify the generator about when to send the next transaction 
  
  bit [7:0] din[$];
  bit [7:0] temp;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    
    forever begin
      #40;
      mbx.get(trans);
      trans.display("SCO");
      
      if(trans.wr == 1'b1)begin
        if(trans.full == 1'b0) begin
           din.push_front(trans.data_in);
          $display("DATA is pushed into the queue");
        end
        else $display("The queue is full");
      end
      
      if(trans.rd == 1'b1) begin
        
        if(trans.empty == 1'b0) begin
            temp = din.pop_back();

            if(trans.data_out == temp) begin
              $display("DATA is MACHED %0d", trans.data_out);
            end
          else $display("DATA MISSMACH %0d", trans.data_out);
        end
        else $display("the Queue is EMPTY");
      end
      -> next;
    end
  endtask
  
  
endclass

//let's test our scoreboard class

module tb;
  
  generator gen;
  driver drv;
  scoreboard sco;
  monitor mon;
  mailbox #(transaction) mbx;
  event next;
  fifo_if interf();
  
  fifo dut(interf.clock, interf.rd, interf.wr, interf.full, interf.empty, interf.data_in, interf.data_out, interf.rst);
  
  initial begin
    interf.clock <= 0;
  end
  
  always begin
    #10 interf.clock <= ~interf.clock;
  end
  
  initial begin
    mbx = new();
    gen = new(mbx);
    drv = new(mbx);
    mon = new(mbx);
    sco = new(mbx);
    
    //drv.next = next;
    gen.next = next;
    sco.next = next;
    drv.interf = interf;
    mon.interf = interf;
    gen.count = 10;
   
  end
  
  initial begin
    fork
      gen.run();
      //drv.reset();
      drv.run();
      sco.run();
    join
    
  end
  
  initial begin
    #800;
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
  
endmodule
