class transaction;
  
  typedef enum int {write = 0, read = 1, random = 2, error = 3} op_type;
  
  randc op_type oper ;
  rand bit [31:0] paddr;
  rand bit [31:0] pwdata;
  rand bit psel;
  rand bit penable;
  rand bit pwrite;
  bit [31:0] prdata;
  bit pready;
  bit pslverr;
  
 
  
  constraint addr_c {
  paddr > 1; paddr < 5;////2 3 4
  }
  
  constraint data_c {
  pwdata > 1; pwdata < 10; /// 2-9
  }
  
  function void display(input string tag);
    $display("[%0s] : OP:%0s  paddr:%0d  pwdata:%0d  psel:%0b  penable:%0b  pwrite:%0b  prdata:%0d  pready:%0b  pslverr:%0b",tag,oper.name(),paddr,pwdata,psel, penable, pwrite, prdata, pready, pslverr);
  endfunction
  
  function transaction copy();
    copy = new();
    copy.oper = this.oper;
    copy.paddr = this.paddr;
    copy.pwdata = this.pwdata;
    copy.psel = this.psel;
    copy.penable = this.penable;
    copy.pwrite = this.pwrite;
    copy.prdata = this.prdata;
    copy.pready = this.pready;
    copy.pslverr = this.pslverr;
  endfunction
  
  
