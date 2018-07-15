`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/12/2018 10:38:10 AM
// Design Name: 
// Module Name: testbench_for_MEM
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


module testbench_for_MEM();
// Inputs
    reg clk;
    reg MEM_valid;
    reg [153:0] EXE_MEM_bus_r;
    reg [31:0] dm_rdata;
    reg MEM_allow_in;
// Outputs
    wire [31:0] dm_addr;
    wire [3:0] dm_wen;
    wire [31:0] dm_wdata;
    wire MEM_over;
    wire [117:0] MEM_WB_bus;
    wire [4:0] MEM_wdest;
    wire [31:0] MEM_pc;
// Debug
    wire [31:0] mem_result;
	wire [31:0] lo_result;
	wire 		hi_write;
	wire 		lo_write;

	// regfile write enable and address
	wire wen;
	wire [4:0] wdest;

	// message WB may use
	wire mfhi;
	wire mflo;
	wire mtc0;
	wire mfc0;
	wire [7:0] cp0r_addr;
	wire syscall;
	wire eret;

	// pc
	wire [31:0] new_pc;

mem mem_module(
    .clk(clk),
    .MEM_valid(MEM_valid),
    .EXE_MEM_bus_r(EXE_MEM_bus_r),
    .dm_rdata(dm_rdata),
    .dm_addr(dm_addr),
    .dm_wen(dm_wen),
    .dm_wdata(dm_wdata),
    .MEM_over(MEM_over),
    .MEM_WB_bus(MEM_WB_bus),
    .MEM_allow_in(MEM_allow_in),
    .MEM_wdest(MEM_wdest),
    .MEM_pc(MEM_pc)
);
    initial begin
        clk = 1;
        MEM_valid = 0;
        EXE_MEM_bus_r = {4'd0,32'd0,
                         32'd0,
                         32'd123,
                         1'd1,1'd1,
                         1'd0,1'd0,
                         1'd0,1'd0,8'd0,1'd0,1'd0,1'd0,5'd0,
                         32'd34};
        dm_rdata = 32'd0;
        MEM_allow_in = 0;
        
        #30 MEM_valid = 1;    
    end
    
    always #10 clk = ~clk;
    assign {wen,
                wdest,
                mem_result,
                lo_result,
                hi_write,
                lo_write,
                mfhi,
                mflo,
                mtc0,
                mfc0,
                cp0r_addr,
                syscall,
                eret,
                new_pc} = MEM_WB_bus;
endmodule
