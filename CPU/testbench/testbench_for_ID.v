`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2018 07:16:09 AM
// Design Name: 
// Module Name: testbench_for_ID
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


module testbench_for_ID();
    // Input
    reg ID_valid;
    reg [63:0] IF_ID_bus_r;
    reg [31:0] rs_value;
    reg [31:0] rt_value;
    reg IF_over;
    reg EXE_wdest;
    reg MEM_wdest;
    reg WB_wdest;
    
    // Output
    wire [4:0] rs;
    wire [4:0] rt;
    wire [32:0] jbr_bus;
//    wire inst_jbr;
    wire ID_over;
    wire [167:0] ID_EXE_bus;
    wire [31:0] ID_pc;
    
    // Debug
    reg [31:0] pc;
    reg [31:0] inst;
    
    // EXE needs
    wire [1:0] muldiv;
    wire mthi;
    wire mtlo;
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    // load/store message that MEM may use
    wire [3:0] mem_control;
    wire [31:0] store_data;

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
    wire [31:0] new_pc;
    
    wire [11:0] debug_alu_control;

    decode decode_module(
        .ID_valid(ID_valid),
        .IF_ID_bus_r(IF_ID_bus_r),
        .rs_value(rs_value),
        .rt_value(rt_value),
        .rs(rs),
        .rt(rt),
        .jbr_bus(jbr_bus),
        // .inst_jbr(inst_jbr),
        .ID_over(ID_over),
        .ID_EXE_bus(ID_EXE_bus),
        .IF_over(IF_over),
        .EXE_wdest(EXE_wdest),
        .MEM_wdest(MEM_wdest),
        .WB_wdest(WB_wdest),
        .ID_pc(ID_pc),
        .debug_alu_control(debug_alu_control)
    );
    
    initial begin
       ID_valid = 1;
       pc = 32'H00000034;
       inst = {6'd0,5'b10101,5'b01010,5'b00010,5'd0,6'b100000};
       IF_ID_bus_r = {pc,inst};
       rs_value = 32'd16;
       rt_value = 32'd32;
       IF_over = 1;
       EXE_wdest = 5'd0;
       MEM_wdest = 5'd0;
       WB_wdest = 5'd0;      
    end
    assign {muldiv,
            mthi,
            mtlo,
            alu_control,
            alu_operand1,
            alu_operand2,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            rf_wen,
            rf_wdest,
            new_pc} = ID_EXE_bus;
endmodule
