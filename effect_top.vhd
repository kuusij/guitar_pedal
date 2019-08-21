library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity effect_top is
port(
  CLK_IN_TOP : in std_logic;
  RST_N_TOP : in std_logic; 
  ADCDAT : in std_logic;
  FX_SWITCH : in std_logic;
  -------------------------
  -- Inouts
  STDIN_TOP : inout std_logic;
  
  -- Outputs
  BCLK : out std_logic;
  ADCLRC : out std_logic;
  DACLRC : out std_logic;
  SCLK_TOP : out std_logic;
  LED_PORT : out std_logic;
  OUT_3V : out std_logic;
  DACDAT : out std_logic;
  FX_ON : out std_logic;
  FAULT : out std_logic );
end effect_top;

architecture structural of effect_top is    

--signal clk, reset_n : std_logic;
--signal std_in, sclk_out : std_logic;

signal data_valid, data_valid_pss, ready : std_logic;
signal dev_addr : std_logic_vector(7 downto 0);
signal reg_addr : std_logic_vector(6 downto 0);
signal data : std_logic_vector(8 downto 0);
signal CLK_IN_TOP_SIG : std_logic;
signal pll_locked : std_logic;
signal pss_done : std_logic;
signal fault_i2c : std_logic;
signal DSP_CLK : std_logic;
signal top_reset_n : std_logic;
signal overdrive : std_logic;
  
component pss
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
  FINALIZED : out std_logic );
end component;

component altpll_oma
	PORT
	(
		inclk0		: IN STD_LOGIC;
		c0		: OUT STD_LOGIC;
		c1		: OUT STD_LOGIC;
		locked		: OUT STD_LOGIC 
	);
END component;

component I2C 
  port(
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
  FAULT : out std_logic );
end component;

component audio_ctrl 
  generic (SAMPLE_WIDTH : integer);
  port(
  -- Inputs
  CLK_IN : in std_logic;
  RST_N 	: in std_logic;
  ADCDAT : in std_logic;
  PSS_DONE : in std_logic;
  FX_ON_OFF : in std_logic;
  INC_OVERDRIVE : in std_logic;
  
  -- Outputs
  --BCLK 	: in std_logic;
  ADCLRC : out std_logic;       
  DACLRC : out std_logic;
  FX_ON : out std_logic;
  DACDAT : out std_logic );
end component;

begin
  top_reset_n <= RST_N_TOP or FX_SWITCH;
  overdrive <= not(RST_N_TOP);
  data_valid <= data_valid_pss and pll_locked;
  OUT_3V <= '1';
  LED_PORT <= pss_done;
  FAULT <= fault_i2c;
  BCLK <= DSP_CLK;
  
  altpll_oma_inst : altpll_oma PORT MAP (
		inclk0	 => CLK_IN_TOP,
		c0	 => CLK_IN_TOP_SIG,
		c1 => DSP_CLK,
		locked	 => pll_locked
	);


  i2c_1 : I2C PORT MAP(CLK_IN => CLK_IN_TOP_SIG,
                      RST_N => top_reset_n,
                      DATA_VALID => data_valid,
                      DEV_ADDR => dev_addr,
							 REG_ADDR => reg_addr,
							 DATA_IN => data,
							 STDIN => STDIN_TOP,
							 SCLK => SCLK_TOP,
							 READY => ready,
							 FAULT => fault_i2c );
							
  dsp_comp : audio_ctrl GENERIC MAP(SAMPLE_WIDTH => 24)
				  PORT MAP(CLK_IN => DSP_CLK,
							  RST_N => top_reset_n,
							  FX_ON_OFF => FX_SWITCH,
                              INC_OVERDRIVE => overdrive,
							  --BCLK => BCLK,
							  ADCLRC => ADCLRC,
							  DACLRC => DACLRC,
							  ADCDAT => ADCDAT,
							  FX_ON => FX_ON,
							  PSS_DONE => pss_done,
							  DACDAT => DACDAT );
							 
  pss_1 : pss PORT MAP(CLK_IN => CLK_IN_TOP_SIG,
                      RST_N => top_reset_n,
							 READY => ready,
							 I2CFAULT => fault_i2c,
                      DATA_VALID => data_valid_pss,
                      DEV_ADDR => dev_addr,
							 REG_ADDR => reg_addr,
							 DATA_OUT => data,
							 FINALIZED => pss_done );
 
end structural;