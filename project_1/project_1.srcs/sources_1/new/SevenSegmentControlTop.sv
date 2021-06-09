`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: SevenSegmentControlTop
*
* Author: Johnson, Ryan
* Class: ECEN 220, Section 2, Winter 2019
* Date: 12 March 2019
*
* Description: Control a Seven Segment Display
*
*
****************************************************************************/


module SevenSegmentControlTop(
    input clk,
    input [15:0] sw,
    input btnc,
    input btnr,
    output [7:0] segment,
    output [7:0] anode
    );
    logic [31:0] dataIn;
    logic [7:0] digitDisplay, digitPoint;
    
    assign dataIn[31:16] = 16'h8888;
    assign dataIn[15:0] = (btnc) ? 16'h8888:
                                   sw[15:0];
        
    assign digitDisplay = (btnc) ? 8'b11111111 :
                          (btnr) ? 8'b00000000 :
                                   8'b00001111 ;
                                   
    assign digitPoint = (btnc) ? 8'b11111111 :
                                 8'b00000000 ;
     
    SevenSegmentControl ctr1(clk, dataIn, digitDisplay, digitPoint, anode, segment);
    
endmodule
