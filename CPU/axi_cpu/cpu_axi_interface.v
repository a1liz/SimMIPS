`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/12/2018 09:14:45 PM
// Design Name: 
// Module Name: cpu_axi_interface
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


module cpu_axi_interface(
    input wire aclk,
    input wire aresetn,
    input wire [6:0] int,
    
    // axi
    // ar
    output wire [3:0] arid,
    output reg [31:0] araddr,
    output wire [7:0] arlen,
    output reg [2:0] arsize,
    output wire [1:0] arburst,
    output wire [1:0] arlock,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    output reg arvalid,
    input wire arready,
    // r
    input wire [3:0] rid,
    input wire [31:0] rdata,
    input wire [1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output reg rready,
    // aw
    output wire [3:0] awid,
    output reg [31:0] awaddr,
    output wire [7:0] awlen,
    output reg [2:0] awsize,
    output wire [1:0] awburst,
    output wire [1:0] awlock,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    output reg awvalid,
    input wire awready,
    // w
    output wire [3:0] wid,
    output reg [31:0] wdata,
    output reg [3:0] wstrb,
    output wire wlast,
    output reg wvalid,
    input wire wready,
    // b
    input wire [3:0] bid,
    input wire [1:0] bresp,
    input wire bvalid,
    output reg bready,
    
    // debug signal for tb
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_wen,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
    );

//----------{inst/data sram part}begin

    // inst sram-like
    wire inst_req;
    wire inst_wr;
    wire [1:0] inst_size;
    wire [31:0] inst_addr;
    wire [31:0] inst_wdata;
    reg [31:0] inst_rdata;
    reg inst_addr_ok;
    reg inst_data_ok;
    
    // data sram-like
    wire data_req;
    wire data_wr;
    wire [1:0] data_size;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    reg [31:0] data_rdata;
    reg data_addr_ok;
    reg data_data_ok;
    
    pipeline_cpu cpu_core (
        .clk        (aclk       ),
        .resetn     (aresetn    ),
        .int        (int        ),
        
        .inst_req   (inst_req   ),
        .inst_wr    (inst_wr    ),
        .inst_size  (inst_size  ),
        .inst_addr  (inst_addr  ),
        .inst_wdata (inst_wdata ),
        .inst_rdata (inst_rdata ),
        .inst_addr_ok(inst_addr_ok),
        .inst_data_ok(inst_data_ok),
        
        .data_req   (data_req   ),
        .data_wr    (data_wr    ),
        .data_size  (data_size  ),
        .data_addr  (data_addr  ),
        .data_wdata (data_wdata ),
        .data_rdata (data_rdata ),
        .data_addr_ok(data_addr_ok),
        .data_data_ok(data_data_ok),
        
        .debug_wb_pc      ( debug_wb_pc     ), // O, 32
        .debug_wb_rf_wen  ( debug_wb_rf_wen ), // O, 4
        .debug_wb_rf_wnum ( debug_wb_rf_wnum), // O, 5
        .debug_wb_rf_wdata(debug_wb_rf_wdata)  // O, 32
    );

    // data_valid
    wire [3:0] inst_sram_data_valid;
    wire [3:0] data_sram_data_valid;
    assign inst_sram_data_valid = (inst_size == 2'b00 && inst_addr[1:0] == 2'b00) ? 4'b0001
                                : (inst_size == 2'b00 && inst_addr[1:0] == 2'b01) ? 4'b0010
                                : (inst_size == 2'b00 && inst_addr[1:0] == 2'b10) ? 4'b0100
                                : (inst_size == 2'b00 && inst_addr[1:0] == 2'b11) ? 4'b1000
                                : (inst_size == 2'b01 && inst_addr[1:0] == 2'b00) ? 4'b0011
                                : (inst_size == 2'b01 && inst_addr[1:0] == 2'b10) ? 4'b1100
                                : (inst_size == 2'b10 && inst_addr[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
    assign data_sram_data_valid = (data_size == 2'b00 && data_addr[1:0] == 2'b00) ? 4'b0001
                                : (data_size == 2'b00 && data_addr[1:0] == 2'b01) ? 4'b0010
                                : (data_size == 2'b00 && data_addr[1:0] == 2'b10) ? 4'b0100
                                : (data_size == 2'b00 && data_addr[1:0] == 2'b11) ? 4'b1000
                                : (data_size == 2'b01 && data_addr[1:0] == 2'b00) ? 4'b0011
                                : (data_size == 2'b01 && data_addr[1:0] == 2'b10) ? 4'b1100
                                : (data_size == 2'b10 && data_addr[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
                                
    always @(posedge aclk) begin
        if (inst_addr_ok) begin
            if (inst_wr)
            begin
                case(inst_size)
                    2'b00 : awsize <= 3'b011;
                    2'b01 : awsize <= 3'b100;
                    2'b10 : awsize <= 3'b101;
                    default : awsize <= 3'b000;
                endcase
            end
            else
            begin
                case(inst_size)
                    2'b00 : arsize <= 3'b011;
                    2'b01 : arsize <= 3'b100;
                    2'b10 : arsize <= 3'b101;
                    default : arsize <= 3'b000;
                endcase
            end
        end
        else if (data_addr_ok) begin
            if (data_wr)
            begin
                case(data_size)
                    2'b00 : awsize <= 3'b011;
                    2'b01 : awsize <= 3'b100;
                    2'b10 : awsize <= 3'b101;
                    default : awsize <= 3'b000;
                endcase
            end
            else
            begin
                case(data_size)
                    2'b00 : arsize <= 3'b011;
                    2'b01 : arsize <= 3'b100;
                    2'b10 : arsize <= 3'b101;
                    default : arsize <= 3'b000;
                endcase
            end
        end
    end    

//----------{inst_read }end

//----------{transcation}begin
        
    // ar tunnel
    assign arid = 4'd0;
    assign arlen = 8'd0;
    assign arburst = 2'b01;
    assign arlock = 2'd0;
    assign arcache = 4'd0;
    assign arprot = 3'd0;

    // aw tunnel
    assign awid = 4'd0;
    assign awlen = 8'd0;
    assign awburst = 2'b01;
    assign awlock = 2'd0;
    assign awcache = 4'd0;
    assign awprot = 3'd0;
    
    // w tunnel
    reg [3:0] rstrb;
    assign wid = 4'd0;
    assign wlast = 1'b1;
    
    reg stall;
    reg current_inst_or_data;   // inst_sram <= 1, data_sram <= 0

    always @(posedge aclk) 
    begin
        if (!aresetn) begin
            // reset
            awvalid <= 1'b0;
            arvalid <= 1'b0;
            wvalid <= 1'b0;
            bready <= 1'b0;
            rready <= 1'b0;
            stall <= 1'b0;
            
            inst_addr_ok <= 1'b0;
            inst_data_ok <= 1'b0;
            data_addr_ok <= 1'b0;
            data_data_ok <= 1'b0;
        end
        else if (bvalid && bready)
        begin
            bready <= 1'b0;
            stall <= 1'b0;
            if (current_inst_or_data)
            begin
                inst_data_ok <= 1'b1;
            end
            else
            begin
                data_data_ok <= 1'b1;
            end
        end
        else if (rvalid && rready)
        begin
            rready <= 1'b0;
            stall <= 1'b0;
            if (current_inst_or_data)
            begin
                inst_data_ok <= 1'b1;
                if (rstrb[0])
                begin
                    inst_rdata[7:0] <= rdata[7:0];
                end
                else
                begin
                    inst_rdata[7:0] <= 8'd0;
                end
                if (rstrb[1])
                begin
                    inst_rdata[15:8] <= rdata[15:8];
                end
                else
                begin
                    inst_rdata[15:8] <= 8'd0;
                end
                if (rstrb[2])
                begin
                    inst_rdata[23:16] <= rdata[23:16];
                end
                else
                begin
                    inst_rdata[23:16] <= 8'd0;
                end
                if (rstrb[3])
                begin
                    inst_rdata[31:24] <= rdata[31:24];
                end
                else
                begin
                    inst_rdata[31:24] <= 8'd0;
                end
            end
            else
            begin
                data_data_ok <= 1'b1;
                if (rstrb[0])
                begin
                    data_rdata[7:0] <= rdata[7:0];
                end
                else
                begin
                    data_rdata[7:0] <= 8'd0;
                end
                if (rstrb[1])
                begin
                    data_rdata[15:8] <= rdata[15:8];
                end
                else
                begin
                    data_rdata[15:8] <= 8'd0;
                end
                if (rstrb[2])
                begin
                    data_rdata[23:16] <= rdata[23:16];
                end
                else
                begin
                    data_rdata[23:16] <= 8'd0;
                end
                if (rstrb[3])
                begin
                    data_rdata[31:24] <= rdata[31:24];
                end
                else
                begin
                    data_rdata[31:24] <= 8'd0;
                end
            end
        end
        else if ((awready && awvalid) || (wready && wvalid))
        begin
            if (awvalid && awvalid)
            begin
                awvalid <= 1'b0;
            end
            else if (wready && wvalid)
            begin
                wvalid <= 1'b0;
            end
            bready <= 1'b1;
        end
        else if (arready && arvalid)
        begin
            arvalid <= 1'b0;
            rready <= 1'b1;
        end
        else if (data_addr_ok)
        begin
            awaddr <= data_addr;
            wdata <= data_wdata;
            wstrb <= data_sram_data_valid;
            rstrb <= data_sram_data_valid;
            araddr <= data_addr;
            awvalid <= data_wr;
            wvalid <= data_wr;
            arvalid <= ~data_wr;
            data_addr_ok <= 1'b0;
        end
        else if (inst_addr_ok)
        begin
            awaddr <= inst_addr;
            wdata <= inst_wdata;
            wstrb <= inst_sram_data_valid;
            rstrb <= inst_sram_data_valid;
            araddr <= inst_addr;
            awvalid <= inst_wr;
            wvalid <= inst_wr;
            arvalid <= ~inst_wr;
            inst_addr_ok <= 1'b0;
        end
        else if (data_req && data_wr && ~stall)
        begin
            data_addr_ok <= 1'b1;
            inst_data_ok <= 1'b0;
            data_data_ok <= 1'b0;
            stall <= 1'b1;
            current_inst_or_data <= 1'b0;
        end
        else if (inst_req && inst_wr && ~stall)
        begin
            inst_addr_ok <= 1'b1;
            inst_data_ok <= 1'b0;
            data_data_ok <= 1'b0;
            stall <= 1'b1;
            current_inst_or_data <= 1'b1;
        end
        else if (data_req && ~data_wr && ~stall)
        begin
            data_addr_ok <= 1'b1;
            inst_data_ok <= 1'b0;
            data_data_ok <= 1'b0;
            stall <= 1'b1;
            current_inst_or_data <= 1'b0;
        end
        else if (inst_req && ~inst_wr && ~stall)
        begin
            inst_addr_ok <= 1'b1;
            inst_data_ok <= 1'b0;
            data_data_ok <= 1'b0;
            stall <= 1'b1;
            current_inst_or_data <= 1'b1;
        end
        else
        begin
            inst_data_ok <= 1'b0;
            data_data_ok <= 1'b0;
        end
    end
//----------{transcationl}end

endmodule

























