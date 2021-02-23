library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768
);
port(
	clock : in std_logic;
	reset : in std_logic;
	
	-- Avalon interface --
	s_addr : in std_logic_vector (31 downto 0);
	s_read : in std_logic;
	s_readdata : out std_logic_vector (31 downto 0);
	s_write : in std_logic;
	s_writedata : in std_logic_vector (31 downto 0);
	s_waitrequest : out std_logic; 
    
	m_addr : out integer range 0 to ram_size-1;
	m_read : out std_logic;
	m_readdata : in std_logic_vector (7 downto 0);
	m_write : out std_logic;
	m_writedata : out std_logic_vector (7 downto 0);
	m_waitrequest : in std_logic;
	
	test: out std_logic_vector(4 downto 0)
);
end cache;

architecture arch of cache is

	-- declare signals here
	-- 15 bit signal will be of the following form: VDTTTTBBBBBWWbb
	
	constant number_of_cache_blocks: integer := 32; 
	
	TYPE t_cache_memory IS ARRAY(number_of_cache_blocks-1 downto 0) OF STD_LOGIC_VECTOR(31 downto 0);

	-- For data requested by CPU
	signal tag_bits: std_logic_vector (3 downto 0);
	signal block_index: std_logic_vector (4 downto 0);
	signal block_index_int: integer;
	signal word_index: std_logic_vector (1 downto 0);
	
	-- For data in the cache
	signal in_cache_tag_bits: std_logic_vector (3 downto 0);
	signal in_cache_valid_bit: std_logic;
	signal in_cache_dirty_bit: std_logic;
	
	signal retrieved_address: std_logic_vector (31 downto 0);

	type t_State is (TVNDDR, TVNDW, TVDW, readMiss, writeMiss, idle);

	signal state: t_State;
	signal cache_memory: t_cache_memory;

begin

Cache_Initialization: PROCESS (clock)
BEGIN
	--This is a cheap trick to initialize the SRAM in simulation
	IF(now < 1 ps)THEN
		For i in 0 to number_of_cache_blocks-1 LOOP
			cache_memory(i) <= std_logic_vector(to_unsigned(i,32));
		END LOOP;
	end if;

END PROCESS;

-- For CPU address
tag_bits <= s_addr (12 downto 9);
block_index <= s_addr (8 downto 4);
word_index <= s_addr (3 downto 2);
test <= block_index;

process (clock, s_addr)
begin	
	--if rising_edge(clock) then
		report "1";
	
		block_index_int <= to_integer(unsigned(block_index));
		report "AAAAAAAAAAAAA"& integer'image(block_index_int);
		-- For cache address
		report "2";
		retrieved_address <= cache_memory(block_index_int);
		in_cache_valid_bit <= retrieved_address(14);
		in_cache_dirty_bit <= retrieved_address(13);
		in_cache_tag_bits <= retrieved_address(12 downto 9);
		
		if s_read = '1' then 
			if in_cache_valid_bit = '1' then
				if tag_bits = in_cache_tag_bits then
					state <= TVNDDR;
				else
					state <= readMiss;
				end if;
			else
				state <= readMiss;
			end if; 
			
		elsif s_write = '1' then
			if in_cache_valid_bit = '1' then 
				if tag_bits = in_cache_tag_bits then
					if in_cache_dirty_bit = '0' then 
						state <= TVNDW;
					else
						state <= TVDW;
					end if;
				else 
					state <= writeMiss;
				end if;
			else 
				state <= writeMiss;
				
			end if;
		else 
			state <= idle;
		end if;
	--end if;
	
end process; 

-- Finite state machine
process (clock, reset)
begin
	if rising_edge(clock) then
		if reset = '1' then
			
		else
		   case state is
		   	-- If CPU is not doing anything
		   	when idle =>
		   	-- If read hit
		   	when TVNDDR =>
		   		s_readdata <= retrieved_address;
		   	-- If write hit
		   	when TVNDW =>
		   		
		   		
		   	-- If write hit but dirty bit then write-back 
		   	when TVDW =>
		   		
		   	-- If read miss
		   	when readMiss =>
		   		
		   	-- If write miss 
		   	when writeMiss =>
		   		
		   end case;
		 end if;
	end if;
end process;
end arch;
