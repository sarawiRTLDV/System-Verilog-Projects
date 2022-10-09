/*++++++++++++++++++++++++++++++++++++++++++++++++++++
-> here the design of the fifo
*/

module fifo( 
  /*
  -> here we declare our inputs and output ports of the fifo module 
  -> the clock and rst are global signals 
  -> remember in our testbench we will be generating the stimulus for rd, wr, rst and data signals using pseudo random generator, but for the clock signal we will be generating it inside our tb top();
  */
  input clock, rd, wr,
  output full, empty, // these two signals are for representing the status of our fifo 
  input [7:0] data_in,
  output reg [7:0] data_out,
  input rst);
 
 
  reg [7:0] mem [31:0];// here we basicaly creating a mem storage with the capability to store 32 elemement 8bits each
  // these two pointers are for mem adressing
  reg [4:0] wr_ptr;
  reg [4:0] rd_ptr; 
 
 
 // now lets understand the mean code of our design
  always@(posedge clock) // this means that our design is sensitive to the positive edge of the clock
  begin
    /*->if reset is high we will initialize the fifo to it's initial state*/
    if (rst == 1'b1)
      begin
        data_out <= 0;
        rd_ptr <= 0;
        wr_ptr <= 0;
        for(int i =0; i < 32; i++) begin
          mem[i] <= 0;
        end
      end
    else
      /*if the reset is low*/
      begin
        /*here we will be cheking if the user wants to write into the fifo or read from it */
        
        if ((wr == 1'b1)  && (full == 1'b0))
          begin
          mem[wr_ptr] <= data_in;
          wr_ptr = wr_ptr + 1;//to not overwrite a memory data
          end
        
        if((rd == 1'b1) && (empty == 1'b0))
          begin
            data_out <= mem[rd_ptr];// here the user will be reading the oldest memory data in our fifo
          rd_ptr <= rd_ptr + 1;// for not reading the same address
          end
      end
end
  
  
assign empty = ((wr_ptr - rd_ptr) == 0) ? 1'b1 : 1'b0; 
  
assign full = ((wr_ptr - rd_ptr) == 31) ? 1'b1 : 1'b0; 
  
endmodule
 
 
 
interface fifo_if;
  
  logic clock, rd, wr;
  logic full, empty;
  logic [7:0] data_in;
  logic [7:0] data_out;
  logic rst;
 
endinterface
