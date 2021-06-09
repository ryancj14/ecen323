`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: seq_multiplier
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 3 Feb 2020
*
* Description: multiplies and writes the result to the product output
*
****************************************************************************/

module seq_multiplier(
    input wire logic clk,
    input wire logic rst,
    input wire logic start,
    input wire logic [31:0] multiplicand,
    input wire logic [31:0] multiplier,
    output logic busy,
    output logic [63:0] product
    );
    
    logic[4:0] mult_cnt;
    logic state;
    localparam idle = 1'b0;
    localparam running = 1'b1;
  
    // increment counter when running
    always_ff@ (posedge clk)
    begin
        if (state == idle) mult_cnt <= 5'b00000;
        else mult_cnt <= mult_cnt + 1;
    end
    
    logic[63:0] product_reg;
    logic[32:0] multiplicand33;
    logic[32:0] sum;
    logic write;
    
    //insert new multiplicand while idle;
    always_ff@ (posedge clk)
        if (state == idle) multiplicand33 <= {1'b0, multiplicand};
        else multiplicand33 <= multiplicand33;
        
    assign write = product_reg[0];
    
    assign sum = multiplicand33 + {1'b0, product_reg[63:32]};   
    
    //reset state or go to next state;
    always_ff@ (posedge clk)
        if (rst) state <= idle;
        else if (start) state <= running;
        else if (mult_cnt == 5'b11111) state <= idle;
        else state <= state;
    
    //assert busy when doing a multiplication
    always_ff@ (posedge clk)
        if (rst) busy <= 1'b0;
        else if (start) busy <= 1'b1;
        else if (state == idle) busy <= 1'b0;
        else if (state == running) busy <= 1'b1;
        else busy <= 1'b0;
    
    //update product_reg every clock cycle
    always_ff@ (posedge clk)
        if (state == idle) product_reg <= {32'b0, multiplier};
        else if (state == running)
        begin
            if (write) product_reg <= {sum, product_reg[31:1]};
            else product_reg <= {1'b0, product_reg[63:1]};
        end
        else product_reg <= product_reg;
        
    //put product_reg into product upon completion of calculation
    always_ff@ (posedge clk)
        if (mult_cnt == 5'b11111) 
        begin
            if (write) product <= {sum, product_reg[31:1]};
            else product <= {1'b0, product_reg[63:1]};
        end
        else product <= product;
    
endmodule
