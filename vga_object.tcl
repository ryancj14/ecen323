restart

add_force clk {0 0} {1 5ns} -repeat_every 10ns
add_force btnc 1
run 300 ns

add_force btnc 0
add_force sw 0000101001011010
add_force btnl 0
add_force btnu 0
add_force btnr 0
add_force btnd 1
run 10000000 ns

add_force btnd 0
add_force btnr 1
run 10000000 ns

add_force btnr 0
add_force btnc 1
run 300 ns

add_force btnc 0
run 10000000 ns



