library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity I2C is
port(
--REMEMBER GENERICS; SIZEOF
  -- Inputs
  CLK_IN : in std_logic;
  RST_N : in std_logic;       
  DATA_VALID : in std_logic;
  DEV_ADDR : in std_logic_vector(7 downto 0);
  REG_ADDR : in std_logic_vector(6 downto 0);
  DATA_IN : in std_logic_vector(8 downto 0);
  
  -- Inouts
  STDIN : inout std_logic;
  
  -- Outputs
  SCLK : out std_logic;
  READY : out std_logic;
  FAULT : out std_logic
   
   );
end I2C;

architecture rtl of I2C is    
signal dev_addr_reg : std_logic_vector(7 downto 0);
signal reg_addr_reg : std_logic_vector(6 downto 0);
signal data_reg : std_logic_vector(8 downto 0);

signal start_clk_out, start_flag : std_logic;
--signal SCLK : std_logic;

constant COUNT_TO_8_SIZE : integer := 4;
signal count_to_eight : unsigned(COUNT_TO_8_SIZE - 1 downto 0);

type t_state is (INITIAL, START, ADDR_TO_DEV, ADDR_TO_REG, DATA, WAIT_FOR_ACK, 
                 EXTRA_CYCLE, STOP);
signal current_state, next_state, next_to_next : T_STATE;
  
begin

  I2C_comms : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
	     STDIN <= '1';
		  dev_addr_reg <= x"00";
		  reg_addr_reg <= b"0000000";
		  data_reg <= b"000000000";
		  start_clk_out <= '0';
		  SCLK <= '1';
		  --SCLK <= '1';
		  current_state <= INITIAL;
		  next_state <= INITIAL;
		  next_to_next <= INITIAL;
		  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
		  READY <= '1';
		  FAULT <= '1';
		  start_flag <= '1';
	   else
		  
		  -- Generating the clock for I2C
		  --if (start_clk_out = '1') then
		  --  SCLK <= not SCLK;
		  --  SCLK <= not SCLK;
        --else
		    --SCLK <= '1';
			-- SCLK <= '1';
		  --end if;
		  
	     case current_state is
          when INITIAL =>
				SCLK <= '1';
				STDIN <= '1';
			   --start_clk_out <= '0';
				count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
            if (DATA_VALID = '1') then
				  dev_addr_reg <= DEV_ADDR;
				  reg_addr_reg <= REG_ADDR;
				  data_reg <= DATA_IN;
			     READY <= '0';
				  current_state <= START;
		      else 
			     current_state <= INITIAL;
			   end if;
          when START =>
		      STDIN <= '0';
				SCLK <= '1';
			   --start_clk_out <= '1';
				current_state <= ADDR_TO_DEV;
				next_state <= EXTRA_CYCLE;
          when ADDR_TO_DEV =>
			   STDIN <= dev_addr_reg(7);
				SCLK <= '0';
			   count_to_eight <= count_to_eight + 1;
				-- TODO assert here, look for overflow
				if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				  dev_addr_reg <= dev_addr_reg(6 downto 0) & '0';
				  current_state <= EXTRA_CYCLE;
				  next_state <= ADDR_TO_DEV;
				else
				  current_state <= EXTRA_CYCLE;
				  next_state <= WAIT_FOR_ACK;
				  next_to_next <= ADDR_TO_REG;
				  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				end if;
          when ADDR_TO_REG =>
			   SCLK <= '0';
			   count_to_eight <= count_to_eight + 1;
				-- TODO assert here, look for overflow
				if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				  STDIN <= reg_addr_reg(6);
				  reg_addr_reg <= reg_addr_reg(5 downto 0) & '0';
				  current_state <= EXTRA_CYCLE;
				  next_state <= ADDR_TO_REG;
				-- 1st data bit is the 8th in here. Only 7 reg addr bits.
				elsif (count_to_eight = to_unsigned(7, COUNT_TO_8_SIZE)) then
				  STDIN <= data_reg(8);
				  data_reg <= data_reg(7 downto 0) & '0';
				  current_state <= EXTRA_CYCLE;
				  next_state <= WAIT_FOR_ACK;
				  next_to_next <= DATA;
				  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				else -- Should not appear
				  current_state <= EXTRA_CYCLE;
				  next_state <= WAIT_FOR_ACK;
				  next_to_next <= DATA;
				  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				end if;
          when DATA =>
				SCLK <= '0';
			   STDIN <= data_reg(8);
			   count_to_eight <= count_to_eight + 1;
				-- TODO assert here, look for overflow
				if (count_to_eight < to_unsigned(7, COUNT_TO_8_SIZE)) then
				  data_reg <= data_reg(7 downto 0) & '0';
				  current_state <= EXTRA_CYCLE;
				  next_state <= DATA;
				else
				  current_state <= EXTRA_CYCLE;
				  next_state <= WAIT_FOR_ACK;
				  next_to_next <= STOP;
				  count_to_eight <= to_unsigned(0, COUNT_TO_8_SIZE);
				end if;
          when STOP =>
				SCLK <= '0';
			   FAULT <= '1';
			   start_clk_out <= '0';
		      STDIN <= '0';
			   --start_clk_out <= '1';
			   current_state <= EXTRA_CYCLE;
				next_state <= INITIAL;
				next_to_next <= INITIAL;
				READY <= '1';
          when WAIT_FOR_ACK =>
		        STDIN <= 'Z';
				
				if (not(next_to_next = EXTRA_CYCLE)) then
				  next_to_next <= EXTRA_CYCLE;
				  SCLK <= '0';
				elsif (STDIN /= '0') then
				  SCLK <= '1';
				  current_state <= EXTRA_CYCLE;
				  next_state <= INITIAL;
				  next_to_next <= INITIAL;
				  FAULT <= '0';
				else
					SCLK <= '1';
				  current_state <= next_state;
				end if;
				
			 -- To generate output clock accurately
          when EXTRA_CYCLE =>
		      SCLK <= '1';
				--if (next_state = WAIT_FOR_ACK) then
		      --  STDIN <= 'Z';
				if (start_flag = '1') then
				  start_flag <= '0';
				  STDIN <= '0';
				end if;
				--if (next_state = INITIAL) then
				--	start_clk_out <= '0';
				--else
				--	start_clk_out <= '1';
				--end if;
				current_state <= next_state;
				next_state <= next_to_next;
				next_to_next <= INITIAL;
			-- TODO Maybe assertion here, invalid state?
        end case;
	   end if;
    end if;
  end process; -- I2C_comms

end rtl;