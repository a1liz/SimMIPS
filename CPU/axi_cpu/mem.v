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
	input wire          resetn,
	input wire 			MEM_valid,
	input wire 	[166:0]	EXE_MEM_bus_r,
	input wire 	[ 31:0] dm_rdata,
	input wire          cancel,
	input wire          data_addr_ok,
	input wire          data_data_ok,
	output reg          data_req,
	output reg          data_wr,
	output reg          dm_en,
	output wire [ 31:0] dm_addr,
	output reg 	[  3:0] dm_wen,
	output reg 	[ 31:0] dm_wdata,
	// output wire dm_ce_n,       // chip enable,  low valid
	// output wire dm_oe_n,       // read enable,  low valid
	// output wire dm_we_n,       // write enable, low valid
	output wire 		MEM_over,
	output wire	[160:0] MEM_WB_bus,
	

	// Five Levels Pipeline New Interface
	input wire 			MEM_allow_in,
	output wire [  4:0] MEM_wdest,
    output wire [ 31:0] MEM_result_quick_get,
    output wire MEM_quick_en,

	// show PC
	output wire [ 31:0] MEM_pc
);

//----------{EXE->MEM bus}begin
	// load/store message that MEM may use
	wire [ 5:0] mem_control;
	wire [31:0] store_data;
	wire data_related_en;

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
	wire break;
	wire addr_exc;
	wire ov_exc;
	wire ri_exc;
	wire is_ds;
	wire [1:0] halfword;
	wire [3:0] rf_wen;
	wire [4:0] rf_wdest;

	//pc
	wire [31:0] pc;
	assign {mem_control,
			store_data,
			data_related_en,
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
			break,
			addr_exc,
			ov_exc,
			ri_exc,
			is_ds,
			halfword,
			rf_wen,
			rf_wdest,
			pc} = EXE_MEM_bus_r;
//----------{EXE->MEM bus}end

