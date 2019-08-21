library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_tap is
generic (SAMPLE_WIDTH : integer := 24;
         TAP_SUM_WIDTH : integer := 20;
         TAP_WIDTH : integer := 8);
port(
  -- Inputs
  CLK_IN : in std_logic;
  RST_N 	: in std_logic;
  SAMPLE_IN : in std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
  SUM_IN : in std_logic_vector(SAMPLE_WIDTH + TAP_SUM_WIDTH - 4 - 1 downto 0);
  TAP_IN : in std_logic_vector(TAP_WIDTH - 1 downto 0);
  
  -- Outputs
  SUM_OUT : out std_logic_vector(SAMPLE_WIDTH + TAP_SUM_WIDTH - 4 - 1 downto 0);
  DELAYED_SAMPLE_OUT : out std_logic_vector(SAMPLE_WIDTH - 1 downto 0)
   );
end fir_tap;

architecture rtl of fir_tap is    
  signal sample_delay : std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
  begin
  
  DATA_IN : process(CLK_IN)
  variable temp_sum : signed(SUM_OUT'length downto 0);
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
        SUM_OUT <= (others => '0');
        DELAYED_SAMPLE_OUT <= (others => '0');
        sample_delay <= (others => '0');
	  else
        DELAYED_SAMPLE_OUT <= SAMPLE_IN;
        sample_delay <= SAMPLE_IN;
        
        --temp_sum := to_signed(0, temp_sum'length) + (signed('0' & TAP_IN)*signed(SAMPLE_IN));
        --temp_sum = temp_sum + signed)

        --temp_sum := (signed(SUM_IN) + (signed('0' & TAP_IN)*signed(SAMPLE_IN)));
        --SUM_OUT <= std_logic_vector(temp_sum(SUM_OUT'high downto 0));
        SUM_OUT <= std_logic_vector((signed(SUM_IN) + (signed('0' & TAP_IN)*signed(SAMPLE_IN))));
	  end if;
    end if;
  end process; -- DATA_IN
  

end rtl;