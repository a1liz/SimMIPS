`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2018 11:07:10 AM
// Design Name: 
// Module Name: testbench_for_EXE
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


module testbench_for_EXE();
    // Input
    reg EXE_valid;
    reg [167:0] ID_EXE_bus_r;
    reg clk;
    
    // Output
    wire EXE_over;
    wire [153:0] EXE_MEM_bus;
    wire [4:0] EXE_wdest;
    wire [31:0] EXE_pc;
    
    // debug
    wire [3:0] mem_control;
    wire [31:0] store_data;
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire hi_write;
    wire lo_write;
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
    reg [153:0] EXE_MEM_bus_r;
    
    exe exe_module(
        .EXE_valid(EXE_valid),
        .ID_EXE_bus_r(ID_EXE_bus_r),
        .EXE_over(EXE_over),
        .EXE_MEM_bus(EXE_MEM_bus),
        .clk(clk),
        .EXE_wdest(EXE_wdest),
        .EXE_pc(EXE_pc)
    );
    
    initial begin
       clk = 1;
       EXE_valid = 0;
       ID_EXE_bus_r = {2'b01,   // muldiv
                       1'b0,    // mthi
                       1'b0,    // mtlo
                       12'd0,   // alu_control
                       32'd290,   // alu_operand1
                       32'd21,   // alu_operand2
                       4'd0,    // mem_control
                       32'd0,   // store_data
                       4'd0,    // mfhi + mflo + mtc0 + mfc0
                       8'd0,    // cp0r_addr[7:0]
                       8'd0,    // syscall + eret + rf_wen + rf_wdest[4:0]
                       32'd0    // pc    
                       };
       #100 EXE_valid = 1;
    end
    
    always @(posedge clk)
    begin
        if (EXE_over)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end
    
    always #10 clk = ~clk;
    
    assign {mem_control,
            store_data,
            exe_result,
            lo_result,
            hi_write,lo_write,
            mfhi,mflo,
            mtc0,mfc0,cp0r_addr,syscall,eret,
            rf_wen,rf_wdest,
            new_pc} = EXE_MEM_bus_r;
endmodule













