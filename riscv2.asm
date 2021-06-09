#######################
# fib_template.asm
# Name:
# Date:
#
# Template for completing Fibinnoci sequence in lab 4
#
#######################
.globl  main

.data
fib_input:
	.word 10
	
result_str:
	.string "\nFibinnoci Number is "

.text
main:

	# Load n into a0 as the argument
	lw a0, fib_input
	
	# Call the fibinnoci function
	jal fibinnoci
	
	# Save the result into s2
	mv s2, a0 

	# Print the Result string
	la a0,result_str      # Put string pointer in a0
        li a7,4               # System call code for print_str
        ecall                 # Make system call

        # Print the number        
 	mv a0, s2
        li a7,1               # System call code for print_int
        ecall                 # Make system call

	# Exit (93) with code 0
        li a0, 0
        li a7, 93
        ecall
        ebreak

fibinnoci:
	
	beqz,a0,done  		# if a0 = 0 return 0
	li a1,1
	beq a0,a1,done		# If a0 = 1 return 1
	li a1,1			# fib_1 = 1;
	li a2,0			# fib_2 = 0;
	li a4,2
for:	
	add a3,a1,a2
	addi a2,a1,0
	addi a1,a3,0
	addi a4,a4,1
	ble a4,a0,for
	addi a0,a3,0
done:
	ret
