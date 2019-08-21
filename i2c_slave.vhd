library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity I2C_slave is
port(
--REMEMBER GENERICS; SIZEOF
  -- Inputs
  CLK_IN : in std_logic;
  RST_N : in std_logic;  
  SCLK : in std_logic;
  -- Inouts
  STDIN : inout std_logic;
  
  -- Outputs
  DEV_ADDR_FINAL : out std_logic_vector(7 downto 0);
  REG_ADDR_FINAL : out std_logic_vector(6 downto 0);
  DATA_REG_FINAL : out std_logic_vector(8 downto 0)
  
   );
end I2C_slave;

architecture behav of I2C_slave is    
signal dev_addr_reg : std_logic_vector(7 downto 0);
signal reg_addr_reg : std_logic_vector(6 downto 0);
signal data_reg : std_logic_vector(8 downto 0);

constant COUNT_TO_8_SIZE : integer := 4;
signal count_to_eight : unsigned(COUNT_TO_8_SIZE - 1 downto 0);

type t_state is (INITIAL, TAKE_DEV_ADDR, TAKE_REG_ADDR, TAKE_DATA, ACK,
                 STOP);
signal current_state, next_state, next_to_next : T_STATE;
  
begin

  I2C_comms : process(CLK_IN)
  begin
    DEV_ADDR_FINAL <= dev_addr_reg;
	REG_ADDR_FINAL <= reg_addr_reg;
	DATA_REG_FINAL <= data_reg;
  
    -- Should this be sensitive to SCLK and not CLK? SINCE the states of the i2c master are synced
	-- to SCLK, and we can't clock in data with clk. How about reset then?
	-- Can we clock this with clk, and check the state of SCLK at the rising edges of CLK?
	-- sen täytyy olla synkassa nopeamman kellon kanssa koska muuten alku ja loppuehtoja ei huomattaisi
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
		  dev_addr_reg <= x"00";
		  reg_addr_reg <= b"0000000";
		  data_reg <= b"000000000";
		  current_state <= INITIAL;
		  next_state <= INITIAL;
		  next_to_next <= INITIAL;
		  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
		  STDIN <= 'Z';
	   elsif (SCLK = '1') then
		  
	     case current_state is
          when INITIAL =>
		        STDIN <= 'Z';
				count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
            if (STDIN = '0') then
				 current_state <= TAKE_DEV_ADDR;
		    else 
			    current_state <= INITIAL;
		    end if;
          when TAKE_DEV_ADDR =>
		       STDIN <= 'Z';
			   --if (SCLK = '1') then
			     --dev_addr_reg(0) <= STDIN;
			     count_to_eight <= count_to_eight + 1;
				  -- TODO assert here, look for overflow
				  if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				    dev_addr_reg <= dev_addr_reg(6 downto 0) & STDIN;
				    current_state <= TAKE_DEV_ADDR;
				  else
				    dev_addr_reg <= dev_addr_reg(6 downto 0) & STDIN;
				    current_state <= ACK;
					--STDIN <= '0';
					next_state <= TAKE_REG_ADDR;
				    count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				  end if;
				--else 
				--  current_state <= TAKE_REG_ADDR;
				--end if;
          when TAKE_REG_ADDR =>
		       STDIN <= 'Z';
			   --if (SCLK = '1') then
			     --reg_addr_reg(6) <= STDIN;
			     count_to_eight <= count_to_eight + 1;
				  -- TODO assert here, look for overflow
				  if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				    reg_addr_reg <= reg_addr_reg(5 downto 0) & STDIN;
				    current_state <= TAKE_REG_ADDR;
				  -- 1st data bit is the 8th in here. Only 7 reg addr bits.
				  elsif (count_to_eight = to_unsigned(7, COUNT_TO_8_SIZE)) then
				    count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				    data_reg(0) <= STDIN;
				    current_state <= ACK;
					--STDIN <= '0';
				    next_state <= TAKE_DATA;
				  else -- Should not happen
				    current_state <= INITIAL;
				    count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				  end if;
				--else
				--  current_state <= TAKE_REG_ADDR;
				--end if;
          when TAKE_DATA =>
		       STDIN <= 'Z';
			   if (SCLK = '1') then
			     --data_reg(0) <= STDIN;
			     count_to_eight <= count_to_eight + 1;
				  -- TODO assert here, look for overflow
				  if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				    data_reg <= data_reg(7 downto 0) & STDIN;
				    current_state <= TAKE_DATA;
				  else
				    data_reg <= data_reg(7 downto 0) & STDIN;
				    --current_state <= ACK;
					STDIN <= '0';
				    next_state <= STOP;
				    count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				  end if;
				else
				  current_state <= TAKE_DATA;
				end if;
          when STOP =>
		       STDIN <= 'Z';
			   if (SCLK = '1' and STDIN = '1') then
			     current_state <= INITIAL;
				else
				  current_state <= STOP;
				end if;
          when ACK =>
			   --STDIN <= 'Z';
			   --if (SCLK = '1') then
				current_state <= next_state;
				STDIN <= '0';
				--else 
				 -- current_state <= ACK;
				--end if;
			 when others =>
			   assert false report "Illegal state in TB I2C slave" severity error;
        end case;
	   end if;
    end if;
  end process; -- I2C_comms

end behav;