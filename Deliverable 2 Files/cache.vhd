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
	m_waitrequest : in std_logic
	
);
end cache;

architecture arch of cache is

	-- declare signals here
	-- 15 bit signal will be of the following form: VDTTTTBBBBBWWbb
	
	constant number_of_cache_lines: integer := 128; 
	
	TYPE t_cache_memory IS ARRAY(number_of_cache_lines-1 downto 0) OF STD_LOGIC_VECTOR(31 downto 0);

	-- For data requests by CPU
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

	type t_State is (idle, read, write, writeBack, replace);

	signal state: t_State;
	signal nextState: t_State; 
	signal cache_memory: t_cache_memory;

begin

-- Used to update the state of the FSM at each clock cycle
clock_for_FSM: process(clock)
begin
	state <= nextState;
end process;

finite_state_machine: process(s_read, s_write, s_addr, state)
begin

	-- For storing CPU data address
	temp_s_addr(3 downto 0) <= (others => '0');
	temp_s_addr(14 downto 4) <= s_addr (14 downto 4);
	tag_bits <= s_addr (14 downto 9);
	block_index <= s_addr (8 downto 4);
	block_index_int <= 4*to_integer(unsigned(s_addr (8 downto 4)));
	word_index <= s_addr (3 downto 2);
	word_index_int <= to_integer(unsigned(s_addr (3 downto 2)));
	
	-- This blocks ensures that the block index isn't used when it's null and just being initialized
	if block_index_int /= -2147483648 then 
		retrieved_address <= cache_memory(block_index_int + word_index_int);
		in_cache_valid_bit <= cache_memory(block_index_int)(15);
		in_cache_dirty_bit <= cache_memory(block_index_int)(14);
		in_cache_tag_bits <= cache_memory(block_index_int)(13 downto 8);
	end if;
	
	case state is
		-- Idle state contains all of the logic for branching into other states
		when idle => 
			s_waitrequest <= '1';
			
			if s_read = '1' then
				if in_cache_valid_bit = '1' then
					if in_cache_tag_bits = tag_bits then
						-- Matching Tag, Valid bit set (dirty bit doesn't matter here)
						nextState <= read;
					else 
						-- Valid bit set, but tag is not matching. 
						-- Dirty bit important here to determine if writeback or simple block replacement
						if in_cache_dirty_bit = '1' then 
							nextState <= writeBack;
						else
							nextState <= replace;
						end if;
					end if;
				else
					nextState <= replace;
				end if;
			elsif s_write = '1' then
				if in_cache_valid_bit = '1' then
					if in_cache_tag_bits = tag_bits then
						-- Matching Tag, Valid bit set (dirty bit doesn't matter here)
						nextState <= write; 
					else 
						-- Valid bit set, but tag is not matching. 
						-- Dirty bit important here to determine if writeback or simple block replacement
						if in_cache_dirty_bit = '1' then 
							nextState <= writeBack;
						else
							nextState <= replace;
						end if;
					end if;
				else 
					nextState <= replace; 
				end if; 
			else 
				nextState <= idle;					
			end if; 
		when read =>
		
			-- Simply reads the data in cache
			s_readdata<= cache_memory(block_index_int + word_index_int);
			nextState <= idle; 
			
			s_waitrequest <= '0';
			
		when write => 
			-- Writes the data to cache
			cache_memory(block_index_int + word_index_int) <= s_writedata; 
	   		cache_memory(block_index_int)(13 downto 8) <= tag_bits;
	   		cache_memory(block_index_int)(14) <= '1';
	   		cache_memory(block_index_int)(15) <= '1';
	   		cache_memory(block_index_int)(31 downto 16) <= (others => '0');
	   		
	   		nextState <= idle;
	   		
	   		s_waitrequest <= '0';
	   		
		when writeBack =>
			-- Writes the data to main memory
			m_write <= '1'; 
	   		
			m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0)));
	   		m_writedata <= cache_memory(block_index_int)(7 downto 0);
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 4;
	   		m_writedata <= cache_memory(block_index_int + 1)(7 downto 0);
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 8;
	   		m_writedata <= cache_memory(block_index_int + 2)(7 downto 0);
	   		
	   		m_addr <= to_integer(unsigned(temp_s_addr(14 downto 0))) + 12;
	   		m_writedata <= cache_memory(block_index_int + 3)(7 downto 0);
	   		
	   		m_write <= '0';
	   		
	   		nextState <= replace;

		when replace => 
			-- Replaces or adds a block from main memory to cache
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
	   		
	   		-- If Read go to read state
	   		If s_read = '1' then 
	   			nextState <= read;
	   		-- If Write go to write state
	   		elsif s_write = '1' then 
	   			nextState <= write;
	   		else 
	   			nextState <= idle;
	   		end if; 
	end case; 
	
end process;

end arch; 
