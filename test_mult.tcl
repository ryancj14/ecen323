#######################################################
# test_mult_mod.tcl
#
#   Provide stimulus for sequential multiplier
#######################################################

# Initialize the simulation
restart
# Run for some time with unspecified inputs (indicated by blue)
run 50 ns
# Create 100 MHz clock and run for 5 clock cycles
# (This should put "red" messed up values in the internal registers)
add_force clk {0} {1 5} -repeat_every 10
run 50 ns
# Initialize the inputs and run for a few clock cycles (turns inputs from blue to  green)
add_force start 0
add_force rst 0
add_force multiplier 00000000 -radix hex
add_force multiplicand 00000000 -radix hex
run 30 ns
# Issue reset pulse (should turn register values in red to zero in green)
add_force rst 1
run 20 ns
add_force rst 0
run 10 ns
# At ths point we are ready to perform a variety of multiplication operations

# Start execution of the first multiplication operation
add_force start {1 0ns}
add_force multiplier 000007e4 -radix hex
add_force multiplicand 0000013d -radix hex
run 10 ns
# return the inputs to zero
add_force start {0 0ns}
add_force multiplier 00000000 -radix hex
add_force multiplicand 00000000 -radix hex
run 360 ns
# At this point the operation should be done and provided correct answer
