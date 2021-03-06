`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_forward_sim_model.sv
//
//  Author: Mike Wirthlin
//  
//  Version 1.3 (2/25/2020)
//    Update the vdersion string below with updates in version
//   
//////////////////////////////////////////////////////////////////////////////////

module riscv_forward_sim_model #(parameter INITIAL_PC = 32'h00400000, DATA_MEMORY_START_ADDRESSS = 32'h10010000) 
	(tb_clk, tb_rst, rtl_PC, rtl_Instruction, rtl_iMemRead, rtl_ALUResult, rtl_dAddress, rtl_dWriteData, 
	rtl_dReadData, rtl_MemRead, rtl_MemWrite, rtl_WriteBackData, inst_mem_filename, data_mem_filename, error_count);

	input tb_clk, tb_rst;			// testbench clock and reset
	input [31:0] rtl_PC;			// PC from the RTL model (used for comparison)
	input [31:0] rtl_Instruction;	// Instruction from the RTL model
	input rtl_iMemRead;				// iMemRead signal from the model
	input [31:0] rtl_ALUResult;
	input [31:0] rtl_dAddress;
	input [31:0] rtl_dWriteData;
	input [31:0] rtl_dReadData;
	input [31:0] rtl_WriteBackData;
	input rtl_MemRead, rtl_MemWrite;
	input string inst_mem_filename, data_mem_filename;
	output [31:0] error_count;
	//input [31:0] pc_halt_address;
		
	// Internal shadow state
	logic [31:0] int_reg [31:0];
	typePack::instruction_t instruction_id, instruction_ex, instruction_mem, instruction_wb;
	logic iMemRead;
	logic [31:0] if_PC, id_PC, ex_PC, mem_PC, wb_PC;	// PC from the simulation model
	logic [31:0] ex_read1, ex_read2, ex_operand1, ex_operand2, ex_immediate, ex_s_immediate;
	logic [31:0] ex_branch_target, ex_alu_result;
	logic [31:0] mem_dAddress, mem_dWriteData, mem_branch_target, mem_alu_result;
	logic mem_branch_taken, wb_branch_taken;
	logic [31:0] wb_writedata, wb_dReadData, wb_alu_result;
	logic wb_RegWrite, mem_RegWrite;
	logic mem_MemRead, mem_MemWrite;
	reg [31:0] errors=0;
	logic load_use_condition, load_use;
	logic [1:0] forwardA, forwardB;
	
	assign error_count = errors;
	localparam sim_model_version = "Version 1.3";
	localparam NOP_INSTRUCTION = 32'h00000013; // addi x0, x0, 0
	localparam EBREAK_INSTRUCTION = 32'h00100073;
	localparam EBREAK_OPCODE = 7'b1110011;

	function string dec_inst(input typePack::instruction_t i);
		case(i.itype.opcode)
			typePack::L: dec_inst = $sformatf("lw x%1d,0x%1h(x%1d)", i.itype.rd, {{20{i.itype.imm[11]}},i.itype.imm}, i.itype.rs1);
			typePack::S: dec_inst = $sformatf("sw x%1d,0x%1h(x%1d)", i.stype.rs2, {{20{i.stype.imm11_5[11]}}, i.stype.imm11_5, i.stype.imm4_0}, i.itype.rs1);
			typePack::BRANCH: dec_inst = $sformatf("beq x%1d,x%1d,0x%1h", i.btype.rs1, i.btype.rs2, 
				{{20{i.btype.imm12}},i.btype.imm12,i.btype.imm11,i.btype.imm10_5,i.btype.imm4_1,1'b0});
		typePack::OP: 
			unique case(i.rtype.funct3)
				typePack::OR : dec_inst = $sformatf("or x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
				typePack::AND : dec_inst = $sformatf("and x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
				typePack::XOR : dec_inst = $sformatf("xor x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
				typePack::SLT :dec_inst = $sformatf("slt x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
				typePack::ADD :
					if (i.rtype.funct7[5] == 1) dec_inst = $sformatf("sub x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
					else dec_inst = $sformatf("add x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
			endcase
		typePack::IMM: 
			unique case(i.itype.funct3)
				typePack::OR : dec_inst = $sformatf("ori x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
				typePack::AND : dec_inst = $sformatf("andi x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
				typePack::XOR : dec_inst = $sformatf("xori x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
				typePack::SLT : dec_inst = $sformatf("slti x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
				typePack::ADD : dec_inst = $sformatf("addi x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
				endcase
		EBREAK_OPCODE: 
			dec_inst = "ebreak";
			default dec_inst = "N/A";
		endcase
	endfunction

	function string stage_state(input [31:0] inst);
		automatic typePack::instruction_t i = inst;
		stage_state = $sformatf("%s",dec_inst(i));
	endfunction
	
	/* This function will copy each character of a string into a single array of bits
	   for use by readmemh for the Vivado simulator. The format of bit array must be as
	   follows:
	   - The last character of the string  must be located at [7:0] of the 
	   - The second to last character of the string must be located at [15:8] and so on
	   - The first character of the string must be located at [l*8-1:(l-1)*8]
	      where l is the number of characters in the array
	   - The location at [(l+1)*8-1:l*8] must be 0 (null terminated string)

	   logic [31: 0] a_vect;
logic [0 :31] b_vect;
logic [63: 0] dword;
integer sel;
a_vect[ 0 +: 8] // == a_vect[ 7 : 0]
a_vect[15 -: 8] // == a_vect[15 : 8]
b_vect[ 0 +: 8] // == b_vect[0 : 7]
b_vect[15 -: 8] // == b_vect[8 :15]
dword[8*sel +: 8] // variable part-select with fixed width

https://forums.xilinx.com/t5/Simulation-and-Verification/readmemh-doesn-t-support-string-as-the-filename/td-p/833603
	*/
	function reg [256*8-1:0] copy_string(string str);
		automatic int i;
		//$display("String:%s len=%1d",str,str.len());
		for (i=0;i<str.len();i=i+1) begin
			// Copy characters from the end of the string to the start
			copy_string[(i+1)*8-1 -: 8] = str.getc(str.len()-i-1);
			//$write("%c-0x%h-%1d ",str.getc(str.len()-i-1),copy_string[(i+1)*8-1 -: 8],i);
		end
		//$display();
		//$write("%d ",i);
		copy_string[(i+1)*8-1 -: 8] = 0;
		//$write(" %c-0x%h-%1d ",str.getc(i),copy_string[(i+1)*8-1 -: 8],i);
		//$display();
	endfunction
	
	function  print_string(reg [256*8-1:0] str);
		automatic int i;
		for (i=0;i<256;i=i+1) begin
			$write("0x%h-%1d ",str[(i+1)*8-1-:8],i);
			if (i%16 == 0)
				$display();
		end
		$display();
	endfunction

	initial begin
		$timeformat(-9, 0, " ns", 20);
		$display("===== RISC-V Forwarding Simulation Model %s =====", sim_model_version);
	end
	
		
	// checking
	always@(negedge tb_clk) begin
		
		if ($time != 0) begin
		
			// Print the time and accumulated errors (so they can identify error #1)
			$write("%0t:",$time);
			//if (errors > 0)
			//	$display(" (%0d errors)",errors);
			//else
			//	$display("No Errors");
			$display();
			
			// Print the status of the IF stage
			$write("  IF: PC=0x%8h",if_PC);
			if (!iMemRead) begin
				$write(" Load Use Stall (iMemRead=0)");				
			end
						if (if_PC != rtl_PC) begin
				$write(" ** ERR** incorrect PC=%h", rtl_PC);
				errors = errors + 1;
			end
			if (iMemRead != rtl_iMemRead) begin
				$write(" ** ERR** incorrect iMemRead=%1h", rtl_iMemRead);
				errors = errors + 1;
			end
			$display();
				
			// Print the status of the ID stage
			$write("  ID: PC=0x%8h I=0x%8h [%s]",id_PC, instruction_id, stage_state(instruction_id));
			if (!iMemRead)
				$write(" Load Use Stall");
			if (insert_ex_bubble)
				$write(" Insert Bubble");			
			if (rtl_Instruction != instruction_id) begin
				$display(" ** ERR** incorrect I=%h", rtl_Instruction);
				errors = errors + 1;
			end
			else $display();
			
			// Print the status of the EX stage
			$write("  EX: PC=0x%8h I=0x%8h [%s]", ex_PC,instruction_ex,stage_state(instruction_ex));
			// See if this is an instruction that uses the ALU result
			if (instruction_ex.itype.opcode == typePack::S ||
				instruction_ex.itype.opcode == typePack::L ||
				instruction_ex.itype.opcode == typePack::BRANCH ||
				((instruction_ex.itype.opcode == typePack::IMM ||    // ALU Op that doesn't write to r0
				  instruction_ex.itype.opcode == typePack::OP) &&
				  instruction_ex.itype.rd != 0)
				) begin
				$write(" alu result=0x%1h ",ex_alu_result);
				if (forwardA == 1)
					$write(" [FWD MEM(0x%1h) to r1]",mem_alu_result);
				else if (forwardA == 2)
					$write(" [FWD WB(0x%1h) to r1]",wb_writedata);
				if (forwardB == 1)
					$write(" [FWD MEM(0x%1h) to r2]",mem_alu_result);
				else if (forwardB == 2)
					$write(" [FWD WB(0x%1h) to r2]",wb_writedata);
				if (rtl_ALUResult != ex_alu_result) begin
					$write(" ** ERR** incorrect alu result=%1h", rtl_ALUResult);
					errors = errors + 1;
				end
					
			end  // Don't care about the else case
			// Print MEM bubble insertion
			if (insert_mem_bubble)
				$write(" Insert Bubble");			
			$display();

			// Print the status of the MEM stage
			$write("  MEM:PC=0x%8h I=0x%8h [%s]",mem_PC,instruction_mem, stage_state(instruction_mem));
			// See if this is an instruction that uses memory
			if (instruction_mem.itype.opcode == typePack::S) begin
				// Is this a store instruction? Check to see that memory is used properly
				if (rtl_MemRead) begin
					$write(" ERR: MemRead should be 0");
					errors = errors + 1;
				end
				if (!rtl_MemWrite) begin
					$write(" ERR: MemWrite should be 1");
					errors = errors + 1;
				end
				if (rtl_dAddress != mem_dAddress) begin
					$write(" Err: Memory Write to address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
					errors = errors + 1;
				end
				if (rtl_dWriteData != mem_dWriteData) begin
					$write(" Err: Memory Write value 0x%1h but expecting value 0x%1h",rtl_dWriteData,mem_dWriteData);
					errors = errors + 1;
				end
				if (rtl_dAddress == mem_dAddress && rtl_dWriteData == mem_dWriteData) begin
					$write(" Memory Write 0x%1h to address 0x%1h ",rtl_dWriteData,rtl_dAddress);
				end
			end else if (instruction_mem.itype.opcode == typePack::L) begin
				// Is this a load instruction? Check to see that memory is used properly
				if (!rtl_MemRead) begin
					$write(" ERR: MemRead should be 1");
					errors = errors + 1;
				end
				if (rtl_MemWrite) begin
					$write(" ERR: MemWrite should be 0");
					errors = errors + 1;
				end
				if (rtl_dAddress != mem_dAddress) begin
					$write(" Err: Memory Read from address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
					errors = errors + 1;
				end
				if (rtl_dAddress == mem_dAddress && rtl_dWriteData == mem_dWriteData) begin
					$write(" Memory Read from address 0x%1h ",rtl_dAddress);  // Note: data not ready until next cycle
				end
			end else begin
				// If it is not an instruction that uses memory, make sure the memory is not being used
				// (No debug necessary if no read operations are occuring)
				if (rtl_MemRead) begin
					$write(" ERR: MemRead should be 0");
					errors = errors + 1;
				end
				if (rtl_MemWrite) begin
					$write(" ERR: MemWrite should be 0");
					errors = errors + 1;
				end
			end
			// See if we have a branch instruction and indicate whether it is taken or not
			if (instruction_mem.itype.opcode == typePack::BRANCH) begin
				if (mem_alu_result == 0)
					$write(" Branch Taken");
				else
					$write(" Branch NOT Taken");
			end

			$display();

			// Print the status of the WB stage
			$write("  WB: PC=0x%8h I=0x%8h [%s] ",wb_PC,instruction_wb,stage_state(instruction_wb));
			if (wb_RegWrite) begin
				// Check to see if this instruction writes back to the register file
				$write("WriteBackData=0x%1h ",rtl_WriteBackData);
				if (!(rtl_WriteBackData === wb_writedata)) begin
					$write(" ** ERR** expecting to write back data=0x%1h", wb_writedata);
					errors = errors + 1;
				end else if (^rtl_WriteBackData === 1'bX || ^wb_writedata === 1'bX) begin
					$write(" ** ERR** Write back data is undefined=0x%1h", wb_writedata);
					errors = errors + 1;
				end
			end
			// no else: We don't know if the rtl is trying to write to the register file
			$display();
			
		end
		if (errors > 0) begin
			$display("*** Error: Simulation Stopped due to errors ***");
			$finish;
		end
	end

	


	///////
	// IF
	///////
	assign iMemRead = !load_use;
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			if_PC <= INITIAL_PC;
			id_PC <= 32'hxxxxxxxx;
		end else begin
			if (iMemRead) begin
				if (mem_branch_taken)
					if_PC <= mem_branch_target;			
				else
					if_PC <= if_PC + 4;			
				id_PC <= if_PC;
			end
		end
	end
		
	// Instruction Memory
	localparam INSTRUCTION_MEMORY_WORDS = 1024;  // 4x1024 - 4096 bytes
	logic [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];
	reg [256*8-1:0] i_filename;
	initial begin
		i_filename = copy_string(inst_mem_filename);
		$readmemh(i_filename, instruction_memory);
		if (^instruction_memory[0] === 1'bX) begin
			$display($sformatf("**** Error: RISC-V Forwarding model instruction memory '%s' failed to load****",inst_mem_filename));
		end
		else
			$display($sformatf("**** RISC_V Forwarding model: Loaded instruction memory '%s' ****",inst_mem_filename));
	end

	// Instruction memory read (synchronous read). No writes
	// Read every clock cycle (even if we will end up ignoring NOP instructions that are read)
	wire [31:0] local_PC = (if_PC - INITIAL_PC) >> 2;
	always@(posedge tb_clk) begin
		if (tb_rst) begin
		  instruction_id <= NOP_INSTRUCTION;  // Initialize instruction with "NOP"
		end
	    else begin
			if (iMemRead) begin
				instruction_id <= instruction_memory[local_PC];
			end
		end
	end

	
	///////
	// ID
	///////
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			// clear contents of registers
			for (int i = 0; i < 32; i=i+1)
				int_reg[i] = 0;
			ex_read1 <= 0;
			ex_read2 <= 0;
		end
		else begin
			// register reads
			ex_read1 <= int_reg[instruction_id.rtype.rs1];
			ex_read2 <= int_reg[instruction_id.rtype.rs2];
			// register writes
			if (wb_RegWrite) 
			begin				
				int_reg[instruction_wb.rtype.rd] = wb_writedata;
				if (instruction_id.rtype.rs1 == instruction_wb.rtype.rd)
					ex_read1 <= wb_writedata;
				if (instruction_id.rtype.rs2 == instruction_wb.rtype.rd)
					ex_read2 <= wb_writedata;					
			end
		end
	end

	// Registers
	wire insert_ex_bubble;
	assign insert_ex_bubble = load_use || mem_branch_taken || wb_branch_taken ;
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			instruction_ex <= NOP_INSTRUCTION;
			ex_PC <= 32'hxxxxxxxx;
		end
		else if (insert_ex_bubble) begin
			instruction_ex <= NOP_INSTRUCTION;
			ex_PC <= 32'hxxxxxxxx;
		end
		else begin
			instruction_ex <= instruction_id;
			ex_PC <= id_PC;
		end
	end

	///////
	// EX
	///////

	always@(*) begin
			ex_branch_target = ex_PC + 
				{{20{instruction_ex.btype.imm12}}, instruction_ex.btype.imm11, 
					instruction_ex.btype.imm10_5, instruction_ex.btype.imm4_1,1'b0};
			// Immediate
			ex_immediate = {{20{instruction_ex.itype.imm[11]}},instruction_ex.itype.imm};
			ex_s_immediate = {{20{instruction_ex.stype.imm11_5[11]}},instruction_ex.stype.imm11_5,instruction_ex.stype.imm4_0};
			
			// Operand 1 (forwarding logic)
			forwardA = 0;
			if (mem_RegWrite && instruction_mem.itype.rd != 0 && instruction_mem.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = mem_alu_result;
				forwardA = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && instruction_wb.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = wb_writedata;
				forwardA = 2;
			end else
				ex_operand1 = ex_read1;
				
			// Operand 2 (forwarding logic)
			forwardB = 0;
			if (instruction_ex.itype.opcode == typePack::S)
				ex_operand2 = ex_s_immediate;
			else if (instruction_ex.itype.opcode == typePack::IMM ||
						 instruction_ex.itype.opcode == typePack::L)
				ex_operand2 = ex_immediate;
			else if (mem_RegWrite && instruction_mem.itype.rd != 0 && instruction_mem.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = mem_alu_result;
				forwardB = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && instruction_wb.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = wb_writedata;
				forwardB = 2;
			end else
				ex_operand2 = ex_read2;
			
			// ALU
			case(instruction_ex.itype.opcode)
				typePack::L: ex_alu_result = ex_operand1 + ex_operand2;
				typePack::S: ex_alu_result = ex_operand1 + ex_operand2;
				typePack::BRANCH: ex_alu_result = ex_operand1 - ex_operand2;
				default: // R or Immediate instructions
					case(instruction_ex.itype.funct3)
						typePack::ADD: 
							if (instruction_ex.rtype.opcode == typePack::OP && instruction_ex.rtype.funct7 ==  7'b0100000)
								ex_alu_result = ex_operand1 - ex_operand2;
							else
								ex_alu_result = ex_operand1 + ex_operand2;
						typePack::SLT: ex_alu_result = ($signed(ex_operand1) < $signed(ex_operand2)) ? 32'd1 : 32'd0;
						typePack::AND: ex_alu_result = ex_operand1 & ex_operand2;
						typePack::OR: ex_alu_result = ex_operand1 | ex_operand2;
						typePack::XOR: ex_alu_result = ex_operand1 ^ ex_operand2;
						default: ex_alu_result = ex_operand1 + ex_operand2;
					endcase
			endcase
	end
	
	assign load_use_condition =	(instruction_ex.itype.opcode == typePack::L) &&  // EX is a load
						((instruction_ex.rtype.rd == instruction_id.rtype.rs1) || // desitination reguster of EX used by ID1
						 (instruction_ex.rtype.rd == instruction_id.rtype.rs2));  // desitination reguster of EX used by ID2						
	assign load_use = load_use_condition && !mem_branch_taken;
	
	wire insert_mem_bubble = mem_branch_taken;
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			instruction_mem <= NOP_INSTRUCTION;
			mem_branch_target <= 0;
			mem_alu_result <= 0;
			mem_dWriteData <= 0;
			mem_PC <= 32'hxxxxxxxx;
		end else if (insert_mem_bubble) begin
			instruction_mem <= NOP_INSTRUCTION;
			mem_branch_target <= 0;
			mem_alu_result <= 0;
			mem_dWriteData <= 0;
			mem_PC <= 32'hxxxxxxxx;
		end else begin
			instruction_mem <= instruction_ex;
			mem_branch_target <= ex_branch_target;
			mem_alu_result <= ex_alu_result;
			mem_dWriteData <= ex_read2;
			mem_PC <= ex_PC;
		end
	end

	
	///////
	// Mem
	///////
	
	assign mem_branch_taken = (instruction_mem.itype.opcode == typePack::BRANCH && mem_alu_result == 0);
	// Data memory
	localparam DATA_MEMORY_WORDS = 256;
	assign mem_dAddress = mem_alu_result;
	reg [256*8-1:0] d_filename;
	
	assign mem_RegWrite = ((instruction_mem.itype.opcode == typePack::OP || 
					instruction_mem.itype.opcode == typePack::IMM ||
					instruction_mem.itype.opcode == typePack::L)) && 
					(instruction_mem.itype.rd != 0);

	
	// Data Memory
	logic [31:0] data_memory[DATA_MEMORY_WORDS-1:0];

	initial begin
		d_filename = copy_string(data_mem_filename);
		$readmemh(d_filename, data_memory);
		//$readmemh("pipe_data_memory.txt", data_memory);
		if (^data_memory[0] === 1'bX) begin
			$display($sformatf("**** Error: RISC-V Simulation model data memory '%s' failed to load****",data_mem_filename));
			//$finish;
		end
		else 
			$display($sformatf("**** RISC-V Simulation model: Loaded data memory '%s' ****",data_mem_filename));
	end

	assign mem_MemRead = (instruction_mem.itype.opcode == typePack::L);
	assign mem_MemWrite = (instruction_mem.itype.opcode == typePack::S);
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			wb_dReadData <= 0;
			wb_dReadData <= 0;
			wb_alu_result <= 0;
			wb_branch_taken <= 0;
			wb_PC <= 32'hxxxxxxxx;
			instruction_wb <= NOP_INSTRUCTION;
		end
		else begin
			if (mem_MemRead)
				wb_dReadData <= data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2];
			if (mem_MemWrite)
				data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2] <= mem_dWriteData;
			wb_alu_result <= mem_alu_result;
			wb_branch_taken <= mem_branch_taken;
			wb_PC <= mem_PC;
			instruction_wb <= instruction_mem;
		end
	end
		
	///////
	// WB
	///////
	assign wb_writedata = (instruction_wb.itype.opcode == typePack::L) ? wb_dReadData : wb_alu_result;
	assign wb_RegWrite = ((instruction_wb.itype.opcode == typePack::OP || 
					instruction_wb.itype.opcode == typePack::IMM ||
					instruction_wb.itype.opcode == typePack::L)) && 
					(instruction_wb.itype.rd != 0);

	// Exit condition
	always_comb
		if (instruction_wb == EBREAK_INSTRUCTION) begin
			$display("Passed! EBREAK instruction reached WB stage at location 0x%8h",wb_PC);
			$finish;
		end
	
endmodule