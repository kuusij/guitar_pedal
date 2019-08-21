LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY testbench IS
END testbench;

ARCHITECTURE behavior OF testbench IS 

	COMPONENT effect_top
	PORT(
        CLK_IN_TOP : in std_logic;
        RST_N_TOP : in std_logic; 
        -------------------------
        -- Inouts
        STDIN_TOP : inout std_logic;
  
        -- Outputs
        SCLK_TOP : out std_logic );
	END COMPONENT;
	
	COMPONENT I2C_slave
	PORT(
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
	END COMPONENT;
	

	SIGNAL clock_tb, reset_n_tb, sclk_tb, stdin_tb, clock_vip :  std_logic;
	signal dev_addr_final : std_logic_vector(7 downto 0);
	signal reg_addr_final : std_logic_vector(6 downto 0);
	signal data_reg_final : std_logic_vector(8 downto 0);

BEGIN

-- Please check and add your generic clause manually
	uut: effect_top PORT MAP(
        CLK_IN_TOP => clock_tb,
        RST_N_TOP => reset_n_tb,
        -------------------------
        -- Inouts
        STDIN_TOP => stdin_tb,
  
        -- Outputs
        SCLK_TOP => sclk_tb
	);

	tb_vip: I2C_slave PORT MAP(
        CLK_IN => clock_vip,
        RST_N => reset_n_tb,
        SCLK => sclk_tb,
        -- Inouts
        STDIN => stdin_tb,
  
        -- Outputs
        DEV_ADDR_FINAL => dev_addr_final,
        REG_ADDR_FINAL => reg_addr_final,
        DATA_REG_FINAL => data_reg_final
	);

-- *** Test Bench - User Defined Section ***000147AE14
   tb : PROCESS
   BEGIN
		reset_n_tb <= '0';
		wait for 20 us;
		reset_n_tb <= '1';
		wait for 20 us;
      wait;
   END PROCESS;
-- *** End Test Bench - User Defined Section ***

   clock_generation : PROCESS(clock_tb)
   BEGIN
	   if (clock_tb = '0') then
		  clock_tb <= '1' after 25 ns;
		else
		  clock_tb <= '0' after 25 ns;
		end if;
   END PROCESS;
   
    clock_generation_vip : PROCESS(clock_tb)
    BEGIN
	   if (clock_vip = '0') then
		  clock_vip <= '1' after 1750 ns;
		else
		  clock_vip <= '0' after 1750 ns;
		end if;
    END PROCESS;

END;