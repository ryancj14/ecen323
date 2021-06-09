`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: riscv_simple_datapath
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 11 Feb 2020
*
* Description: acts as a datapath to process instructions
*
****************************************************************************/

module riscv_simple_datapath #(parameter INITIAL_PC = 32'h00400000) (
    input wire logic clk,
    input wire logic rst,
    input wire logic [31:0] instruction,
    input wire logic PCSrc,
    input wire logic ALUSrc,
    input wire logic RegWrite,
    input wire logic [3:0] ALUCtrl,
    output logic [31:0] PC,
    output logic Zero,
    output logic [31:0] dAddress,
    output logic [31:0] dWriteData,
    input wire logic [31:0] dReadData,
    input wire logic MemtoReg
    );
    
    logic [31:0] RF[31:0]; 
   
    integer i; // i needs to be declared before it is used
    initial
    for (i = 0; i < 32; i=i+1)
        RF[i] = 0; // initializes each register to 0
    
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd = instruction[11:7];
    logic [31:0] writeDataR;
    logic [31:0] aluResult;
    
    assign writeDataR = (MemtoReg) ? dReadData : aluResult;
    
    //writes data to the specified register if RegWrite is asserted
    always_ff@ (posedge clk)
        if (RegWrite && rd != 0) RF[rd] <= writeDataR;
    
    logic [31:0] data1;
    logic [31:0] data2;
    logic [31:0] imm;
    logic [31:0] immI;
    logic [31:0] immS;
    localparam SOpCode = 7'b0100011;
    assign immI = {{20{instruction[31]}},instruction[31:20]};
    assign immS = {{20{instruction[31]}},instruction[31:25],instruction[11:7]};
    assign imm = (instruction[6:0] == SOpCode) ? immS : immI;
    assign data1 = RF[rs1];
    assign data2 = (ALUSrc) ? imm:
                              RF[rs2];
    logic [31:0] writeDataM;
    assign writeDataM = RF[rs2];
    
    localparam AND = 4'b0000;
    localparam OR  = 4'b0001;
    localparam ADD = 4'b0010;
    localparam SUB = 4'b0110;
    localparam SLT = 4'b0111;
    localparam XOR = 4'b1100;
    
    assign aluResult = (ALUCtrl == AND) ? data1 & data2 :
                       (ALUCtrl == OR)  ? data1 | data2 :
                       (ALUCtrl == ADD) ? data1 + data2 :
                       (ALUCtrl == SUB) ? data1 - data2 :
                       (ALUCtrl == SLT) ? ($signed(data1) < $signed(data2)) :
                       (ALUCtrl == XOR) ? data1 ^ data2 : 0;
    assign Zero = (aluResult == 0) ? 1'b1 : 1'b0;
    
    localparam usual_offset = 4;
    logic [31:0] branch_offset;
    assign branch_offset = {{20{instruction[31]}},instruction[7],instruction[30:25],instruction[11:8],1'b0};
    // updates the pc to pc + 4 or to pc + branch_offset
    always_ff@ (posedge clk)
        if (rst) PC <= INITIAL_PC;
        else if (PCSrc) PC <= PC + branch_offset;
        else PC <= PC + usual_offset;
    
    always_comb
    begin
        dWriteData = writeDataM;
        dAddress = aluResult;
    end     
    
endmodule
