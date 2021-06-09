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

module seq_divider(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] divisor,
    input wire [31:0] dividend,
    output logic busy,
    output logic [31:0] quotient,
    output logic [31:0] remainder
    );
    
    logic[4:0] divide_cnt;
    localparam CNT_END = 5'b11111;
    logic state;
    localparam idle = 1'b0;
    localparam running = 1'b1;
  
    // increment counter when running
    always_ff@ (posedge clk)
    begin
        if (state == idle) divide_cnt <= 5'b00000;
        else divide_cnt <= divide_cnt + 1;
    end
    
    logic[63:0] remainder_reg;
    logic[31:0] divisor_reg;
    logic[31:0] update;
    
    //insert new divisor while idle;
    always_ff@ (posedge clk)
        if (state == idle) divisor_reg <= divisor;
        else divisor_reg <= divisor_reg;
    
    assign update = remainder_reg[62:31] - divisor_reg;   
    
    //reset state or go to next state;
    always_ff@ (posedge clk)
        if (rst) state <= idle;
        else if (start) state <= running;
        else if (divide_cnt == CNT_END) state <= idle;
        else state <= state;
    
    //assert busy when doing a division
    always_ff@ (posedge clk)
        if (rst) busy <= 1'b0;
        else if (start) busy <= 1'b1;
        else if (state == idle) busy <= 1'b0;
        else if (state == running) busy <= 1'b1;
        else busy <= 1'b0;
    
    //update remainder_reg every clock cycle
    always_ff@ (posedge clk)
        if (state == idle) remainder_reg <= {32'h0000, dividend};
        else if (state == running)
        begin
            if (remainder_reg[62:31] >= divisor_reg) 
                remainder_reg <= {update[31:0],remainder_reg[30:0],1'b1};
            else remainder_reg <= {remainder_reg[62:0],1'b0};
        end
        else remainder_reg <= remainder_reg;
        
    //put remainder_reg into remainder and quotient upon completion of calculation or set to zero at reset
    always_ff@ (posedge clk)
        if (divide_cnt == CNT_END) 
        begin
            if (remainder_reg[62:31] >= divisor_reg) 
            begin
                remainder <= update[31:0];
                quotient <= {remainder_reg[30:0], 1'b1};
            end
            else 
            begin
                remainder <= remainder_reg[62:31];
                quotient <= {remainder_reg[30:0], 1'b0};
            end
        end
        else if (rst)
        begin   
            remainder <= 32'h0000;
            quotient <= 32'h0000;
        end 
        else
        begin
            remainder <= remainder;
            quotient <= quotient;
        end
            
endmodule
