# Start execution of the second multiplication operation
add_force start {1 0ns}
add_force multiplier 786d4f31 -radix hex
add_force multiplicand 34e1cb0a -radix hex
run 10 ns
# return the inputs to zero
add_force start {0 0ns}
add_force multiplier 00000000 -radix hex
add_force multiplicand 00000000 -radix hex
run 360 ns
# At this point the operation should be done and provided correct answer

# Start execution of the third multiplication operation
add_force start {1 0ns}
add_force multiplier c412e59b -radix hex
add_force multiplicand a3102f73 -radix hex
run 10 ns
# return the inputs to zero
add_force start {0 0ns}
add_force multiplier 00000000 -radix hex
add_force multiplicand 00000000 -radix hex
run 360 ns
# At this point the operation should be done and provided correct answer
