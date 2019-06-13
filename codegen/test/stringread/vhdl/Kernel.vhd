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

library work;
use work.Axi_pkg.all;
use work.UtilStr_pkg.all;

entity Kernel is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    kcd_clk                      : in  std_logic;
    kcd_reset                    : in  std_logic;
    mmio_awvalid                 : in  std_logic;
    mmio_awready                 : out std_logic;
    mmio_awaddr                  : in  std_logic_vector(31 downto 0);
    mmio_wvalid                  : in  std_logic;
    mmio_wready                  : out std_logic;
    mmio_wdata                   : in  std_logic_vector(31 downto 0);
    mmio_wstrb                   : in  std_logic_vector(3 downto 0);
    mmio_bvalid                  : out std_logic;
    mmio_bready                  : in  std_logic;
    mmio_bresp                   : out std_logic_vector(1 downto 0);
    mmio_arvalid                 : in  std_logic;
    mmio_arready                 : out std_logic;
    mmio_araddr                  : in  std_logic_vector(31 downto 0);
    mmio_rvalid                  : out std_logic;
    mmio_rready                  : in  std_logic;
    mmio_rdata                   : out std_logic_vector(31 downto 0);
    mmio_rresp                   : out std_logic_vector(1 downto 0);
    StringRead_Name_valid        : in  std_logic;
    StringRead_Name_ready        : out std_logic;
    StringRead_Name_dvalid       : in  std_logic;
    StringRead_Name_last         : in  std_logic;
    StringRead_Name_length       : in  std_logic_vector(31 downto 0);
    StringRead_Name_count        : in  std_logic_vector(0 downto 0);
    StringRead_Name_chars_valid  : in  std_logic;
    StringRead_Name_chars_ready  : out std_logic;
    StringRead_Name_chars_dvalid : in  std_logic;
    StringRead_Name_chars_last   : in  std_logic;
    StringRead_Name_chars_data   : in  std_logic_vector(7 downto 0);
    StringRead_Name_chars_count  : in  std_logic_vector(0 downto 0);
    StringRead_Name_cmd_valid    : out std_logic;
    StringRead_Name_cmd_ready    : in  std_logic;
    StringRead_Name_cmd_firstIdx : out std_logic_vector(31 downto 0);
    StringRead_Name_cmd_lastidx  : out std_logic_vector(31 downto 0);
    StringRead_Name_cmd_ctrl     : out std_logic_vector(2*bus_addr_width-1 downto 0);
    StringRead_Name_cmd_tag      : out std_logic_vector(0 downto 0);
    StringRead_Name_unl_valid    : in  std_logic;
    StringRead_Name_unl_ready    : out std_logic;
    StringRead_Name_unl_tag      : in  std_logic_vector(0 downto 0)
  );
end entity;
architecture Implementation of Kernel is
  -- Registers used:
  constant REG_CONTROL          : natural := 0;
  constant REG_STATUS           : natural := 1;
  constant REG_RETURN0          : natural := 2;
  constant REG_RETURN1          : natural := 3;
  constant REG_STRINGS_FIRSTIDX : natural := 4;
  constant REG_STRINGS_LASTIDX  : natural := 5;
  constant REG_OFFSETS_BUF_LO   : natural := 6;
  constant REG_OFFSETS_BUF_HI   : natural := 7;
  constant REG_VALUES_BUF_LO    : natural := 8;
  constant REG_VALUES_BUF_HI    : natural := 9;

  constant REG_WIDTH            : natural := 32;
  constant NUM_REGS             : natural := 10;
  constant MAX_STR_LEN          : natural := 128;

  type reg_array_t is array(natural range <>) of std_logic_vector(31 downto 0);
  signal rreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);
  signal rreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal rreg_en                : std_logic_vector(NUM_REGS-1 downto 0);
  
  signal wreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal wreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);

  signal stat_done              : std_logic;
  signal stat_busy              : std_logic;
  signal stat_idle              : std_logic;
  signal ctrl_reset             : std_logic;
  signal ctrl_stop              : std_logic;
  signal ctrl_start             : std_logic;
  signal not_kcd_reset          : std_logic;

