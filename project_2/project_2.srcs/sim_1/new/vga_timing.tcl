restart
run 100 ns
 
# set inputs low
add_force LOAD 0
add_force DIN 0
 
# add oscillating clock input with 10ns period
add_force CLK {0 0} {1 5ns} -repeat_every 10ns
