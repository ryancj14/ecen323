restart

add_force clk {0 0} {1 5ns} -repeat_every 10ns
add_force rst 1
run 300 ns

add_force rst 0
run 300000000 ns