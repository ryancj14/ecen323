`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: vga_test
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 24 January 2020
*
* Description: module to display four colored squares.
*
****************************************************************************/
module vga_test(
    input wire logic clk,
    input wire logic btnc,
    output logic hs,
    output logic vs,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue
    );
    
    logic hsreg;
    logic vsreg;
    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic last_column;
    logic last_row;
    logic blank;
    
    //instantiating our vga_timing module to get the various values through
    vga_timing v1(.clk(clk), .rst(btnc), .hs(hsreg), .vs(vsreg), .pixel_x(pixel_x), .pixel_y(pixel_y), .last_column(last_column), .last_row(last_row), .blank(blank) );
    
    //register for hs to avoid glitches in timing signals
    always_ff@(posedge clk)
        hs <= hsreg;
        
    //register for vs to avoid glitches in timing signals
    always_ff@(posedge clk)
        vs <= vsreg;
    
    logic red_square_on;
    logic [11:0] red_square_rgb;
    logic green_square_on;
    logic [11:0] green_square_rgb;
    logic yellow_square_on;
    logic [11:0] yellow_square_rgb;
    logic magenta_square_on;
    logic [11:0] magenta_square_rgb;
    logic [11:0] background_rgb;
    logic [11:0] rgb_out;
    
    assign red_square_on = ((pixel_x >= 180 && pixel_x < 280) &&
                         (pixel_y >= 100 && pixel_y < 200));
    assign red_square_rgb = {4'b1111,4'b0000,4'b0000};
    assign green_square_on = ((pixel_x >= 400 && pixel_x < 500) &&
                     (pixel_y >= 100 && pixel_y < 200));
    assign green_square_rgb = {4'b0000,4'b1111,4'b0000};
    assign yellow_square_on = ((pixel_x >= 180 && pixel_x < 280) &&
                     (pixel_y >= 300 && pixel_y < 400));
    assign yellow_square_rgb = {4'b1111,4'b1111,4'b0000};
    assign magenta_square_on = ((pixel_x >= 400 && pixel_x < 500) &&
                     (pixel_y >= 300 && pixel_y < 400));
    assign magenta_square_rgb = {4'b1111,4'b0000,4'b1111};
    assign background_rgb = {4'b1111,4'b1111,4'b1111};
    assign rgb_out = red_square_on ? red_square_rgb :
                     green_square_on ? green_square_rgb :
                     yellow_square_on ? yellow_square_rgb :
                     magenta_square_on ? magenta_square_rgb :
                     background_rgb;
    
    always_ff@(posedge clk)
    begin            
        vgaRed <= rgb_out[11:8];
        vgaGreen <= rgb_out[7:4];
        vgaBlue <= rgb_out[3:0];
    end
    
endmodule
