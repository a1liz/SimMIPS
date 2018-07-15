`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:23:41 PM
// Design Name: 
// Module Name: adder
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

module adder(
	input wire [31:0] 	operand1,
	input wire [31:0] 	operand2,
	input wire 			cin,
	output wire [31:0] 	result,
	output wire 		cout
	);
	assign {cout,result} = operand1 + operand2 + cin;
endmodule