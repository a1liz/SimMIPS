`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2018 08:51:59 AM
// Design Name: 
// Module Name: pipeline_cpu
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

module pipeline_cpu(
    input wire clk,  // clock
    input wire resetn,   // reset signal
    
    // display data
    input wire [4:0] rf_addr,
    input wire [31:0] mem_addr,
    output wire [31:0] rf_data,
    output wire [31:0] mem_data,
    output wire [31:0] IF_pc,
    output wire [31:0] IF_inst,
    output wire [31:0] ID_pc,
    output wire [31:0] EXE_pc,
    output wire [31:0] MEM_pc,
    output wire [31:0] WB_pc,
    
    // Five Levels Pipeline
    output wire [31:0] cpu_5_valid,
    output wire [31:0] HI_data,
    output wire [31:0] LO_data
    );

// ----------{Five Levels Pipeline Control Signal}begin---------- //
//
    // Valid signal of 5 modules
    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    // Over signal of 5 modules, from the output of each module
    wire IF_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;
    // 
    wire IF_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;

    // when syscall and eret arrive at WB, Cancel singal will be sent.
    wire cancel;

    // Each level allow-in symbol: self-Level valid or self-level
    assign IF_allow_in = (IF_over & ID_allow_in) | cancel;
    assign ID_allow_in = ~ID_valid | (ID_over & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in);
    assign WB_allow_in = ~WB_valid | WB_over;

    // IF_valid, After reset, valid always.
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // reset
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end

    // ID_valid
    always @(posedge clk) begin
        if (!resetn || cancel)
        begin
            // reset
            ID_valid <= 1'b0;
        end
        else
        begin
            ID_valid <= IF_over;
        end
    end

    // EVE_valid
    always @(posedge clk) begin
        if (resetn) 
        begin
            // reset
            EXE_valid <= 1'b0;    
        end
        else if (ID_allow_in)
        begin
            EXE_valid <= ID_over;    
        end
    end

    //MEM_valid
    always @(posedge clk) begin
        if (!resetn || cancel)
        begin
            // reset
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in) 
        begin
            MEM_valid <= EXE_over;    
        end
    end
    
    // WB_valid
    always @(posedge clk) begin
        if (!resetn || cancel)
        begin
            // reset
            WB_valid <= 1'b0;   
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;    
        end
    end

    assign cpu_5_valid = {12'd0     ,{4{IF_valid}},{4{ID_valid}},
                            {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
// ----------{Five Levels Pipeline Control Signal}end---------- //

// ----------{Bus between Five Levels}begin-------------------- //
//
    wire [ 63:0] IF_ID_bus;     // IF->ID Bus
    wire [166:0] ID_EXE_bus;    // ID->EXE Bus
    wire [153:0] EXE_MEM_bus;   // EXE->MEM Bus
    wire [117:0] MEM_WB_bus;    // MEM->WB Bus

    // Latch Bus Signal above
    reg [ 63:0] IF_ID_bus_r;
    reg [166:0] ID_EXE_bus_r;
    reg [153:0] EXE_MEM_bus_r;
    reg [117:0] MEM_WB_bus_r;

    // Latch Signal from IF to ID
    always @(posedge clk) 
    begin
        if (IF_over && ID_allow_in) 
        begin
            IF_ID_bus_r <= IF_ID_bus;    
        end
    end

    // Latch Signal from ID to EXE
    always @(posedge clk)
    begin
        if (ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;            
        end
    end

    // Latch Signal from EXE to MEM
    always @(posedge clk)
    begin
        if (EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end

    // Latch Signal from MEM to WB
// ----------{Bus between Five Levels}end---------------------- //

// ----------{Other Interaction Signal}begin------------------- //
//
    // jump bus
    wire [32:0] jbr_bus;

    // Interaction between IF and inst_rom
    wire [31:0] inst_addr;
    wire [31:0] inst;

    // Interaction between ID and EXE, MEM, WB
    wire [ 4:0] EXE_wdest;
    wire [ 4:0] MEM_wdest;
    wire [ 4:0] WB_wdest;

    // Interaction between MEM and data_ram
    wire [ 3:0] dm_wen;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;

    // Interaction between ID and regfile
    wire [ 4:0] rs;
    wire [ 4:0] rt;
    wire [31:0] rs_value;
    wire [31:0] rt_value;

    // Interaction between WB and regfile
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;

    // Interaction between WB and IF
    wire [32:0] exc_bus;
// ----------{Other Interaction Signal}end--------------------- //

// ----------{Each Module Instantiation}begin------------------ //
//
    wire next_fetch;    // it's going to run fetch module, need latch the value of PC
    // when IF allows in, latch PC and fetch next instruction.
    assign next_fetch = IF_allow_in;
    fetch IF_module(
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF_valid  (IF_valid  ),  // I, 1
        .next_fetch(next_fetch),  // I, 1
        .inst      (inst      ),  // I, 32
        .jbr_bus   (jbr_bus   ),  // I, 33
        .inst_addr (inst_addr ),  // O, 32
        .IF_over   (IF_over   ),  // O, 1
        .IF_ID_bus (IF_ID_bus ),  // O, 64
        
        // Five Levels Pipeline New Interface
        .exc_bus   (exc_bus   ),  // I, 32
        
        // Show PC and instruction fetched
        .IF_pc     (IF_pc     ),  // O, 32
        .IF_inst   (IF_inst   )   // O, 32
    );

    decode ID_module(
        .ID_valid   (ID_valid   ),  // I, 1
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        .rs_value   (rs_value   ),  // I, 32
        .rt_value   (rt_value   ),  // I, 32
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus    ),  // O, 33
//        .inst_jbr   (inst_jbr   ),  // O, 1
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        
        // Five Levels Pipeline New Interface
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .WB_wdest    (WB_wdest    ),// I, 5
        
        // Show PC
        .ID_pc       (ID_pc       ) // O, 32
    ); 

    exe EXE_module(
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        // Five Levels Pipeline New Interface
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ),  // O, 5
        
        // show PC
        .EXE_pc      (EXE_pc      )   // O, 32
    );

    mem MEM_module(
        .clk          (clk          ),  // I, 1 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .dm_rdata     (dm_rdata     ),  // I, 32
        .dm_addr      (dm_addr      ),  // O, 32
        .dm_wen       (dm_wen       ),  // O, 4 
        .dm_wdata     (dm_wdata     ),  // O, 32
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        
        // Five Levels Pipeline New Interface
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest    (MEM_wdest    ),  // O, 5
        
        // show PC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        
        // Five Levels Pipeline New Interface
        .clk         (clk         ),  // I, 1
      .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest    (WB_wdest    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        // show PC and value of HI and LO
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     )   // O, 32
    );

    inst_rom inst_rom_module(
        .clka       (clk           ),  // I, 1 ,clock
        .addra      (inst_addr[9:2]),  // I, 8 ,instruction address
        .douta      (inst          )   // O, 32,instruction
    );

    regfile rf_module(
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value ),  // O, 32

        //display rf
        .test_addr(rf_addr),  // I, 5
        .test_data(rf_data)   // O, 32
    );
    
    data_ram data_ram_module(
        .clka   (clk         ),  // I, 1,  clock 
        .wea    (dm_wen      ),  // I, 1,  write Enable
        .addra  (dm_addr[9:2]),  // I, 8,  read address
        .dina   (dm_wdata    ),  // I, 32, write data
        .douta  (dm_rdata    ),  // O, 32, read data

        //display mem
        .clkb   (clk          ),  // I, 1,  clock
        .web    (4'd0         ),  // don't use write ability of port2
        .addrb  (mem_addr[9:2]),  // I, 8,  read address
        .doutb  (mem_data     ),  // I, 32, write data
        .dinb   (32'd0        )   // don't use write ability of port2
    );

// ----------{Each Module Instantiation}end-------------------- //

endmodule