`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2023 09:55:51 PM
// Design Name: 
// Module Name: tb
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


module tb(
    );
    
    parameter word_size = 32;
    parameter address_size = 32;
    
    integer clkCounter = 0;
    reg rst_n, clk;
    
    always 
    begin
        #10 clk = ~clk;
        clkCounter = clkCounter + 1;
        // $display("addr: %b data: %b wen: %b \n\n", dmem_addr, dmem_data, dmem_wen);
        if (clkCounter == 5000) $finish;
    end
        
    initial
        begin
            rst_n = 0;
            clk = 0;
            
            #35 rst_n = 1;
                                    
        end
            
wire [9:0] cc;
wire [address_size-1:0] imem_addr;
wire [word_size-1:0] imem_insn;
wire [address_size-1:0] dmem_addr;
wire [word_size-1:0] dmem_data;
wire dmem_wen, read;
wire [3:0] byte_en;


cpu dut 
(
    .*
);
    
    // Change to the file you need
rom #( .addr_width (address_size), .data_width (word_size), .init_file ("line.dat") )
imem (
.addr(imem_addr),
.data(imem_insn)
);

ram #( .addr_width (address_size), .data_width (word_size), .init_file ("dmem.dat") )
dmem (
.rst_n (rst_n),
.clk (clk),
.wen (dmem_wen),
.addr (dmem_addr),
.data (dmem_data),
.byte_en (byte_en)
);
        
endmodule
