library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- TODO TSEKKAA BITTIVEKTORIEN SLAISSAUS, SIELLÄ USEIN VIRHEITÄ

entity compressor is
generic (SAMPLE_WIDTH : integer := 24);
port(
--REMEMBER GENERICS; SIZEOF
  -- Inputs
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
end compressor;

architecture rtl of compressor is    

	COMPONENT fir_tap
    GENERIC (SAMPLE_WIDTH : INTEGER := 24;
             TAP_SUM_WIDTH : INTEGER := 20;
             TAP_WIDTH : INTEGER := 8 );
	PORT(
          CLK_IN : in std_logic;
          RST_N 	: in std_logic;
          SAMPLE_IN : in std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
          SUM_IN : in std_logic_vector(SAMPLE_WIDTH + TAP_SUM_WIDTH - 4 - 1 downto 0);
          TAP_IN : in std_logic_vector(TAP_WIDTH - 1 downto 0);
          
          -- Outputs
          SUM_OUT : out std_logic_vector(SAMPLE_WIDTH + TAP_SUM_WIDTH - 4 - 1 downto 0);
          DELAYED_SAMPLE_OUT : out std_logic_vector(SAMPLE_WIDTH - 1 downto 0)
       );
	END COMPONENT;
    
    constant c_num_of_taps : integer := 32;
    constant c_bitwidth_taps : integer := 16;
    constant c_shift_after_filter : integer := 12;
    constant c_tap_width : integer := 8;
    constant c_num_of_points : integer := 64;
    constant c_saturation_val : integer := 134217728;
    constant c_saturation_length : integer := 29;
    constant c_interval : integer := c_saturation_val / c_num_of_points; --  signed(c_saturation_length - 1 downto 0) := (to_signed(c_saturation_val, c_saturation_length) / c_num_of_points);
    constant c_saturation_high : integer := c_saturation_val - c_interval;
    constant c_saturation_low : integer := -c_saturation_val + c_interval;
    signal c_overdrive : signed(7 downto 0); -- := "00010000";
    constant c_fuzziness : signed(3 downto 0) := ("0110"); -- Corresponds to 0,75

    TYPE taps IS ARRAY ( 0 to c_num_of_taps - 1) OF unsigned(c_tap_width - 1 downto 0);
    TYPE pre_c_points IS ARRAY ( 0 to c_num_of_points - 1) OF INTEGER RANGE 0 to 7887795;
    TYPE coeffs IS ARRAY ( 0 to c_num_of_points - 1) OF INTEGER RANGE 0 to 409;
    TYPE samples_type IS ARRAY (0 to c_num_of_taps) OF STD_LOGIC_VECTOR(SAMPLE_WIDTH - 1 downto 0);
    TYPE sums_type IS ARRAY (0 to c_num_of_taps) OF STD_LOGIC_VECTOR(SAMPLE_WIDTH + c_bitwidth_taps - 4 - 1 downto 0);
    
    --signal samples : samples_type;
    --signal sums : sums_type;
    --signal abs_input : std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
    signal temp_saturated, sat_maybe_inverted : signed(29 - 1 downto 0);
    signal index_s : integer range 0 to 63;
    signal s_mult_temp : signed(44 - 1 downto 0);
    
    -- Matlab generated FIR tap coefficients
    --constant c_taps : taps := (  to_unsigned(19, 8), to_unsigned(21, 8), to_unsigned(28, 8), to_unsigned(39, 8), to_unsigned(54, 8), to_unsigned(72, 8), to_unsigned(92,  114,  137,  159,  180,  200,  216,  229,  238,
    --                            243,  243,  238,  229,  216,  200,  180,  159,  137,  114, 8), to_unsigned(92, 8), to_unsigned(72, 8), to_unsigned(54, 8), to_unsigned(39, 8), to_unsigned(28, 8),
    --                            to_unsigned(21, 8), to_unsigned(19, 8) );
                                
    constant c_taps : taps := ( to_unsigned(19, 8), to_unsigned(21, 8), to_unsigned(28, 8), to_unsigned(39, 8), to_unsigned(54, 8), to_unsigned(72, 8), to_unsigned(92, 8), 
                                to_unsigned(114, 8), to_unsigned(137, 8), to_unsigned(159, 8), to_unsigned(180, 8), 
                                to_unsigned(200, 8), to_unsigned(216, 8), to_unsigned(229, 8), to_unsigned(238, 8), to_unsigned(243, 8), to_unsigned(243, 8), to_unsigned(238, 8),
                                to_unsigned(229, 8), to_unsigned(216, 8), to_unsigned(200, 8), to_unsigned(180, 8), to_unsigned(159, 8), to_unsigned(137, 8), 
                                to_unsigned(114, 8), to_unsigned(92, 8), to_unsigned(72, 8), to_unsigned(54, 8), to_unsigned(39, 8), to_unsigned(28, 8), to_unsigned(21, 8), to_unsigned(19, 8) );
                                
                                                    
                                 
    -- Matlab generated precalculated points and coefficients
    constant c_pre_c_points : pre_c_points := ( 0,  1677721,  2796202,  3595117,  4194304,  4660337,  5033164,  5338205,  5592405,
                                               5807497,  5991862,  6151645,  6291456,  6414817,  6524472,  6622585,  6710886,  6790777,
                                               6863406,  6929719,  6990506,  7046430,  7098052,  7145851,  7190235,  7231558,  7270126,
                                               7306206,  7340032,  7371807,  7401712,  7429909,  7456540,  7481731,  7505596,  7528237,
                                               7549747,  7570207,  7589692,  7608272,  7626007,  7642953,  7659163,  7674683,  7689557,
                                               7703823,  7717519,  7730677,  7743330,  7755505,  7767229,  7778527,  7789421,  7799933,
                                               7810083,  7819888,  7829367,  7838535,  7847407,  7855997,  7864320,  7872385,  7880207,
                                               7887795 );
   
    constant c_coeffs : coeffs := ( 409,  273,  195,  146,  113,   91,   74,   62,   52,   45,   39,   34,   30,   26,   23,
                                    21,   19,   17,   16,   14,   13,   12,   11,   10,   10,    9,    8,    8,    7,    7,
                                     6,    6,    6,    5,    5,    5,    4,    4,    4,    4,    4,    3,    3,    3,    3,
                                     3,    3,    3,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
                                     1,    1,    1,    0);
    signal inp_env : signed(32 - 1 downto 0);
    signal inp_env_s : signed(31 - 1 downto 0);
    signal inp_temp : signed(36 - 1 downto 0);
    signal inp_temps : signed(24 - 1 downto 0);
    signal s_precpoint : integer range 0 to 15713174;
    signal s_coeff : integer range 0 to 414;
    signal dc_off_cnt : integer range 0 to 2047;
    signal dc_offset_temp : signed(SAMPLE_WIDTH + 13 - 1 downto 0);
    signal dc_offset, offset_removed : signed(SAMPLE_WIDTH-1 downto 0);
    
    signal sample_del1, sample_del2 : std_logic_vector(SAMPLE_IN'high downto 0);
    
    
  begin
  
  c_overdrive <= signed('0' & unsigned(OVERDRIVE));

    -- FIR_TAPS: for I in 0 to c_num_of_taps - 1 generate
  
        -- first_tap : if I = 0 generate
            -- tap_instance : fir_tap
            -- generic map(SAMPLE_WIDTH => SAMPLE_WIDTH,
                        -- TAP_SUM_WIDTH => c_bitwidth_taps,
                        -- TAP_WIDTH => c_tap_width)
            -- port map(
                  -- CLK_IN => CLK_IN,
                  -- RST_N => RST_N, 
                  -- SAMPLE_IN => abs_input, 
                  -- SUM_IN => sums(1), 
                  -- TAP_IN => std_logic_vector(c_taps(0)), 

                  -- SUM_OUT => sums(0), 
                  -- DELAYED_SAMPLE_OUT => samples(0)
               -- );
        -- end generate first_tap;
      
        -- other_taps : if I > 0 generate
            -- tap_instance : fir_tap
            -- generic map(SAMPLE_WIDTH => SAMPLE_WIDTH,
                        -- TAP_SUM_WIDTH => c_bitwidth_taps,
                        -- TAP_WIDTH => c_tap_width)
            -- port map(
                  -- CLK_IN => CLK_IN,
                  -- RST_N => RST_N, 
                  -- --SAMPLE_IN => samples(I - 1), 
                  -- SAMPLE_IN => abs_input,
                  -- SUM_IN => sums(I + 1), 
                  -- TAP_IN => std_logic_vector(c_taps(I)), 

                  -- SUM_OUT => sums(I), 
                  -- DELAYED_SAMPLE_OUT => samples(I)
               -- );
        -- end generate other_taps;      
        
    -- end generate FIR_TAPS;
    
  --sums(c_num_of_taps) <= (others => '0');
    
  -- ABS_VAL_FOR_FIR : process(CLK_IN)
  -- begin
    -- if(rising_edge(CLK_IN)) then
        -- if(RST_N = '0') then
            -- abs_input <= (others => '0');
        -- else
            -- if(SAMPLE_IN(SAMPLE_IN'high) /= '0') then -- if negative
                -- abs_input <= std_logic_vector(signed(not(SAMPLE_IN)) + 1);
            -- else    
                -- abs_input <= SAMPLE_IN;
            -- end if;
        -- end if;
    -- end if;
  -- end process; -- ABS_VAL_FOR_FIR
  
  ENVELOPE <= std_logic_vector(inp_temps);
  
  ENV_PLUS_INPUT <= std_logic_vector(inp_env_s);
  SATURATED <= std_logic_vector(temp_saturated);
  MULTIPLIED <= std_logic_vector(s_mult_temp);
  
  DATA_IN : process(CLK_IN)
  variable temp_out : signed(SAMPLE_WIDTH + c_bitwidth_taps - 4 - 1 downto 0);
  variable temp_out_shifted : signed(SAMPLE_WIDTH - 1 downto 0);
  variable input_plus_env : signed(c_overdrive'length + SAMPLE_WIDTH - 1 downto 0);

  variable input_plus_env_shifted : signed(c_saturation_length + 2 - 1 downto 0);
  variable saturated_input : signed(c_saturation_length - 1 downto 0);
  variable multiplied_temp : signed(44 - 1 downto 0);
  variable output : signed(44 - 1 downto 0);
  variable negative : std_logic;
  variable pre_c_point : integer range 0 to 15713174;
  variable coeff : integer range 0 to 414;
  variable arr_index : integer range 0 to c_num_of_points;
  variable dc_offset_tmp : signed(dc_offset_temp'high downto 0);
  begin
    if (rising_edge(CLK_IN)) then
      if (RST_N = '0') then
        SAMPLE_OUT <= (others => '0');
        sample_del1 <=  (others => '0');
        sample_del2 <=  (others => '0');
        dc_off_cnt <= 0;
        dc_offset <= (others => '0');
        dc_offset_temp <= (others => '0');
	  else
        sample_del1 <= SAMPLE_IN;
        sample_del2 <= sample_del1;
        --temp_out := shift_right(signed(sums(c_num_of_taps - 1)), c_shift_after_filter);
        --temp_out := shift_right(signed(sums(0)), c_shift_after_filter);
        --inp_temp <= temp_out;
        inp_temp <= (others => '0');
        --SAMPLE_OUT <= std_logic_vector(temp_out(SAMPLE_WIDTH - 1 downto 0));
        temp_out_shifted := temp_out(temp_out_shifted'high downto 0);
        --inp_temps <= temp_out_shifted;
        
        -- DEBUG
        inp_temps <= (others => '0');
        
        if (dc_off_cnt = 2047) then
            dc_off_cnt <= 0;
            dc_offset_tmp := dc_offset_temp + signed(SAMPLE_IN);
            dc_offset_tmp := shift_right(dc_offset_tmp, 11);
            dc_offset <= dc_offset_tmp(dc_offset'high downto 0); -- & dc_offset_tmp(SAMPLE_WIDTH - 2 downto 0);
            dc_offset_temp <= (others => '0');
        else
            dc_off_cnt <= dc_off_cnt + 1;
            dc_offset_temp <= to_signed(0, dc_offset_temp'length) + dc_offset_temp + signed(SAMPLE_IN);
        end if;
        --input_plus_env := c_overdrive*(signed(SAMPLE_IN) + shift_right((c_fuzziness*temp_out_shifted), 3));
        
        
        --input_plus_env := c_overdrive*(signed(sample_del2) + shift_right((c_fuzziness*temp_out_shifted), 3));
        input_plus_env := c_overdrive*(signed(SAMPLE_IN)); --- dc_offset);
        input_plus_env_shifted := input_plus_env(input_plus_env_shifted'high downto 0);
        inp_env <= input_plus_env;
        inp_env_s <= input_plus_env_shifted;
        
        if (input_plus_env_shifted > c_saturation_high) then
            saturated_input := to_signed(c_saturation_high, saturated_input'length);
        elsif (input_plus_env_shifted < c_saturation_low) then
            saturated_input := to_signed(c_saturation_low, saturated_input'length);
        else
            saturated_input := input_plus_env_shifted(saturated_input'high downto 0);
        end if;
        temp_saturated <= saturated_input;
        
        if(saturated_input(saturated_input'high) /= '0') then -- Negative samples handlded separately
            negative := '1';
            saturated_input := not(saturated_input) + 1;
        else
            negative := '0';
        end if;
        sat_maybe_inverted <= saturated_input;
        -- Precalculated point selected based on the 4 MSBs of saturated input
        arr_index := to_integer(unsigned(saturated_input(saturated_input'high - 2 downto saturated_input'high - 7)));
        index_s <= arr_index;
        
        pre_c_point := c_pre_c_points(arr_index); 
        coeff := c_coeffs(arr_index);
        s_precpoint <= pre_c_point;
        s_coeff <= coeff;
        
        output := to_signed(pre_c_point, output'length);
        multiplied_temp := coeff*(signed('0' & (saturated_input(saturated_input'high - 8 downto 0))));
        --_mult_temp <= multiplied_temp;
        multiplied_temp := shift_right(multiplied_temp, 9);
        s_mult_temp <= multiplied_temp;
        output := output + multiplied_temp;
        
        if(negative /= '0') then
            output := not(output) + 1;
        end if;
        output := shift_right(output, 2);
        --output := shift_right(output, to_integer(shift_right(c_overdrive, 3)));
        
        SAMPLE_OUT <= std_logic_vector(output(SAMPLE_WIDTH - 1 downto 0));
	  end if;
    end if;
  end process; -- DATA_IN
  

end rtl;