`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: decode
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

module decode(
	input wire		ID_valid,
	input wire [63:0]	IF_ID_bus_r,	// If->ID bus
	input wire [31:0]	rs_value,
	input wire [31:0]	rt_value,
	output wire [ 4:0]	rs,
	output wire [ 4:0]	rt,
	output wire [32:0]	jbr_bus,		// jump bus
	// output			inst_jbr,	// if instruciton is jump branch instruciton, Five Levels Pipeline doesn't use 
	output wire 		ID_over,		// ID module finish
	output wire [167:0]	ID_EXE_bus,		// ID->EXE bus

	// Five Levels Pipeline New Interface
	input wire 		IF_over,		// branch instruciton need this signal
	input wire [ 4:0]	EXE_wdest,		// destination address that EXE will write back to regfile 
	input wire [ 4:0]	MEM_wdest,		// destination address that MEM will write back to regfile 
	input wire [ 4:0]	WB_wdest,		// destination address that WB will write back to regfile 

	// show PC
	output wire [31:0]	ID_pc
);

//----------{IF->ID bus}begin
	wire [31:0] pc;
	wire [31:0] inst;
	assign {pc, inst} = IF_ID_bus_r;	// IF->ID bus sends to pc and instruction
//----------{IF->ID bus}end

//----------{instruction decode} begin
    wire [5:0] op;
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire [4:0] sa;
    wire [5:0] funct;
    wire [15:0] imm;
    wire [15:0] offset;
    wire [25:0] target;
    wire [2:0] cp0r_sel;
    
    assign op       = inst[31:26];  // Operator Code
    assign rs       = inst[25:21];  // Source Operand 1
    assign rt       = inst[20:16];  // Source Operand 2
    assign rd       = inst[15:11];  // Target Operand
    assign sa       = inst[10:6];   // Special Area, might be used to storing offset
    assign funct    = inst[5:0];    // function code
    assign imm      = inst[15:0];   // immediate data
    assign offset   = inst[15:0];   // address offset
    assign target   = inst[25:0];   // target address
    assign cp0r_sel = inst[2:0];	// select area of cp0 register

    // Instruction list to be implemented
    
    // Loongson require lists of instructions:

    wire inst_ADD,	  inst_ADDI,	inst_ADDU,		inst_ADDIU;
    wire inst_SUB,     inst_SUBU,  	inst_SLT,   	inst_SLTI;
    wire inst_SLTU,    inst_SLTIU,  	inst_DIV,    	inst_DIVU;
    wire inst_MULT,    inst_MULTU,  	inst_AND,    	inst_ANDI;
    wire inst_LUI,     inst_NOR,    	inst_OR,     	inst_ORI;
    wire inst_XOR,     inst_XORI,   	inst_SLL,    	inst_SLLV,   inst_SRA;
    wire inst_SRAV,    inst_SRL,    	inst_SRLV,   	inst_BEQ;
    wire inst_BNE,     inst_BGEZ,   	inst_BGTZ,   	inst_BLEZ;
    wire inst_BLTZ,    inst_BLTZAL, 	inst_BGEZAL,	inst_J;
    wire inst_JAL,     inst_JR,     	inst_JALR, 		inst_MFHI;
    wire inst_MFLO,    inst_MTHI,   	inst_MTLO, 		inst_BREAK;
    wire inst_SYSCALL, inst_LB,     	inst_LBU,    	inst_LH;
    wire inst_LHU,     inst_LW,     	inst_SB,     	inst_SH;
    wire inst_SW,      inst_ERET,   	inst_MFC0,   	inst_MTC0;

    wire op_zero;   // Operator Code is all-zero
    wire rs_zero;   // Source Operand 1 is all-zero
    wire rt_zero;   // Source Operand 2 is all-zero
    wire rd_zero;   // Target Operand is all-zero
    wire sa_zero;   // Special Area is all-zero

    assign op_zero = ~(|op);
    assign rs_zero = ~(|rs);
    assign rt_zero = ~(|rt);
    assign rd_zero = ~(|rd);
    assign sa_zero = ~(|sa);
    
    assign inst_ADD = op_zero & sa_zero & (funct == 6'b100000);     // Add Word
    assign inst_ADDI = (op == 6'b001000);                           // Add Immediate Word
    assign inst_ADDU = op_zero & sa_zero & (funct == 6'b100001);	// Add Unsigned Word
    assign inst_ADDIU = (op == 6'b001001);                          // Add Immediate Unsigned Word
    assign inst_SUB = op_zero & sa_zero & (funct == 6'b100010);     // Subtract Word
    assign inst_SUBU = op_zero & sa_zero & (funct == 6'b100011);    // Subtract Unsigned Word
    assign inst_SLT = op_zero & sa_zero & (funct == 6'b101010);     // Set on Less Than
    assign inst_SLTI = (op == 6'b001010);                           // Set on Less Than Immediate
    assign inst_SLTU = op_zero & sa_zero & (funct == 6'b101011);    // Set on Less Than Unsigned
    assign inst_SLTIU = (op == 6'b001011);                          // Set on Less Than Immediate Unsigned
    assign inst_DIV = op_zero & rd_zero & sa_zero & (funct == 6'b011010);   // Divide Word
    assign inst_DIVU = op_zero & rd_zero & sa_zero & (funct == 6'b011011);  // Divide Unsigned Word
    assign inst_MULT = op_zero & rd_zero & sa_zero & (funct == 6'b011000);  // Multiply Word
    assign inst_MULTU = op_zero & rd_zero & sa_zero & (funct == 6'b011001); // Multiply Unsigned Word
    assign inst_AND = op_zero & sa_zero & (funct == 6'b100100);     // And
    assign inst_ANDI = (op == 6'b001100);                           // And Immediate
    assign inst_LUI = (op == 6'b001111) & rs_zero;                  // Load Upper Immediate
    assign inst_NOR = op_zero & sa_zero & (funct == 6'b100111);     // Not Or
    assign inst_OR = op_zero & sa_zero & (funct == 6'b100101);      // Or
    assign inst_ORI = (op == 6'b001101);                            // Or Immediate
    assign inst_XOR = op_zero & sa_zero & (funct == 6'b100110);     // Exclusive OR
    assign inst_XORI = (op == 6'b001110);                           // Exclusive OR Immediate
    assign inst_SLL = op_zero & rs_zero & (funct == 6'b000000);     // Shift Word Left Logical
    assign inst_SLLV = op_zero & sa_zero & (funct == 6'b000100);    // Shift Word Left Logical Variable
    assign inst_SRA = op_zero & rs_zero & (funct == 6'b000011);     // Shift Word Right Arithmetic
    assign inst_SRAV = op_zero & sa_zero & (funct == 6'b0000111);   // Shift Word Right Arithmetic Variable
    // Question 
    assign inst_SRL = op_zero & rs_zero & (funct == 6'b000010);     // Shift Word Right Logical
    assign inst_SRLV = op_zero & sa_zero & (funct == 6'b000110);    // Shift Word Right Logical Variable
    assign inst_BEQ = (op == 6'b000100);                            // Branch on Equal
    assign inst_BNE = (op == 6'b000101);                            // Branch on Not Equal
    assign inst_BGEZ = (op == 6'b000001) & (rt == 5'b00001);        // Branch on Greater Than or Equal to Zero
    assign inst_BGTZ = (op == 6'b000111) & rt_zero;                 // Branch on Greater Than Zero
    assign inst_BLEZ = (op == 6'b000110) & rt_zero;                 // Branch on Less Than or Equal to Zero
    assign inst_BLTZ = (op == 6'b000001) & rt_zero;                 // Branch on Less Than Zero
    assign inst_BLTZAL = (op == 6'b000001) & (rt == 5'b10000);      // Branch on Less Than Zero and Link
    assign inst_BGEZAL = (op == 6'b000001) & (rt == 5'b10001);      // Branch on Greater Than or Equal to Zero and Link
    assign inst_J = (op == 6'b000010);                              // Jump
    assign inst_JAL = (op == 6'b000011);                            // Jump and Link
    assign inst_JR = op_zero & rt_zero & rd_zero & (funct == 6'b001000);    // Jump Register
    assign inst_JALR = op_zero & rt_zero & (funct == 6'b001001);    // Jump and Link Register
    assign inst_MFHI = op_zero & rs_zero & rt_zero & sa_zero & (funct == 6'b010000);    // Move From HI Register
    assign inst_MFLO = op_zero & rs_zero & rt_zero & sa_zero & (funct == 6'b010010);    // Move From LO Register
    assign inst_MTHI = op_zero & rt_zero & rd_zero & sa_zero & (funct == 6'b010001);    // Move to HI Register
    assign inst_MTLO = op_zero & rt_zero & rd_zero & sa_zero & (funct == 6'b010011);    // Move to LO Register
    assign inst_BREAK = op_zero & (funct == 6'b001101);             // Breakpoint
    assign inst_SYSCALL = op_zero & (funct == 6'b001100);           // System Call
    assign inst_LB = (op == 6'b100000);                             // Load Byte
    assign inst_LBU = (op == 6'b100100);                            // Load Byte Unsigned
    assign inst_LH = (op == 6'b100001);                             // Load Halfword
    assign inst_LHU = (op == 6'b100101);                            // Load Halfword Unsigned
    assign inst_LW = (op == 6'b100011);                             // Load Word
    assign inst_SB = (op == 6'b101000);                             // Store Byte
    assign inst_SH = (op == 6'b101001);                             // Store Halfword
    assign inst_SW = (op == 6'b101011);                             // Store Word
    assign inst_ERET = (op == 6'b010000) & (rs == 5'b10000) & rt_zero & rd_zero & sa_zero & (funct == 6'b011000);   // Exception Return
    assign inst_MFC0 = (op == 6'b010000) & rs_zero & (inst[10:3] == 8'd0);   		// Move from Coprocessor 0
    assign inst_MTC0 = (op == 6'b010000) & (rs == 5'b00100) & (inst[10:3] == 8'd0);	// Move to Coprocessor 0

    // Jump Branch Instruction
    wire inst_jr;		// register jump instruction
    wire inst_j_link;	// link jump instruction
    wire inst_jbr;		// all branch jump instruction
    assign inst_jr = inst_JALR | inst_JR;
    assign inst_j_link = inst_JAL | inst_JALR | inst_BLTZAL | inst_BGEZAL;
    assign inst_jbr = inst_J 		| inst_JAL 		| inst_jr
    				| inst_BEQ		| inst_BNE		| inst_BGEZ
    				| inst_BGTZ 	| inst_BLEZ		| inst_BLTZ
    				| inst_BLTZAL 	| inst_BGEZAL;

    // load store
    wire inst_load;
    wire inst_store;
    assign inst_load = inst_LB | inst_LBU | inst_LH | inst_LHU | inst_LW;	// load instruction
    assign inst_store = inst_SB | inst_SH | inst_SW;						// store instruction
    
   	
    
    // classify by alu operation
    wire inst_add, inst_sub, inst_slt, inst_sltu;
    wire inst_div, inst_mul, inst_and, inst_lui;
    wire inst_nor, inst_or, inst_xor;
    wire inst_sll, inst_srl, inst_sra;
    
    assign inst_add = inst_ADD | inst_ADDI | inst_ADDU | inst_ADDIU | inst_LW | inst_SW | inst_j_link;
    assign inst_sub = inst_SUB | inst_SUBU;
    assign inst_slt = inst_SLT | inst_SLTI;
    assign inst_sltu =  inst_SLTU | inst_SLTIU;
    assign inst_div = inst_DIV | inst_DIVU;
    assign inst_mul = inst_MULT | inst_MULTU;
    assign inst_and = inst_AND | inst_ANDI;
    assign inst_lui = inst_LUI;
    assign inst_nor = inst_NOR;
    assign inst_or = inst_OR | inst_ORI;
    assign inst_xor = inst_XOR | inst_XORI;
    assign inst_sll = inst_SLL | inst_SLLV;
    assign inst_srl = inst_SRL | inst_SRLV;
    assign inst_sra = inst_SRA | inst_SRAV;

    // shift instruction that use sa area as offset 
    wire inst_shf_sa;
    assign inst_shf_sa = inst_SLL & inst_SLLV & inst_SRA & inst_SRAV & inst_SRL & inst_SRLV;

    // classify by immediate extend method
    wire  inst_imm_zero;	// immediate zero_extend
    wire inst_imm_sign;		// immediate symbol_extend
    assign inst_imm_zero = inst_ANDI | inst_LUI | inst_ORI | inst_XORI;
	assign inst_imm_sign = inst_ADDI | inst_ADDIU | inst_SLTI | inst_SLTIU | inst_load | inst_store;

	// classify by destination register number
	wire inst_wdest_rt;	// instruction that write_address of regfile is rt
	wire inst_wdest_31;	// instruction that write_address of regfile is 31
	wire inst_wdest_rd;	// instruction that write_address of regfile is rd
	assign inst_wdest_rt = inst_imm_zero | inst_ADDI | inst_ADDIU | inst_SLTI
						 | inst_SLTIU | inst_load | inst_MFC0;
	assign inst_wdest_31 = inst_JAL  | inst_BLTZAL | inst_BGEZAL;
	assign inst_wdest_rd = inst_ADD  | inst_ADDU   | inst_SUB | inst_SUBU
                         | inst_SLT  | inst_SLTU   | inst_AND | inst_NOR
						 | inst_OR   | inst_XOR    | inst_SLL | inst_SLLV 
						 | inst_SRA	 | inst_SRAV   | inst_SRL | inst_SRLV 
						 | inst_JALR | inst_MFHI   | inst_MFLO;

	// classify by source register number
	wire inst_no_rs;	// rs is not-zero and do not read rs from regfile
	wire inst_no_rt;	// rt is not-zero and do not read rt from regfile
	assign inst_no_rs = inst_MTC0 | inst_BREAK | inst_SYSCALL | inst_ERET;
	assign inst_no_rt = inst_wdest_rt | inst_BGEZ | inst_BLTZAL | inst_BGEZAL
					  | inst_J | inst_JAL;
//-----------{instruction decode}end

//-----------{Branch Instruction Execute}begin
	// bd_pc,branch jump instruction 
	wire [31:0] bd_pc;
	assign bd_pc = pc + 3'b100;

	// JMP
	wire 		j_taken;
	wire [31:0] j_target;
	assign  j_taken = inst_J | inst_JAL | inst_jr;
	// register jump address is rs_value, other is {bd_pc[31:28], target, 2'b00};
	assign j_target = inst_jr ? rs_value : {bd_pc[31:28],target,2'b00};

	// branch instruction
	wire rs_equal_rt;
	wire rs_ez;
	wire rs_ltz;
	assign rs_equal_rt = (rs_value == rt_value);	// GPR[rs] == GPR[rt]
	assign rs_ez = ~(|rs_value);					// GPR[rs] == 0
	assign rs_ltz = rs_value[31];					// GPR[rs] < 0
	wire br_taken;
	wire [31:0] br_target;
	assign br_taken = inst_BEQ & rs_equal_rt
					| inst_BNE & ~rs_equal_rt
					| inst_BGEZ & ~rs_ltz
                    | inst_BGEZAL & ~rs_ltz
					| inst_BGTZ & ~rs_ltz & ~rs_ez
					| inst_BLEZ & (rs_ltz | rs_ez)
					| inst_BLTZ & rs_ltz
					| inst_BLTZAL & rs_ltz;
	// Branch jump target address: PC = PC + offset << 2
	assign br_target[31:2] = bd_pc[31:2] + {{14{offset[15]}}, offset};
	assign br_target[1:0] = bd_pc[1:0];

	// jump and branch instruction
	wire jbr_taken;
	wire [31:0] jbr_target;
	assign jbr_taken = (j_taken | br_taken) & ID_over;
	assign jbr_target = j_taken ? j_target : br_target;

	// ID->IF jump bus
	assign jbr_bus = {jbr_taken, jbr_target};
//-----------{Branch Instruction Execute}end

//-----------{ID finish}begin
	// Due to pipeline, there's data correlation
	wire rs_wait;
	wire rt_wait;
	assign rs_wait = ~inst_no_rs & (rs!=5'd0) & ((rs==EXE_wdest) | (rs==MEM_wdest) | (rs==WB_wdest));
	assign rt_wait = ~inst_no_rt & (rt!=5'd0) & ((rt==EXE_wdest) | (rt==MEM_wdest) | (rt==WB_wdest));

	// As for branch jump instruction, only after IF executing finish, ID should be finish.
	// Otherwise, ID has been finish and IF is still fetching, next_pc can not be latched to PC,
	// and when IF is finish, next_pc can be latched to PC, the data in jbr_bus is invalid.
	// Leading to branch jumping failure.
	// (~inst_jbr | IF_over) is (~inst_jbr | (inst_jbr & IF_over))
	assign ID_over = ID_valid & ~rs_wait & ~rt_wait & (~inst_jbr | IF_over);
//-----------{ID finish}end

//-----------{ID->EXE bus}begin
	// EXE needs
	wire [1:0] muldiv;
	wire mthi;
	wire mtlo;
    assign muldiv = inst_mul ? 2'b01 : inst_div ? 2'b10 : 2'b00;
	assign mthi = inst_MTHI;
	assign mtlo = inst_MTLO;
	// ALU's 2 operand and control signal
	wire [11:0] alu_control;
	wire [31:0] alu_operand1;
	wire [31:0] alu_operand2;

	// Link jump is just storing PC from jump to GPR[31]
	// In pipeline CPU, we'd better think about delay slot, so link jump should calculate PC + 8, and store it to GPR[31]
	assign alu_operand1 = inst_j_link ? pc : inst_shf_sa ? {27'd0,sa} : rs_value;
	assign alu_operand2 = inst_j_link ? 32'd8 : inst_imm_zero ? {16'd0, imm} : inst_imm_sign ? {{16{imm[15]}},imm} : rt_value;
	assign alu_control = {inst_add,		// ALU operator code, one-hot coding
						  inst_sub, 
						  inst_slt, 
						  inst_sltu,  
						  inst_and, 
						  inst_nor, 
						  inst_or, 
						  inst_xor, 
						  inst_sll, 
						  inst_srl, 
						  inst_sra, 
						  inst_lui};
	// load/store message that MEM may use.
	wire lb_sign;	// load byte is signed-load
	wire ls_word;	// load/store is Byte or Word, 0:byte;1:word
	wire [3:0] mem_control;	// control signal that MEM need
	wire [31:0] store_data;
	assign lb_sign = inst_LB;
	assign ls_word = inst_LW | inst_SW;
	assign mem_control = {inst_load,
						  inst_store,
						  ls_word,
						  lb_sign};

	// message that WB may need
	wire mfhi;
	wire mflo;
	wire mtc0;
	wire mfc0;
	wire [7:0] cp0r_addr;
	wire syscall;	// there's special operation in WB for syscall and eret 
	wire eret;
	wire rf_wen;			// WB's register write enable
	wire [4:0] rf_wdest;	// WB's destination register 
	assign syscall = inst_SYSCALL;
	assign eret = inst_ERET;
	assign mfhi = inst_MFHI;
	assign mflo = inst_MFLO;
	assign mtc0 = inst_MTC0;
	assign mfc0 = inst_MFC0;
	assign cp0r_addr = {rd,cp0r_sel};
	assign rf_wen = inst_wdest_rt | inst_wdest_31 | inst_wdest_rd;
	assign rf_wdest = inst_wdest_rt ? rt : 			// not use regfile then set to 0
					  inst_wdest_31 ? 5'd31 :		// so that judge clearly whether data correlate or not.
					  inst_wdest_rd ? rd : 5'd0;
	assign store_data = rt_value;
	assign ID_EXE_bus = {muldiv, mthi, mtlo,						// EXE need
						 alu_control, alu_operand1, alu_operand2,	// EXE need
						 mem_control, store_data,					// MEM need
						 mfhi, mflo,								// WB need
						 mtc0, mfc0, cp0r_addr, syscall, eret,		// WB need
						 rf_wen, rf_wdest,							// WB need
						 pc};										// PC value
//-----------{ID->EXE bus}end

//-----------{show pc of ID module}begin
	assign  ID_pc = pc;
//-----------{show pc of ID module}end
endmodule











