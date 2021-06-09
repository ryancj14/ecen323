`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: vga_timing
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 13 January 2020
*
* Description: to correctly time a display on a vga screen
*
****************************************************************************/

module vga_timing(
    input wire logic clk,
    input wire logic rst,
    output logic hs,
    output logic vs,
    output logic [9:0] pixel_x,
    output logic [9:0] pixel_y,
    output logic last_column,
    output logic last_row,
    output logic blank
    );
    
    logic pixel_en;
    logic [1:0] pixel_cnt;
    
    localparam CLOCKS_PER_PIXEL_CLK = 4;
    localparam HORIZONTAL_PIXELS = 800;
    localparam VERTICAL_PIXELS = 521;
    localparam LAST_COLUMN = 639;
    localparam LAST_ROW = 479;
    localparam HOR_FRONT_PORCH = 16;
    localparam HOR_PULSE_WIDTH = 96;
    localparam VER_FRONT_PORCH = 10;
    localparam VER_PULSE_WIDTH = 2;
    
    // incrementing pixel_cnt to enable pixel_en every fourth clock
    always_ff@(posedge clk)
    begin
        if (rst)
            pixel_cnt <= 0;
        else
            pixel_cnt <= pixel_cnt +1;
    end
    
    assign pixel_en = (pixel_cnt == CLOCKS_PER_PIXEL_CLK - 1) ? 1'b1 : 1'b0;
    
    //incrementing pixel_x until it reaches max value HORIZONTAL_PIXELS
    always_ff@(posedge clk)
    begin
        if (rst)
            pixel_x <= 0;
        else if (pixel_en == 1'b1)
        begin    
            if (pixel_x == HORIZONTAL_PIXELS - 1)
                pixel_x <= 0;
            else
                pixel_x <= pixel_x +1;
        end
    end
    
    assign hs = (pixel_x <= LAST_COLUMN + HOR_FRONT_PORCH) ? 1 :
                (pixel_x <= LAST_COLUMN + HOR_FRONT_PORCH + HOR_PULSE_WIDTH) ? 0 : 1;
    assign last_column = (pixel_x == LAST_COLUMN) ? 1'b1 : 1'b0;
    
    //incrementing pixel_y after each row of pixel_x is incremented until it reaches max value VERTICAL_PIXELS
    always_ff@(posedge clk)
    begin
        if (rst)
            pixel_y <= 0;
        else if (pixel_en == 1'b1 && pixel_x == HORIZONTAL_PIXELS - 1)
        begin    
            if (pixel_y == VERTICAL_PIXELS - 1)
                pixel_y <= 0;
            else
                pixel_y <= pixel_y +1;
        end
    end
    
    assign vs = (pixel_y <= LAST_ROW + VER_FRONT_PORCH) ? 1 :
                (pixel_y <= LAST_ROW + VER_FRONT_PORCH + VER_PULSE_WIDTH) ? 0 : 1;
    assign last_row = (pixel_y == LAST_ROW) ? 1'b1 : 1'b0;
    
    assign blank = (pixel_x <= LAST_COLUMN && pixel_y <= LAST_ROW) ? 0 : 1;

endmodule









