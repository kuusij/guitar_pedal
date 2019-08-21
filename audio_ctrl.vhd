library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- TODO TSEKKAA BITTIVEKTORIEN SLAICCAUS, SIELLÄ USEIN VIRHEITÄ

entity audio_ctrl is
generic (SAMPLE_WIDTH : integer := 24);
port(
--REMEMBER GENERICS; SIZEOF
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
  FX_ON : out std_logic;
  DACLRC : out std_logic;
  DACDAT : out std_logic
   );
end audio_ctrl;

architecture rtl of audio_ctrl is  

	COMPONENT compressor
    GENERIC (SAMPLE_WIDTH : INTEGER := 24);
	PORT(
          CLK_IN : in std_logic;
          RST_N 	: in std_logic;
          SAMPLE_IN : in std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
          OVERDRIVE : in std_logic_vector(6 downto 0);
          
          -- Outputs
          SAMPLE_OUT : out std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
          ENVELOPE : out std_logic_vector(24 - 1 downto 0);
          ENV_PLUS_INPUT : out std_logic_vector(31 - 1 downto 0);
          SATURATED : out std_logic_vector(29 - 1 downto 0);
          MULTIPLIED : out std_logic_vector(44 - 1 downto 0)
        );
	END COMPONENT;

  
signal adc_in_l, adc_in_l2, adc_in_r, adc_in_r2, adc_flips_l, adc_flips_r : signed(SAMPLE_WIDTH-1 downto 0);
signal dc_offset_temp : signed(SAMPLE_WIDTH + 13 - 1 downto 0);
signal dac_out_l, dac_out_r, dc_offset, offset_removed : signed(SAMPLE_WIDTH-1 downto 0);
signal compressed : std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
attribute syn_preserve: boolean;
attribute syn_preserve of adc_flips_r: signal is true;
attribute syn_preserve of adc_flips_l: signal is true;

signal BCLK_out : std_logic;

signal adc_count_width : integer range 0 to SAMPLE_WIDTH-1 := 0; 
signal dac_count_width : integer range 0 to SAMPLE_WIDTH-1 := 0;

signal pulse_cnt : integer range 0 to 4 := 0;
signal dc_off_cnt : integer range 0 to 8191;

signal s_overdrive : unsigned(6 downto 0);
--constant s_overdrive : unsigned(6 downto 0) := "0001000";

signal lr_ctrl_bit : std_logic;
signal lr_ctrl_cntr : integer range 0 to 768 := 0;

type adc_state is (INITIAL, ADC_L, ADC_R);
signal adc_current_state : adc_state;

type dac_state is (INITIAL, DAC_L, DAC_R);
signal dac_current_state : dac_state;

signal lfcounter : integer range 0 to 1535 := 0;

signal l_sample_taken, r_sample_taken : std_logic;
  
signal fx_toggle, fx_reg, rl_toggle : std_logic;

signal inc_toggle, inc_reg : std_logic;

signal inc_cntr : integer range 0 to 6;

signal blvd_ctr : unsigned(21 downto 0);
signal toggle_blvd : std_logic;
signal blvd_mute_ctr : unsigned(11 downto 0);

constant ZERO_LEVEL : unsigned (SAMPLE_WIDTH - 1 downto 0) := x"FBA898";

constant FX_WIDTH : integer := 1;
constant FX_INDEX : integer := adc_in_r'high - 5;
begin

	uut: compressor 
        GENERIC MAP(SAMPLE_WIDTH => 24)
        PORT MAP(
        CLK_IN => lr_ctrl_bit,
        RST_N => RST_N,
        -------------------------
        -- Inouts
        SAMPLE_IN => std_logic_vector(offset_removed),
        OVERDRIVE => std_logic_vector(s_overdrive),
  
        -- Outputs
        SAMPLE_OUT => compressed,
        ENVELOPE => open,
        ENV_PLUS_INPUT => open,
        SATURATED => open,
        MULTIPLIED => open
	);

	ADCLRC <= lr_ctrl_bit;
	DACLRC <= lr_ctrl_bit;
	FX_ON <= fx_reg;

  LR_CTRL : process(CLK_IN)
  begin
	if (falling_edge(CLK_IN)) then
		if (RST_N = '0' or PSS_DONE = '1') then
			lr_ctrl_bit <= '0';
			lr_ctrl_cntr <= 0;
		else
			if (lr_ctrl_cntr = 63) then
				lr_ctrl_cntr <= 0;
				lr_ctrl_bit <= not(lr_ctrl_bit);
			else
				lr_ctrl_cntr <= lr_ctrl_cntr + 1;
			end if;
		end if;
	end if;
  end process; -- LR_CTRL
