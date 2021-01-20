library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

-- Do not modify the port map of this structure
entity comments_fsm is
port (clk : in std_logic;
      reset : in std_logic;
      input : in std_logic_vector(7 downto 0);
      output : out std_logic
  );
end comments_fsm;

architecture behavioral of comments_fsm is

-- The ASCII value for the '/', '*' and end-of-line characters
constant SLASH_CHARACTER : std_logic_vector(7 downto 0) := "00101111";
constant STAR_CHARACTER : std_logic_vector(7 downto 0) := "00101010";
constant NEW_LINE_CHARACTER : std_logic_vector(7 downto 0) := "00001010";

type t_State is (NoComment, Confirming, CommentBlock, Terminating, CommentLine);

signal state: t_State;

begin

-- Insert your processes here
process (clk, reset)
begin
	if rising_edge(clk) then
		if reset = '0' then
			state <= NoComment;
		else
		   case state is
		   	when NoComment =>
		   		output <= '0';
		   		If input = SLASH_CHARACTER then
					state <= Confirming;
		   		else
		   			state <= NoComment;
		   		end if;
		   	when Confirming =>
		   		if input = STAR_CHARACTER then
		   			state <= CommentBlock;
		   		elsif input = SLASH_CHARACTER then
		   			state <= CommentLine;
		   		else
		   			state <= NoComment;
		   		end if;
		   	when CommentBlock =>
		   		output <= '1';
		   		if input = STAR_CHARACTER then
		   			state <= Terminating;
		   		else
		   			state <= CommentBlock;
		   		end if; 
		   	when CommentLine =>
		   		output <= '1';
		   		if input = NEW_LINE_CHARACTER then
		   			state <= NoComment;
		   		else 
		   			state <= CommentLine;
		   		end if;
		   	when Terminating =>
		   		if input = SLASH_CHARACTER then
		   			state <= NoComment;
		   		else 
		   			state <= CommentBlock;
		   		end if;
		   end case;
		 end if;
	end if;
end process;

end behavioral;
