`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: riscv_basic_pipeline
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 24 Feb 2020
*
* Description: pipelines the control and datapath instructions
*
****************************************************************************/

module riscv_basic_pipeline #(parameter INITIAL_PC = 32'h00400000) (
    input wire logic clk,
    input wire logic rst,
    output logic [31:0] PC,
    input wire logic [31:0] instruction,
    output logic [31:0] ALUResult,
    output logic [31:0] dAddress,
    output logic [31:0] dWriteData,
    input wire logic [31:0] dReadData,
    output logic MemRead,
    output logic MemWrite,
    output logic [31:0] WriteBackData
    );
    
    logic [31:0] RF[31:0]; 
   
    integer i; // i needs to be declared before it is used
    initial
    for (i = 0; i < 32; i=i+1)
        RF[i] = 0; // initializes each register to 0
    
    //////////////////////////////////////////////////////////////////////
    // IF: Instruction Fetch
    //////////////////////////////////////////////////////////////////////	
    logic [31:0] if_PC;
    //////////////////////////////////////////////////////////////////////
    // ID: Instruction Decode
    //////////////////////////////////////////////////////////////////////
    logic [31:0] id_PC;
    
    logic [3:0] id_ALUCtrl;
    logic id_ALUSrc;
    logic id_MemWrite;
    logic id_MemRead;
    logic id_Branch;
    logic id_RegWrite;
    logic id_MemtoReg;
    
    logic store;
    logic load;
    logic branch;
    logic itype;
    logic [6:0] opcode;
    logic [2:0] funct3;
    localparam AND = 4'b0000;
    localparam OR  = 4'b0001;
    localparam ADD = 4'b0010;
    localparam SUB = 4'b0110;
    localparam SLT = 4'b0111;
    localparam XOR = 4'b1100;
    
    logic [31:0] id_data1;
    logic [31:0] id_data2;
    logic [31:0] id_imm;
    logic [31:0] immI;
    logic [31:0] immS;
    localparam SOpCode = 7'b0100011;
    
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [4:0] id_rd;
    
    logic [31:0] id_branch_offset;
    //////////////////////////////////////////////////////////////////////
    // EX: Execute
    //////////////////////////////////////////////////////////////////////
    logic [31:0] ex_PC;
    logic ex_Zero;
    
    logic [3:0] ex_ALUCtrl;
    logic ex_ALUSrc;
    logic ex_MemWrite;
    logic ex_MemRead;
    logic ex_Branch;
    logic ex_RegWrite;
    logic ex_MemtoReg;
    
    logic [4:0] ex_rd;
    logic [31:0] ex_data1;
    logic [31:0] ex_data2; 
    logic [31:0] ex_imm;
    logic [31:0] data2;
    logic [31:0] ex_aluResult;
    
    logic [31:0] ex_branch_offset;
    logic [31:0] ex_branch_target;
    //////////////////////////////////////////////////////////////////////
    // MEM: Memory Access
    //////////////////////////////////////////////////////////////////////
    logic [31:0] mem_branch_target;
    logic mem_PCSrc;
    logic mem_Zero;
    
    logic mem_MemWrite;
    logic mem_MemRead;
    logic mem_Branch;
    logic mem_RegWrite;
    logic mem_MemtoReg;
    
    logic [4:0] mem_rd;
    
    logic [31:0] mem_write_data;
    logic [31:0] mem_aluResult;
    logic [31:0] mem_read_data;
    //////////////////////////////////////////////////////////////////////
    // WB: Write-Back
    //////////////////////////////////////////////////////////////////////
    logic wb_RegWrite;
    logic wb_MemtoReg;
    
    logic [31:0] wb_WriteData;
    logic [31:0] wb_read_data;
    logic [31:0] wb_aluResult;
    
    logic [4:0] wb_rd;
    //////////////////////////////////////////////////////////////////////
    // IF: Instruction Fetch
    //////////////////////////////////////////////////////////////////////	
    //PC signal update
    always_ff@ (posedge clk) begin
        if (rst) if_PC <= INITIAL_PC;
        else if (mem_PCSrc) if_PC <= mem_branch_target;
        else if_PC <= if_PC + 4;
    end
    assign PC = if_PC;
    //////////////////////////////////////////////////////////////////////
    // ID: Instruction Decode
    //////////////////////////////////////////////////////////////////////
    //IF to ID PC signal
    always_ff@ (posedge clk) begin
        if (rst) id_PC <= 0;
        else id_PC <= if_PC;
    end
    
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign store = (opcode == 7'b0100011) ? 1'b1 : 1'b0;
    assign load  = (opcode == 7'b0000011) ? 1'b1 : 1'b0;
    assign branch = (opcode == 7'b1100011) ? 1'b1 : 1'b0;
    assign itype = (opcode == 7'b0010011) ? 1'b1 : 1'b0;
    always_comb begin
        id_ALUCtrl = (funct3 == 3'b111) ? AND :
                     (funct3 == 3'b110) ? OR  :
                     (funct3 == 3'b100) ? XOR :
                     (store || load)    ? ADD :
                     (funct3 == 3'b010) ? SLT :
                     (branch)           ? SUB :
                     (itype)            ? ADD :
                     (instruction[30] == 1'b1) ? SUB : ADD;
        id_ALUSrc = itype | load | store;
        id_MemtoReg = load;
        id_MemRead = load;
        id_Branch = branch;
        id_MemWrite = store;
        id_RegWrite = (!branch & !store);
    end
    
    assign immI = {{20{instruction[31]}},instruction[31:20]};
    assign immS = {{20{instruction[31]}},instruction[31:25],instruction[11:7]};
    assign id_imm = (instruction[6:0] == SOpCode) ? immS : immI;
    
    assign id_rd = instruction[11:7];
    assign id_rs1 = instruction[19:15];
    assign id_rs2 = instruction[24:20];
    
    always_comb begin
        id_data1 <= RF[id_rs1];
        id_data2 <= RF[id_rs2];
        if (wb_RegWrite) begin
            if (id_rs1 == wb_rd) begin
                if (wb_rd == 0) id_data1 <= 0;
                else id_data1 <= wb_WriteData;
            end
            if (id_rs2 == wb_rd) begin
                if (wb_rd == 0) id_data2 <= 0;
                else id_data2 <= wb_WriteData;
            end
        end
    end
     // synchronous write and read with "write first" mode
    always_ff@ (posedge clk) begin
        if (wb_RegWrite && (wb_rd != 0)) RF[wb_rd] <= wb_WriteData;
    end
    
    assign id_branch_offset = {{20{instruction[31]}},instruction[7],
                            instruction[30:25],instruction[11:8],1'b0};
    
    //////////////////////////////////////////////////////////////////////
    // EX: Execute
    //////////////////////////////////////////////////////////////////////
    //ID to EX PC signal
    always_ff@ (posedge clk) begin
        if (rst) ex_PC <= 0;
        else ex_PC <= id_PC;
    end
        
    //ID to EX control signals
    always_ff@ (posedge clk) begin
        if (rst) begin
            ex_ALUCtrl <= 0;
            ex_ALUSrc <= 0;
            ex_MemWrite <= 0;
            ex_MemRead <= 0;
            ex_Branch <= 0;
            ex_RegWrite <= 0;
            ex_MemtoReg <= 0;
        end
        else if (mem_PCSrc) begin
            ex_MemWrite <= 0;
            ex_MemRead <= 0;
            ex_Branch <= 0;
            ex_RegWrite <= 0;
            ex_MemtoReg <= 0;
        end
        else begin
            ex_ALUCtrl <= id_ALUCtrl;
            ex_ALUSrc <= id_ALUSrc;
            ex_MemWrite <= id_MemWrite;
            ex_MemRead <= id_MemRead;
            ex_Branch <= id_Branch;
            ex_RegWrite <= id_RegWrite;
            ex_MemtoReg <= id_MemtoReg;
        end
    end
    
    //ID to EX rd signal
    always_ff@ (posedge clk) begin
        if (rst) ex_rd <= 0;
        else ex_rd <= id_rd;
    end
    
    //ID to EX branch_offset signal
    always_ff@ (posedge clk) begin
        if (rst) ex_branch_offset <= 0;
        else ex_branch_offset <= id_branch_offset;
    end
    
    //ID to EX data1 data2 imm signals
    always_ff@ (posedge clk) begin
        if (rst) begin
            ex_data1 <= 0;
            ex_data2 <= 0;
            ex_imm <= 0;
        end
        else begin
            ex_data1 <= id_data1;
            ex_data2 <= id_data2;
            ex_imm <= id_imm;
        end
    end
    
    assign data2 = (ex_ALUSrc) ? ex_imm : ex_data2;
    assign ex_aluResult = (ex_ALUCtrl == AND) ? ex_data1 & data2 :
                       (ex_ALUCtrl == OR)  ? ex_data1 | data2 :
                       (ex_ALUCtrl == ADD) ? ex_data1 + data2 :
                       (ex_ALUCtrl == SUB) ? ex_data1 - data2 :
                       (ex_ALUCtrl == SLT) ? ($signed(ex_data1) < $signed(data2)) :
                       (ex_ALUCtrl == XOR) ? ex_data1 ^ data2 : 0;
    assign ex_Zero = (ex_aluResult == 0) ? 1'b1 : 1'b0;
    assign ex_branch_target = ex_PC + ex_branch_offset;
    assign ALUResult = ex_aluResult;
    //////////////////////////////////////////////////////////////////////
    // MEM: Memory Access
    //////////////////////////////////////////////////////////////////////
    //EX to MEM control signals
    always_ff@ (posedge clk) begin
        if (rst | mem_PCSrc) begin
            mem_MemWrite <= 0;
            mem_MemRead <= 0;
            mem_Branch <= 0;
            mem_RegWrite <= 0;
            mem_MemtoReg <= 0;
        end
        else begin
            mem_MemWrite <= ex_MemWrite;
            mem_MemRead <= ex_MemRead;
            mem_Branch <= ex_Branch;
            mem_RegWrite <= ex_RegWrite;
            mem_MemtoReg <= ex_MemtoReg;
        end
    end
    
    //EX to MEM rd signal
    always_ff@ (posedge clk) begin
        if (rst) mem_rd <= 0;
        else mem_rd <= ex_rd;
    end
    
    //EX to MEM Zero and branch_target signals
    always_ff@ (posedge clk) begin
        if (rst) begin
            mem_Zero <= 0;
            mem_branch_target <= 0;
        end
        else begin
            mem_Zero <= ex_Zero;
            mem_branch_target <= ex_branch_target;
        end
    end
    
    //EX to MEM write_data signal
    always_ff@ (posedge clk) begin
        if (rst) mem_write_data <= 0;
        else mem_write_data <= ex_data2;
    end
    
    //EX to MEM aluResult signal
    always_ff@ (posedge clk) begin
        if (rst) mem_aluResult <= 0;
        else mem_aluResult <= ex_aluResult;
    end
    
    assign mem_PCSrc = mem_Zero & mem_Branch;
 
    assign MemWrite = mem_MemWrite;
    assign MemRead = mem_MemRead;
    assign dAddress = mem_aluResult;
    assign dWriteData = mem_write_data;
    assign mem_read_data = dReadData;
    
    //////////////////////////////////////////////////////////////////////
    // WB: Write-Back
    //////////////////////////////////////////////////////////////////////
    //MEM to WB control signals
    always_ff@ (posedge clk) begin
        if (rst) begin
            wb_RegWrite <= 0;
            wb_MemtoReg <= 0;
        end
        else begin
            wb_RegWrite <= mem_RegWrite;
            wb_MemtoReg <= mem_MemtoReg;
        end
    end
    
    //MEM to WB aluResult
    always_ff@ (posedge clk) begin
        if (rst) wb_aluResult <= 0;
        else wb_aluResult <= mem_aluResult;
    end
    
    assign wb_read_data = dReadData;
    assign wb_WriteData = (wb_MemtoReg) ? wb_read_data : wb_aluResult;
   
    always_ff@ (posedge clk) begin
        if (rst) wb_rd <= 0;
        else wb_rd <= mem_rd;
    end
     
    /////////////////////
    // Top-Level Ports //
    /////////////////////   
       
    assign WriteBackData = wb_WriteData;
    
endmodule
