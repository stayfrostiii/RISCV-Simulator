`timescale 1ns/1ps

module ram #(addr_width = 4, data_width = 4, string init_file = "dummy.dat" )
(
input rst_n,
input clk,
input wen,
input [addr_width-1:0]addr,
input [3:0] byte_en,
//input [data_width-1:0] data_in,
inout [data_width-1:0]data
);

//reg [31:0] mem [4294967295:0];
reg [31:0] mem [1000000000:0];

initial
    begin
        $readmemb (init_file, mem);
    end
    
wire [31:0] memr;

assign memr[7:0] = rst_n ? ( ( wen | ~byte_en[0] ) ? 'z : mem[addr][7:0]) : 'z;
assign memr[15:8] = rst_n ? ( ( wen | ~byte_en[1] ) ? 'z : mem[addr][15:8]) : 'z;
assign memr[23:16] = rst_n ? ( ( wen | ~byte_en[2] ) ? 'z : mem[addr][23:16]) : 'z;
assign memr[31:24] = rst_n ? ( ( wen | ~byte_en[3] ) ? 'z : mem[addr][31:24]) : 'z;
    
assign data = rst_n ? ( wen ? 'z : memr) : 'z;

always @ (*)
begin
        $display("addr: %d mem: %d wen: %d \n\n", addr, rst_n ? ( wen ? 'z : mem[addr]) : 'z, wen);
end


integer clkCounter = 0;

always_ff @ (posedge clk)
    begin
        if (rst_n)
        begin
            // $display ("%b %b\n", wen, byte_en );
            if (wen)
            begin
//                case (byte_en)
//                begin
//                    4'b0001 : mem[addr] = 32'bx;
//                    4'b0010 : mem[addr] = 32'bx;
//                    4'b0011 : mem[addr] = 32'bx;
//                    4'b0100 : mem[addr] = 32'bx;
//                    4'b0101 : mem[addr] = 32'bx;
//                    4'b0111 : mem[addr] = 32'bx;
//                    4'b1000 : mem[addr] = 32'bx;
//                    4'b1001 : mem[addr] = 32'bx;
//                    4'b1010 : mem[addr] = 32'bx;
//                    4'b1011 : mem[addr] = 32'bx;
//                    4'b1100 : mem[addr] = 32'bx;
//                    4'b1101 : mem[addr] = 32'bx;
//                    4'b1111 : mem[addr] = #0.1 data;
//                endcase

//                if (byte_en[3]) mem[addr] <= #0.1 (mem[addr] & 32'hffffff00) | (data & 32'h000000ff);
//                if (byte_en[2]) mem[addr] <= #0.1 (mem[addr] & 32'hffff00ff) | (data & 32'h0000ff00);
//                if (byte_en[1]) mem[addr] <= #0.1 (mem[addr] & 32'hff00ffff) | (data & 32'h00ff0000);
//                if (byte_en[0]) mem[addr] <= #0.1 (mem[addr] & 32'h00ffffff) | (data & 32'hff000000);
                
                if (byte_en[3]) mem[addr][31:24] <= #0.1 data[31:24];
                if (byte_en[2]) mem[addr][23:16] <= #0.1 data[23:16];
                if (byte_en[1]) mem[addr][15:8] <= #0.1 data[15:8];
                if (byte_en[0]) mem[addr][7:0] <= #0.1 data[7:0];
            end
        end
    end
    
endmodule

/*`timescale 1ns/1ps

module ram #(addr_width = 4, data_width = 4, string init_file = "dummy.dat" )
(
input rst_n,
input clk,
input wen,
input [addr_width-1:0]addr,
//input [data_width-1:0] data_in,
inout [data_width-1:0]data
);

reg [31:0] mem [255:0];

initial
    begin
        $readmemb (init_file, mem);
    end
    
assign data = rst_n ? ( wen ? 'z : mem[addr]) : 'z;

//always @ (*)
//begin
//        $display("addr: %b mem: %b wen: %b \n\n", addr, rst_n ? ( wen ? 'z : mem[addr]) : 'z, wen);
//end


integer clkCounter = 0;

always_ff @ (posedge clk)
    begin
        clkCounter = clkCounter + 1;
        // $display("%d", clkCounter);
        if (rst_n)
            begin
                if (wen)
                begin
                    *//*if (^data === 1'bx) begin  // Check if data is 'x'
                        $display("ERROR: Unknown value on data line at addr = %b, time = %t", addr, $time);
                    end else begin
                        $display("Valid data: addr = %b, data = %b, time = %t", addr, data, $time);
                    end*//*
                    mem[addr] <= #0.1 data;
                end
            end
        if (clkCounter == 30)
        begin
            $writememb("output.txt", mem); // Write the contents of the memory to output.dat
            // $display("Memory contents written to output.dat");
        end
    end
        
endmodule*/