begin
  -- Instantiate the AXI mmio component to communicate with host more easily 
  -- through registers.
  axi_mmio_inst : AxiMmio
    generic map (
      BUS_ADDR_WIDTH     => 32,
      BUS_DATA_WIDTH     => 32,
      NUM_REGS           => NUM_REGS,
      REG_CONFIG         => "WRRRWWWWWW",
      SLV_R_SLICE_DEPTH  => 0,
      SLV_W_SLICE_DEPTH  => 0
    )
    port map (
      clk                => kcd_clk,
      reset_n            => not_kcd_reset,
      s_axi_awvalid      => mmio_awvalid,
      s_axi_awready      => mmio_awready,
      s_axi_awaddr       => mmio_awaddr,
      s_axi_wvalid       => mmio_wvalid,
      s_axi_wready       => mmio_wready,
      s_axi_wdata        => mmio_wdata,
      s_axi_wstrb        => mmio_wstrb,
      s_axi_bvalid       => mmio_bvalid,
      s_axi_bready       => mmio_bready,
      s_axi_bresp        => mmio_bresp,
      s_axi_arvalid      => mmio_arvalid,
      s_axi_arready      => mmio_arready,
      s_axi_araddr       => mmio_araddr,
      s_axi_rvalid       => mmio_rvalid,
      s_axi_rready       => mmio_rready,
      s_axi_rdata        => mmio_rdata,
      s_axi_rresp        => mmio_rresp,
      regs_out           => wreg_concat,
      regs_in            => rreg_concat,
      regs_in_en         => rreg_en
    );

  -- Flip reset
  not_kcd_reset <= not(kcd_reset);

  -- Turn signals into something more readable
  write_regs_unconcat: for I in 0 to NUM_REGS-1 generate
    wreg_array(I) <= wreg_concat((I+1)*32-1 downto I*32);
  end generate;
  read_regs_concat: for I in 0 to NUM_REGS-1 generate
    rreg_concat((I+1)*32-1 downto I*32) <= rreg_array(I);
  end generate;

  -- Always enable read registers
  rreg_array(REG_STATUS) <= (0 => stat_idle, 1 => stat_busy, 2 => stat_done, others => '0');
  rreg_en <= (REG_STATUS => '1', REG_RETURN0 => '1', REG_RETURN1 => '1', others => '0');
  
  -- We don't use the return registers for this kernel. Put some random data.
  rreg_array(REG_RETURN0) <= X"42001337";
  rreg_array(REG_RETURN1) <= X"0DDF00D5";
  
  -- Connect the control bits  
  ctrl_start <= wreg_array(REG_CONTROL)(0);
  ctrl_stop  <= wreg_array(REG_CONTROL)(1);
  ctrl_reset <= wreg_array(REG_CONTROL)(2);

  -- Stringread kernel example (simulation only)
  process is
    variable string_idx    : natural := 0;
    variable string_length : natural := 0;
    variable current_char  : natural := 0;
    variable num_chars     : natural := 0;
    variable is_last       : boolean := false;
    variable is_last_char  : boolean := false;
    variable int_char      : integer := 0;
    variable char          : character := '0';
    variable str           : string(1 to MAX_STR_LEN);
  begin
    -- Initial status outputs
    stat_idle <= '1';
    stat_busy <= '0';
    stat_done <= '0';
    
    -- Initial Fletcher streams handshake signals
    StringRead_Name_cmd_valid <= '0';
    StringRead_Name_ready <= '0';
    StringRead_Name_chars_ready <= '0';

    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(kcd_clk);
      exit when ctrl_reset = '0' and ctrl_start = '1';
    end loop;

    stat_busy <= '1';

    -- Issue the command:
    StringRead_Name_cmd_firstIdx <= wreg_array(REG_STRINGS_FIRSTIDX);
    StringRead_Name_cmd_lastIdx  <= wreg_array(REG_STRINGS_LASTIDX);

    -- The addresses can be taken from the registers, but they are passed
    -- through the user core. In this way, the user can create new buffers
    -- without communicating with host software.
    StringRead_Name_cmd_ctrl <= wreg_array( REG_VALUES_BUF_HI) & wreg_array( REG_VALUES_BUF_LO)   -- Values buffer
                   & wreg_array(REG_OFFSETS_BUF_HI) & wreg_array(REG_OFFSETS_BUF_LO);  -- Offsets buffer
                   
    -- Validate the command.
    StringRead_Name_cmd_valid <= '1';

    -- Wait for command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when StringRead_Name_cmd_ready = '1';
    end loop;
    StringRead_Name_cmd_valid <= '0';

    loop
      -- Receive a string length

      -- Wait for valid length
      StringRead_Name_ready <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when StringRead_Name_valid = '1';
      end loop;

      -- Save the string length, reset the current character and the string
      current_char := 0;
      string_length := to_integer(unsigned(StringRead_Name_length));
      for I in 1 to MAX_STR_LEN loop
        str(I) := nul;
      end loop;

      -- Check if this is the last string
      is_last := StringRead_Name_last = '1';

      -- Not ready to receive a new length at the moment.
      StringRead_Name_ready <= '0';

      -- Obtain all string characters
      loop

        StringRead_Name_chars_ready <= '1';

        -- Wait for handshake
        loop
          wait until rising_edge(kcd_clk);
          exit when StringRead_Name_chars_valid = '1';
        end loop;

        -- Check the number of characters delivered
        num_chars := to_integer(unsigned(StringRead_Name_chars_count));

        -- For each character in the output
        for I in 0 to num_chars-1 loop
          -- Convert the std_logic_vector part to a character
          int_char := to_integer(unsigned(StringRead_Name_chars_data(8*(i+1)-1 downto 8*i)));
          char := character'val(int_char);

          -- Set the character in the string
          str(1+current_char) := char;

          current_char := current_char + 1;
        end loop;

        -- check if this is the last (bunch of) characters
        is_last_char := StringRead_Name_chars_last = '1';

        exit when is_last_char;
      end loop;

      StringRead_Name_chars_ready <= '0';

      -- Check if the string length and the number of characters received is
      -- correct
      assert(current_char = string_length)
        report "String length expected to be zero on last signal, " &
                integer'image(string_length) & " instead."
        severity failure;

      -- Dump the string to the output
      println("String " & integer'image(string_idx) & " : " & str);

      string_idx := string_idx + 1;

      -- If this was the last string, exit the loop
      exit when is_last;
    end loop;

    -- Wait a few extra cycles ...
    -- (normally you should use unlock stream for this)
    for I in 0 to 3 loop
        wait until rising_edge(kcd_clk);
    end loop;

    -- Signal done to the usercore controller
    stat_busy <= '0';
    stat_done <= '1';
    wait;
  end process;


end architecture;
