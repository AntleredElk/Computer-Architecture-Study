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
	m_waitrequest : in std_logic
	
);
end cache;

architecture arch of cache is

	-- declare signals here
	-- 15 bit signal will be of the following form: VDTTTTBBBBBWWbb
	
	constant number_of_cache_blocks: integer := 32; 
	
	TYPE t_cache_memory IS ARRAY(number_of_cache_blocks-1 downto 0) OF STD_LOGIC_VECTOR(31 downto 0);

	-- For data requested by CPU
	signal tag_bits: std_logic_vector (3 downto 0);
	signal block_index: std_logic_vector (3 downto 0);
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

-- For CPU address
tag_bits <= s_addr (11 downto 8);
block_index <= s_addr (7 downto 4);
block_index_int <= to_integer(unsigned(block_index));
word_index <= s_addr (3 downto 2);

process (s_addr)
begin	
	--if rising_edge(clock) then

		-- For cache address

		if block_index_int /= -2147483648 then 
			retrieved_address <= cache_memory(block_index_int);
		end if;
		
		in_cache_valid_bit <= retrieved_address(13);
		in_cache_dirty_bit <= retrieved_address(12);
		in_cache_tag_bits <= retrieved_address(11 downto 8);
		
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
process (s_addr)
begin

	   case state is
	   	-- If CPU is not doing anything
	   	when idle =>
	   		report "No Reads or Writes have occured.";
	   	when TVNDDR =>
	   		report "Read Hit Occured:";
	   		s_readdata <= retrieved_address;
	   	-- If write hit
	   	when TVNDW =>
	   		cache_memory(block_index_int)(7 downto 0) <= s_addr(7 downto 0); 
	   		cache_memory(block_index_int)(11 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(12) <= '1';
	   		cache_memory(block_index_int)(13) <= '1';
	   		cache_memory(block_index_int)(31 downto 14) <= (others => '0'); 
	   		
	   	-- If write hit but dirty bit then write-back 
	   	when TVDW =>
	   		-- Write back into memory first 
	   		m_addr <= to_integer(unsigned(s_addr(14 downto 0)));
	   		m_write <= '1';
	   		m_writedata <= cache_memory(block_index_int)(7 downto 0);
	   		
	   		-- Write to cache
	   		cache_memory(block_index_int)(7 downto 0) <= s_addr(7 downto 0); 
	   		cache_memory(block_index_int)(11 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(12) <= '0';
	   		cache_memory(block_index_int)(13) <= '1';
	   		cache_memory(block_index_int)(31 downto 14) <= (others => '0'); 
	   		
	   	-- If read miss
	   	when readMiss =>
	   		report "Read Miss Occured:";
	   		m_addr <= to_integer(unsigned(s_addr(14 downto 0)));
	   		m_read <= '1';
	   		cache_memory(block_index_int)(7 downto 0) <= m_readdata; 
	   		m_read <= '0';
	   		cache_memory(block_index_int)(11 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(12) <= '0';
	   		cache_memory(block_index_int)(13) <= '1';
	   		cache_memory(block_index_int)(31 downto 14) <= (others => '0');
	   		s_readdata<= cache_memory(block_index_int); 
	   		

	   	-- If write miss 
	   	when writeMiss =>
	   		report "Write Miss Occured:";
	   		m_addr <= to_integer(unsigned(s_addr(14 downto 0)));
	   		m_write <= '1';
	   		m_writedata <= s_addr(7 downto 0);
	   		m_write <= '0';
	   		cache_memory(block_index_int)(7 downto 0) <= s_addr(7 downto 0); 
	   		cache_memory(block_index_int)(11 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(12) <= '0';
	   		cache_memory(block_index_int)(13) <= '1';
	   		cache_memory(block_index_int)(31 downto 14) <= (others => '0'); 
	   		
	   		
	   end case;

end process;
end arch;
