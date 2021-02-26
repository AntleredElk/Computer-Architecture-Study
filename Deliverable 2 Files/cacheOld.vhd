library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_bit_unsigned.all;

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
	test1: out std_logic_vector (5 downto 0);
	test2: out std_logic_vector (5 downto 0)
	
);
end cache;

architecture arch of cache is

	-- declare signals here
	-- 15 bit signal will be of the following form: VDTTTTBBBBBWWbb
	
	constant number_of_cache_lines: integer := 128; 
	
	TYPE t_cache_memory IS ARRAY(number_of_cache_lines-1 downto 0) OF STD_LOGIC_VECTOR(31 downto 0);

	-- For data requested by CPU
	signal tag_bits: std_logic_vector (5 downto 0);
	signal block_index: std_logic_vector (4 downto 0);
	signal block_index_int: integer;
	signal word_index: std_logic_vector (1 downto 0);
	signal word_index_int: integer;
	
	-- For data in the cache
	signal in_cache_tag_bits: std_logic_vector (5 downto 0);
	signal in_cache_valid_bit: std_logic;
	signal in_cache_dirty_bit: std_logic;
	signal temp_s_addr: std_logic_vector(14 downto 0);
	signal retrieved_address: std_logic_vector (31 downto 0);

	type t_State is (readHit, writeHit, writeBack, readMiss, writeMiss, idle);

	signal state: t_State;
	signal cache_memory: t_cache_memory;

begin

-- For CPU address
	temp_s_addr(3 downto 0) <= (others => '0');
	temp_s_addr(14 downto 4) <= s_addr (14 downto 4);
--	tag_bits <= s_addr (14 downto 9);
	block_index <= s_addr (8 downto 4);
	--block_index_int <= 4*to_integer(unsigned(block_index));
	word_index <= s_addr (3 downto 2);
	--word_index_int <= to_integer(unsigned(word_index));
	
	block_index_int <= 4*to_integer(unsigned(s_addr (8 downto 4)));
	word_index_int <= to_integer(unsigned(s_addr (3 downto 2)));
	
process (s_read, s_write, s_addr)
begin	
	report integer'image(block_index_int);
	s_waitrequest <= '1';
	--s_readdata <= s_addr;
	test1(4 downto 0) <= block_index;
	--test2 <= in_cache_tag_bits;
	
	if block_index_int /= -2147483648 then 
		retrieved_address <= cache_memory(block_index_int + word_index_int);
		in_cache_valid_bit <= cache_memory(block_index_int)(15);
		in_cache_dirty_bit <= cache_memory(block_index_int)(14);
		in_cache_tag_bits <= cache_memory(block_index_int)(13 downto 8);
	end if;

	if s_read = '1' and s_write ='0' then 
		if in_cache_valid_bit = '1' then
			if in_cache_tag_bits = s_addr (14 downto 9) then
				state <= readHit;
			else
				if in_cache_dirty_bit = '1' then 
					state <= writeBack;
				else
					state <= readMiss;
				end if;
			end if;
		else
			state <= readMiss;
		end if; 
		
	elsif s_write = '1' and s_read = '0' then
		if in_cache_valid_bit = '1' then 
			if tag_bits = in_cache_tag_bits then
				state <= writeHit;
			else 
				if in_cache_dirty_bit = '1' then 
					state <= writeBack;
				else
					state <= writeMiss;
				
				end if;
			end if;
			
		end if;
	else 
		state <= idle;
	end if;
	
	
end process; 

process(state)
begin

	   case state is
	   	-- If CPU is not doing anything
	   	when idle =>
	   		report "No Reads or Writes have occured.";
	   	when readHit =>
	   		report "Read Hit Occured:";
			
	   		s_readdata <= retrieved_address;
	   	-- If write hit
	   	when writeHit =>
	   		report "Write Hit Occured:";
			cache_memory(block_index_int + word_index_int)(7 downto 0) <= s_addr(7 downto 0); 
	   		cache_memory(block_index_int)(13 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(14) <= '1';
	   		cache_memory(block_index_int)(15) <= '1';
	   		cache_memory(block_index_int)(31 downto 16) <= (others => '0');
	   		--state <= idle;
	   		
	   	-- If cache hit but dirty bit then write-back 
	   	when writeBack =>
	   		report "Write Back Occured:";
	   		-- Write back into memory first 
	   		m_write <= '1'; 
	   		
			m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)));
	   		m_writedata <= temp_s_addr(7 downto 0);
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 4;
	   		m_writedata(3 downto 0) <= "0100";
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 8;
	   		m_writedata(3 downto 0) <= "1000";
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 12;
	   		m_writedata(3 downto 0) <= "1100";
	   		
	   		m_write <= '0';
	   		
	   		-- Write to cache
	   		
	   		cache_memory(block_index_int)(13 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(14) <= '0';
	   		cache_memory(block_index_int)(15) <= '0';
	   		cache_memory(block_index_int)(31 downto 16) <= (others => '0');
	   		--state <= idle;
	   		
	   		
	   	when readMiss =>
	   		report "Read Miss Occured:";
	   		
	   		m_read <= '1';
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)));
	   		cache_memory(block_index_int)(7 downto 0) <= m_readdata;
	   		cache_memory(block_index_int)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+4; 
	   		cache_memory(block_index_int+1)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+1)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+8;
	   		cache_memory(block_index_int+2)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+2)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+12;
	   		cache_memory(block_index_int+3)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+3)(31 downto 8) <= (others => '0');
	   		m_read <= '0';
	   		
	   		cache_memory(block_index_int)(13 downto 8) <= s_addr (14 downto 9);
	   		cache_memory(block_index_int)(14) <= '0';
	   		cache_memory(block_index_int)(15) <= '1';
	   		cache_memory(block_index_int)(31 downto 16) <= (others => '0');
	   		
	   		s_readdata<= cache_memory(block_index_int + word_index_int); 
	   		--state <= idle;
	   		

	   	-- If write miss 
	   	when writeMiss =>
	   	
	   	 	report "Write Miss Occured:";
	   	 	m_write <= '1';
	   	 	
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + word_index_int;
	   		m_writedata <= s_addr(7 downto 0);
	   		
	   		m_write <= '0';	   		
	   		
	   		m_read <= '1';
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)));
	   		cache_memory(block_index_int)(7 downto 0) <= m_readdata;
	   		cache_memory(block_index_int)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+4; 
	   		cache_memory(block_index_int+1)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+1)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+8;
	   		cache_memory(block_index_int+2)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+2)(31 downto 8) <= (others => '0');
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)))+12;
	   		cache_memory(block_index_int+3)(7 downto 0) <= m_readdata; 
	   		cache_memory(block_index_int+3)(31 downto 8) <= (others => '0');
	   		m_read <= '0';
	   		
	   		cache_memory(block_index_int)(13 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(14) <= '0';
	   		cache_memory(block_index_int)(15) <= '1';
	   		cache_memory(block_index_int)(31 downto 16) <= (others => '0');
	   		--state <= idle;		
	   		
	   end case;
	s_waitrequest <= '0';
end process;
 

end arch;
