module spi(
  input clk,
  input rst,
  input newd,
  input[11:0] din,
  output reg sclk,
  output reg cs,
  output reg mosi
);
 
  
  typedef enum bit[1:0] {idle = 2'b00, send = 2'b10} type_state;
  type_state state = idle;
  
  // first of all we have to generate the sclk for our case we want sclk = 1Mhz;
  int countc = 0;
  int count = 0;
  
  always@(posedge clk)begin
    
    if(rst == 1'b1) begin
      countc <= 0;
      sclk <= 0;
    end
    else begin
      if(countc < 50) begin
        countc <= countc + 1;
      end
      else begin
        sclk <= ~sclk;
        countc <= 0;
      end
    end
  end
  
  
  // now lets take care of the state machine of our design
  reg [11:0]temp;
  always@(posedge sclk) begin
    
    if(rst == 1'b1) begin
      cs <= 1'b1;
      mosi <= 1'b0;
    end
    else begin
      case (state)
        idle:
          begin
            if(newd == 1'b1) begin
              state <= send;
              count <= 0;
              temp <= din;
              cs <= 1'b0;
            end
            else begin
              state <= idle;
              temp <= 12'h000;
            end
          end
        send:
          begin
            if(count <= 11) begin
              mosi <= temp[count]; // send the LSB first
              count <= count + 1;
            end
            else begin
              count <= 0;
              cs <= 1'b1;
              state <= idle;
            end
          end
        default: state <= idle;
     endcase
    end
  end
endmodule       
        
// defining our interface 
interface spi_interf;          
  logic clk;
  logic rst;
  logic newd;
  logic [11:0] din;
  logic  sclk;
  logic  cs;
  logic  mosi;
endinterface
