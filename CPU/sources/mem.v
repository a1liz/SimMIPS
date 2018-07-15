`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: mem
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
module mem(
	input wire 			clk,
	input wire 			MEM_valid,
	input wire 	[153:0]	EXE_MEM_bus_r,
	input wire 	[ 31:0] dm_rdata,
	output wire [ 31:0] dm_addr,
	output reg 	[  3:0] dm_wen,
	output reg 	[ 31:0] dm_wdata,
	output wire 		MEM_over,
	output wire	[117:0] MEM_WB_bus,

	// Five Levels Pipeline New Interface
	input wire 			MEM_allow_in,
	output wire [  4:0] MEM_wdest,

	// show PC
	output wire [ 31:0] MEM_pc
);

//----------{EXE->MEM bus}begin
	// load/store message that MEM may use
	wire [ 3:0] mem_control;
	wire [31:0] store_data;

	// EXE result and data of HI/LO
	wire [31:0] exe_result;
	wire [31:0] lo_result;
	wire 		hi_write;
	wire 		lo_write;

	// message that WB may use
	wire mfhi;
	wire mflo;
	wire mtc0;
	wire mfc0;
	wire [7:0] cp0r_addr;
	wire syscall;
	wire eret;
	wire rf_wen;
	wire [4:0] rf_wdest;

	//pc
	wire [31:0] pc;
	assign {mem_control,
			store_data,
			exe_result,
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
			rf_wen,
			rf_wdest,
			pc} = EXE_MEM_bus_r;
//----------{EXE->MEM bus}end

//----------{load/store memory access}begin
	wire inst_load;
	wire inst_store;
	wire ls_word;
	wire lb_sign;
	assign {inst_load, inst_store, ls_word, lb_sign} = mem_control;

	// Memory access w/r address
	assign dm_addr = exe_result;

	// write enable of store operation
	always @(*) 
	begin
		if (MEM_valid & inst_store) // MEM valid and store enable 
		begin 
			if (ls_word)
			begin
				dm_wen <= 4'b1111; // store word intruction, write enable is all-1
			end
			else 
			begin
				case (dm_addr[1:0])
					2'b00 	: dm_wen <= 4'b0001;
					2'b01 	: dm_wen <= 4'b0010;
					2'b10 	: dm_wen <= 4'b0100;
					2'b11 	: dm_wen <= 4'b1000;
					default : dm_wen <= 4'b0000;
				endcase
			end
		end
		else
		begin
			dm_wen <= 4'b0000;
		end
	end

	//  write data of store operation
	always @(*) 
	begin
		case (dm_addr[1:0])
			2'b00 	: dm_wdata <= store_data;
			2'b01 	: dm_wdata <= {16'b0, store_data[7:0], 8'd0};
			2'b10 	: dm_wdata <= {8'd0, store_data[7:0], 16'd0};
			2'b11 	: dm_wdata <= {store_data[7:0], 24'd0};
			default : dm_wdata <= store_data;
		endcase
	end

	// data reading by load
	wire 		load_sign;
	wire [31:0] load_result;
	assign load_sign = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7] :
					   (dm_addr[1:0]==2'd1) ? dm_rdata[15] :
					   (dm_addr[1:0]==2'd2) ? dm_rdata[23] : dm_rdata[31];
	assign load_result[7:0] = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7:0 ] :
							  (dm_addr[1:0]==2'd1) ? dm_rdata[15:8 ] :
							  (dm_addr[1:0]==2'd2) ? dm_rdata[23:16] : dm_rdata[31:24];
	assign load_result[31:8] = ls_word ? dm_rdata[31:8] : {24{lb_sign & load_sign}};
//----------{load/store memory access}end

//----------{MEM finish}begin
	// Cause of data in RAM is synchronize wirte and read,
	// for load instruction, when fetch data, there's one beat delay
	// means that the next beat after sending address can we get data loaded.
	// So that when MEM is executing load operation, sometimes it may cost 2 beats to get data
	// but for other operation, it only costs one beat.
	reg MEM_valid_r;
	always @(posedge clk) 
	begin
		if (MEM_allow_in) 
		begin
			MEM_valid_r <= 1'b0;
		end
		else
		begin
			MEM_valid_r <= MEM_valid;	
		end
	end
	assign MEM_over = inst_load ? MEM_valid_r : MEM_valid;
	// if data in RAM is asynchronize read, then MEM_valid is MEM_over.
	// means that it costs one beat to finish.
//----------{MEM finish}end

//----------{dest value of MEM module}begin
	// Only when MEM module is valid, 
	// the destination register number of write back is meaningful
	assign MEM_wdest = rf_wdest & {5{MEM_valid}};
//----------{dest value of MEM module}end

//----------{MEM->WB bus}begin
	wire [31:0] mem_result;	// MEM->WB result is load or EXE result
	assign mem_result = inst_load ? load_result : exe_result;
	assign MEM_WB_bus = {rf_wen,rf_wdest,
						 mem_result,
						 lo_result,
						 hi_write,lo_write,
						 mfhi,mflo,
						 mtc0,mfc0,cp0r_addr,syscall,eret,
						 pc};
//----------{MEM->WB bus}end

//----------{show PC of MEM module}begin
	assign MEM_pc = pc;
//----------{show PC of MEM module}end
endmodule






