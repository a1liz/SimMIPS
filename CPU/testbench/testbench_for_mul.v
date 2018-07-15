`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2018 08:32:57 AM
// Design Name: 
// Module Name: testbench_for_mul
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


module testbench_for_mul();
// Inputs
    reg clk;
    reg mult_begin;
    reg [31:0] mult_op1;
    reg [31:0] mult_op2;
// Outputs
    wire [63:0] product;
    wire mult_end;
// debug
    wire debug_mult_valid;
    wire [63:0] debug_product_temp;
    wire [31:0] debug_multiplier;
    wire [31:0] debug_multiplicand;

multiply multiply_module(
    .clk(clk),
    .mult_begin(mult_begin),
    .mult_op1(mult_op1),
    .mult_op2(mult_op2),
    .product(product),
    .mult_end(mult_end),
    .debug_mult_valid(debug_mult_valid),
    .debug_product_temp(debug_product_temp),
    .debug_multiplier(debug_multiplier),
    .debug_multiplicand(debug_multiplicand)
);
    initial begin
        clk = 1;
        mult_begin = 0;
        #10 mult_begin = 1;
        mult_op1 = 32'd15;
        mult_op2 = 32'd21;
    end
    always #10 clk = ~clk;
endmodule
