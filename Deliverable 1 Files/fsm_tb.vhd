LIBRARY ieee;
USE ieee.STD_LOGIC_1164.all;

ENTITY fsm_tb IS
END fsm_tb;

ARCHITECTURE behaviour OF fsm_tb IS

COMPONENT comments_fsm IS
PORT (clk : in std_logic;
      reset : in std_logic;
      input : in std_logic_vector(7 downto 0);
      output : out std_logic
  );
END COMPONENT;

--The input signals with their initial values
SIGNAL clk, s_reset, s_output: STD_LOGIC := '0';
SIGNAL s_input: std_logic_vector(7 downto 0) := (others => '0');

CONSTANT clk_period : time := 1 ns;
CONSTANT SLASH_CHARACTER : std_logic_vector(7 downto 0) := "00101111";
CONSTANT STAR_CHARACTER : std_logic_vector(7 downto 0) := "00101010";
CONSTANT NEW_LINE_CHARACTER : std_logic_vector(7 downto 0) := "00001010";

BEGIN
dut: comments_fsm
PORT MAP(clk, s_reset, s_input, s_output);

 --clock process
clk_process : PROCESS
BEGIN
	clk <= '0';
	WAIT FOR clk_period/2;
	clk <= '1';
	WAIT FOR clk_period/2;
END PROCESS;

--TODO: Thoroughly test your FSM
stim_process: PROCESS

--A character signal should not be sustained for more than, say, 1ns
constant period: time := 1ns;
constant ASCII_constant: std_logic_vector(7 downto 0) := "00000000";

BEGIN   
	-- Read the asserts as: What came immediately before it is either a comment or not. 
	-- NOTE: Assert 0 means what came immediately before is not a comment
	--	 Assert 1 means what came immediately before is a comment
	
	--Test Case 1
	REPORT "Example 1: /*ASCII\n*/";
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '0') REPORT "Comment start /*ASCII\n*/: Output should be '0'" SEVERITY ERROR;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= NEW_LINE_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "Comment start /*ASCII\n*/: Output should be '1'" SEVERITY ERROR;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of /*ASCII\n*/: Output should be '1'" SEVERITY ERROR;
	REPORT "_______________________";
	-- End Test Case 1
	
	--Test Case 2
	REPORT "Example 2: /*ASCII*ASCII/*/";
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '0') REPORT "Comment start /*ASCII*ASCII/*/: Output should be '0'" SEVERITY ERROR;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of /*ASCII*ASCII/*/: Output should be '1'" SEVERITY ERROR;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of /*ASCII*ASCII/*/: Output should be '1'" SEVERITY ERROR;
	REPORT "_______________________";
	-- End Test Case 2
	
	--Test Case 3
	REPORT "Example 3: /*ASCII*//";
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '0') REPORT "Comment start /*ASCII*//: Output should be '0'" SEVERITY ERROR;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of /*ASCII*//: Output should be '1'" SEVERITY ERROR;
	REPORT "_______________________";
	-- End Test Case 3
	
	-- Test Case 4
	REPORT "Example 4: ///*ASCII*/\n";
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "Comment start //Hello\n: Output should be '1'" SEVERITY ERROR;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "Comment start //Hello\n: Output should be '1'" SEVERITY ERROR;
	s_input <= NEW_LINE_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of //Hello\n: Output should be '1'" SEVERITY ERROR;
	REPORT "_______________________";
	-- End Test Case 4
	
	-- Test Case 5
	REPORT "Example 5: //ASCII*/\n";
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '0') REPORT "Comment start //ASCII*/\n: Output should be '0'" SEVERITY ERROR;
	s_input <= ASCII_constant;
	WAIT FOR period;
	s_input <= STAR_CHARACTER;
	WAIT FOR period;
	s_input <= SLASH_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "Comment start //ASCII*/\n: Output should be '1'" SEVERITY ERROR;
	s_input <= NEW_LINE_CHARACTER;
	WAIT FOR period;
	ASSERT (s_output = '1') REPORT "End of //ASCII*/\n: Output should be '1'" SEVERITY ERROR;
	REPORT "_______________________";
	-- End Test Case 5
	

END PROCESS stim_process;
END;
