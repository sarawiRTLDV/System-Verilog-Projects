`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2022 04:11:11 PM
// Design Name: 
// Module Name: UART_TOP
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


module UART_TOP
#(
    parameter clk_freq = 1000000,
    parameter baudrate = 9600
)
(
    input clk, rst,
    input rx, 
    input [7:0] tx_din,
    input send,
    output  tx, 
    output [7:0] rx_data,
    output tx_done, 
    output rx_done
    );
    // here were are performing the connections needed between the UART pins and the UART_TX and UART_RX components pins
    UART_TX #(clk_freq, baudrate) utx (clk, rst, send, tx_din, tx, tx_done);
    
    UART_RX #(clk_freq, baudrate) urx (clk, rst, rx, rx_done, rx_data);
    
    
    
endmodule


/////////////////////////////////////////////////////
// here we declare our module
// and by the way we are using parameter in other to give the user the ability to set his prefered clk_freq and br

module UART_TX 
#(
    parameter clk_freq = 1000000,
    parameter baudrate = 9600
)
(
    input clk, rst,// these are global signals
    input send, // to start sending data we need make this input high
    input [7:0]tx_data,// this will contain the data that we will be sending
    output reg tx, // this is the output pin from which we will be sending the data
    output reg tx_done// this will inform us when all the data is sent
    );
    // the first thing that we have to do is to generate the clock for our baudrate
    // to do that we need to calculate the clk_count; means how many clock tick a bit take to be sent
    localparam clkcount = (clk_freq/baudrate);//x

    integer count = 0;
    integer counts = 0;
    
    /*
    cuz we don't want to use the system clock and instead of that, 
    we want use a slower clock for our uart we need to generate it
    */
    reg uclk = 0; // this will be the uart clok that we need to generate it 
    
    // just as we did with spi protol we need to use the state machine for uart_tx and uart_rx
    // in this case we have 4 state 
    enum bit[1:0] {idle = 2'b00, start = 2'b01, transfer = 2'b10, done = 2'b11} state;
    
    // the generate uclk
    always @(posedge clk)begin
    // clkcount is simply the uclk periode
        if(count <= (clkcount/2))
            count <= count + 1;
        else begin
            count <= 0;
            uclk <= ~uclk;
        end
    end
    
    
    // now we have to discribe how our uart_tx should behave 
    
    reg [7:0] din; // this will hold the txdata, we use to not corrupt the data inside the tx data register
    
    // since our uart is sinsitive to uclk 
    always@(posedge uclk) begin
        if(rst == 1'b1) begin
            state <= idle;    
        end
        else 
            case(state)
                idle:
                    begin
                        count <= 0;
                        counts <= 0;
                        tx <= 1'b1;
                        tx_done <= 1'b0;
                        if(send == 1'b1) begin
                            state <= transfer; 
                            tx <= 1'b0; 
                            din <= tx_data;
                        end
                        else begin
                            state <= idle;
                        end 
                    end
                transfer:
                    begin
                        if(counts <= 7) begin
                            
                            counts <= counts + 1;
                            tx <= din[counts];
                            state <= transfer;
                        end
                        else begin
                            tx <= 1'b1;
                            state <= idle;
                            tx_done <= 1'b1;
                        end
                    end
                default: state <= idle;
             endcase
     end
endmodule



/////////////////////////////////////////////////////
// here we declare our module
// and by the way we are using parameter in other to give the user the ability to set his prefered clk_freq and br

module UART_RX 
#(
    parameter clk_freq = 1000000,
    parameter baudrate = 9600
)
(
    input clk,
    input rst,// these are global signals
    input rx, // this is the pin in which we will receive data
    output reg rx_done,
    output reg [7:0]rx_data// this will hold the received data on the rx pin
    );
    // the first thing that we have to do is to generate the clock for our baudrate
    // to do that we need to calculate the clk_count; means how many clock tick a bit take to be sent
    localparam clkcount = (clk_freq/baudrate);//x

    integer count = 0;
    integer counts = 0;
    
    /*
    cuz we don't want to use the system clock and instead of that, 
    we want use a slower clock for our uart we need to generate it
    */
    reg uclk = 0; // this will be the uart clok that we need to generate it 
    
    // just as we did with spi protol we need to use the state machine for uart_tx and uart_rx
    // in this case we have 4 state 
    enum bit[1:0] {idle = 2'b00, start = 2'b01, receive = 2'b10, done = 2'b11} state;
    
    // the generate uclk
    always @(posedge clk)begin
    // clkcount is simply the uclk periode
        if(count < (clkcount/2)) begin
            count <= count + 1;
        end
        else begin
            count <= 0;
            uclk <= ~uclk;
        end
    end
    
    
    // now we have to discribe how our uart_rx should behave 
    
    reg [7:0] dout; // this will hold the rxdata, simply the data that we will be storing in the rx_data register
    
    // since our uart is sinsitive to uclk 
    always@(posedge uclk) begin
        if(rst == 1'b1) begin
            rx_done <= 1'b0;
            counts <= 0;
            rx_data <= 8'h00;
        end
        else 
            case(state)
                idle:
                    begin
                        counts <= 0;
                        rx_data <= 8'h00;
                        rx_done <= 1'b0;
                        if(rx == 1'b0) begin
                            state <= start; 
                        end
                        else begin
                            state <= idle;
                        end
                    end
                start:
                    begin
                        if(counts <= 7) begin
                            rx_data[counts] <= {rx, rx_data[7:1]}; // this is a write shift register                            counts <= counts + 1;
                            counts <= counts + 1;
                        end
                        else begin
                            counts <= 0;
                            rx_done <= 1'b1;
                            state <= idle;
                        end
                    end
                    
                default: state <= idle;
             endcase
     end
endmodule


interface uart_interf;
   logic clk,rst;
   logic utxclk, urxclk;
   logic rx;
   logic[7:0] tx_din;
   logic send;
   logic tx;
   logic [7:0] rx_data;
   logic rx_done;
   logic tx_done;
endinterface
