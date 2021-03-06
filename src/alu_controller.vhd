library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_lib.all;

-- This component receieves signals from the controller unit and the 
-- instruction register. It decodes all inputs to determine what computation
-- the ALU does. Additionally, it tells the HI, LO, and ALU registers whether
-- they should load new values or not.

-- Author		: Daniel Hamilton
-- Creation 	: 3/29/2019
-- Last Edit 	: 3/29/2019

-- UPDATES
-- 3/29/2019	: Component initialization. 

entity ALU_CONTROLLER is
	port (
		ir_r_type 	: in 	std_logic_vector(5 downto 0);	-- IR(5 downto 0) for opcodes of 0x00
		op_code	 	: in	std_logic_vector(5 downto 0);	
			
		op_select 	: out 	std_logic_vector(5 downto 0);
		hi_en	 	: out 	std_logic;
		lo_en	 	: out 	std_logic;
		alu_lo_hi 	: out std_logic_vector(1 downto 0)
	);
end ALU_CONTROLLER;

architecture BHV of ALU_CONTROLLER is
	
	signal alu_lo_hi_sig : std_logic_vector(1 downto 0);
	signal op_select_sig : std_logic_vector(5 downto 0);
	signal lo_en_sig	 : std_logic;
	signal hi_en_sig	 : std_logic;
	
	-- ENUM SIGNAL DECLARATIONS --------------------------------------------
	signal instruction	: INSTR_T;
	
begin
	
	-- DECODE THE OP CODE INSTRUCTIONS ---------------------------------
	process(ir_r_type, op_code)
	begin
		
		-- DEFAULT SIGNAL ASSIGNMENTS
		alu_lo_hi_sig <= std_logic_vector(to_unsigned(ALU_OUT_MUX_ALU,2)); -- ALU OUT
		lo_en_sig <= '0';  -- these should always be able to update except for specific cases
		hi_en_sig <= '0';  -- these should always be able to update except for specific cases
		op_select_sig <= "111111"; -- by default, HALT
		instruction <= T_DEFAULT;
		
		case OP_CODE is
		when "000000" =>	-- 0x00, r type instructions (15)
			
			-- DECODE R TYPE INSTRUCTIONS WITH IR_R_TYPE
			case IR_R_TYPE is
			when "100001" => -- add unsigned
				instruction <= T_ADD;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_ADD, 6));
				
			when "100011" => -- subtract unsigned
				instruction <= T_SUB;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SUB, 6));
				
			when "011000" => -- multiply signed words
				instruction <= T_MULT_SIGNED;
				lo_en_sig <= '1';
				hi_en_sig <= '1';
				op_select_sig <= std_logic_vector(to_unsigned(ALU_MULT, 6));
				
			when "011001" => -- multiply unsigned words
				instruction <= T_MULTU;
				lo_en_sig <= '1';
				hi_en_sig <= '1';
				op_select_sig <= std_logic_vector(to_unsigned(ALU_MULTU, 6));
				
			when "100100" => -- bitwise logical AND
				instruction <= T_AND;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_AND, 6));
				
			when "100101" => -- bitwise logical OR
				instruction <= T_OR;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_OR, 6));
				
			when "100110" => -- bitwise exclusive OR
				instruction <= T_XOR;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_XOR, 6));
				
			when "000010" => -- shift right logical
				instruction <= T_SRL;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SRL, 6));
				
			when "000000" => -- shift left logical
				instruction <= T_SLL;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SLL, 6));
				
			when "000011" => -- shift right arithmetic 
				instruction <= T_SRA;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SRA, 6));
				
			when "101010" => -- set on less than
				instruction <= T_SLT;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SLT, 6));
				
			when "101011" => -- set on less than unsigned 
				instruction <= T_SLTU;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_SLTU, 6));
				
			when "010000" => -- move from hi register
				instruction <= T_MFHI;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_MFHI, 6));
				alu_lo_hi_sig <= std_logic_vector(to_unsigned(ALU_OUT_MUX_HI,2));
				
			when "010010" => -- move from lo register
				instruction <= T_MFLO;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_MFLO, 6));
				alu_lo_hi_sig <= std_logic_vector(to_unsigned(ALU_OUT_MUX_LO,2));
				
			when "001000" => -- jump register 
				instruction <= T_JR;
				op_select_sig <= std_logic_vector(to_unsigned(ALU_JR, 6));
				
			when others => null;
			end case;
			
		when "000001" => 	-- 0x01, branch instructions (2)
			
			-- greater than equal to 0 if rt loaded with 0x0
			-- less than 0 if rt loaded with 0x1
			instruction <= T_BCOMPZ;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_BCOMPZ, 6));
			
		when "000010" => 	-- 0x02, branch to address (1)
			
			-- jump to address
			instruction <= T_J;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_J, 6));
			
		when "000011" => 	-- 0x03, jump and link (1)
			
			-- jump to address and link
			instruction <= T_JAL;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_JAL, 6));
			
		when "000100" =>	-- 0x04, branch on equal (1)
			
			-- branch on equal
			instruction <= T_BEQ;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_BEQ, 6));
			
		when "000101" =>	-- 0x05, branch not equal (1)
			
			-- branch if not equal
			instruction <= T_BNE;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_BNE, 6));
			
		when "000110" =>	-- 0x06, branch on less than or equal to 0 (1)
			
			-- branch on less than or equal to 0
			instruction <= T_BLEZ;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_BLEZ, 6));
			
		when "000111" =>	-- 0x07, branch on greater than 0 (1)
			
			-- branch on greater than 0
			instruction <= T_BGTZ;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_BGTZ, 6));
			
		when "001001" => 	-- 0x09, add immediate unsigned (1)
			
			-- add immediate unsigned
			instruction <= T_ADD;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_ADD, 6));
			
		when "001010" => 	-- 0x0A, set on less than immediate signed (1)
			
			-- set on less than immediate signed (1)
			instruction <= T_SLTI;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_SLTI, 6));
			
		when "001011" =>	-- 0x0B, set on less than immediate unsigned (1)
		
			-- set on less than immediate unsigned
			instruction <= T_SLTIU;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_SLTIU, 6));
			
		when "001100" => 	-- 0x0C, AND immediate (1)
			
			-- and immediate
			instruction <= T_AND;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_AND, 6));
			
		when "001101" =>	-- 0x0D, OR immediate (1)
			
			-- or immediate
			instruction <= T_OR;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_OR, 6));
			
		when "001110" =>	-- 0x0E, exclusive OR immediate (1)
			
			-- exclusive or immediate
			instruction <= T_XOR;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_XOR, 6));
			
		when "010000" => 	-- 0x10, subtract immediate unsigned (1)
			
			-- subtract immediate unsigned
			instruction <= T_SUBIU;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_SUB, 6));
			
		when "100011" =>	-- 0x23, load word (1)
			
			-- load word
			instruction <= T_LW;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_LW, 6));
			
		when "101011" =>	-- 0x2B, store word (1)
			
			-- store word
			instruction <= T_SW;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_SW, 6));
			
		when OP_HOLD =>	
			
			instruction <= T_HOLD;
			
		when "111111" => 	-- 0x3F, fake instruction
			
			-- fake instruction
			instruction <= T_HALT;
			op_select_sig <= std_logic_vector(to_unsigned(ALU_HALT, 6));
			
		when others => null;
		end case;
		
	end process;
	
	-- SIGNAL TO PORT CONNECTIONS ---------------------------------------
	op_select	<= op_select_sig;
	hi_en	    <= hi_en_sig;
	lo_en	    <= lo_en_sig;	 
	alu_lo_hi   <= alu_lo_hi_sig;
	
end BHV;