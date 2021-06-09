restart

# Set a repeating clock
add_force clk {0 0} {1 5} -repeat_every 10
# set default values for the inputs
add_force sw 0000000000000000
add_force btnc 0
add_force btnr 0
run 1000000 ns

add_force btnc 0
add_force btnr 1
run 1000000 ns

add_force btnc 1
add_force btnr 1
run 1000000 ns

add_force sw 0001000100010010
add_force btnc 0
add_force btnr 0
run 1000000 ns

add_force btnc 0
add_force btnr 1
run 1000000 ns

add_force btnc 1
add_force btnr 1
run 1000000 ns