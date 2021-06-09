-------------------------------------------------------------------------------
-- Filename:        tb_vga_timiong.vhd
--
-- Description:     Simple testbench for VGA controller
-- 
-- Author:          Mike Wirthlin
--
-- Revision:        1.5
--   1.5 : Changed testbench for a 100 MHz clock
--   1.4 : Used component declaration instead of entity declaration
--
-- To Do:
--  - A student created logic for the annodes that placed the "blank"
--    as highest priroity over the an select. This was not caught by the
--    testbench. Create a test in which multiple segemtns are begin blanked,
--    and check to makes sure the corresponding segments are turned in (or not
--    on) in the proper order. Make sure you don't blank other segments when
--    you blank one segment.
--  - Need to change the testbench so that there is a timeout - if the VS signal
--    does not change in some minimum time, give an error message. Some students are
--    simulating for long periods of time (Seconds!) before giving up.
-- Description:
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_vga_timing is
end tb_vga_timing;

architecture testbench of tb_vga_timing is


  signal t_clk, t_rst: std_logic;
  signal t_HS, t_VS, t_blank : std_logic;
  signal t_pixel_x : std_logic_vector(9 downto 0);
  signal t_pixel_y : std_logic_vector(9 downto 0);
  signal t_column : unsigned(9 downto 0);
  signal t_row : unsigned(9 downto 0);
  signal t_last_column, t_last_row : std_logic;
  signal clk50MHz : std_logic := '0';
  
  constant UNINIT_STARTUP_TIME : time := 200 ns;
 
  constant CLOCK_PERIOD : time := 10 ns;
  constant PIXEL_PERIOD : time := 4 * CLOCK_PERIOD;
  constant HALF_CLOCK_PERIOD : time := CLOCK_PERIOD / 2;
  constant UNINITIALIZED_TIME : time := 500 ns;
  constant CLOCK_INIT_TIME : time := 500 ns;
  constant RESET_RELEASE_TIME : time := CLOCK_INIT_TIME + 500 ns;
  constant POST_RESET_TEST_TIME : time := 45 ms;
    
  ----------------------------------------------------------------
  -- Horizontal timing constants
  ----------------------------------------------------------------
  constant HORIZONTAL_DISPLAY_CLOCKS : INTEGER := 640;
  constant HORIZONTAL_PULSE_CLOCKS : Integer := 96;
  constant HORIZONTAL_FRONT_PORCH_CLOCKS : Integer := 16;
  constant HORIZONTAL_BACK_PORCH_CLOCKS : Integer := 48;
  constant HORIZONTAL_LINE_CLOCKS : Integer :=
    HORIZONTAL_DISPLAY_CLOCKS + HORIZONTAL_PULSE_CLOCKS +
    HORIZONTAL_FRONT_PORCH_CLOCKS +HORIZONTAL_BACK_PORCH_CLOCKS;
    
  -- 96 pixel clocks (3840 ns)
  constant HS_LOW_TIME : time := PIXEL_PERIOD * HORIZONTAL_PULSE_CLOCKS;
  -- 800-96=704 pixel clocks (28160 ns)
  constant HS_HIGH_TIME : time := PIXEL_PERIOD *
    (HORIZONTAL_DISPLAY_CLOCKS + HORIZONTAL_FRONT_PORCH_CLOCKS +
     HORIZONTAL_BACK_PORCH_CLOCKS);
  constant HS_BACK_PORCH_TIME : time :=
    PIXEL_PERIOD * HORIZONTAL_BACK_PORCH_CLOCKS;
  constant HS_FRONT_PORCH_TIME : time :=
    PIXEL_PERIOD * HORIZONTAL_FRONT_PORCH_CLOCKS;
  constant HORIZONTAL_LINE_TIME : time :=
    PIXEL_PERIOD * HORIZONTAL_LINE_CLOCKS;
  
  ----------------------------------------------------------------
  -- Vertical timing constants
  ----------------------------------------------------------------
  constant VERTICAL_DISPLAY_LINES : INTEGER := 480;
  constant VERTICAL_PULSE_LINES : Integer := 2;
  constant VERTICAL_FRONT_PORCH_LINES : Integer := 10;
  constant VERTICAL_BACK_PORCH_LINES : Integer := 29;
  constant VERTICAL_BACK_PORCH_TIME : Time :=
    (HORIZONTAL_LINE_TIME * VERTICAL_BACK_PORCH_LINES);
  constant VERTICAL_FRONT_PORCH_TIME : Time :=
    (HORIZONTAL_LINE_TIME * VERTICAL_FRONT_PORCH_LINES);
  -- 2 lines = 2x800 = 1600 clocks (64,000 ns)
  --constant VS_LOW_TIME : time := 30080 ns;
  constant VS_LOW_TIME : time := VERTICAL_PULSE_LINES * HORIZONTAL_LINE_TIME;
  -- 521-2 lines = 519x800 = 415200 clocks (1660800)
  -- 0-479: display
  -- 480-489: front porch
  -- 490-491: pulse
  --constant VS_HIGH_TIME : time := 16353920 ns;
  constant VS_HIGH_TIME : time := HORIZONTAL_LINE_TIME * (
    VERTICAL_DISPLAY_LINES + VERTICAL_FRONT_PORCH_LINES +
    VERTICAL_BACK_PORCH_LINES);
  
  type CLOCK_STATE_TYPE is (uninitialized, zero, running);
  signal clock_state : CLOCK_STATE_TYPE;
  
  signal full_frame_count : Integer := 0;
  
  component vga_timing
    port(
      clk : in std_logic;
      rst : in std_logic;
      HS : out std_logic;
      VS : out std_logic;
      pixel_x : out std_logic_vector(9 downto 0);
      pixel_y : out std_logic_vector(9 downto 0);
      last_column : out std_logic;
      last_row : out std_logic;
      blank : out std_logic
    );
  end component;

  
