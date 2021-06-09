`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: riscv_simple_datapath
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 11 Feb 2020
*
* Description: acts as a control that implements one instruction at a time
*
****************************************************************************/

module riscv_single_cycle #(parameter INITIAL_PC = 32'h00400000) (
    input wire logic clk,
    input wire logic rst,
    input wire logic [31:0] instruction,
    input wire logic [31:0] dReadData,
    output logic [31:0] PC,
    output logic [31:0] dAddress,
    output logic [31:0] dWriteData,
    output logic MemRead,
    output logic MemWrite
    );
    
    logic PCSrc;
    logic ALUSrc;
    logic MemtoReg;
    logic RegWrite;
    logic Zero;
    logic [3:0] ALUCtrl;
    riscv_simple_datapath d212(.clk(clk), .rst(rst), .instruction(instruction), 
                               .PCSrc(PCSrc), .ALUSrc(ALUSrc), .RegWrite(RegWrite), 
                               .ALUCtrl(ALUCtrl), .PC(PC), .Zero(Zero), 
                               .dAddress(dAddress), .dWriteData(dWriteData), 
                               .dReadData(dReadData), .MemtoReg(MemtoReg));
    
    localparam AND = 4'b0000;
    localparam OR  = 4'b0001;
    localparam ADD = 4'b0010;
    localparam SUB = 4'b0110;
    localparam SLT = 4'b0111;
    localparam XOR = 4'b1100;
    logic store;
    logic load;
    logic branch;
    logic itype;
    logic [6:0] opcode;
    logic [2:0] funct3;
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign store = (opcode == 7'b0100011) ? 1'b1 : 1'b0;
    assign load  = (opcode == 7'b0000011) ? 1'b1 : 1'b0;
    assign branch = (opcode == 7'b1100011) ? 1'b1 : 1'b0;
    assign itype = (opcode == 7'b0010011) ? 1'b1 : 1'b0;
    assign ALUCtrl = (funct3 == 3'b111) ? AND :
                     (funct3 == 3'b110) ? OR  :
                     (funct3 == 3'b100) ? XOR :
                     (store || load)    ? ADD :
                     (funct3 == 3'b010) ? SLT :
                     (branch)           ? SUB :
                     (itype)            ? ADD :
                     (instruction[30] == 1'b1) ? SUB : ADD;
    
    always_comb
    begin
        ALUSrc = itype | load | store;
        PCSrc = branch & Zero;
        MemtoReg = load;
        MemRead = load;
        MemWrite = store;
        RegWrite = (!branch & !store);
    end
    
endmodule
