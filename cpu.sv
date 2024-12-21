`timescale 1ns / 1ps

module cpu (
    input clk, rst_n,
    output reg [9:0] cc,
    input reg [31:0] imem_insn,
    output reg [31:0] imem_addr, dmem_addr,
    output reg dmem_wen, read,
    output reg [3:0] byte_en,
    inout signed [31:0] dmem_data
    );
    
    reg [31:0] decode, execute, write_back, at_end, result, exe_result;
    // reg [1:0] cc_count;
    
    reg [31:0] regInUse;
    reg read;
    
    reg [31:0] insn_executed;
    reg [31:0] insn_addr_executed;
    
    integer pc_counter;
    integer cc_tracer;
    
    assign dmem_data = dmem_wen ? exe_result : 32'bz;
     
    initial
    begin
        pc_counter = $fopen("pc_trace.txt", "a");
        cc_tracer = $fopen("cc_trace.txt", "a");
    end
          
    reg [31:0] dmem_temp;
                       
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            dmem_wen <= 1;
            read <= 0;
        end
        else
        begin
            if (read === 1'b0) 
            begin
                #25;
            end
            #10; dmem_wen <= ~dmem_wen; 
        end
    end 
    
    // Fetch
    always @(posedge clk or negedge rst_n)
    begin    
        if (!rst_n)
        begin
            imem_addr <= 32'b0;
            insn_addr_executed <= 32'b0;
            decode <= 32'bx;
            cc <= 0;
            byte_en <= 0;
        end
        else if (dmem_wen === 0)
        begin
            // Shows what instruction and instruction address is currently active 
            // $display("Instruction: %b, Instruction Mem: %b", imem_insn, imem_addr);
            // $display("Fetch: \nimem_insn: %b cc: %d dmem_wen: %b\n", imem_insn, cc, dmem_wen);
            $fdisplay(pc_counter, "PC: %h", imem_addr);
            decode <= imem_insn;
            imem_addr <= imem_addr + 4;
            cc <= cc + 1;
            read <= 0; #10;
            read <= 1; #45;
            read <= 0;
        end
    end
    
    // Variables for the I-type instruction table
    // [31:20] = immediate[11:0], [19:15] = rs1, [14:12] = funct3, [11:7] = rd, [6:0] = opcode
    reg [6:0] opcode;
    reg [4:0] rd;
    reg [2:0] funct3;
    reg [4:0] rs1;
    reg [31:0] immediate;
    
    // Variables for the R-type instruction table
    // [31:25] = funct7, [24:20] = rs2, [19:15] = rs1, [14:12] = funct3, [11:7] = rd, [6:0] = opcode
    reg [4:0] rs2;
    reg [6:0] funct7;
    
    // Decode
    always @ (posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            execute <= 32'bx;
        end
        else if (dmem_wen === 0)
        begin
            // $display("Decode: \nimem_insn: %b cc: %d dmem_wen: %b\n", decode, cc, dmem_wen);
            execute <= decode;
            
            // U-Type Instructions (lui/auipc)
            if (decode[6:0] === 7'b0110111 | decode[6:0] === 7'b0010111)
            begin
                immediate <= { 12'bzzzzzzzzzzzz, decode[31:12] };
                rd <= decode[11:7];
                opcode <= decode[6:0];
                                
                if (regInUse[decode[11:7]] === 1) 
                begin
                    #20;
//                    $display("wait");
                    regInUse[decode[11:7]] <= 1;
                end
                else
                begin
                    regInUse[decode[11:7]] <= 1;
//                    $display("go");
                end
            end
            
            // JAL Instruction
            else if (decode[6:0] === 7'b1101111)
            begin
                immediate[31:20] <= { 12{decode[31]} };
                immediate[19:12] = decode[19:12];
                immediate[11] = decode[20];
                immediate[10:1] = decode[30:21];
                rd <= decode[11:7];
                opcode <= decode[6:0];
                
                if (regInUse[decode[11:7]] === 1) 
                begin
                    #20;
//                    $display("wait");
                    regInUse[decode[11:7]] <= 1;
                end
                else
                begin
                    regInUse[decode[11:7]] <= 1;
//                    $display("go");
                end
            end
            
            // Branch Instructions
            else if (decode[6:0] === 7'b1100011)
            begin
                immediate[31:12] = { 20{decode[31]} };
                immediate[11] = decode[7];
                immediate[10:5] = decode[30:25];
                immediate[4:1] = decode[11:8];
                rs2 <= decode[24:20];
                rs1 <= decode[19:15];
                funct3 = decode [14:12];
                opcode <= decode [6:0];
                
                if (regInUse[decode[24:20]] === 1 | regInUse[decode[11:7]] === 1) 
                begin
                    #20;
//                    $display("wait");
                    regInUse[decode[11:7]] <= 1;
                end
                else
                begin
                    regInUse[decode[11:7]] <= 1;
//                    $display("go");
                end
            end
            
            // Immediate, Load, JALR Instructions
            else if (decode[6:0] === 7'b0010011 | decode[6:0] === 7'b0000011 | decode[6:0] === 7'b1100111)
            begin
                immediate <= { {20{decode[31]}}, decode[31:20] };
                rs1 <= decode[19:15];   
                         
                funct3 <= decode[14:12];
                rd <= decode[11:7];
                opcode <= decode[6:0];
                
                if (regInUse[decode[19:15]] === 1 | regInUse[decode[11:7]] === 1) 
                begin
                    #20;
//                    $display("wait");
                    regInUse[decode[19:15]] <= 1;
                    regInUse[decode[11:7]] <= 1;
                end
                else
                begin
                    regInUse[decode[19:15]] <= 1;
                    regInUse[decode[11:7]] <= 1;
//                    $display("go");
                end
            end
            
            // R-Type and Store Instructions
            // [31:25] = funct7, [24:20] = rs2, [19:15] = rs1, [14:12] = funct3, [11:7] = rd, [6:0] = opcode
            else if (decode[6:0] === 7'b0110011 | decode[6:0] === 7'b0100011)
            begin
                if (decode[6:0] === 7'b0100011)
                begin
                    immediate[31:5] <= { {20{decode[31]}}, decode[31:25] };
                    immediate[4:0] <= decode[11:7];
                end
                else
                begin
                    funct7 <= decode[31:25];
                    rd <= decode[11:7];
                end
                rs2 <= decode[24:20];
                rs1 <= decode[19:15];
                         
                funct3 <= decode[14:12];
                opcode <= decode[6:0];
                
                if (regInUse[decode[19:15]] === 1 | regInUse[decode[11:7]] === 1) 
                begin
                    #20;
//                    $display("wait");
                    regInUse[decode[19:15]] <= 1;
                    regInUse[decode[11:7]] <= 1;
                end
                else
                begin
                    regInUse[decode[19:15]] <= 1;
                    regInUse[decode[11:7]] <= 1;
//                    $display("go");
                end
            end 
            // $display("Instruction Mem: %b \nregInUse: %b", imem_addr, regInUse);
            
//            $display("Instruction: %b, Instruction Mem: %b", decode, imem_addr - 4);
//            $display(
//                "Immediate: %h \n rs1: %d \n funct3: %b \n rd: %d \n opcode: %b \n\n",
//                { {20{decode[31]}}, decode[31:20] }, decode[19:15], decode[14:12], decode[11:7], decode[6:0]
//            );
        end
    end
        
    reg [31:0] rs1Val, rs2Val;
    reg [11:0] offset;
    reg [3:0] current_byte_en;
    
    // Execute
    always @ (posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            write_back <= 32'bx;
        end
        else if (dmem_wen === 0)
        begin
            // $display("Execute: \nimem_insn: %b cc: %d dmem_wen: %b \ndmem_addr: %d dmem_data %h immediate: %h \n", execute, cc, dmem_wen, dmem_addr, dmem_data, immediate);
            write_back <= execute;            
            
            case (execute[6:0])
                7'b0000011 : // Load Instructions
                begin
                    dmem_addr <= rs1;
                    byte_en <= 4'b1111;
                    
                    #2.5;
                    
                    dmem_temp <= dmem_data;
                    
                    #2.5;
                    
                    if (execute[14:12] === 3'b000 | execute[14:12] === 3'b100) // lb / lbu
                    begin                                                
                        if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                            immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                        begin
                            current_byte_en <= 4'b0001;
                            offset <= immediate;
                        end
                        
                        else if (immediate === 1 | immediate === 5 | immediate === 9 | immediate === 13 | 
                            immediate === 17 | immediate === 21 | immediate === 25 | immediate === 29)
                        begin
                            current_byte_en <= 4'b0010;
                            offset <= immediate - 1;
                        end
                        
                        else if (immediate === 2 | immediate === 6 | immediate === 10 | immediate === 14 | 
                            immediate === 18 | immediate === 22 | immediate === 26 | immediate === 30)
                        begin
                            current_byte_en <= 4'b0100;
                            offset <= immediate - 2;
                        end
                        
                        else if (immediate === 3 | immediate === 7 | immediate === 11 | immediate === 15 | 
                            immediate === 19 | immediate === 23 | immediate === 27 | immediate === 31)
                        begin
                            current_byte_en <= 4'b1000;
                            offset <= immediate - 3;
                        end
                    end
                    else if (execute[14:12] === 3'b001 | execute[14:12] === 3'b101) // lh / lhu
                    begin
                        if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                            immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                        begin
                            current_byte_en <= 4'b0011;
                            offset <= immediate;
                        end
                                                    
                        else if (immediate === 2 | immediate === 6 | immediate === 10 | immediate === 14 | 
                            immediate === 18 | immediate === 22 | immediate === 26 | immediate === 30)
                        begin
                            current_byte_en <= 4'b1100;
                            offset <= immediate - 2;
                        end
                    end
                    else if (execute[14:12] === 3'b010) // lw
                    begin
                        if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                            immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                        begin
                            current_byte_en <= 4'b1111;
                            offset <= immediate;
                        end
                    end
                    
                    #2.5;
                    
                    dmem_addr <= dmem_temp + offset;
                    
                    #2.5;
                    
                    if (execute[14:12] === 3'b100) dmem_temp <= { 24'b0, dmem_data[7:0] };
                    else if (execute[14:12] === 3'b101) dmem_temp <= { 16'b0, dmem_data[15:0] };
                    else
                    begin
                        case (current_byte_en)
                            4'b0001 : dmem_temp <= { {24{dmem_data[7]}}, dmem_data[7:0] };
                            4'b0010 : dmem_temp <= { {24{dmem_data[15]}}, dmem_data[15:7] };
                            4'b0100 : dmem_temp <= { {24{dmem_data[23]}}, dmem_data[23:16] };
                            4'b1000 : dmem_temp <= { {24{dmem_data[31]}}, dmem_data[31:24] };
                            4'b0011 : dmem_temp <= { {16{dmem_data[15]}}, dmem_data[15:0] };
                            4'b1100 : dmem_temp <= { {16{dmem_data[31]}}, dmem_data[31:16] };
                            4'b1111 : dmem_temp <= dmem_data;
                        endcase
                        $display ("here %d", { {24{dmem_data[31]}}, dmem_data[31:24] });
                    end
                    
                    #10;
                    byte_en <= 4'b1111;
                    dmem_addr <= rd;
                    if (dmem_temp === 32'bx) result <= 32'b0;
                    else result <= dmem_temp;
                end
                
                7'b0100011 : // Store Instructions
                begin
                    dmem_addr <= rs2;
                    byte_en <= 4'b1111;
                    #5;
                        rs1Val <= dmem_data;
                    #5;
                    dmem_addr <= rs1;
                    byte_en <= 4'b1111;
                    
                    #5;
                        rs2Val <= dmem_data;
                    #5;
                    
                    case(execute[14:12])
                        3'b000 : // sb
                        begin                                                
                            if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                                immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                            begin
                                current_byte_en <= 4'b0001;
                                offset <= immediate;
                            end
                            
                            else if (immediate === 1 | immediate === 5 | immediate === 9 | immediate === 13 | 
                                immediate === 17 | immediate === 21 | immediate === 25 | immediate === 29)
                            begin
                                current_byte_en <= 4'b0010;
                                offset <= immediate - 1;
                            end
                            
                            else if (immediate === 2 | immediate === 6 | immediate === 10 | immediate === 14 | 
                                immediate === 18 | immediate === 22 | immediate === 26 | immediate === 30)
                            begin
                                current_byte_en <= 4'b0100;
                                offset <= immediate - 2;
                            end
                            
                            else if (immediate === 3 | immediate === 7 | immediate === 11 | immediate === 15 | 
                                immediate === 19 | immediate === 23 | immediate === 27 | immediate === 31)
                            begin
                                current_byte_en <= 4'b1000;
                                offset <= immediate - 3;
                            end
                        end
                        3'b001 : // sh
                        begin
                            if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                                immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                            begin
                                current_byte_en <= 4'b0011;
                                offset <= immediate;
                            end
                                                        
                            else if (immediate === 2 | immediate === 6 | immediate === 10 | immediate === 14 | 
                                immediate === 18 | immediate === 22 | immediate === 26 | immediate === 30)
                            begin
                                current_byte_en <= 4'b1100;
                                offset <= immediate - 2;
                            end
                        end
                        3'b010 : // sw
                        begin
                            if (immediate === 0 | immediate === 4 | immediate === 8 | immediate === 12 | 
                                immediate === 16 | immediate === 20 | immediate === 24 | immediate === 28)
                            begin
                                current_byte_en <= 4'b1111;
                                offset <= immediate;
                            end
                        end
                    endcase
                    
                    #5;
                    dmem_addr <= rs2Val + offset;
                    #5;
                    if (rs1Val === 32'bx) result <= 32'b0;
                    else 
                    begin
                        case (current_byte_en)
                            4'b0001 : result <= { 24'bz, rs1Val[7:0] };
                            4'b0010 : result <= { 16'bz, rs1Val[7:0], 8'bz };
                            4'b0100 : result <= { 8'bz, rs1Val[7:0], 16'bz };
                            4'b1000 : result <= { rs1Val[7:0], 24'bz };
                            4'b0011 : result <= { 16'bz, rs1Val[15:0] };
                            4'b1100 : result <= { rs1Val[15:0], 16'bz };
                            4'b1111 : result <= rs1Val;
                        endcase
                    end
//                    else result <= rs1Val;
                end
                
                7'b0010011 : // Immediate Instruction
                begin
                    current_byte_en <= 4'b1111;
                    dmem_addr <= rs1;
                    #10;
                    rs1Val <= dmem_data;
                    #10;
                    dmem_addr <= rd;
                    
                    case(execute[14:12])
                        3'b000 : // addi - 0x0
                        begin                
                            if (rs1Val === 32'bx) result <= immediate;
                            else result <= rs1Val + immediate;
                        end
                        
                        3'b100 : // xori - funct3 = 0x4
                        begin                
                            if (rs1Val === 32'bx) result <= 32'b0 & immediate;
                            else result <= rs1Val ^ immediate;
                        end
                        
                        3'b110 : // ori - funct3 = 0x6
                        begin                
                            if (rs1Val === 32'bx) result <= 32'b0 & immediate;
                            else result <= rs1Val | immediate;
                        end
                        
                        3'b111 : // andi - funct3 = 0x7
                        begin                
                            if (rs1Val === 32'bx) result <= 32'b0 & immediate;
                            else result <= rs1Val & immediate;
                        end
                        
                        3'b001 : // slli - funct3 = 0x1
                        begin                
                            result <= rs1Val << execute[24:20];
                        end
                        
                        3'b101 : // srli/srai - funct3 = 0x5
                        begin 
                            if (immediate[11:5] === 7'b0000000) // srli
                            begin               
                                result <= rs1Val >> immediate[4:0];
                            end
                            else if (immediate[11:5] === 7'b0100000) // srai
                            begin
                                result <= $signed(rs1Val) >>> immediate[4:0];
                            end
                        end
                        
                        3'b010 : // slti - funct3 = 0x2
                        begin                
                            if (rs1Val === 32'bx) result <= 1;
                            else result <= (rs1Val < immediate) ? 1 : 0;
                        end
                        
                        3'b011 : // sltiu - funct3 = 0x3
                        begin                
                            if (rs1Val === 32'bx) result <= immediate;
                            else result <= rs1Val + immediate;
                        end
                    endcase
                end
            
                7'b0110011 : // Register Instructions
                begin
                    dmem_addr <= rs1;
                    #5;
                    rs1Val <= dmem_data;
                    #5;
                    dmem_addr <= rs2;
                    #10;
                    dmem_addr <= rd;
                
                    case(execute[14:12])
                        3'b000 : // add/sub - funct = 0x0
                        begin    
                            if (execute[31:25] === 5'b0)
                            begin            
                                if (dmem_data === 32'bx & rs1Val === 32'bx) result <= 32'b0;
                                else if (dmem_data === 32'bx) result <= rs1Val;
                                else if (rs1Val === 32'bx) result <= dmem_data;
                                else result <= dmem_data + rs1Val;
                            end
                            else
                            begin
                                if (dmem_data === 32'bx & rs1Val === 32'bx) result <= 32'b0;
                                else if (dmem_data === 32'bx) result <= rs1Val;
                                else if (rs1Val === 32'bx) result <= 32'b0 - dmem_data;
                                else result <= rs1Val - dmem_data;
                            end
                        end
                        
                        3'b001 : // sll - funct3 = 0x1
                        begin                
                            result <= rs1Val << dmem_data[4:0];
                        end
                        
                        3'b010 : // slt - funct3 = 0x2
                        begin                
                            if (dmem_data === 32'bx | rs1Val === 32'bx) result <= 1;
                            else result <= (rs1Val < dmem_data) ? 1 : 0;
                        end
                        
                        3'b011 : // sltu - funct3 = 0x3
                        begin                
                            if (dmem_data === 32'bx | rs1Val === 32'bx) result <= 1;
                            else result <= (rs1Val < dmem_data) ? 1 : 0;
                        end
                        
                        3'b100 : // xor - funct3 = 0x4
                        begin    
//                            $display("%b \n%b", rs1Val, dmem_data);            
                            if (dmem_data === 32'bx & rs1Val === 32'bx) result <= 32'b0;
                            else if (dmem_data === 32'bx) result <= 32'b0 ^ rs1Val;
                            else if (rs1Val === 32'bx) result <= 32'b0 ^ dmem_data;
                            else result <= rs1Val ^ dmem_data;
                        end
                        
                        3'b101 : // srl/sra - funct3 = 0x5
                        begin 
                            if (execute[31:25] === 7'b0000000)
                            begin  
                                result <= rs1Val >> dmem_data[4:0];
                            end
                            else if (execute[31:25] === 7'b0100000)
                            begin
                                result <= rs1Val >>> dmem_data[4:0];
                            end
                        end
                        
                        3'b110 : // or - funct3 = 0x6
                        begin                        
                            if (dmem_data === 32'bx & rs1Val === 32'bx) result <= 32'b0;
                            else if (dmem_data === 32'bx) result <= rs1Val;
                            else if (rs1Val === 32'bx) result <= dmem_data;
                            else result <= dmem_data | rs1Val;   
                        end
                        
                        3'b111 : // and - funct3 = 0x7
                        begin                
                            if (dmem_temp === 32'bx | rs1Val === 32'bx) result <= 32'b0;
                            else result <= rs1Val & dmem_data;
                        end
                    endcase
                end
                
                7'b0110111 : // LUI Instruction
                begin
                    result <= immediate << 12;
                    dmem_addr <= rd;
                end
                
                7'b0010111 : // AUIPC Instruction
                begin
                    result <= imem_addr + ( immediate << 12 );
                    dmem_addr <= rd;
                end
                
                7'b1101111 : // JAL Instruction
                begin
                    dmem_addr <= rd;
                    result <= imem_addr + 4;
                    imem_addr <= imem_addr + immediate;
                end
                
                7'b1100111 : // JALR Instruction
                begin
                    dmem_addr <= rs1;
                    #10;
                    imem_addr <= dmem_data + immediate;
                    dmem_addr <= rd;
                    result <= imem_addr + 4;
                end
                
                7'b1100011 : // Branch Instruction
                begin
                    dmem_addr <= rs1;
                    #2.5;
                    rs1Val <= dmem_data;
                    #2.5;
                    dmem_addr <= rs2;
                    #2.5;
                    dmem_addr <= rd;
                
                    case(execute[14:12])
                        3'b000 : // beq
                        begin
                            if (rs1Val === dmem_data) imem_addr <= imem_addr + immediate;
                        end
                        3'b001 : // bne
                        begin
                            if (rs1Val !== dmem_data) imem_addr <= imem_addr + immediate;
                        end
                        3'b100 : // blt
                        begin
                            if (rs1Val < dmem_data) imem_addr <= imem_addr + immediate;
                        end
                        3'b101 : // bge
                        begin
                            if (rs1Val >= dmem_data) imem_addr <= imem_addr + immediate;
                        end
                        3'b110 : // bltu
                        begin
                            if (rs1Val < dmem_data) imem_addr <= imem_addr + immediate;
                        end
                        3'b111 : // bgeu
                        begin
                            if (rs1Val >= dmem_data) imem_addr <= imem_addr + immediate;
                        end
                    endcase
                end
            endcase
        end
    end
    
    assign exe_result = result;
    assign byte_en = current_byte_en;
        
    // Write Back
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n) at_end <= 32'bx;
        else if (result !== 32'bx & dmem_wen === 0)
        begin
            // $display("Write Back: \nimem_insn: %b cc: %d dmem_wen: %b \ndmem_addr: %d dmem_data %h\n", write_back, cc, dmem_wen, dmem_addr, dmem_data);
            $fdisplay(cc_tracer, "Reading \nCC: %d, Register: %d \nValue Read: %h\n", cc, dmem_addr, dmem_data);
        end
        else if (result !== 32'bx)
        begin
            // $display("Write Back: \nimem_insn: %b cc: %d dmem_wen: %b \ndmem_addr: %d result: %h\n", write_back, cc, dmem_wen, dmem_addr, exe_result);
            $fdisplay(cc_tracer, "Writing \nCC: %d, Register: %d \nNew Value: %h\n", cc, dmem_addr, exe_result);
            at_end <= write_back;
            regInUse[write_back[19:15]] <= 0;
            regInUse[write_back[11:7]] <= 0;
        end
    end
    
    final
    begin
        $fclose(pc_counter);
        $fclose(cc_tracer);
    end
                           
endmodule