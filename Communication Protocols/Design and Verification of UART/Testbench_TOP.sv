`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2022 04:25:56 PM
// Design Name: 
// Module Name: Testbench_Top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


class transaction;
    // first of all we want to use an enum data type to randomize the read and write operation 
    // read -> read data from the prepheral 
    // write -> write data to the prepheral
    
  typedef enum bit[1:0] {write = 2'b00, read = 2'b01} oper_type;
    
    
    // since we want to randomize the oper_type
    randc oper_type oper;
    // now we need to the variables of our transaction
    bit rx;
    rand bit [7:0] tx_din;
    bit send;
    bit tx;
    bit[7:0] rx_data;
    bit rx_done;
    bit tx_done;
    
    // now its time to define our deep copy function 
    function transaction copy();
        copy = new();
        copy.oper = this.oper;
        copy.rx = this.rx;
        copy.tx_din = this.tx_din;
        copy.send = this.send;
        copy.tx = this.tx;
        copy.rx_data = this.rx_data;
        copy.rx_done = this.rx_done;
        copy.tx_done = this.tx_done;
    endfunction
    
    // now lets declare our display function
    function void display(input string tag);
        $display("[%0s]: oper:%0d, RX:%0b, TX_DATA:%0d, send:%0b, TX:%0b, RX_DATA:%0d, rx_done:%0b, tx_done:%0b",tag, oper, rx, tx_din, send, tx, rx_data, rx_done, tx_done);
    endfunction
endclass

// now lets create our generator class
class generator;
    transaction trans;
    mailbox #(transaction) mbxgd;
    
    event done;
    
    int count = 0;
    
    event nextgd;
    event nextgs;
    function new(mailbox #(transaction) mbxgd);
        this.mbxgd = mbxgd;
        trans = new();
    endfunction
    
    task run();
        repeat(count) begin
           assert(trans.randomize())else $error("[GEN]: RANDOMISATION FAILED!!!");
           mbxgd.put(trans.copy);
           trans.display("GEN");
           @(nextgd);
           @(nextgs);
        end
        -> done;
    endtask
endclass

class driver;
    virtual uart_interf interf;
    transaction datac;
    mailbox #(transaction) mbxgd;
    mailbox #(bit [7:0]) mbxds;// the reason for which we are using this, is to compare the data sent to uart(tx_din) with the data that we will be getting in the scoreboard
    
    event nextgd;
    
    bit [7:0] data; //  this will hold the data received from uart_rx
    
    function new(mailbox #(transaction) mbxgd, mailbox #(bit [7:0])mbxds);
        this.mbxgd = mbxgd;
        this.mbxds = mbxds;
    endfunction
    
    task reset();
        interf.rst <= 1'b1;
        interf.tx_din <= 0;
        interf.tx <= 1'b1;
        interf.rx <= 1'b1;
        interf.send <= 0;
        interf.rx_data <= 0;
        interf.rx_done <= 1'b0;
        interf.tx_done <= 1'b0;
        
        repeat(5)@(posedge interf.utxclk);
        interf.rst <= 1'b0;
        @(posedge interf.utxclk);
        $display("[DRV]: RESET DONE!!!");
    endtask
    
    task run();
        forever begin
            mbxgd.get(datac);
            datac.display("DRV");
            // if we are sending data using uart_tx
            if(datac.oper == 2'b00) begin
                interf.rst <= 1'b0;
                interf.tx_din <= datac.tx_din; // ??????????
                interf.send <= 1'b1;
                interf.rx <= 1'b1;
                @(posedge interf.utxclk);
                interf.send <= 1'b0;
                mbxds.put(datac.tx_din);
                $display("[DRV]: Data sent: %0d", datac.tx_din);
              	wait(interf.tx_done == 1'b1);
                ->nextgd;
            end
          	else if(datac.oper == 2'b01) begin
                @(posedge interf.urxclk);
                interf.rst <= 1'b0;
                interf.send <= 1'b0;            
                interf.rx <= 1'b0;
                @(posedge interf.urxclk);
                for(int i = 0; i <= 7; i++) begin
                    @(posedge interf.urxclk);
                    interf.rx <= $urandom;
                    data[i] <= interf.rx;      
                end
                mbxds.put(data);
                $display("[DRV] : DATA RCVD : %0d", data);
                wait(interf.rx_done == 1'b1);
                interf.rx <= 1'b1;
                -> nextgd;
            end
        end
    endtask
endclass

class monitor;
    
    virtual uart_interf interf;
    transaction trans;
    mailbox #(bit [7:0]) mbxms;
    bit [7:0] srx;// send 
    bit [7:0] rrx;// recv
    
    function new(mailbox #(bit [7:0]) mbxms);
         this.mbxms = mbxms; 
    endfunction
    
    task run();
        forever begin
            @(posedge interf.utxclk);
            if((interf.send == 1'b1) && (interf.rx == 1'b1)) begin
                @(posedge interf.utxclk);// start collecting tx data from next clock tick
                for(int i = 0; i <= 7; i++) begin
                    @(posedge interf.utxclk);
                    srx[i] = interf.tx;
                end
                $display("[MON]: DATA SEND on UART TX %0d", srx);
                
                @(posedge interf.utxclk);
                mbxms.put(srx);
            end
            
            else if((interf.rx == 1'b0) && (interf.send == 1'b0)) begin
                wait(interf.rx_done == 1'b1);
                rrx = interf.rx_data;
                $display("[MON]: DATA RCVD RX %0d", rrx);
                @(posedge interf.utxclk);
                mbxms.put(rrx);
            end
        end
    endtask

endclass


class scoreboard;
    
    mailbox #(bit [7:0]) mbxds;
    mailbox #(bit [7:0]) mbxms;
    
    event nextgs;
    
    bit [7:0] ds;
    bit [7:0] ms;
    
    function new(mailbox #(bit [7:0]) mbxds, mailbox #(bit [7:0])mbxms);
        this.mbxds = mbxds;
        this.mbxms = mbxms;
    endfunction
    
    
    task run();
        forever begin
            mbxds.get(ds);
            mbxms.get(ms);
            
            $display("[SCO]: DRV -> %0d,  MON -> %0d", ds, ms);
            if(ds == ms) $display("DATA MATCHED");
            else $error("DATA MISMATCHED");
            
            ->nextgs;
        end
    endtask
    
endclass


class environment;
    
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    event nextgd;
    
    event nextgs;
    
    mailbox #(transaction) mbxgd;
    mailbox #(bit [7:0]) mbxds;
    mailbox #(bit [7:0]) mbxms;
    
    virtual uart_interf interf;
    
    function new(virtual uart_interf interf);
        mbxgd = new();
        mbxms = new();
        mbxds = new();
        
        gen = new(mbxgd);
        drv = new(mbxgd, mbxds);
        mon = new(mbxms);
        sco = new(mbxds, mbxms);
        
        this.interf = interf;
        drv.interf = this.interf;
        mon.interf = this.interf;
        
      gen.nextgs = nextgs;
      sco.nextgs = nextgs;
     
      gen.nextgd = nextgd;
      drv.nextgd = nextgd;
      
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


module Testbench_Top();
    uart_interf interf();
    
    UART_TOP #(1000000, 9600) dut (interf.clk, interf.rst, interf.rx, interf.tx_din, interf.send, interf.tx, interf.rx_data, interf.tx_done, interf.rx_done);
    
    initial begin
        interf.clk <= 0;
    end
    
    always #10 interf.clk <= ~interf.clk;
    
    environment env;
    
    initial begin
        env = new(interf);
        env.gen.count = 5;
        env.run();
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
    
    assign interf.utxclk = dut.utx.uclk;
    assign interf.urxclk = dut.urx.uclk;
    
endmodule

