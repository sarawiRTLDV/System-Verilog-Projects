class transaction;
  bit newd;
  rand bit [11:0] din;
  bit cs;
  bit mosi;

  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.cs = this.cs;
    copy.mosi  = this.mosi;
  endfunction
  
  function void display(string tag);
    
    $display("[%0s]: newd = %0b, din = %0d, cs = %0b, mosi = %0b", tag, newd, din, cs, mosi);
    
  endfunction
  
endclass

// lets test our transaction class
/*module tb();
  
  transaction trans;
  
  initial begin
    trans = new();
    #10;
    trans.randomize();
  end
  
  initial begin
  	trans.display("trans");
  end
  
  
endmodule
*/


class generator;
  
  transaction trans;
  mailbox#(transaction) mbxgendrv;
  
  event drvnext;// this will be triggered by the driver
  event sconext;// this will be triggered by the monitor
  event done;
  
  int count = 0;
  
  function new(mailbox #(transaction) mbx);
    this.mbxgendrv = mbx;
     trans = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(trans.randomize()) else $error("Randomization Faild");
      mbxgendrv.put(trans.copy());
      trans.display("GEN");
      @(drvnext);// waiting for the driver to complete its work
      @(sconext);// waiting for the sco to complete its work
    end
    -> done;// the end of generation
  endtask
  
  
endclass



// now we need to create our driver class

class driver;
  virtual spi_interf interf;
  transaction datac;
  mailbox #(transaction) mbxgendrv;
  mailbox #(bit [11:0]) mbxdrvsco;
  
  event drvnext;
  
  function new(mailbox#(transaction) mbxgendrv, mailbox#(bit [11:0]) mbxdrvsco);
    this.mbxgendrv = mbxgendrv;
    this.mbxdrvsco = mbxdrvsco;
  endfunction
  
  task reset();
    interf.rst <= 1'b1;
    interf.newd <= 1'b0;
    interf.din <= 0;
    interf.cs  <= 1'b1;
    interf.mosi <= 1'b0;
    
    repeat(5)@(posedge interf.clk);
    interf.rst <= 1'b0;
    repeat(5) @(posedge interf.clk);
    $display("[DRV] : RESET DONE");
  endtask
  
  task run();
    
    forever begin
      mbxgendrv.get(datac);
      //datac.display("DRV");
      @(posedge interf.sclk);
      interf.newd <= 1'b1;
      interf.din <= datac.din;
      mbxdrvsco.put(datac.din);
      @(posedge interf.sclk);
      interf.newd <= 1'b0;
      wait(interf.cs == 1'b1);
      $display("[DRV]: DATA SENT -> %0d", datac.din);
      ->drvnext;
    end
  endtask
  
endclass



//now we have to create our monitor class 

class monitor;
  
  virtual spi_interf interf;
  
  mailbox #(bit [11:0]) mbxmonsco;
  
  //event sconext; // here we are adding a temperary event
 
  bit [11:0] srx;
  
  function new(mailbox #(bit [11:0]) mbxmonsco);
    this.mbxmonsco = mbxmonsco;
  endfunction
  
  
  task run();
    
    forever begin
      @(posedge interf.sclk);
      wait(interf.cs == 1'b0); // wait till the start of transaction 
      @(posedge interf.sclk);
      
      for(int i = 0; i  <= 11; i++) begin
        @(posedge interf.sclk);// wait till the positive edge of the clock
         srx[i] = interf.mosi;
      end
      
      wait(interf.cs == 1'b1);// wait till the end of the transaction
      $display("[MON]: (mosi)DATA SENT TO SCO -> %0d", srx);
      mbxmonsco.put(srx);
      //->sconext;
    end
    
  endtask
  
endclass

/*
module tb;
  
  generator gen;
  driver drv;
  monitor mon;
  spi_interf interf();
  mailbox #(transaction) mbxtb;
  mailbox #(bit [11:0]) mbxdrvsco, mbxmonsco;
  
  event next;
  event sconext;
  event done;
  
  spi dut(interf.clk, interf.rst, interf.newd, interf.din, interf.sclk, interf.cs, interf.mosi);
  
  initial begin 
    interf.clk <= 0;
  end
  
  always begin 
    #5;
    interf.clk <= ~interf.clk;
  end
  
  initial begin
    mbxtb = new();
    mbxdrvsco = new();
    mbxmonsco = new();
    gen = new(mbxtb);
    drv = new(mbxtb, mbxdrvsco);
    mon = new(mbxmonsco);
 
    
    drv.interf = interf;
    mon.interf = interf;
    
    
    drv.drvnext = next;
    gen.drvnext = next;
        
    gen.sconext = sconext;
    mon.sconext = sconext;
    
    gen.done = done;
    
    gen.count = 20;
  end
  
  initial begin
    fork
      drv.reset();
      drv.run();
      gen.run();
      mon.run();
    join_none
    wait(gen.done.triggered);
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
endmodule

*/


////  let us built our scoreboard class


class scoreboard;
  
  mailbox #(bit [11:0]) mbxmonsco, mbxdrvsco;
  
  bit [11:0] datadrv, datamon;
  
  event sconext;
  
  function new(mailbox #(bit [11:0]) mbxmonsco, mbxdrvsco);
    this.mbxdrvsco = mbxdrvsco;
    this.mbxmonsco = mbxmonsco;
  endfunction
    
  
  task run();
    
    forever begin
      
      mbxdrvsco.get(datadrv);
      mbxmonsco.get(datamon);
      
      if(datadrv == datamon) begin
        $display("[SCO]: DATA MATCHED");
      end
      else $error("[SCO]: DATA MISSMATCHED");
      ->sconext;
    end
   
  endtask
  
endclass


/*
module tb;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  spi_interf interf();
  mailbox #(transaction) mbxgendrv;
  mailbox #(bit [11:0]) mbxdrvsco, mbxmonsco;
  
  event drvnext;
  event sconext;
  event done;
  
  spi dut(interf.clk, interf.rst, interf.newd, interf.din, interf.sclk, interf.cs, interf.mosi);
  
  initial begin 
    interf.clk <= 0;
  end
  
  always begin 
    #5;
    interf.clk <= ~interf.clk;
  end
  
  initial begin
    mbxgendrv = new();
    mbxdrvsco = new();
    mbxmonsco = new();
    
    gen = new(mbxgendrv);
    drv = new(mbxgendrv, mbxdrvsco);
    mon = new(mbxmonsco);
    sco = new(mbxdrvsco, mbxmonsco);
 
    
    drv.interf = interf;
    mon.interf = interf;
    
    
    drv.drvnext = next;
    gen.drvnext = next;
        
    gen.sconext = sconext;
    sco.sconext = sconext;
    
    gen.done = done;
    
    gen.count = 20;
  end
  
  initial begin
    fork
      drv.reset();
      drv.run();
      gen.run();
      mon.run();
      sco.run();
    join_none
    wait(gen.done.triggered);
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
endmodule
*/


// the last phase is to create an envirment class

class envirnment;
  
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  virtual spi_interf interf;
  
  mailbox #(transaction) mbxgendrv;
  mailbox #(bit [11:0]) mbxdrvsco;
  mailbox #(bit [11:0]) mbxmonsco;
  
  
  event drvnext;
  event sconext;
  
  function new(virtual spi_interf interf);
    mbxgendrv = new();
    mbxdrvsco = new();
    mbxmonsco = new();
    
    gen = new(mbxgendrv);
    drv = new(mbxgendrv, mbxdrvsco);
    mon = new(mbxmonsco);
    sco = new(mbxdrvsco, mbxmonsco);
    
    this.interf = interf;
    drv.interf = this.interf;
    mon.interf = this.interf;
    
    gen.drvnext = this.drvnext;
    drv.drvnext = this.drvnext;
    
    gen.sconext = this.sconext;
    sco.sconext = this.sconext; 
    
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
    join_none
  endtask
  
  task pos_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    pos_test();
  endtask
endclass



module tb;
  
  envirnment env;
  spi_interf interf();
  
   spi dut(interf.clk, interf.rst, interf.newd, interf.din, interf.sclk, interf.cs, interf.mosi);
  
  initial begin 
    interf.clk <= 0;
  end
  
  always begin 
    #5;
    interf.clk <= ~interf.clk;
  end
  
  initial begin
    env = new(interf);
    env.gen.count = 20;
  end
  
  initial begin
    env.run();
  end
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
    
  end
endmodule