//----------{load/store memory access}begin
	wire inst_load;
	wire inst_store;
	wire ls_word;
	wire lb_sign;
	wire [1:0] ls_bit;
	assign {inst_load, inst_store, ls_word, lb_sign, ls_bit} = mem_control;

	// addr_exc use
	wire lw_addr_exc;
	wire lh_addr_exc;
	wire sw_addr_exc;
	wire sh_addr_exc;
	wire [31:0] badvaddr;
	assign lw_addr_exc = (inst_load && ls_word && (ls_bit == 2'b11) && (dm_addr[1:0] != 2'b00)) ? 1'b1 : 1'b0;
	assign lh_addr_exc = (inst_load && (halfword != 2'b00) && (dm_addr[0] != 1'b0)) ? 1'b1 : 1'b0;
	assign sw_addr_exc = (inst_store && ls_word && (ls_bit == 2'b11) && (dm_addr[1:0] != 2'b00)) ? 1'b1 : 1'b0;
 	assign sh_addr_exc = (inst_store && (halfword != 2'b00) && (dm_addr[0] != 1'b0)) ? 1'b1 : 1'b0;
    assign badvaddr = dm_addr;


	// Memory access w/r address
	assign dm_addr = exe_result;
    reg addr_sent;

    always @(posedge clk)
    begin
        if (!resetn || data_data_ok)
        begin
            addr_sent <= 1'b0;
        end
        else if (data_addr_ok)
        begin
            data_req <= 1'b0;
        end
        else if (MEM_valid & (inst_store | inst_load) & ~addr_sent & ~cancel)
        begin
            data_req <= 1'b1;
            addr_sent <= 1'b1;
            data_wr <= inst_store;
        end
    end
    
	// write enable of store operation
	always @(*) 
	begin
		if (MEM_valid & inst_store) // MEM valid and store enable 
		begin 
			dm_en <= 1'b1 & (final_addr_exc == 2'd0);
			if (ls_word & (ls_bit == 2'b11))
			begin
				dm_wen <= 4'b1111; // store word intruction, write enable is all-1
			end
			else if (halfword[1])
			begin
			     dm_wen <= dm_addr[1] ? 4'b1100 : 4'b0011;
			end
			else if (ls_bit[0]) // SWR
			begin
			    case (dm_addr[1:0])
                    2'b00     : dm_wen <= 4'b1111;
                    2'b01     : dm_wen <= 4'b1110;
                    2'b10     : dm_wen <= 4'b1100;
                    2'b11     : dm_wen <= 4'b1000;
                    default   : dm_wen <= 4'b0000;
                endcase
			end
			else if (ls_bit[1]) // SWL
            begin
                case (dm_addr[1:0])
                    2'b00     : dm_wen <= 4'b0001;
                    2'b01     : dm_wen <= 4'b0011;
                    2'b10     : dm_wen <= 4'b0111;
                    2'b11     : dm_wen <= 4'b1111;
                    default   : dm_wen <= 4'b0000;
                endcase
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
		else if (MEM_valid & inst_load)
		begin
		  dm_en <= 1'b1;
		  dm_wen <= 4'b0000;
		end
		else
		begin
			dm_en <= 1'b0;
            dm_wen <= 4'b0000;
		end
	end

	//  write data of store operation
	always @(*) 
	begin
	    if (halfword[1]) 
	    begin
	       if (dm_addr[1])
	       begin
	           dm_wdata <= {store_data[15:0], 16'd0};
	       end
	       else
	       begin
	           dm_wdata <= {16'd0, store_data[15:0]};
	       end
	    end
	    else if (ls_bit[0]) // SWR
	    begin
	       case (dm_addr[1:0])
                2'b00     : dm_wdata <= store_data;
                2'b01     : dm_wdata <= {store_data[23:0], dm_rdata[ 7:0]};
                2'b10     : dm_wdata <= {store_data[15:0], dm_rdata[15:0]};
                2'b11     : dm_wdata <= {store_data[ 7:0], dm_rdata[23:0]};
                default   : dm_wdata <= store_data;
            endcase
	    end
	    else if (ls_bit[1]) // SWL
	    begin
	       case (dm_addr[1:0])
                2'b00     : dm_wdata <= {dm_rdata[31:8 ], store_data[31:24]};
                2'b01     : dm_wdata <= {dm_rdata[31:16], store_data[31:16]};
                2'b10     : dm_wdata <= {dm_rdata[31:24], store_data[31:8]};
                2'b11     : dm_wdata <= store_data;
                default   : dm_wdata <= store_data;
            endcase
	    end
	    else
	    begin
            case (dm_addr[1:0])
                2'b00 	: dm_wdata <= store_data;
                2'b01 	: dm_wdata <= {16'd0, store_data[7:0], 8'd0};
                2'b10 	: dm_wdata <= {8'd0, store_data[7:0], 16'd0};
                2'b11 	: dm_wdata <= {store_data[7:0], 24'd0};
                default : dm_wdata <= store_data;
            endcase
        end
	end

	// data reading by load
	wire 		load_sign;
	wire [31:0] load_result;
	wire [7:0] half_result;
	wire [31:0] load_final_result;
	reg [31:0] lwl_lwr_result;
	assign load_sign = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7] :
					   (dm_addr[1:0]==2'd1) ? dm_rdata[15] :
					   (dm_addr[1:0]==2'd2) ? dm_rdata[23] : dm_rdata[31];
	assign load_result[7:0] = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7:0 ] :
							  (dm_addr[1:0]==2'd1) ? dm_rdata[15:8 ] :
							  (dm_addr[1:0]==2'd2) ? dm_rdata[23:16] : dm_rdata[31:24];
    assign half_result = (dm_addr[1]==2'd0) ? dm_rdata[15:8 ] : dm_rdata[31:24]; 
	assign load_result[31:8] = ls_word ? dm_rdata[31:8] : halfword[1] ? {{16{dm_rdata[15]}},half_result} : halfword[0] ? {16'd0,half_result} : {24{lb_sign & load_sign}};
	assign load_final_result = (ls_bit==2'b11 | ls_bit==2'b00) ? load_result : lwl_lwr_result;
	
	
	always @(*) 
        begin
            if (ls_bit[0])  // LWR
            begin
                case (dm_addr[1:0])
                    2'b00     : lwl_lwr_result <= dm_rdata;
                    2'b01     : lwl_lwr_result <= {store_data[31:24],dm_rdata[31:8 ]};
                    2'b10     : lwl_lwr_result <= {store_data[31:16],dm_rdata[31:16]};
                    2'b11     : lwl_lwr_result <= {store_data[31:8 ],dm_rdata[31:24]};
                    default   : lwl_lwr_result <= dm_rdata;
                endcase
            end
            else if (ls_bit[1]) // LWL
            begin
                case (dm_addr[1:0])
                    2'b00     : lwl_lwr_result <= {dm_rdata[ 7:0],store_data[23:0]};
                    2'b01     : lwl_lwr_result <= {dm_rdata[15:0],store_data[15:0]};
                    2'b10     : lwl_lwr_result <= {dm_rdata[23:0],store_data[ 7:0]};
                    2'b11     : lwl_lwr_result <= dm_rdata;
                    default   : lwl_lwr_result <= dm_rdata;
                endcase
            end
        end
//----------{load/store memory access}end

//----------{CE signal}begin
    // assign dm_ce_n = ~MEM_valid | MEM_over; // when MEM is valid and not over, dm_ce_n is 0.
    // assign dm_oe_n = ~inst_load;
    // assign dm_we_n = ~inst_store;
//----------{CE signal}end

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
	assign MEM_over = (inst_load|inst_store) ? (data_data_ok & MEM_valid) : MEM_valid;
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
	wire [1:0] final_addr_exc;
	assign final_addr_exc = addr_exc ? 2'b11 : (lw_addr_exc|lh_addr_exc) ? 2'b10 : (sw_addr_exc|sh_addr_exc) ? 2'b01 : 2'b00;
	assign mem_result = inst_load ? load_final_result : exe_result;
	assign MEM_WB_bus = {halfword,rf_wen,rf_wdest,
						 mem_result,
						 lo_result,
						 hi_write,lo_write,
						 mfhi,mflo,
						 mtc0,mfc0,cp0r_addr,syscall,eret,break,final_addr_exc,ov_exc,ri_exc,is_ds,
						 badvaddr,
						 pc};
	assign MEM_result_quick_get = mem_result;
	assign MEM_quick_en = data_related_en & ~mfhi & ~mflo;
//----------{MEM->WB bus}end

//----------{show PC of MEM module}begin
	assign MEM_pc = pc;
//----------{show PC of MEM module}end
endmodule