--
  DATA_IN : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
	     adc_in_l <= (others => '0');
		  adc_in_r <= (others => '0');
		  adc_current_state <= INITIAL;
		  adc_count_width <= 0;
		  r_sample_taken <= '0';
		  l_sample_taken <= '0';
		  adc_flips_r <= (others => '0');
		  adc_flips_l <= (others => '0');
	   else
		  
	     case adc_current_state is
          when INITIAL =>
				r_sample_taken <= '1';
				l_sample_taken <= '1';
            if (PSS_DONE = '0') then
					if (lr_ctrl_bit = '0') then
						adc_current_state <= ADC_R;
					else
						adc_current_state <= ADC_L;
					end if;
		      else 
			     adc_current_state <= INITIAL;
			   end if;
          when ADC_L =>
		      if (adc_count_width < SAMPLE_WIDTH) then
					adc_in_l((SAMPLE_WIDTH-adc_count_width)-1) <= ADCDAT;
					adc_count_width <= adc_count_width + 1;
					adc_current_state <= ADC_L;
					l_sample_taken <= '0';
				elsif (lr_ctrl_bit = '0') then
					adc_current_state <= ADC_R;
					adc_flips_l <= adc_flips_l or adc_in_l;
					adc_count_width <= 0;
					l_sample_taken <= '1';
				else
					adc_current_state <= ADC_L;
					l_sample_taken <= '1';
				end if;
          when ADC_R =>
		      if (adc_count_width < SAMPLE_WIDTH) then
					adc_in_r((SAMPLE_WIDTH-adc_count_width)-1) <= ADCDAT;
					adc_count_width <= adc_count_width + 1;
					adc_current_state <= ADC_R;
					r_sample_taken <= '0';
				elsif (lr_ctrl_bit = '1') then
					adc_current_state <= ADC_L;
					adc_flips_r <= adc_flips_r or adc_in_r;
					r_sample_taken <= '1';
					adc_count_width <= 0;
				else
					adc_current_state <= ADC_R;
					r_sample_taken <= '1';
				end if;
        end case;
	   end if;
    end if;
  end process; -- DATA_IN
  
  
  data_reg : process(CLK_IN)
  variable temp_filt, temp_filt_l : signed(adc_in_r'high downto 0);
  variable temp_result : signed(adc_in_r'high + 1 downto 0);
  variable temp_mult : signed(temp_filt'length + blvd_mute_ctr'length downto 0);
  variable dc_offset_tmp : signed(dc_offset_temp'high downto 0);
  variable ss_overdrive : unsigned(6 downto 0);
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
	     dac_out_l <= (others => '0');
		  dac_out_r <= (others => '0');
		  fx_reg <= '1';
          inc_reg <= '1';
          inc_toggle <= '0';
		  fx_toggle <= '0';
		  blvd_ctr <= (others => '0');
		  rl_toggle <= '0';
		  blvd_mute_ctr <= (others => '1');
		  pulse_cnt <= 0;
		  temp_filt := x"F00000";
		  offset_removed <= (others => '0');
          dc_off_cnt <= 0;
          dc_offset_temp <= (others => '0');
          dc_offset <= (others => '0');
          inc_cntr <= 0;
          s_overdrive <= "0000001";
	   else
		  if (FX_ON_OFF = '0') then
				if (fx_toggle = '0') then
					fx_toggle <= '1';
					fx_reg <= not(fx_reg);
				end if;
		  else
				fx_toggle <= '0';
		  end if;
          
		  if (INC_OVERDRIVE = '1') then
				if (inc_toggle = '0') then
					inc_toggle <= '1';
					inc_reg <= not(inc_reg);
                    if(inc_cntr = 6) then
                        inc_cntr <= 0;
                    else
                        inc_cntr <= inc_cntr + 1;
                    end if;
				end if;
		  else
				inc_toggle <= '0';
		  end if;
          ss_overdrive := "0000001";
          
          s_overdrive <= shift_left(ss_overdrive, inc_cntr);
		  
		  if (r_sample_taken = '1') then
				if(rl_toggle = '1') then
					rl_toggle <= '0';
                    if (dc_off_cnt = 8191) then
                        dc_off_cnt <= 0;
                        dc_offset_tmp := dc_offset_temp + adc_in_r;
                        dc_offset_tmp := shift_right(dc_offset_tmp, 13);
                        dc_offset <= dc_offset_tmp(dc_offset'high downto 0); -- & dc_offset_tmp(SAMPLE_WIDTH - 2 downto 0);
                        dc_offset_temp <= (others => '0');
                    else
                        dc_off_cnt <= dc_off_cnt + 1;
                        dc_offset_temp <= to_signed(0, dc_offset_temp'length) + dc_offset_temp + adc_in_r;
                    end if;
					--if (pulse_cnt = 4) then
					--	pulse_cnt <= 0;
					--	temp_filt := not(temp_filt);
					--else
					--	pulse_cnt <= pulse_cnt + 1;
					--end if;
					-- TODO TeroK temporarily disabled to see ADC amplitude
					--temp_filt := to_signed(0, temp_filt'length) + adc_in_r;
					--temp_filt(9 downto 0) := b"0101010101";
					--temp_filt := shift_left(temp_filt, 4); -- (adc_in_r, 4);
					--temp_result := signed('0' & adc_in_r) - signed('0' & ZERO_LEVEL);
                    temp_filt := adc_in_r - dc_offset;
                    --temp_filt := shift_right(temp_filt, 8);
                    --temp_filt := shift_right(temp_filt, inc_cntr);
                    
                    
                    --temp_filt := (others => adc_in_r(adc_in_r'high));
					--temp_filt := temp_filt(temp_filt'high) & temp_filt(temp_filt'high - 2 downto 0) & temp_filt(0) ;
					--temp_filt := temp_result(temp_result'high) & temp_result(temp_result'high - 6 downto 0) & b"0000";
					--to_signed(0, temp_filt'length) + adc_in_r - ZERO_LEVEL;
					
					--temp_filt_l := to_signed(0, temp_filt_l'length) + adc_in_l;
					--temp_filt_l(9 downto 0) := b"0101010101";
					--temp_filt_l := shift_left(temp_filt_l, 4); --(adc_in_l, 4);
					--temp_result := signed('0' & adc_in_r) - signed('0' & ZERO_LEVEL);
					temp_filt_l := temp_filt;
					offset_removed <= temp_filt;
					--temp_filt_l := temp_result(temp_result'high) & temp_result(temp_result'high - 6 downto 0) & b"0000";
					--to_signed(0, temp_filt_l'length) + adc_in_l;
					
					if (fx_reg = '0') then
						--temp_filt := temp_filt(temp_filt'high downto FX_INDEX) & to_signed(0, FX_WIDTH) & temp_filt(FX_INDEX - FX_WIDTH - 1 downto 0);
						--temp_filt(10 downto 0) := to_signed(0, 11);
						
						
						if (blvd_ctr < to_unsigned(4675, 22)) then
							blvd_ctr <= blvd_ctr + to_unsigned(1, 22);
						else
							blvd_ctr <= (others => '0');
							toggle_blvd <= not(toggle_blvd);
						end if;
						
						if (toggle_blvd = '1') then
						  if (blvd_mute_ctr < to_unsigned((2 ** blvd_mute_ctr'length) - 1, blvd_mute_ctr'length)) then
							blvd_mute_ctr <= blvd_mute_ctr + to_unsigned(1, blvd_mute_ctr'length);
						  end if;

						else
							if (blvd_mute_ctr > to_unsigned((2 ** (blvd_mute_ctr'length - 1)) - 1, blvd_mute_ctr'length)) then
								blvd_mute_ctr <= blvd_mute_ctr - to_unsigned(1, blvd_mute_ctr'length);
							end if;
						end if;
						
						temp_mult := signed('0' & blvd_mute_ctr) * (temp_filt - temp_filt_l);
						temp_mult := shift_right(temp_mult, blvd_mute_ctr'length) + temp_filt_l;
						--dac_out_l <= temp_mult(temp_mult'high) & temp_mult(dac_out_l'high - 1 downto 0);
						--dac_out_r <= temp_mult(temp_mult'high) & temp_mult(dac_out_l'high - 1 downto 0);
						--dac_out_l <= (b"100000000000000000000000");
						--dac_out_r <= (b"100000000000000000000000");
						temp_result := (others => temp_filt(temp_filt'high));
						--dac_out_l <= temp_result(temp_result'high downto temp_result'high - 1) & temp_filt(temp_filt'high - 1 downto 1); 											
						--temp_filt(temp_filt'high) & ;
						--dac_out_r <= temp_result(temp_result'high downto temp_result'high - 1) & temp_filt(temp_filt'high - 1 downto 1); 
						
						dac_out_l <= shift_left(signed(compressed), 2);
						dac_out_r <= shift_left(signed(compressed), 2);
					else
						--temp_filt(8 downto 0) := to_signed(0, 9);
						--temp_mult := to_signed(0, temp_mult'length) + temp_filt - temp_filt_l;
						--temp_mult := shift_left(temp_mult, 4);
						dac_out_l <= shift_left(temp_filt, 2);
						dac_out_r <= shift_left(temp_filt_l, 2);
					end if;
				end if;
		  else
				rl_toggle <= '1';
		  end if;
		  
		end if;
	 end if;
  end process; -- data_reg
  
--  tone_gen : process(CLK_IN)
--  begin
--    if (rising_edge(CLK_IN)) then
--      if (RST_N = '0') then
--	     dac_out_l <= (others => '0');
--		  dac_out_r <= (others => '0');
--		  lfcounter <= 0;
--	   else
--		  if (lfcounter = 1535) then
--				lfcounter <= 0;
--				dac_out_l <= not(dac_out_l);
--				dac_out_r <= not(dac_out_r);
--		  else
--				lfcounter <= lfcounter + 1;
--		  end if;
--		end if;

--  end process; -- tone_gen
--  ----------------------
--  
  DATA_OUT : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
	     --dac_out_l <= (others => '0');
		  --dac_out_r <= (others => '0');
		  dac_current_state <= INITIAL;
		  dac_count_width <= 0;
	   else
		  
	     case dac_current_state is
          when INITIAL =>
            if (PSS_DONE = '0') then
					if (lr_ctrl_bit = '1') then
						dac_current_state <= DAC_R;
					else
						dac_current_state <= DAC_L;
					end if;
		      else 
			     dac_current_state <= INITIAL;
			   end if;
          when DAC_L =>
		      if (dac_count_width < SAMPLE_WIDTH) then
					DACDAT <= dac_out_l((SAMPLE_WIDTH-dac_count_width)-1);
					dac_count_width <= dac_count_width + 1;
					dac_current_state <= DAC_L;
				elsif (lr_ctrl_bit = '1') then
					dac_current_state <= DAC_R;
					DACDAT <= dac_out_r(SAMPLE_WIDTH-1);
					dac_count_width <= 1;
				else
					dac_current_state <= DAC_L;
					DACDAT <= '0';
				end if;
          when DAC_R =>
		      if (dac_count_width < SAMPLE_WIDTH) then
					DACDAT <= dac_out_r((SAMPLE_WIDTH-dac_count_width)-1);
					dac_count_width <= dac_count_width + 1;
					dac_current_state <= DAC_R;
				elsif (lr_ctrl_bit = '0') then
					dac_current_state <= DAC_L;
					DACDAT <= dac_out_l(SAMPLE_WIDTH-1);
					dac_count_width <= 1;
				else
					dac_current_state <= DAC_R;
					DACDAT <= '0';
				end if;
        end case;
	   end if;
    end if;
  end process; -- DATA_OUT

end rtl;