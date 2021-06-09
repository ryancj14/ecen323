`timescale 1ns / 1ps
/***************************************************************************
* 
* Module: vga_object
*
* Author: Ryan Johnson
* Class: ECEN 323, Section 01, Winter 2020
* Date: 24 January 2020
*
* Description: top module for displaying on vga according to buttons pressed.
*
****************************************************************************/

module vga_object(
    input wire clk,
    input wire btnc,
    input wire btnl,
    input wire btnr,
    input wire btnd,
    input wire btnu,
    input wire [11:0] sw,
    output logic hs,
    output logic vs,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic [7:0] seg,
    output logic [7:0] anode
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
    
    //register for hs and vs to avoid glitches in timing signals
    always_ff@(posedge clk)
    begin
        hs <= hsreg;
        vs <= vsreg;
    end
    
    localparam CLOCKS_PER_PIXEL_CLK = 4;
    logic [1:0] pixel_cnt;
    logic [15:0] frame_cnt;
    logic frame_en;
    always_ff@(posedge clk)
    begin   
        if (btnc)
            pixel_cnt <= 0;
        else 
            pixel_cnt <= pixel_cnt + 1;
    end
    assign frame_en = (pixel_cnt == CLOCKS_PER_PIXEL_CLK - 1) ? 1'b1 : 1'b0;
    always_ff@(posedge clk)
    begin
        if(btnc)
            frame_cnt <= 0;
        else if(frame_en && last_row && last_column) 
            frame_cnt <= frame_cnt + 1;
    end
    
    logic[31:0] dataIn = {16'h0000,frame_cnt};
    SevenSegmentControl ss1(.clk(clk),.reset(btnc),.dataIn(dataIn),.digitDisplay(8'h0F),.digitPoint(8'h00),.anode(anode),.segment(seg));
    
    logic red_square_on;
    logic [11:0] red_square_rgb;
    logic green_square_on;
    logic [11:0] green_square_rgb;
    logic yellow_square_on;
    logic [11:0] yellow_square_rgb;
    logic magenta_square_on;
    logic [11:0] magenta_square_rgb;
    logic [11:0] background_rgb;
    logic [11:0] blank_rgb;
    logic [11:0] nb_rgb_out;
    logic [11:0] lb_rgb_out;
    logic [11:0] rb_rgb_out;
    logic [11:0] ub_rgb_out;
    logic [11:0] db_rgb_out;
    logic [11:0] rgb_out;
    
    localparam MAX = 4'b1111;
    localparam MIN = 4'b0000;
    assign blank_rgb = {MIN,MIN,MIN};
    assign ub_rgb_out = {MIN,MIN,MIN};
    assign db_rgb_out = {MAX,MAX,MAX};
    assign rb_rgb_out = sw;
    
    assign red_square_on = ((pixel_x >= 180 && pixel_x < 280) &&
                         (pixel_y >= 100 && pixel_y < 200));
    assign red_square_rgb = {MAX,MIN,MIN};
    assign green_square_on = ((pixel_x >= 400 && pixel_x < 500) &&
                     (pixel_y >= 100 && pixel_y < 200));
    assign green_square_rgb = {MIN,MAX,MIN};
    assign yellow_square_on = ((pixel_x >= 180 && pixel_x < 280) &&
                     (pixel_y >= 300 && pixel_y < 400));
    assign yellow_square_rgb = {MAX,MAX,MIN};
    assign magenta_square_on = ((pixel_x >= 400 && pixel_x < 500) &&
                     (pixel_y >= 300 && pixel_y < 400));
    assign magenta_square_rgb = {MAX,MIN,MAX};
    assign background_rgb = {MAX,MAX,MAX};
    
    assign nb_rgb_out = red_square_on ? red_square_rgb :
                        green_square_on ? green_square_rgb :
                        yellow_square_on ? yellow_square_rgb :
                        magenta_square_on ? magenta_square_rgb :
                        background_rgb;
                     
    localparam BLACK = 79;
    localparam BLUE = 159;
    localparam GREEN = 239;
    localparam CYAN = 319;
    localparam RED = 399;
    localparam MAGENTA = 479;
    localparam YELLOW = 559;
    logic [3:0] red_color;
    logic [3:0] green_color;
    logic [3:0] blue_color;

    assign red_color = (pixel_x <= CYAN) ? MIN : MAX;
                       
    assign green_color = (pixel_x <= BLUE)   ? MIN : 
                         (pixel_x <= CYAN)   ? MAX : 
                         (pixel_x <= MAGENTA)? MIN : MAX;       
    
    assign blue_color = (pixel_x <= BLACK)  ? MIN :
                        (pixel_x <= BLUE)   ? MAX : 
                        (pixel_x <= GREEN)  ? MIN :
                        (pixel_x <= CYAN)   ? MAX : 
                        (pixel_x <= RED)    ? MIN :
                        (pixel_x <= MAGENTA)? MAX :
                        (pixel_x <= YELLOW) ? MIN : MAX;
        
    assign lb_rgb_out = {red_color, green_color, blue_color};
    
    assign rgb_out = blank ? blank_rgb :
                     btnl ? lb_rgb_out :
                     btnr ? rb_rgb_out :
                     btnu ? ub_rgb_out :
                     btnd ? db_rgb_out :
                     nb_rgb_out;
    
    always_ff@(posedge clk)
    begin            
        vgaRed <= rgb_out[11:8];
        vgaGreen <= rgb_out[7:4];
        vgaBlue <= rgb_out[3:0];
    end
    
endmodule
