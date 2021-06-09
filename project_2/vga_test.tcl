restart

add_force clk {0 0} {1 5} -repeat_every 10
add_force btnc 1
run 20ns;

add_force btnc 0;
run 300000000000ns;