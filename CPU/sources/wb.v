`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: wb
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
`define EXC_ENTER_ADDR 32'd0	// Exception entrance address
								// Exception implemented here only contains SYSCALL
module wb(
	input wire     		WB_valid,
	input wire [117:0]	MEM_WB_bus_r,
	output wire 		rf_wen,
	output wire [  4:0] rf_wdest,
	output wire [ 31:0] rf_wdata,
	output wire 		WB_over,

	// Five Levels Pipeline New Interface
	input wire 		    clk,
	input wire 	       	resetn,
	output wire [ 32:0] exc_bus,
	output wire [  4:0] WB_wdest,
	output wire     	cancel,

	// Show PC and HI/LO
	output wire [ 31:0] WB_pc,
	output wire [ 31:0] HI_data,
	output wire [ 31:0] LO_data
);
//---------{MEM->WB bus}begin
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
	wire [31:0] pc;
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
			pc} = MEM_WB_bus_r;
//---------{MEM->WB bus}end

//---------{HI/LO register}begin
	reg [31:0] hi;
	reg [31:0] lo;

	always @(posedge clk) 
	begin
		if (hi_write) 
		begin
			hi <= mem_result;
		end
	end

	always @(posedge clk) 
	begin
		if (lo_write) 
		begin
			lo <= lo_result;
		end
	end
//---------{HI/LO register}end

//---------{cp0 register}begin
// only implement STATUS(12,0),CAUSE(13,0),EPC(14,0)
// Every CP0 register only use 5 bit cp0 number
	wire [31:0] cp0r_status;
	wire [31:0] cp0r_cause;
	wire [31:0] cp0r_epc;

	// write enable
	wire status_wen;
	// wire cause_wen;
	wire epc_wen;
	assign status_wen = mtc0 & (cp0r_addr=={5'd12,3'd0});
	assign epc_wen = mtc0 & (cp0r_addr=={5'd14,3'd0});

	//cp0 register read
	wire [31:0] cp0r_rdata;
	assign cp0r_rdata = (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
						(cp0r_addr=={5'd13,3'd0}) ? cp0r_cause :
						(cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;

	// STATUS register
	// only implement STATUS[1], i.e. EXL area
	// EXL area is software w&r enable, so we need status_wen
	reg status_exl_r;
	assign cp0r_status = {30'd0,status_exl_r,1'b0};
	always @(posedge clk) 
	begin
		if (!resetn || eret) 
		begin
			status_exl_r <= 1'b0;
		end
		else if (syscall) 
		begin
			status_exl_r <= 1'b1;	
		end
		else if (status_wen)
		begin
			status_exl_r <= mem_result[1];
		end
	end

	// CAUSE register
	// only implement CAUSE[6:2], i.e. ExcCode area, store Exception Code
	// ExcCode Area is Software Read Only, write disenable, so don't need cause_wen
	reg [4:0] cause_exc_code_r;
	assign cp0r_cause = {25'd0, cause_exc_code_r, 2'd0};
	always @(posedge clk) 
	begin
		if (syscall) begin
			cause_exc_code_r <= 5'd8;
		end
	end
//---------{cp0 register}end

//---------{WB finish}begin
	// all operations in WB module can be finish in one beat.
	// so WB_valid is WB_over.
	assign WB_over = WB_valid;
//---------{WB finish}end

//---------{WB -> regfile Signal}begin
	assign rf_wen = wen & WB_over;
	assign rf_wdest = wdest;
	assign rf_wdata = mfhi ? hi :
					  mflo ? lo :
					  mfc0 ? cp0r_rdata : mem_result;
//---------{WB -> regfile Signal}end

//---------{Exception pc Signal}begin
	wire 		exc_valid;
	wire [31:0] exc_pc;
	assign exc_valid = (syscall | eret) & WB_valid;
	// the return address of eret is GRP[epc]
	// SYSCALL's excPC should be {EBASE[31:10],10'h180},
	// But for experiment, we should set EXC_ENTER_ADDR to 0 to simplify coding test program
	assign exc_pc = syscall ? `EXC_ENTER_ADDR : cp0r_epc;
	assign exc_bus = {exc_valid,exc_pc};
//---------{Exception pc Signal}end

//---------{dest of WB module}begin
	// Only when WB module is valid, the regfile number of it's write destination is meaningful
	assign WB_wdest = rf_wdest & {5{WB_valid}};
//---------{dest of WB module}end

//---------{Show PC of WB module and HI/LO}begin
	assign WB_pc = pc;
	assign HI_data = hi;
	assign LO_data = lo;
//---------{Show PC of WB module and HI/LO}end
endmodule















