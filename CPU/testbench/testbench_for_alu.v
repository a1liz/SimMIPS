`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2018 08:08:15 AM
// Design Name: 
// Module Name: testbench_for_alu
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


module testbench_for_alu();
// Inputs
    reg [11:0] alu_control;
    reg [31:0] alu_src1;
    reg [31:0] alu_src2;
// Outputs
    wire [31:0] alu_result;
// Debug

alu alu_module(
    .alu_control(alu_control),
    .alu_src1(alu_src1),
    .alu_src2(alu_src2),
    .alu_result(alu_result)
);

    initial begin
        alu_control = {1'b1,11'b0};
        alu_src1 = 32'd15;
        alu_src2 = 32'd20;
    end
endmodule