endclass
/////////////////////////////////////////
/*
 
module tb;
  
  transaction tr;
  
  initial begin
    tr = new();
    tr.display("TOP");
  end
  
endmodule
 
*/
 
 
 
 
 
 
 
 
 
 
/////////////////////////////////////////
class generator;
  
   transaction tr;
  
   mailbox #(transaction) mbx;
  
   int count = 0;
  
   event nextdrv; ///driver completed task of triggering interface
  
   event nextsco; ///scoreboard completed its objective
  
   event done; 
   
   
  function new(mailbox #(transaction) mbx);
      this.mbx = mbx;
      tr=new();
   endfunction; 
 
   task run(); 
    
     repeat(count)	 
	     begin    
           assert(tr.randomize()) else $error("Randomization failed");	
           mbx.put(tr.copy);
           tr.display("GEN");
           @(nextdrv);
           @(nextsco);
         end  
     ->done;
   endtask
  
  
endclass
 
/////////////////////////////////////////////////////
/*
  module tb;
    
    generator gen;
    mailbox #(transaction) mbx;
    
    
    
    initial begin
      mbx = new();
      gen = new(mbx);
      gen.count = 20;
      gen.run();
      
      
    end
    
    
  endmodule
 
*/
 
 
 
 
///////////////////////////////////////////////////////
 
class driver;
  
   virtual abp_if vif;
  
   mailbox #(transaction) mbx;
  
   transaction datac;
  
   event nextdrv;
 
    function new(mailbox #(transaction) mbx);
      this.mbx = mbx;
   endfunction; 
  
  
  task reset();
    vif.presetn <= 1'b0;
    vif.psel <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwdata <= 0;
    vif.paddr <= 0;
    vif.pwrite <= 1'b0;
    repeat(5) @(posedge vif.pclk);
    vif.presetn <= 1'b1;
    repeat(5) @(posedge vif.pclk);
    $display("[DRV] : RESET DONE");
  endtask
   
  task run();
    forever begin
      
      mbx.get(datac);
      
      if(datac.oper == 0) ///write
        begin
          @(posedge vif.pclk);
    		vif.psel <= 1'b1;
    		vif.penable <= 1'b0;
   		    vif.pwdata <= datac.pwdata;
   		    vif.paddr <= datac.paddr;
  		    vif.pwrite <= 1'b1;
          @(posedge vif.pclk);
           vif.penable <= 1'b1; 
          repeat(2) @(posedge vif.pclk); 
          vif.psel <= 1'b0;
          vif.penable <= 1'b0;
          vif.pwrite <= 1'b0;
          $display("[DRV] : DATA WRITE OP data :%0d and addr : %0d", datac.pwdata, datac.paddr);          
        end
      else if (datac.oper == 1) //read
        begin
            @(posedge vif.pclk);
            vif.psel <= 1'b1;
    		vif.penable <= 1'b0;
   		    vif.pwdata <= datac.pwdata;
   		    vif.paddr <= datac.paddr;
  		    vif.pwrite <= 1'b0;
          @(posedge vif.pclk);
           vif.penable <= 1'b1; 
          repeat(2) @(posedge vif.pclk); 
          vif.psel <= 1'b0;
          vif.penable <= 1'b0;
          vif.pwrite <= 1'b0;
          
          $display("[DRV] : DATA READ OP addr : %0d", datac.paddr); 
        end
      else if (datac.oper== 2) ///random
        begin
           @(posedge vif.pclk);
            vif.psel <= 1;
    		vif.penable <= 0;
   		    vif.pwdata <= datac.pwdata;
   		    vif.paddr <= datac.paddr;
  		    vif.pwrite <= datac.pwrite;
          @(posedge vif.pclk);
            vif.penable <= 1; 
          repeat(2) @(posedge vif.pclk); 
          vif.psel <= 1'b0;
          vif.penable <= 1'b0;
          vif.pwrite <= 1'b0;
          $display("[DRV] : RANDOM OPERATION");          
        end
      else if (datac.oper == 3)  ///slv error
        begin
           @(posedge vif.pclk);
            vif.psel <= 1;
    		vif.penable <= 0;
   		    vif.pwdata <= datac.pwdata;
            vif.paddr <= $urandom_range(32,100);
  		    vif.pwrite <= datac.pwrite;
          @(posedge vif.pclk);
            vif.penable <= 1; 
          repeat(2) @(posedge vif.pclk); 
          vif.psel <= 1'b0;
          vif.penable <= 1'b0;
          vif.pwrite <= 1'b0;
          $display("[DRV] : SLV ERROR");       
        end
      
      
      ->nextdrv;
    end
  endtask
  
  
endclass
 
 
 
/*
  module tb;
    
    generator gen;
    driver drv;
    mailbox #(transaction) mbx;
    event next;
    
    abp_if vif();
    apb_ram dut (vif.presetn, vif.pclk, vif.psel, vif.penable, vif.pwrite, vif.paddr, vif.pwdata, vif.prdata, vif.pready,vif.pslverr);
    
    initial begin
      vif.pclk <= 0;
    end
    
    always #10 vif.pclk <= ~vif.pclk;
    
    initial begin
      mbx = new();
      
      gen = new(mbx);
      
      gen.count = 20;
      
      drv = new(mbx);
      
      drv.vif = vif;
      
      gen.nextdrv = next;
      drv.nextdrv = next;
      
      fork
      gen.run();
      drv.run();
      join_none
      wait(gen.done.triggered);
      $finish();
    end
    
    initial begin
    
    end
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
    
    
  endmodule
  
*/
 
 
 
//////////////////////////////////
 
class monitor;
 
   virtual abp_if vif;
  
   mailbox #(transaction) mbx;
  
   transaction tr;
 
  
 
 
    function new(mailbox #(transaction) mbx);
      this.mbx = mbx;     
   endfunction;
  
  task run();
    tr = new();
    forever begin
      @(posedge vif.pclk);
      if((vif.psel) && (!vif.penable)) 
            begin
              
      		  @(posedge vif.pclk);
              if(vif.psel && vif.pwrite && vif.penable) ////write access
        			 begin
                      @(posedge vif.pclk);  
        			 tr.pwdata = vif.pwdata;
        			 tr.paddr = vif.paddr;
        			 tr.pwrite = vif.pwrite;
                     tr.pslverr = vif.pslverr;
                       $display("[MON] : DATA WRITE data : %0d and addr : %0d write :%0b", vif.pwdata, vif.paddr, vif.pwrite);
                       @(posedge vif.pclk);
         			end ////write access
     			 else if (vif.psel && !vif.pwrite && vif.penable)
          			 begin
                        @(posedge vif.pclk);
         			tr.prdata = vif.prdata;
         			tr.pwrite = vif.pwrite;
        			tr.paddr = vif.paddr;
                    tr.pslverr = vif.pslverr;
                      @(posedge vif.pclk);  
                       
                       $display("[MON] : DATA READ data : %0d and addr : %0d write:%0b", vif.prdata,vif.paddr, vif.pwrite);
                       
                       
                       
          			 end
      	
         
    
           mbx.put(tr);
         end
    end
  endtask
  
 
  
endclass
 
///////////////////////////////////////////////
 
class scoreboard;
  
   mailbox #(transaction) mbx;
   transaction tr;
   event nextsco;
  
  bit [31:0] pwdata[12] = '{default:0};
  bit [31:0] rdata;
  int index;
  
   function new(mailbox #(transaction) mbx);
      this.mbx = mbx;     
    endfunction;
  
  task run();
  forever begin
      
      mbx.get(tr);
    $display("[SCO] : DATA RCVD wdata:%0d rdata:%0d addr:%0d write:%0b", tr.pwdata, tr.prdata, tr.paddr, tr.pwrite);
      
    if( (tr.pwrite == 1'b1) && (tr.pslverr == 1'b0))  ///write access
      begin 
        pwdata[tr.paddr] = tr.pwdata;
        $display("[SCO] : DATA STORED DATA : %0d ADDR: %0d",tr.pwdata, tr.paddr);
      end
    else if((tr.pwrite == 1'b0) && (tr.pslverr == 1'b0))  ///read access
      begin
       rdata = pwdata[tr.paddr];    
        if( tr.prdata == rdata)
          $display("[SCO] : Data Matched"); 
       else
        $display("[SCO] : Data Mismatched"); 
     end 
    else if(tr.pslverr == 1'b1)
      begin
        $display("[SCO] : SLV ERROR DETECTED");
      end
   ->nextsco;
  end
  endtask
 
  
endclass
 
//////////////////////////////////////////////////////////
 
class environment;
 
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco; 
  
    
  
    event nextgd; ///gen -> drv
  
    event nextgs;  /// gen -> sco
  
  mailbox #(transaction) gdmbx; ///gen - drv
    
     
  mailbox #(transaction) msmbx;  /// mon - sco
  
    virtual abp_if vif;
 
  
  function new(virtual abp_if vif);
       
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    
    
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.nextsco = nextgs;
    sco.nextsco = nextgs;
    
    gen.nextdrv = nextgd;
    drv.nextdrv = nextgd;
 
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
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
  
  
endclass
 
 
//////////////////////////////////////////////////
 module tb;
    
   abp_if vif();
 
 apb_ram dut (vif.presetn, vif.pclk, vif.psel, vif.penable, vif.pwrite, vif.paddr, vif.pwdata, vif.prdata, vif.pready,vif.pslverr);
   
    initial begin
      vif.pclk <= 0;
    end
    
    always #10 vif.pclk <= ~vif.pclk;
    
    environment env;
    
    
    
    initial begin
      env = new(vif);
      env.gen.count = 30;
      env.run();
    end
      
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
   
    
  endmodule
