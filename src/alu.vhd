library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_LIB.all;

-- All computation is handled by this component. Inputs are 
-- selected by the main controller's signals AluSrcA, AluSrcB.
-- Output is controlled by ALU controller signal ALU_LO_HI.

-- Author		: Daniel Hamilton
-- Creation 	: 3/29/2019
-- Last Edit 	: 3/29/2019

-- UPDATES
-- 3/29/2019	: Component initialization. 

-- TODO: Remove hardcoded X"0000" in case IN_WIDTH is not 32 bits
-- TODO: Complete the Jump Register (ALU_JR) instruction

entity ALU is
	generic (
		WIDTH : positive := 32;
		IN_WIDTH : positive := 32
	);
	port (
		a 			: in std_logic_vector( IN_WIDTH-1 downto 0 );  -- rs
		b 			: in std_logic_vector( IN_WIDTH-1 downto 0 );	-- rt
		ir_shift 	: in std_logic_vector( 4 downto 0 );		-- number of times to shift, bits IR(10 downto 6)
		op_select 	: in std_logic_vector( 5 downto 0 );		-- op code select from the ALU controller
	
		branch_taken : out std_logic;
		result 		 : out std_logic_vector( WIDTH-1 downto 0 );
		result_hi	 : out std_logic_vector( WIDTH-1 downto 0 )
	);
end ALU;

architecture BHV of ALU is
	signal result_sig 		: std_logic_vector( 2*WIDTH-1 downto 0 ); -- works with multiply
	signal branch_taken_sig : std_logic;
begin
	
	process( op_select, ir_shift, a, b, result_sig )
		variable OP_SELECT_VAR 	: integer; -- just to make decoding pretty :)
		variable IR_SHIFT_VAR 	: integer;
		variable SIGN_BIT		: std_logic;
		variable SIGNED_A		: signed(IN_WIDTH-1 downto 0);
		variable SIGNED_B		: signed(IN_WIDTH-1 downto 0);
	begin
		
		-- MUX SELECT PREPARATION
		OP_SELECT_VAR 	:= to_integer(unsigned(OP_SELECT));
		IR_SHIFT_VAR 	:= to_integer(unsigned(IR_SHIFT));
		SIGNED_A 		:= signed(a);
		SIGNED_B 		:= signed(b);
		
		-- DEFAULT SIGNAL VALUES
		branch_taken_sig 	<= '0';
		result_sig 			<= (others => '0');
		
		-- MUX FOR ALU FUNCTIONS
		case OP_SELECT_VAR is
			
		when ALU_ADD =>		-- add unsigned bits
			-- rd <- rs + rt
			result_sig <= X"0000" & std_logic_vector( unsigned(a) + unsigned(b) );
			
		when ALU_SUB =>		-- subtract unsigned bits
			-- rd <- rs - rt
			result_sig <= X"0000" & std_logic_vector( unsigned(a) - unsigned(b) );
			
		when ALU_MULT =>	-- signed multiply
			-- (LO, HI) <- rs x rt
			result_sig <= std_logic_vector( unsigned(a) * unsigned(b) );
	
		when ALU_AND =>		-- bitwise and
			-- rd <- rs AND rt
			result_sig <= X"0000" & (a and b);
			
		when ALU_OR =>		-- bitwise or
			-- rd <- rs OR rt
			result_sig <= X"0000" & (a or b);
			
		when ALU_XOR =>		-- bitwise exclusive or
			-- rd <- rs XOR rt
			result_sig <= X"0000" & (a xor b);
			
		when ALU_SRL =>		-- shift right logical
			-- rd <- rt >> sa
			result_sig <= X"0000" & b;
			result_sig <= std_logic_vector(shift_right(unsigned(result_sig), IR_SHIFT_VAR));
			
		when ALU_SLL =>		-- shift left logical
			-- rd <- rt << sa
			result_sig <= X"0000" & b;
			result_sig <= std_logic_vector(shift_left(unsigned(result_sig), IR_SHIFT_VAR));
			
		when ALU_SRA =>		-- shift right arithmetic
			-- rd <- rt >> sa
			sign_bit := b(IN_WIDTH-1); -- top bit is the sign bit for a signed number
			result_sig <= X"0000" & b;
			result_sig <= std_logic_vector(shift_right(unsigned(result_sig), IR_SHIFT_VAR));
			result_sig(IN_WIDTH-1) <= sign_bit; -- duplicate the sign bit
			
		when ALU_SLT =>		-- set if less than signed
			-- rd <- rs < rt	
			if ( signed_a < signed_b ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else 
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
				
		when ALU_SLTU =>	-- set if less than unsigned
			if ( unsigned(a) < unsigned(b) ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else 
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
			
		when ALU_MFHI =>	-- move hi reg
			-- rd <- HI
			result_sig <= (others => '1'); -- doesn't matter
			
		when ALU_MFLO =>	-- move lo reg
			-- rd <- LO
			result_sig <= (others => '1'); -- doesn't matter
			
		when ALU_LW =>		-- load word
			-- rd <- mem[base + offset] stored in rt
			result_sig <= X"0000" & b;
			
		when ALU_SW =>		-- store word
			-- mem[base + offset] <- rt
			result_sig <= X"0000" & b;
			
		when ALU_BEQ =>		-- break if A equals B
			-- if rs = rt, branch
			-- if result = 0, don't branch.
			-- if result = 1, branch.
			if ( unsigned(a) = unsigned(b) ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
			
		when ALU_BNE =>		-- break if A does not equal B
			-- if rs != rt, branch
			-- if result = 0, don't branch.
			-- if result = 1, branch.
			if ( unsigned(a) /= unsigned(b) ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
			
		when ALU_BLEZ =>	-- break if less than equal to 0
			-- if rs <= 0, branch
			-- if result = 0, don't branch.
			-- if result = 1, branch.
			if ( signed_a <= to_signed(0, WIDTH) ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
			
		when ALU_BGTZ =>	-- break if greater than 0
			-- if rs <= 0, branch
			-- if result = 0, don't branch.
			-- if result = 1, branch.
			if ( signed_a > to_signed(0, WIDTH) ) then
				branch_taken_sig <= '1';
				result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
			else
				result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
			end if;
			
		when ALU_BCOMPZ =>	-- compare to 0
			
			-- check what the controller loaded into register B to
			-- determine what comparison to make.
			if ( b = std_logic_vector(to_unsigned(0, WIDTH)) ) then
				-- branch on less than 0
				if ( signed_b < to_signed(0, WIDTH) ) then
					branch_taken_sig <= '1';
					result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
				else
					result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
				end if;
								
			else -- if b = 1
				-- branch on greater than or equal to 0
				if ( signed_b >= to_signed(1, WIDTH) ) then
					branch_taken_sig <= '1';
					result_sig <= std_logic_vector(to_unsigned(1, 2*WIDTH));
				else
					result_sig <= std_logic_vector(to_unsigned(0, 2*WIDTH));
				end if;
			end if;
			
		when ALU_JR =>		-- jump register
			
		when ALU_HALT =>	-- fake instruction
		
		when others => null;
		end case;
		
	end process;
	
	-- SIGNAL TO PORT CONNECTIONS
	branch_taken 	<= branch_taken_sig;			
	result 			<= result_sig(WIDTH-1 downto 0); -- lo, alu_out
	result_hi 		<= result_sig(2*WIDTH-1 downto WIDTH); -- hi
	
end BHV;
	