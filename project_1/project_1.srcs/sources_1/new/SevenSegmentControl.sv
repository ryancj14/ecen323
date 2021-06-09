`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: SevenSegmentControl
*
* Author: Johnson, Ryan
* Class: ECEN 220, Section 2, Winter 2019
* Date: 12 March 2019
*
* Description: Control a Seven Segment Display
*
*
****************************************************************************/

module SevenSegmentControl(
    input clk,
    input [31:0] dataIn,
    input [7:0] digitDisplay,
    input [7:0] digitPoint,
    output [7:0] anode,
    output [7:0] segment
    );
    
    logic[16:0] q = 0;
    always_ff @(posedge clk)
    begin
        q <= q + 1;
    end
    
    logic[2:0] digitSelect;
    assign digitSelect = q[16:14];
    logic[7:0] digitChosen;
    
    assign digitChosen = (digitSelect == 3'b000) ? 8'b00000001 :
                         (digitSelect == 3'b001) ? 8'b00000010 :
                         (digitSelect == 3'b010) ? 8'b00000100 :
                         (digitSelect == 3'b011) ? 8'b00001000 :
                         (digitSelect == 3'b100) ? 8'b00010000 :
                         (digitSelect == 3'b101) ? 8'b00100000 :
                         (digitSelect == 3'b110) ? 8'b01000000 :
                         (digitSelect == 3'b111) ? 8'b10000000 : 8'b00000000;
           
    assign anode = ~(digitChosen & digitDisplay);
    
    logic[3:0] dataToUse;
    assign dataToUse = (digitSelect == 3'b000) ? dataIn[3:0] :
                       (digitSelect == 3'b001) ? dataIn[7:4] :
                       (digitSelect == 3'b010) ? dataIn[11:8] :
                       (digitSelect == 3'b011) ? dataIn[15:12] :
                       (digitSelect == 3'b100) ? dataIn[19:16] :
                       (digitSelect == 3'b101) ? dataIn[23:20] :
                       (digitSelect == 3'b110) ? dataIn[27:24] :
                       (digitSelect == 3'b111) ? dataIn[31:28] : 4'b0000;
           
    assign segment[6:0] = (dataToUse == 4'b0000) ? 7'b1000000 :
                          (dataToUse == 4'b0001) ? 7'b1111001 :
                          (dataToUse == 4'b0010) ? 7'b0100100 :
                          (dataToUse == 4'b0011) ? 7'b0110000 :
                          (dataToUse == 4'b0100) ? 7'b0011001 :
                          (dataToUse == 4'b0101) ? 7'b0010010 :
                          (dataToUse == 4'b0110) ? 7'b0000010 :
                          (dataToUse == 4'b0111) ? 7'b1111000 :
                          (dataToUse == 4'b1000) ? 7'b0000000 :
                          (dataToUse == 4'b1001) ? 7'b0010000 :
                          (dataToUse == 4'b1010) ? 7'b0001000 :
                          (dataToUse == 4'b1011) ? 7'b0000011 :
                          (dataToUse == 4'b1100) ? 7'b1000110 :
                          (dataToUse == 4'b1101) ? 7'b0100001 :
                          (dataToUse == 4'b1110) ? 7'b0000110 :
                          (dataToUse == 4'b1111) ? 7'b0001110 : 7'b0000000;
    
    assign segment[7] = (digitSelect == 3'b000) ? ~digitPoint[0] :
                        (digitSelect == 3'b001) ? ~digitPoint[1] :
                        (digitSelect == 3'b010) ? ~digitPoint[2] :
                        (digitSelect == 3'b011) ? ~digitPoint[3] :
                        (digitSelect == 3'b100) ? ~digitPoint[4] :
                        (digitSelect == 3'b101) ? ~digitPoint[5] :
                        (digitSelect == 3'b110) ? ~digitPoint[6] :
                        (digitSelect == 3'b111) ? ~digitPoint[7] : 1'b1;
    
endmodule
