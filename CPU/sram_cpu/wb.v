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
`define EXC_ENTER_ADDR 32'hBFC00380	// Exception entrance address
								    // Exception implemented here only contains SYSCALL
module wb(
	input wire     		WB_valid,
	input wire [160:0]	MEM_WB_bus_r,
	output wire [  3:0]	rf_wen,
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
	wire [1:0] halfword;
	wire [3:0] wen;
	wire [4:0] wdest;

	// message WB may use
	wire mfhi;
	wire mflo;
	wire mtc0;
	wire mfc0;
	wire [7:0] cp0r_addr;
	wire syscall;
	wire eret;
	wire break;
	wire [1:0] addr_exc;
	wire ov_exc;
	wire ri_exc;
	wire is_ds;
	wire [31:0] badvaddr;

	// pc
	wire [31:0] pc;
	assign {halfword,
	        wen,
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
			break,
			addr_exc,
			ov_exc,
			ri_exc,
			is_ds,
			badvaddr,
			pc} = MEM_WB_bus_r;
//---------{MEM->WB bus}end

//---------{HI/LO register}begin
	reg [31:0] hi;
	reg [31:0] lo;

	always @(posedge clk) 
	begin
	    if (!resetn)
	    begin
	       hi <= 32'd0;
	    end
		else if (hi_write && WB_valid) 
		begin
			hi <= mem_result;
		end
	end

	always @(posedge clk) 
	begin
	    if (!resetn)
	    begin
	       lo <= 32'd0;
	    end
		else if (lo_write && WB_valid) 
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
	wire [31:0] cp0r_badvaddr;
	wire [31:0] cp0r_count;
	wire [31:0] cp0r_compare;

	// write enable
	wire status_wen;
	wire epc_wen;
	wire cause_wen;
	wire count_wen;
	wire compare_wen;
	assign status_wen = mtc0 & (cp0r_addr=={5'd12,3'd0});
	assign epc_wen = mtc0 & (cp0r_addr=={5'd14,3'd0});
	assign cause_wen = mtc0 & (cp0r_addr=={5'd13,3'd0});
	assign count_wen = mtc0 & (cp0r_addr=={5'd9,3'd0});
	assign compare_wen = mtc0 & (cp0r_addr=={5'd11,3'd0});

	//cp0 register read
	wire [31:0] cp0r_rdata;
	assign cp0r_rdata = (cp0r_addr=={5'd8,3'd0}) ? cp0r_badvaddr :
	                    (cp0r_addr=={5'd9,3'd0}) ? cp0r_count :
	                    (cp0r_addr=={5'd11,3'd0}) ? cp0r_compare :
	                    (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
						(cp0r_addr=={5'd13,3'd0}) ? cp0r_cause :
						(cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;

	// STATUS register
	// implement STATUS[31:0], i.e. EXL area
	// EXL area is software w&r enable, so we need status_wen
	reg [31:0] status_r;
	assign cp0r_status = status_r;
	always @(posedge clk) 
	begin
		if (!resetn) 
		begin
			status_r[31:23] <= 9'd0;
			status_r[22] <= 1'b1;
			status_r[21:16] <= 6'd0;
			status_r[7:0] <= 8'd0;
		end
		else if (eret)
		begin
		    status_r[1] <= 1'b0;
		end
		else if ((cp0r_status[0] && ~cp0r_status[1] && 
                    ( (cp0r_cause[15] & cp0r_status[15])
                    | (cp0r_cause[14] & cp0r_status[14])
                    | (cp0r_cause[13] & cp0r_status[13])
                    | (cp0r_cause[12] & cp0r_status[12])
                    | (cp0r_cause[11] & cp0r_status[11])
                    | (cp0r_cause[10] & cp0r_status[10])
                    | (cp0r_cause[9] & cp0r_status[9])
                    | (cp0r_cause[8] & cp0r_status[8]))) | exc_happened) 
		begin
			status_r[1] <= 1'b1;
		end
		else if (status_wen && WB_valid)
		begin
			status_r <= {
							9'd0,
							1'd1,
							6'd0,
							mem_result[15:8],
							6'd0,
							mem_result[1:0]
						};
		end
	end

	// CAUSE register
	// only implement CAUSE[6:2], i.e. ExcCode area, store Exception Code
	// ExcCode Area is Software Read Only, write disenable, so don't need cause_wen
	reg [31:0] cause_r;
	assign cp0r_cause = cause_r;
	always @(posedge clk) 
	begin
		if (!resetn)
		begin
			cause_r[31:7] <= 25'd0;
			cause_r[1:0] <= 2'd0;
		end
		// IP7 <- TI
		cause_r[15] <= cause_r[30];
		if ((exc_happened | int_happened) & WB_over)
		begin
			cause_r[31] <= is_ds;
		end
		if (compare_wen && WB_valid)
		begin
		    cause_r[30] <= 1'b0;
		end 
		else if (count_r == compare_r)			// TI
		begin
			cause_r[30] <= 1'b1;
			cause_r[15] <= cause_r[30];
			cause_r[6:2] <= 5'h0;
		end
		if (syscall)						// Sys
		begin
			cause_r[6:2] <= 5'h8;
		end
		if (break)						// Bp
		begin
			cause_r[6:2] <= 5'h9;
		end
		if (addr_exc[1] == 1'b1) 	// AdEL
		begin
			cause_r[6:2] <= 5'h4;
		end
		if (addr_exc[1:0] == 2'b01) 	// AdEsS
		begin
			cause_r[6:2] <= 5'h5;
		end
		if (ri_exc)					// RI
		begin 				
			cause_r[6:2] <= 5'ha;
		end
		if (ov_exc)					// Ov
		begin 				
			cause_r[6:2] <= 5'hc;
		end
		if (cause_wen && WB_valid)
		begin
		    cause_r[9:8] <= mem_result[9:8];
		end
	end

	// EPC register
	// Store address that appear exception
	// EPC is readable, so we need epc_wen
	reg [31:0] epc_r;
	assign cp0r_epc = epc_r;
	always @(posedge clk)
	begin
		if (exc_valid && is_ds)
		begin
		   epc_r <= pc - 32'd4;
		end
		else if (exc_valid && ~is_ds)
		begin
			epc_r <= pc;
		end
		else if (epc_wen && WB_valid)
		begin
		   epc_r <= mem_result;
		end
	end

	// BadVAddr register
	//
	reg [31:0] badvaddr_r;
	assign cp0r_badvaddr = badvaddr_r;
	always @(posedge clk) 
	begin
		if ((addr_exc[1:0] == 2'b10) || (addr_exc[1:0] == 2'b01))
		begin
			badvaddr_r <= badvaddr;
		end
		else if (addr_exc[1:0] == 2'b11)
		begin
		    badvaddr_r <= pc;
		end
	end

	// COUNT register
	//
	reg [31:0] count_r;
	reg count0;
	assign cp0r_count = count_r;
	always @(posedge clk) 
	begin
	    if (!resetn)
	    begin
	       count0 <= 1'b0;
	    end
	    else if (count0)
	    begin
	       count0 <= 1'b0;
           count_r <= count_r + 1'b1;
	    end
	    else if (~count0)
	    begin
	       count0 <= 1'b1;
	    end
		if (count_wen && WB_valid)
		begin
			count_r <= mem_result;
		end
	end

	// COMPARE register
	//
	reg [31:0] compare_r;
	assign cp0r_compare = compare_r;
	always @(posedge clk) 
	begin
		if (compare_wen && WB_valid)
		begin
			compare_r <= mem_result;
		end
	end
   
   // exception and interruption send signal 'cancel'
   assign cancel = exc_valid;

   
   
//---------{cp0 register}end

//---------{WB finish}begin
	// all operations in WB module can be finish in one beat.
	// so WB_valid is WB_over.
	assign WB_over = WB_valid;
//---------{WB finish}end

//---------{WB -> regfile Signal}begin
	assign rf_wen = wen & {4{WB_over}} & {4{(~exc_happened)}};
	assign rf_wdest = wdest;
	assign rf_wdata = mfhi ? hi :
					  mflo ? lo :
					  mfc0 ? cp0r_rdata : 
					  halfword[1] ? {{16{mem_result[15]}},mem_result[15:0]} :
					  halfword[0] ? {16'd0,mem_result[15:0]} :  
					  mem_result;
//---------{WB -> regfile Signal}end

//---------{Exception pc Signal}begin
	wire 	    exc_happened;
	reg         int_happened;
	wire 		exc_valid;
	wire [31:0] exc_pc;
	assign exc_happened = syscall | break | (addr_exc[1:0]!=2'b00) | ov_exc | ri_exc;
	always @(posedge clk)
	begin
	    if (!resetn)
	    begin
	        int_happened <= 1'b0;
	    end
	    else if (cp0r_status[0] && ~cp0r_status[1] && 
	        ( (cp0r_cause[15] & cp0r_status[15])
            | (cp0r_cause[14] & cp0r_status[14])
            | (cp0r_cause[13] & cp0r_status[13])
            | (cp0r_cause[12] & cp0r_status[12])
            | (cp0r_cause[11] & cp0r_status[11])
            | (cp0r_cause[10] & cp0r_status[10])
            | (cp0r_cause[9] & cp0r_status[9])
            | (cp0r_cause[8] & cp0r_status[8])))
        begin
	        int_happened <= 1'b1;
	    end
	    else if (exc_valid)
	    begin
	        int_happened <= 1'b0;
	    end
	end

	assign exc_valid = ((exc_happened | eret | int_happened) & WB_valid);
	// the return address of eret is GRP[epc]
	// SYSCALL's and BREAK's excPC should be {EBASE[31:10],10'h180},
	assign exc_pc = (exc_happened | int_happened) ? `EXC_ENTER_ADDR : cp0r_epc;
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