begin  -- testbench

  --------------------------------------------------
  -- Main testbench process:
  --------------------------------------------------

  process
  begin

    --report "--- Begin with input signals uninitialized ---";
    clock_State <= uninitialized;
    t_rst <= 'U';
    wait for UNINITIALIZED_TIME;
    
    --report "--- Start Clock Without Reset ---";
    clock_State <= zero;
    wait for CLOCK_INIT_TIME;
    clock_state <= running;
    wait for CLOCK_INIT_TIME;
    
    --report "--- Issue Reset  ---";
    t_rst <= '1';
    wait for RESET_RELEASE_TIME;
    
    --report "--- Release Reset  ---";
    t_rst <= '0';

    -- The initialization is over. Let the timing generator
    -- run for a while
    wait until full_frame_count = 1;
      
    report "--- Done  ---";
    wait;
    
  end process;
    

  ----------------------------------------------------------------------
  -- Instance Design under test
  ----------------------------------------------------------------------
  uut: vga_timing
    port map (
      clk => t_clk,
      rst => t_rst,
      HS => t_HS,
      VS => t_VS,
      pixel_x => t_pixel_x,
      pixel_y => t_pixel_y,
      last_column => t_last_column,
      last_row => t_last_row,
      blank => t_blank);
      
  t_column <= unsigned(t_pixel_x);
  t_row <= unsigned(t_pixel_y);
  
  ---------------------------------------------------------------
  -- Check the last_column signal
  ---------------------------------------------------------------
  process
    variable L : LINE;
    variable print_message : boolean := false;
  begin
    wait until t_last_column'event or t_column'event;
    wait until t_last_column'stable(1 ns) or t_column'stable(1 ns);
    print_message := false;
    if (t_last_column = '1' and t_column /= HORIZONTAL_DISPLAY_CLOCKS-1) then
      write(L, string'("Error: last_column asserted when pixel_x="));
      write(L, to_integer(t_column));
      print_message := true;
    end if;
    if (t_last_column = '0' and t_column = HORIZONTAL_DISPLAY_CLOCKS-1) then
      write(L, string'("Error: last_column not asserted when pixel_x="));
      write(L, to_integer(t_column));
      print_message := true;
    end if;
    if (print_message) then
      write(L, string'(" at time:"));
      write(L, NOW);
      writeline(output, L);
    end if;
  end process;

  ---------------------------------------------------------------
  -- Check the last_row signal
  ---------------------------------------------------------------
  process
    variable L : LINE;
    variable print_message : boolean := false;
  begin
    wait until t_last_row'event or t_row'event;
    wait until t_last_row'stable(1 ns) or t_row'stable(1 ns);
    print_message := false;
    if (t_last_row = '1' and t_row /= VERTICAL_DISPLAY_LINES-1) then
      write(L, string'("Error: last_row asserted when pixel_y="));
      write(L, to_integer(t_row));
      print_message := true;
    end if;
    if (t_last_row = '0' and t_column = VERTICAL_DISPLAY_LINES-1) then
      write(L, string'("Error: last_ROW not asserted when pixel_Y="));
      write(L, to_integer(t_ROW));
      print_message := true;
    end if;
    if (print_message) then
      write(L, string'(" at time:"));
      write(L, NOW);
      writeline(output, L);
    end if;
  end process;
  
  ---------------------------------------------------------------
  -- Check the BLANK signal
  ---------------------------------------------------------------
  process
    variable L : LINE;
    variable print_message : boolean := false;
  begin
    wait until t_blank'event or t_column'event or t_row'event;
    wait until t_blank'stable(1 ns) or t_column'stable(1 ns) or t_row'stable(1 ns);

    print_message := false;
    
    -- Check blank high signal
    if (t_blank = '1' and (t_column < HORIZONTAL_DISPLAY_CLOCKS
                           and t_row < VERTICAL_DISPLAY_LINES)) then
      write(L, string'("Error: blank asserted when pixel_x="));
      write(L, to_integer(t_column));
      write(L, string'(" and pixel_y="));
      write(L, to_integer(t_row));
      print_message := true;
    end if;
    
    -- Check blank high signal
    if (t_blank = '0' and (t_column >= HORIZONTAL_DISPLAY_CLOCKS
                           or t_row >= VERTICAL_DISPLAY_LINES)) then
      write(L, string'("Error: blank de-asserted when pixel_x="));
      write(L, to_integer(t_column));
      write(L, string'(" and pixel_y="));
      write(L, to_integer(t_row));
      print_message := true;
    end if;
    
    if (print_message) then
      write(L, string'(" at time:"));
      write(L, NOW);
      writeline(output, L);
    end if;

  end process;

  ---------------------------------------------------------------
  -- Check the HS signal. Measure both the high and low time
  ---------------------------------------------------------------
  process
    variable hs_falling_edge_time, hs_rising_edge_time,
      hs_low_time_measured, hs_high_time_measured : time;
    variable L : LINE;
  begin
    -- Wait until a falling edge on HS
    wait until t_hs'event and t_hs = '0';
    hs_falling_edge_time := NOW;

    -- Wait until a rising edge on HS (measure HS low time)
    wait until t_hs'event and t_hs = '1';
    hs_rising_edge_time := NOW;
    hs_low_time_measured := hs_rising_edge_time - hs_falling_edge_time;
    if (hs_low_time_measured /= HS_LOW_TIME) then
      --report "Incorrect HS Timing" severity error;
      write(L, string'("Incorrect HS low time. HS low measured at "));
      write(L, hs_low_time_measured);
      write(L, string'(" but expecting "));
      write(L, HS_LOW_TIME);
      write(L, string'(" at time:"));
      write(L, NOW);
      writeline(output, L);
    end if;

    -- Wait until a falling edge on HS (measure HS high time)
    wait until t_hs'event and t_hs = '0';
    hs_falling_edge_time := NOW;
    hs_high_time_measured := hs_falling_edge_time - hs_rising_edge_time;
    if (hs_high_time_measured /= HS_HIGH_TIME) then
      write(L, string'("Incorrect HS high time. HS high measured at "));
      write(L, hs_high_time_measured);
      write(L, string'(" but expecting "));
      write(L, HS_HIGH_TIME);
      write(L, string'(" at time:"));
		write(L, NOW);
      writeline(output, L);
    end if;
    
  end process;

  ---------------------------------------------------------------
  -- Check the horizontal back porch and front porch times
  ---------------------------------------------------------------
  process
    variable edge_time,
      h_back_porch, h_front_porch : time;
    variable L : LINE;
  begin

    -- Wait until a rising edge on HS
    wait until t_rst = '0' and t_hs'event and t_hs = '1';
    edge_time := NOW;

    -- Wait until the pixel_x = 0
    wait until t_pixel_x'event and unsigned(t_pixel_x) = 0;
    h_back_porch := NOW - edge_time;
    if (h_back_porch /= HS_BACK_PORCH_TIME) then
      write(L, string'("Incorrect H back porch time. Measured at "));
      write(L, h_back_porch);
      write(L, string'(" but expecting "));
      write(L, HS_BACK_PORCH_TIME);
      write(L, string'(" at time:"));
		write(L, NOW);
      writeline(output, L);
    end if;

    -- Wait until the last pixel has ended
    wait until t_pixel_x'event and unsigned(t_pixel_x) = HORIZONTAL_DISPLAY_CLOCKS;
    edge_time := NOW;
    wait until t_hs'event and t_hs = '0';
    h_front_porch := NOW - edge_time;
    if (h_front_porch /= HS_FRONT_PORCH_TIME) then
      write(L, string'("Incorrect H front porch time. Measured at "));
      write(L, h_back_porch);
      write(L, string'(" but expecting "));
      write(L, HS_FRONT_PORCH_TIME);
      write(L, string'(" at time:"));
		write(L, NOW);
      writeline(output, L);
    end if;
    
  end process;

  
  ---------------------------------------------------------------
  -- Response: check the VS signal
  ---------------------------------------------------------------
  process
    variable vs_falling_edge_time, vs_rising_edge_time,
      vs_low_time_measured, vs_high_time_measured : time;
    variable L : LINE;
  begin
    -- Wait until a falling edge on VS
    wait until t_vs'event and t_vs = '0';
    vs_falling_edge_time := NOW;
	 
	 -- wait until the rising edge on VS (measure VS low time)
    wait until t_vs'event and t_vs = '1';
    vs_rising_edge_time := NOW;
    vs_low_time_measured := vs_rising_edge_time - vs_falling_edge_time;

    if (vs_low_time_measured /= VS_LOW_TIME) then
      report "Incorrect VS Timing" severity error;
      write(L, string'("Incorrect VS low time. VS low measured at "));
      write(L, vs_low_time_measured);
      write(L, string'(" but expecting "));
      write(L, VS_LOW_TIME);
      write(L, string'(" at time:"));
      write(L, vs_rising_edge_time);
      writeline(output, L);
    end if;

    wait until t_vs'event and t_vs = '0';
    vs_falling_edge_time := NOW;
    vs_high_time_measured := vs_falling_edge_time - vs_rising_edge_time;

    if (vs_high_time_measured /= VS_HIGH_TIME) then
      report "Incorrect VS Timing" severity error;
      write(L, string'("Incorrect VS high time. VS high measured at "));
      write(L, vs_high_time_measured);
      write(L, string'(" but expecting "));
      write(L, VS_HIGH_TIME);
      write(L, string'(" at time:"));
      write(L, vs_falling_edge_time);
      writeline(output, L);
    end if;
	 
	 full_frame_count <= full_frame_count + 1;

  end process;
      
  ---------------------------------------------------------------
  -- Check the vertical back porch and front porch times
  ---------------------------------------------------------------
  process
    variable edge_time,
      v_back_porch, V_front_porch : time;
    variable L : LINE;
  begin

    -- Wait until a rising edge on VS
    wait until t_rst = '0' and t_VS'event and t_vs = '1';
    edge_time := NOW;

    -- Wait until the pixel_y = 0
    wait until t_pixel_y'event and unsigned(t_pixel_y) = 0;
    v_back_porch := NOW - edge_time;
    if (v_back_porch /= VERTICAL_BACK_PORCH_TIME) then
      write(L, string'("Incorrect VS back porch time. Measured at "));
      write(L, v_back_porch);
      write(L, string'(" but expecting "));
      write(L, VERTICAL_BACK_PORCH_TIME);
      write(L, string'(" at time:"));
		write(L, NOW);
      writeline(output, L);
    end if;

    -- Wait until the last pixel has ended
    wait until t_pixel_y'event and unsigned(t_pixel_y) = VERTICAL_DISPLAY_LINES;
    edge_time := NOW;
    wait until t_Vs'event and t_vs = '0';
    v_front_porch := NOW - edge_time;
    if (v_front_porch /= VERTICAL_FRONT_PORCH_TIME) then
      write(L, string'("Incorrect V front porch time. Measured at "));
      write(L, v_back_porch);
      write(L, string'(" but expecting "));
      write(L, VERTICAL_FRONT_PORCH_TIME);
      write(L, string'(" at time:"));
		write(L, NOW);
      writeline(output, L);
    end if;
    
  end process;

  --------------------------------------------------
  -- Clock generation statement
  --------------------------------------------------
  with clock_state select
    t_clk <= 'U' when uninitialized,
        '0' when zero,
         clk50MHz when others;
  clk50MHz <= not clk50MHz after HALF_CLOCK_PERIOD;
              
end testbench;
