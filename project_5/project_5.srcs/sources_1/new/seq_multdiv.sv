`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: seq_multdiv
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 7 Feb 2020
*
* Description: multiplies or divides and writes the result to the outputs
*
****************************************************************************/

module seq_multdiv(
    input wire clk,
    input wire rst,
    input wire start,
    input wire op,
    input wire [31:0] a,
    input wire [31:0] b,
    output logic busy,
    output logic [31:0] r1,
    output logic [31:0] r2
    );
    
    logic [31:0] multiplier;
    logic [31:0] multiplicand;
    logic [31:0] divisor;
    logic [31:0] dividend;
    assign multiplicand = a;
    assign dividend = a;
    assign multiplier = b;
    assign divisor = b;
    
    logic mult_start;
    logic div_start;
    logic mult_busy;
    logic div_busy;
    logic held_op;
    
    always_ff@ (posedge clk) 
    begin
        if(start && !busy) held_op <= op;
    end
      
    assign mult_start = (!op && !busy && start) ? 1'b1 : 1'b0;
                        
    assign div_start = (op && !busy && start) ? 1'b1 : 1'b0;              
    
    logic [63:0] mult_product;
    logic [31:0] div_quotient;
    logic [31:0] div_remainder;
    
    // connecting to seq_multiplier
    seq_multiplier m1(.clk(clk), .rst(rst), .start(mult_start), .multiplicand(multiplicand), 
        .multiplier(multiplier), .busy(mult_busy), .product(mult_product));
    
    // connecting to seq_divider
    seq_divider d1(.clk(clk), .rst(rst), .start(div_start), .dividend(dividend),
        .divisor(divisor), .busy(div_busy), .quotient(div_quotient), .remainder(div_remainder));
   
    // assign busy the correct value
    assign busy = held_op ? div_busy : mult_busy;
    
    // assign r1 and r2 the result of the operation
    always_comb
        if (held_op) 
        begin
            r1 = div_quotient;
            r2 = div_remainder;
        end
        else
        begin
            r1 = mult_product[31:0];
            r2 = mult_product[63:32];
        end
        
    
endmodule
