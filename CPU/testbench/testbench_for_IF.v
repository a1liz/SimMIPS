`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/09/2018 11:55:17 AM
// Design Name: 
// Module Name: testbench_for_IF
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


module testbench_for_IF();

// Inputs
reg clk = 0;
always #10 clk=~clk;
reg resetn;
reg IF_valid;
reg next_fetch;
reg [31:0] inst;
reg [32:0] jbr_bus;
reg [32:0] exc_bus;

// Outputs
wire [31:0] inst_addr;
wire IF_over;
wire [63:0] IF_ID_bus;
wire [31:0] IF_pc;
wire [31:0] IF_inst;

// Debug

// Others
reg IF_allow_in;


// Instantiate the Unit Under Test (UUT)
fetch fetch_module(
    .clk(clk),
    .resetn(resetn),
    .IF_valid(IF_valid),
    .next_fetch(next_fetch),
    .inst(inst),
    .jbr_bus(jbr_bus),
    .inst_addr(inst_addr),
    .IF_over(IF_over),
    .IF_ID_bus(IF_ID_bus),
    .exc_bus(exc_bus),
    .IF_pc(IF_pc),
    .IF_inst(IF_inst)
);

    initial begin
        resetn = 0;
        next_fetch = 1;
        jbr_bus = 33'd0;
        exc_bus = 33'd0;
        #20 resetn = 1;
    end
    
    always #30 next_fetch = ~next_fetch;
    always #10 inst = $random;
    
    always @(posedge clk)
    begin
        if(!resetn)
        begin
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end
    
endmodule
