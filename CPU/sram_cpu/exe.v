`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: exe
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
module exe(
	input wire 		    EXE_valid,
	input wire [181:0]  ID_EXE_bus_r,	// ID->EXE bus
	output wire 	    EXE_over,		// EXE module finish
	output wire [166:0]	EXE_MEM_bus,	// EXE->MEM bus

	// Five Levels Pipeline New Interface
	input wire 			clk,
	output wire [  4:0] EXE_wdest,		// destination address that EXE write back to regfile
    output wire [ 31:0] EXE_result_quick_get,   // destination data that latter pipeline may use
    output wire         EXE_quick_en,

	// show PC
	output wire [ 31:0]	EXE_pc
	
	// debug
//	output wire [31:0] debug_div_remainder,
//	output wire debug_div_begin,
//	output wire [31:0] debug_op1,
//	output wire [31:0] debug_op2
);
//----------{ID->EXE bus}begin
	// EXE needs
	wire [1:0] muldiv;
	wire muldiv_signed;
	wire mthi;
	wire mtlo;
	wire [11:0] alu_control;
	wire [31:0] alu_operand1;
	wire [31:0] alu_operand2;
	wire data_related_en;

	// load/store message that MEM may use
	wire [5:0] mem_control;
	wire [31:0] store_data;
	
	// message that WB may use
	wire mfhi;
	wire mflo;
	wire mtc0;
	wire mfc0;
	wire [7:0] cp0r_addr;
	wire syscall;
	wire eret;
	wire break;
	wire addr_exc;
	wire ri_exc;
	wire ov_exc_en;
	wire is_ds;
	wire [1:0] halfword;
	wire [3:0] rf_wen;
	wire [4:0] rf_wdest;
	
	// pc
	wire [31:0] pc;
	assign {muldiv,
	        muldiv_signed,
			mthi,
			mtlo,
			alu_control,
			alu_operand1,
			alu_operand2,
			data_related_en,
			mem_control,
			store_data,
			mfhi,
			mflo,
			mtc0,
			mfc0,
			cp0r_addr,
			syscall,
			eret,
			break,
			addr_exc,
			ri_exc,
			ov_exc_en,
			is_ds,
			halfword,
			rf_wen,
			rf_wdest,
			pc} = ID_EXE_bus_r;
//----------{ID->EXE bus}end

//----------{ALU}begin
	wire [31:0] alu_result;
	wire ov_exc;
	alu alu_module(
		.alu_control	(alu_control),		// I, 12, ALU control signal
		.alu_src1		(alu_operand1),		// I, 32, ALU operand 1
		.alu_src2		(alu_operand2),		// I, 32, ALU operand 2
		.alu_result		(alu_result),		// O, 32, ALU result
		.ov_exc 		(ov_exc)			// O, 1,  Overflow exception
	);
//----------{ALU}end

//----------{Multiplier-Divier Unit}begin
	wire  		div_begin;
	wire [31:0] div_result;
	wire [31:0] div_remainder;
	wire 		div_end;

	assign div_begin = muldiv[1] & EXE_valid;
	divider divider_module(
		.clk 			(clk),
		.div_begin 		(div_begin),
		.div_signed     (muldiv_signed),
		.div_op1 		(alu_operand1),
		.div_op2		(alu_operand2),
		.div_result		(div_result),
		.div_remainder	(div_remainder),
		.div_end 		(div_end)
	);

	wire 		mult_begin;
	wire [63:0] product;
	wire 		mult_end;

	assign mult_begin = muldiv[0] & EXE_valid;
	multiply multiply_module (
		.clk		(clk),
		.mult_begin (mult_begin),
		.mult_signed(muldiv_signed),
		.mult_op1 	(alu_operand1),
		.mult_op2	(alu_operand2),
		.product 	(product),
		.mult_end 	(mult_end)
	);
//----------{Multiplier-Divier Unit}end

//----------{EXE finish} begin
	// For ALU operation, all can complete in 1 beat.
	// But for multiply and divide operation, it need several beats.
	assign EXE_over = EXE_valid & (~muldiv[0] | mult_end) & (~muldiv[1] | div_end);
//----------{EXE finish} end

//----------{dest value of EXE module} begin
	// only when EXE module is valid, EXE_wdest is meaningful.
	assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//----------{dest value of EXE module} end

//----------{EXE->MEM bus}begin
	wire [31:0] exe_result;	// the last reuslt to write back in EXE
	wire [31:0] lo_result;
	wire 		hi_write;
	wire 		lo_write;
	wire        ov_exc_final;
	// The value to write to HI is put into exe_result, including MULT and MTHI.
	// The value to write to LO is put into lo_result, including MULT and MTLO.
	assign exe_result = mthi 		? alu_operand1 :
						mtc0 		? alu_operand2 :
						muldiv[0]	? product[63:32] : 
						muldiv[1] 	? div_remainder : alu_result;
	assign lo_result = mtlo ? alu_operand1 : 
					   muldiv[0] ? product[31:0] : div_result;
	assign hi_write = muldiv[0] | muldiv[1] | mthi;
	assign lo_write = muldiv[0] | muldiv[1] | mtlo;
    assign ov_exc_final = ov_exc_en & ov_exc;
	assign EXE_MEM_bus = {mem_control,store_data,			// load/store message and store's data
						  data_related_en,                  
						  exe_result,						// exe calculation or mul's high-32bit or div's remainder
						  lo_result,						// mul's' low-32bit result or div's quotient
						  hi_write,lo_write,				// HI/LO write able
						  mfhi,mflo,						// signal that WB need
						  mtc0,mfc0,						// signal that WB need
						  cp0r_addr,syscall,eret,break,		// signal that WB need
						  addr_exc, ov_exc_final, ri_exc,	// signal that WB need
						  is_ds,halfword,rf_wen,rf_wdest,	// signal that WB need
						  pc};								// PC
	assign EXE_result_quick_get = exe_result;
	assign EXE_quick_en = data_related_en;
//----------{EXE->MEM bus}end

//----------{show PC of EXE module}begin
	assign EXE_pc = pc;
//----------{show PC of EXE module}end

// debug
//    assign debug_div_begin = div_begin;
//    assign debug_div_remainder = div_remainder;
//    assign debug_op1 = alu_operand1;
//    assign debug_op2 = alu_operand2;
endmodule















