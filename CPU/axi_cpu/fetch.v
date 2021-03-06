`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: fetch
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

`define STARTADDR 32'HBFC00000		// Start Address of Program
module fetch(
	input wire			clk,		// clock	
	input wire			resetn,		// reset signal , low level valid
	input wire			IF_valid,	// IF valid signal
	input wire          next_fetch,
	input wire          inst_addr_ok,
	input wire          inst_data_ok,
	input wire 	[31:0]	inst,		// instruction from inst_rom
	input wire	[32:0]	jbr_bus,	// jump bus
	output wire 		inst_req,	// inst_sram-like request
	output wire	[31:0]	inst_addr,	// fetch_address sent to inst_ram
	output wire			IF_over,	// IF module is finish
	output wire	[65:0]	IF_ID_bus,	// IF -> ID bus

	// Five Levels Pipeline New Interface
	input wire	[32:0]	exc_bus,	// Exception pc bus
	input wire          is_ds,		// Current instruction is delay slot or not
	input wire  [31:0]  ID_pc,     


	// Show PC and instruction fetched
	output wire	[31:0] 	IF_pc,
	output wire	[31:0]	IF_inst
);

// -----------{PC}begin
	wire [31:0] next_pc;
	wire [31:0] seq_pc;
	reg  [31:0] pc;

	// jump pc
	wire		jbr_taken;
	wire [31:0] jbr_target;
	assign {jbr_taken, jbr_target} = jbr_bus;	// jump bus => whether jump and target address

	// Exception PC
	wire		exc_valid;
	wire [31:0] exc_pc;
	reg         has_exc;
	assign {exc_valid, exc_pc} = exc_bus;

	// PC+4
	assign seq_pc[31:2] = pc[31:2] + 1'b1;
	assign seq_pc[1:0] = pc[1:0];

	// New Instruction: if exception appears, PC becomes entrance address of Exception
	// 					else if instruction jump, PC becomes jump address.
	//					else pc + 4.
	assign next_pc = exc_valid ? exc_pc : jbr_taken ? jbr_target : seq_pc;
    assign inst_req = IF_valid;

	always @(posedge clk)
	begin
		if (!resetn)
		begin
			// reset
			pc <= `STARTADDR;
			has_exc <= 1'b0;	
		end
		else if (next_fetch)
		begin
			pc <= next_pc;
			if (exc_valid)
			begin
			    has_exc <= 1'b1;
			end
		end
		else if (inst_data_ok)
		begin
		    has_exc <= 1'b0;
		end
	end
// -----------{PC}end

// -----------{Instruction Sent to inst_rom}begin

	assign inst_addr = inst_addr_ok ? pc : 32'hxxxxxxxx;
// -----------{Instruction Sent to inst_rom}end

// -----------{IF finish}begin
	// due to inst_rom is synchronous r&w,
	// when fetch data, there's a beat delayed
	// it means we can only fetch the instruction in next beat after send address
	// Therefore, the fetch module need two beats.
	// Also when PC refresh, IF_over should be reset to 0
	// then latch IF_valid and that's IF_over signal
	assign IF_over = ~resetn ? 1'b0 : inst_data_ok & ~has_exc & IF_valid;
	
	// If inst_rom is asynchronous read, IF_valid is IF_over signal.
	// What's means IF can finish in one beat.  
// -----------{IF finish}end

// -----------{IF->ID bus}begin
	wire addr_exc;
	assign addr_exc = (pc[1:0]!=2'b00) ? 1'b1 : 1'b0;
	assign IF_ID_bus = {pc, inst, addr_exc, is_ds & (pc==(ID_pc + 32'd4))};	// if IF is valid, latch PC and instruction
// -----------{IF->ID bus}end

// -----------{show PC and instruction of IF module}begin
	assign IF_pc = pc;
	assign IF_inst = inst;
// -----------{show PC and instruction of IF module}end
endmodule












