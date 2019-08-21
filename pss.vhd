library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pss is
port(
  CLK_IN : in std_logic;
  RST_N : in std_logic; 
  -------------------------
  READY : in std_logic;
  I2CFAULT : in std_logic;
  -------------------------
  DATA_VALID : out std_logiC;
  -------------------------
  DEV_ADDR : out std_logic_vector(7 downto 0);
  REG_ADDR : out std_logic_vector(6 downto 0);
  DATA_OUT : out std_logic_vector(8 downto 0);
  FINALIZED : out std_logic
   );
end pss;

architecture rtl of pss is    

type dev_addresses_type is array (integer range <>) of std_logic_vector(7 downto 0);
type reg_addresses_type is array (integer range <>) of std_logic_vector(6 downto 0);
type data_type is array (integer range <>) of std_logic_vector(8 downto 0);

constant DSP_ACT : std_logic_vector(6 downto 0) := "0001001";
constant LLIN : std_logic_vector(6 downto 0) := "0000000";
constant RLIN : std_logic_vector(6 downto 0) := "0000001";

constant HP_VOL : std_logic_vector(6 downto 0) := "0000010";
constant INPUT_SEL : std_logic_vector(6 downto 0) := "0000100";
constant ADC_DAC : std_logic_vector(6 downto 0) := "0000101";
constant PWR_OFF : std_logic_vector(6 downto 0) := "0000110";
constant CLK_MODE : std_logic_vector(6 downto 0) := "0000111";
constant SAMPLE_R : std_logic_vector(6 downto 0) := "0001000";
constant RESET : std_logic_vector(6 downto 0) := "0001111";


-- TODO Add meaningful addresses, dataconstant DSP_ACT : std_logic_vector(6 downto 0) := 
constant dev_addresses : dev_addresses_type(0 to 11) := (x"34", x"34", x"34", x"34", x"34", x"34", x"34", x"34", x"34", x"34", x"34", x"34"); 
--constant reg_addresses : reg_addresses_type(dev_addresses'range) := (RESET, DSP_ACT, LLIN, HP_VOL, INPUT_SEL, PWR_OFF);
constant reg_addresses : reg_addresses_type(dev_addresses'range) := (PWR_OFF, RESET, DSP_ACT, LLIN, RLIN, HP_VOL, INPUT_SEL, ADC_DAC, CLK_MODE, SAMPLE_R, PWR_OFF, DSP_ACT); 
constant datas : data_type(dev_addresses'range) := ("000010010", -- Power on everything except OUTPD
													"000000000", --, -- RESET
													"000000000", -- DISABLE DSP interface
													"101110011", --"101101011", -- lLINE IN VOL
													--"101110111", -- lLINE IN VOL
													"101110011",--"010010011", -- rLINE IN VOL
													--"111111000", -- L/R HP VOL
													"101111001", -- L/R HP VOL
													--"011010010", -- Select DAC, disable bypass 
													"000010010",
													
													"000000001", --HPF
													--"000010110", -- enable HPF to get measure of dc offset, sel 48khz 
													--"000010111", -- disable ADC HPF, sel 48khz 
													"000001010", -- I2S, 24-bits, LRP 0, Master mode
													"000011100", -- 48kHz sampling rate, BOSR bit may have to be set
													"000000010", -- Power on LIN, ADC, DAC etc
													"000000001"); -- ACTIVATE DSP interface

--constant datas : data_type(dev_addresses'range) := ("000000000",
--																	 "000000000", -- DISABLE DSP interface
	--																 "100011111", -- LINE IN VOL
		--															 "101111111", -- L/R HP VOL
			--														 "000101101", -- Select DAC, disable bypass
				--													 
					--												 --"000000101"); -- disable ADC HPF, sel 44,1khz
						--											 "000001100"); -- Power on LIN, ADC, DAC etc
							--										 --"0"); -- 
--

type t_state is (INITIAL, START, STOP);
signal current_state : T_STATE;

signal current_op_num : integer range 0 to datas'length;
  
begin

  reg_ops : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
		  DATA_VALID <= '0';
        DEV_ADDR <= (others => '0');
        REG_ADDR <= (others => '0');
        DATA_OUT <= (others => '0');
		  FINALIZED <= '1';
		  current_state <= INITIAL;
		  
		  current_op_num <= 0;
	   else
	     case current_state is
          when INITIAL =>
				if (READY = '1') then
				  DEV_ADDR <= dev_addresses(current_op_num);
				  REG_ADDR <= reg_addresses(current_op_num);
				  DATA_OUT <= datas(current_op_num);
			     DATA_VALID <= '1';
				  current_state <= START;
		      else 
			     current_state <= INITIAL;
			   end if;
				if (I2CFAULT = '0') then
						current_op_num <= 0;
				end if;
          when START =>
		      if (current_op_num >= datas'high) then
				  current_state <= STOP;
				else
				  current_op_num <= current_op_num + 1;
				  current_state <= INITIAL; 
				end if;
          when STOP =>
				if (READY = '1') then
					FINALIZED <= '0';
				end if;
			   DATA_VALID <= '0';
				current_state <= STOP;
			 when others =>
			   assert false report "Illegal state in pss" severity error;
			-- TODO Maybe assertion here, invalid state?
        end case;
	   end if;
    end if;
  end process; -- reg_ops

end rtl;