-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This unit generates a pseudorandom output based on a linear-feedback shift-
-- register.
--
-- Symbol: (PRNG)--->

-- Inspired by
-- https://www.nandland.com/vhdl/modules/lfsr-linear-feedback-shift-register.html
entity StreamPseudoRandomGenerator is
  generic (

    -- Width of the output stream
    DATA_WIDTH                  : positive := 32

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- LSFR initial value after reset. Default is zero which is not an invalid
    -- state since we use XNORs.
    seed                        : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Psuedorandom output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamPseudoRandomGenerator;

architecture Behavioral of StreamPseudoRandomGenerator is

  constant MIN_DATA_WIDTH : natural := 3;
  constant MAX_DATA_WIDTH : natural := 168;
  constant MAX_TAPS       : natural := 5;

  type taps_type is array(0 to MAX_TAPS-1) of natural;
  type taps_array_type is array(MIN_DATA_WIDTH to MAX_DATA_WIDTH) of taps_type;

  -- Taps for all combinations of supported data widths.
  -- This is from Xilinx App note xapp052.

  constant taps_array : taps_array_type := (
    --0   => (0,0,0,0,0,0),
    --1   => (0,0,0,0,0,0),
    --2   => (0,0,0,0,0,0),
    3   => (2,0,0,0,0),
    4   => (3,0,0,0,0),
    5   => (3,0,0,0,0),
    6   => (5,0,0,0,0),
    7   => (6,0,0,0,0),
    8   => (6,5,4,0,0),
    9   => (5,0,0,0,0),
    10  => (7,0,0,0,0),
    11  => (9,0,0,0,0),
    12  => (6,4,1,0,0),
    13  => (4,3,1,0,0),
    14  => (5,3,1,0,0),
    15  => (14,0,0,0,0),
    16  => (15,13,4,0,0),
    17  => (14,0,0,0,0),
    18  => (11,0,0,0,0),
    19  => (6,2,1,0,0),
    20  => (17,0,0,0,0),
    21  => (19,0,0,0,0),
    22  => (21,0,0,0,0),
    23  => (18,0,0,0,0),
    24  => (23,22,17,0,0),
    25  => (22,0,0,0,0),
    26  => (6,2,1,0,0),
    27  => (5,2,1,0,0),
    28  => (25,0,0,0,0),
    29  => (27,0,0,0,0),
    30  => (6,4,1,0,0),
    31  => (28,0,0,0,0),
    32  => (22,2,1,0,0),
    33  => (20,0,0,0,0),
    34  => (27,2,1,0,0),
    35  => (33,0,0,0,0),
    36  => (25,0,0,0,0),
    37  => (5,4,3,2,1),
    38  => (6,5,1,0,0),
    39  => (35,0,0,0,0),
    40  => (38,21,19,0,0),
    41  => (8,0,0,0,0),
    42  => (41,20,19,0,0),
    43  => (42,38,37,0,0),
    44  => (43,18,17,0,0),
    45  => (44,42,41,0,0),
    46  => (45,26,25,0,0),
    47  => (42,0,0,0,0),
    48  => (47,21,20,0,0),
    49  => (40,0,0,0,0),
    50  => (49,24,23,0,0),
    51  => (50,36,35,0,0),
    52  => (49,0,0,0,0),
    53  => (52,38,37,0,0),
    54  => (53,18,17,0,0),
    55  => (31,0,0,0,0),
    56  => (55,35,34,0,0),
    57  => (50,0,0,0,0),
    58  => (39,0,0,0,0),
    59  => (58,38,37,0,0),
    60  => (59,0,0,0,0),
    61  => (60,46,45,0,0),
    62  => (61,6,5,0,0),
    63  => (62,0,0,0,0),
    64  => (63,61,60,0,0),
    65  => (47,0,0,0,0),
    66  => (65,57,56,0,0),
    67  => (66,58,57,0,0),
    68  => (59,0,0,0,0),
    69  => (67,42,40,0,0),
    70  => (69,55,54,0,0),
    71  => (65,0,0,0,0),
    72  => (66,25,19,0,0),
    73  => (48,0,0,0,0),
    74  => (73,59,58,0,0),
    75  => (74,65,64,0,0),
    76  => (75,41,40,0,0),
    77  => (76,47,46,0,0),
    78  => (77,59,58,0,0),
    79  => (70,0,0,0,0),
    80  => (79,43,42,0,0),
    81  => (77,0,0,0,0),
    82  => (79,47,44,0,0),
    83  => (82,38,37,0,0),
    84  => (71,0,0,0,0),
    85  => (84,58,57,0,0),
    86  => (85,74,73,0,0),
    87  => (74,0,0,0,0),
    88  => (87,17,16,0,0),
    89  => (51,0,0,0,0),
    90  => (89,72,71,0,0),
    91  => (90,8,7,0,0),
    92  => (91,80,79,0,0),
    93  => (91,0,0,0,0),
    94  => (73,0,0,0,0),
    95  => (84,0,0,0,0),
    96  => (94,49,47,0,0),
    97  => (91,0,0,0,0),
    98  => (87,0,0,0,0),
    99  => (97,54,52,0,0),
    100 => (63,0,0,0,0),
    101 => (100,95,94,0,0),
    102 => (101,36,35,0,0),
    103 => (94,0,0,0,0),
    104 => (103,94,93,0,0),
    105 => (89,0,0,0,0),
    106 => (91,0,0,0,0),
    107 => (105,44,42,0,0),
    108 => (77,0,0,0,0),
    109 => (108,103,102,0,0),
    110 => (109,98,97,0,0),
    111 => (101,0,0,0,0),
    112 => (110,69,67,0,0),
    113 => (104,0,0,0,0),
    114 => (113,33,32,0,0),
    115 => (114,101,100,0,0),
    116 => (15,46,45,0,0),
    117 => (115,99,97,0,0),
    118 => (85,0,0,0,0),
    119 => (111,0,0,0,0),
    120 => (113,9,2,0,0),
    121 => (103,0,0,0,0),
    122 => (121,63,62,0,0),
    123 => (121,0,0,0,0),
    124 => (7,0,0,0,0),
    125 => (124,18,17,0,0),
    126 => (125,90,89,0,0),
    127 => (126,0,0,0,0),
    128 => (126,101,99,0,0),
    129 => (124,0,0,0,0),
    130 => (127,0,0,0,0),
    131 => (130,84,83,0,0),
    132 => (103,0,0,0,0),
    133 => (132,82,81,0,0),
    134 => (77,0,0,0,0),
    135 => (124,0,0,0,0),
    136 => (135,11,10,0,0),
    137 => (116,0,0,0,0),
    138 => (137,131,130,0,0),
    139 => (136,134,131,0,0),
    140 => (111,0,0,0,0),
    141 => (140,110,109,0,0),
    142 => (121,0,0,0,0),
    143 => (142,123,122,0,0),
    144 => (143,75,74,0,0),
    145 => (93,0,0,0,0),
    146 => (145,87,86,0,0),
    147 => (146,110,109,0,0),
    148 => (121,0,0,0,0),
    149 => (148,40,39,0,0),
    150 => (97,0,0,0,0),
    151 => (148,0,0,0,0),
    152 => (151,87,86,0,0),
    153 => (152,0,0,0,0),
    154 => (152,27,25,0,0),
    155 => (154,124,123,0,0),
    156 => (155,41,40,0,0),
    157 => (156,131,130,0,0),
    158 => (157,132,131,0,0),
    159 => (128,0,0,0,0),
    160 => (159,142,141,0,0),
    161 => (143,0,0,0,0),
    162 => (161,75,74,0,0),
    163 => (162,104,103,0,0),
    164 => (163,151,150,0,0),
    165 => (164,135,134,0,0),
    166 => (165,128,127,0,0),
    167 => (161,0,0,0,0),
    168 => (166,153,151,0,0)
  );

  type reg_type is record
    valid                       : std_logic;
    lfsr                        : std_logic_vector(DATA_WIDTH downto 1);
    xnor_bit                    : std_logic;
  end record;

  signal r                      : reg_type;
  signal d                      : reg_type;

begin

  -- This unit only supports an output length of up to 128 bits. Generate an
  -- error in simulation.

  --pragma translate off
  assert DATA_WIDTH <= 128
    report "StreamPseudoRandomGenerator data width may not exceed 128 bits."
    severity failure;
  --pragma translate on

  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      r                         <= d;

      if reset = '1' then
        r.valid <= '0';
        r.lfsr(DATA_WIDTH downto 1) <= seed;
      end if;
    end if;
  end process;

  comb_proc: process(r,
    out_ready
  ) is
    variable v: reg_type;
  begin
    v                           := r;

    -- Determine what to shift in by XNORring
    -- Grab the last bit as the first XNOR input
      v.xnor_bit := r.lfsr(DATA_WIDTH);

    -- Loop over each bit of the register, except the first one, which is never
    -- tapped.
    for i in 1 to DATA_WIDTH-1 loop
      -- Loop over all other possible taps in the constant taps array
      for j in 0 to MAX_TAPS-1 loop
        -- If the bit we are at is in the taps list
        if taps_array(DATA_WIDTH)(j) = i then
          -- XNOR the bit with what we already have
          v.xnor_bit := v.xnor_bit xnor r.lfsr(i);
        end if;
      end loop;
    end loop;

    -- Ready the next output only when there is no valid output at the moment
    -- or if it was accepted.
    if (v.valid = '1' and out_ready = '1') or v.valid = '0' then
      -- Shift in the xnor bit
      v.lfsr(1) := v.xnor_bit;

      -- Shift the other bits
      for i in 2 to DATA_WIDTH loop
        v.lfsr(i) := r.lfsr(i-1);
      end loop;

      v.valid := '1';
    end if;

    -- Registered output
    d                           <= v;
  end process;

  -- Connect the output valid to the registered valid
  out_valid                     <= r.valid;
  out_data                      <= r.lfsr(DATA_WIDTH downto 1);

end Behavioral;

