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
use ieee.std_logic_misc.all;
use IEEE.numeric_std.all;

library work;
use work.Utils.all;

entity kmeans is
    generic(
      TAG_WIDTH                                  : natural;
      BUS_ADDR_WIDTH                             : natural;
      INDEX_WIDTH                                : natural;
      REG_WIDTH                                  : natural;
      NUM_USER_REGS                              : natural;
      DIMENSION                                  : natural;
      DATA_WIDTH                                 : natural;
      CENTROID_REGS                              : natural;
      CENTROIDS                                  : natural
    );
    port(
      point_out_ready                            : out std_logic;
      point_out_dimension_out_count              : in std_logic_vector(log2ceil(DIMENSION + 1) - 1 downto 0);
      point_out_dimension_out_data               : in std_logic_vector(511 downto 0);
      point_out_dimension_out_dvalid             : in std_logic;
      point_out_dimension_out_last               : in std_logic;
      point_out_dimension_out_ready              : out std_logic;
      point_out_dimension_out_valid              : in std_logic;
      point_out_length                           : in std_logic_vector(INDEX_WIDTH-1 downto 0);
      point_out_last                             : in std_logic;
      point_out_valid                            : in std_logic;
      point_cmd_valid                            : out std_logic;
      point_cmd_ready                            : in std_logic;
      point_cmd_firstIdx                         : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      point_cmd_lastIdx                          : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      point_cmd_tag                              : out std_logic_vector(TAG_WIDTH-1 downto 0);
      point_cmd_point_dimension_values_addr      : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      point_cmd_point_offsets_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      -------------------------------------------------------------------------
      acc_reset                                  : in std_logic;
      acc_clk                                    : in std_logic;
      -------------------------------------------------------------------------
      ctrl_done                                  : out std_logic;
      ctrl_busy                                  : out std_logic;
      ctrl_idle                                  : out std_logic;
      ctrl_reset                                 : in std_logic;
      ctrl_stop                                  : in std_logic;
      ctrl_start                                 : in std_logic;
      -------------------------------------------------------------------------
      idx_first                                  : in std_logic_vector(REG_WIDTH-1 downto 0);
      idx_last                                   : in std_logic_vector(REG_WIDTH-1 downto 0);
      reg_return0                                : out std_logic_vector(REG_WIDTH-1 downto 0);
      reg_return1                                : out std_logic_vector(REG_WIDTH-1 downto 0);
      -------------------------------------------------------------------------
      reg_point_dimension_values_addr            : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      reg_point_offsets_addr                     : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      user_regs_in                               : in std_logic_vector(NUM_USER_REGS * REG_WIDTH - 1 downto 0);
      user_regs_out                              : out std_logic_vector(NUM_USER_REGS * REG_WIDTH - 1 downto 0);
      user_regs_out_en                           : out std_logic_vector(NUM_USER_REGS - 1 downto 0)
    );
end entity kmeans;


architecture behavior of kmeans is

  constant ACCUMULATOR_WIDTH                     : natural := DATA_WIDTH;
  constant DIMENSION_REGS                        : natural := CENTROID_REGS / DIMENSION;

  component filter is
    generic(
      DATA_WIDTH         : natural;
      OPERANTS           : natural;
      TUSER_WIDTH        : positive := 1;
      SLICES             : natural  := 1
    );
    port(
      clk                : in  std_logic;
      reset              : in  std_logic;
      s_axis_tvalid      : in  std_logic;
      s_axis_tready      : out std_logic;
      s_axis_tdata       : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      s_axis_tlast       : in  std_logic := '0';
      s_axis_tuser       : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      s_axis_count       : in  std_logic_vector(log2ceil(OPERANTS + 1) - 1 downto 0);
      m_axis_tvalid      : out std_logic;
      m_axis_tready      : in  std_logic;
      m_axis_tdata       : out std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      m_axis_tlast       : out std_logic;
      m_axis_tuser       : out std_logic_vector(TUSER_WIDTH-1 downto 0)
    );
  end component;

  component axi_funnel is
    generic(
      SLAVES          : natural;
      DATA_WIDTH      : natural
    );
    port(
      reset           : in  std_logic;
      clk             : in  std_logic;
      -------------------------------------------------------------------------
      in_data         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_valid        : in  std_logic;
      in_ready        : out std_logic;
      in_last         : in  std_logic;
      out_data        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid       : out std_logic_vector(SLAVES-1 downto 0);
      out_ready       : in  std_logic_vector(SLAVES-1 downto 0);
      out_last        : out std_logic_vector(SLAVES-1 downto 0)
    );
  end component;

  component distance is
    generic(
      DIMENSION         : natural;
      DATA_WIDTH        : natural;
      TUSER_WIDTH       : natural := 1
    );
    port(
      reset             : in  std_logic;
      clk               : in  std_logic;
      -------------------------------------------------------------------------
      centroid          : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_data        : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_valid       : in  std_logic;
      point_ready       : out std_logic;
      point_last        : in  std_logic;
      point_tuser       : in  std_logic_vector(TUSER_WIDTH - 1 downto 0) := (others => '0');
      distance_distance : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      distance_point    : out std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      distance_valid    : out std_logic;
      distance_ready    : in  std_logic;
      distance_last     : out std_logic;
      distance_tuser    : out std_logic_vector(TUSER_WIDTH - 1 downto 0)
    );
  end component;

  component mask is
    generic(
      DATA_WIDTH         : natural;
      OPERANTS           : natural;
      TUSER_WIDTH        : positive := 1;
      SLICES             : natural  := 1
    );
    port(
      clk                : in  std_logic;
      reset              : in  std_logic;
      s_axis_tvalid      : in  std_logic;
      s_axis_tready      : out std_logic;
      s_axis_tdata       : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      s_axis_tlast       : in  std_logic := '0';
      s_axis_tuser       : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      s_axis_mask        : in  std_logic_vector(OPERANTS - 1 downto 0);
      m_axis_tvalid      : out std_logic;
      m_axis_tready      : in  std_logic;
      m_axis_tdata       : out std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      m_axis_tlast       : out std_logic;
      m_axis_tuser       : out std_logic_vector(TUSER_WIDTH-1 downto 0)
    );
  end component;

  component selector_tree is
    generic(
      DATA_WIDTH              : natural;
      TUSER_WIDTH             : natural := 1;
      OPERATION               : string := "min";
      OPERANTS                : natural
    );
    port(
      clk                     : in  std_logic;
      reset                   : in  std_logic;
      s_axis_tvalid           : in  std_logic_vector(OPERANTS-1 downto 0);
      s_axis_tready           : out std_logic_vector(OPERANTS-1 downto 0);
      s_axis_tdata            : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      s_axis_tuser            : in  std_logic_vector(TUSER_WIDTH - 1 downto 0) := (others => '0');
      s_axis_tlast            : in  std_logic_vector(OPERANTS-1 downto 0)      := (others => '0');
      m_axis_result_tvalid    : out std_logic;
      m_axis_result_tready    : in  std_logic;
      m_axis_result_tdata     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      m_axis_result_tuser     : out std_logic_vector(TUSER_WIDTH - 1 downto 0);
      m_axis_result_tlast     : out std_logic;
      m_axis_result_tselected : out std_logic_vector(log2ceil(OPERANTS)-1 downto 0)
    );
  end component;

  component point_accumulators is
    generic(
      DIMENSION         : natural;
      CENTROIDS         : natural;
      DATA_WIDTH        : natural;
      ACCUMULATOR_WIDTH : natural
    );
    port(
      reset             : in  std_logic;
      clk               : in  std_logic;
      -------------------------------------------------------------------------
      point_data        : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_centroid    : in  std_logic_vector(log2ceil(CENTROIDS)-1 downto 0);
      point_valid       : in  std_logic;
      point_ready       : out std_logic;
      point_last        : in  std_logic;
      accum_data        : out std_logic_vector(ACCUMULATOR_WIDTH * DIMENSION * CENTROIDS - 1 downto 0);
      accum_counters    : out std_logic_vector(ACCUMULATOR_WIDTH * CENTROIDS - 1 downto 0);
      accum_valid       : out std_logic
    );
  end component;

  component divider is
    generic(
      IN_WIDTH             : natural;
      OUT_WIDTH            : natural
    );
    port(
      clk                  : in  std_logic;
      reset                : in  std_logic;
      s_in_valid           : in  std_logic;
      s_in_ready           : out std_logic;
      s_in_numerator       : in  std_logic_vector(IN_WIDTH-1 downto 0);
      s_in_denominator     : in  std_logic_vector(IN_WIDTH-1 downto 0);
      m_result_valid       : out std_logic;
      m_result_ready       : in  std_logic;
      m_result_quotient    : out std_logic_vector(OUT_WIDTH-1 downto 0);
      m_result_remainder   : out std_logic_vector(OUT_WIDTH-1 downto 0)
    );
  end component;

  type haf_state_t is (RESET, WAITING, SETUP, ACCUMULATING, MEAN, END_ITERATION, DONE);
	signal state, state_next  : haf_state_t;

  signal reset_internal     : std_logic;

  subtype point_t is std_logic_vector(DIMENSION * DATA_WIDTH - 1 downto 0);

  signal point_forward_valid,
         point_forward_ready,
         point_forward_last : std_logic;
  signal point_filter_valid,
         point_filter_ready,
         point_filter_last  : std_logic;
  signal point_forward_data,
         point_filter_data,
         point_split_data   : point_t;
  signal point_split_valid,
         point_split_ready,
         point_split_last   : std_logic_vector(CENTROIDS - 1 downto 0);

  signal distance_data      : std_logic_vector(CENTROIDS * DATA_WIDTH - 1 downto 0);
  signal distance_valid,
         distance_ready,
         distance_last,
         distance_mask      : std_logic_vector(CENTROIDS - 1 downto 0);
  type distance_points_t is array (0 to CENTROIDS - 1) of point_t;
  signal distance_point     : distance_points_t;

  signal distance_m_data    : std_logic_vector(CENTROIDS * DATA_WIDTH - 1 downto 0);
  signal distance_m_valid,
         distance_m_ready,
         distance_m_last    : std_logic_vector(CENTROIDS - 1 downto 0);
  signal distance_m_point   : distance_points_t;

  signal centroid_point     : point_t;
  signal centroid_min       : std_logic_vector(log2ceil(CENTROIDS)-1 downto 0);
  signal centroid_ready,
         centroid_valid,
         centroid_last      : std_logic;

  signal accum_data         : std_logic_vector(ACCUMULATOR_WIDTH * DIMENSION * CENTROIDS - 1 downto 0);
  signal accum_counters     : std_logic_vector(ACCUMULATOR_WIDTH * CENTROIDS - 1 downto 0);
  signal accum_valid        : std_logic;
  signal accumulator_reset  : std_logic;

  signal divi_valid,
         divi_valid_next,
         divi_ready,
         divo_valid,
         divo_ready         : std_logic;
  signal div_numerator,
         div_denominator    : std_logic_vector(ACCUMULATOR_WIDTH - 1 downto 0);
  signal div_quotient       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal div_dimension,
         div_dimension_next : unsigned(log2ceil(DIMENSION) - 1 downto 0);
  signal div_centroid,
         div_centroid_next  : unsigned(log2ceil(CENTROIDS) - 1 downto 0);

  signal centroid_moved,
         centroid_moved_next: std_logic;

begin

  filter_inst: filter
    generic map (
      DATA_WIDTH         => DATA_WIDTH,
      OPERANTS           => DIMENSION
    )
    port map (
      clk                => acc_clk,
      reset              => reset_internal,
      s_axis_tvalid      => point_forward_valid,
      s_axis_tready      => point_forward_ready,
      s_axis_tdata       => point_forward_data,
      s_axis_tlast       => point_forward_last,
      s_axis_count       => point_out_dimension_out_count(log2ceil(DIMENSION+1)-1 downto 0),
      m_axis_tvalid      => point_filter_valid,
      m_axis_tready      => point_filter_ready,
      m_axis_tdata       => point_filter_data,
      m_axis_tlast       => point_filter_last
    );

  --TODO: replace with StreamSync
  distance_sync: axi_funnel
    generic map (
      SLAVES                 => CENTROIDS,
      DATA_WIDTH             => DATA_WIDTH * DIMENSION
    )
    port map (
      reset                  => reset_internal,
      clk                    => acc_clk,
      in_data                => point_filter_data,
      in_valid               => point_filter_valid,
      in_ready               => point_filter_ready,
      in_last                => point_filter_last,
      out_data               => point_split_data,
      out_valid              => point_split_valid,
      out_ready              => point_split_ready,
      out_last               => point_split_last
    );

  -- Distance to other centroids
  centroid_g: for c in 0 to CENTROIDS - 1 generate
    signal centroid_data : std_logic_vector(CENTROID_REGS * REG_WIDTH - 1 downto 0);
    signal point_split_enabled : std_logic_vector(0 downto 0);
  begin
    centroid_data <= user_regs_in((c + 1) * CENTROID_REGS * REG_WIDTH - 1 downto c * CENTROID_REGS * REG_WIDTH);
    point_split_enabled <= "0" when centroid_data(centroid_data'length - 1) = '1' and unsigned(centroid_data(centroid_data'length - 2 downto 0)) = 0 else "1";

    distance_inst: distance
      generic map (
        DIMENSION         => DIMENSION,
        DATA_WIDTH        => DATA_WIDTH,
        TUSER_WIDTH       => 1
      )
      port map (
        reset             => acc_reset,
        clk               => acc_clk,
        -------------------------------------------------------------------------
        centroid          => centroid_data,
        point_data        => point_split_data,
        point_valid       => point_split_valid(c),
        point_ready       => point_split_ready(c),
        point_last        => point_split_last(c),
        point_tuser       => point_split_enabled,
        distance_distance => distance_data((c + 1) * DATA_WIDTH - 1 downto c * DATA_WIDTH),
        distance_point    => distance_point(c),
        distance_valid    => distance_valid(c),
        distance_ready    => distance_ready(c),
        distance_last     => distance_last(c),
        distance_tuser    => distance_mask(c downto c)
      );

    mask_inst: mask
    generic map (
      DATA_WIDTH         => DATA_WIDTH,
      OPERANTS           => 1,
      TUSER_WIDTH        => DATA_WIDTH * DIMENSION
    )
    port map (
      clk                => acc_clk,
      reset              => reset_internal,
      s_axis_tvalid      => distance_valid(c),
      s_axis_tready      => distance_ready(c),
      s_axis_tdata       => distance_data((c + 1) * DATA_WIDTH - 1 downto c * DATA_WIDTH),
      s_axis_tlast       => distance_last(c),
      s_axis_tuser       => distance_point(c),
      s_axis_mask        => distance_mask(c downto c),
      m_axis_tvalid      => distance_m_valid(c),
      m_axis_tready      => distance_m_ready(c),
      m_axis_tdata       => distance_m_data((c + 1) * DATA_WIDTH - 1 downto c * DATA_WIDTH),
      m_axis_tlast       => distance_m_last(c),
      m_axis_tuser       => distance_m_point(c)
    );
  end generate;

  -- Find nearest centroid
  selector_tree_inst: selector_tree generic map (
    DATA_WIDTH              => DATA_WIDTH,
    TUSER_WIDTH             => DATA_WIDTH * DIMENSION,
    OPERANTS                => CENTROIDS
  )
  port map (
    clk                     => acc_clk,
    reset                   => reset_internal,
    s_axis_tvalid           => distance_m_valid,
    s_axis_tready           => distance_m_ready,
    s_axis_tdata            => distance_m_data,
    s_axis_tuser            => distance_m_point(0),
    s_axis_tlast            => distance_m_last,
    m_axis_result_tvalid    => centroid_valid,
    m_axis_result_tready    => centroid_ready,
    m_axis_result_tdata     => open,
    m_axis_result_tuser     => centroid_point,
    m_axis_result_tlast     => centroid_last,
    m_axis_result_tselected => centroid_min
  );

  -- Accumulate the points at the nearest centroid
  point_accumulators_inst: point_accumulators generic map (
    DIMENSION         => DIMENSION,
    CENTROIDS         => CENTROIDS,
    DATA_WIDTH        => DATA_WIDTH,
    ACCUMULATOR_WIDTH => ACCUMULATOR_WIDTH
  )
  port map (
    reset             => accumulator_reset,
    clk               => acc_clk,
    point_data        => centroid_point,
    point_centroid    => centroid_min,
    point_valid       => centroid_valid,
    point_ready       => centroid_ready,
    point_last        => centroid_last,
    accum_data        => accum_data,
    accum_counters    => accum_counters,
    accum_valid       => accum_valid
  );

  divider_inst: divider generic map (
    IN_WIDTH             => ACCUMULATOR_WIDTH,
    OUT_WIDTH            => DATA_WIDTH
  )
  port map (
    clk                  => acc_clk,
    reset                => reset_internal,
    s_in_valid           => divi_valid,
    s_in_ready           => divi_ready,
    s_in_numerator       => div_numerator,
    s_in_denominator     => div_denominator,
    m_result_valid       => divo_valid,
    m_result_ready       => divo_ready,
    m_result_quotient    => div_quotient
  );

  -- Provide base address to ArrayReader
  point_cmd_point_dimension_values_addr <= reg_point_dimension_values_addr;
  point_cmd_point_offsets_addr <= reg_point_offsets_addr;
  point_cmd_tag <= (others => '0');

  -- Set the first and last index on our column
  point_cmd_firstIdx <= idx_first;
  point_cmd_lastIdx  <= idx_last;

  -- Connect centroid data to output of divider
  centroid_write_g: for C in 0 to CENTROIDS - 1 generate
    dimension_write_g: for D in 0 to DIMENSION - 1 generate
      -- TODO: depend on CENTROID_REGS instead of DATA_WIDTH
      user_regs_out((C * DIMENSION + D + 1) * DATA_WIDTH - 1 downto (C * DIMENSION + D) * DATA_WIDTH) <= div_quotient;
    end generate;
  end generate;
  
  -- Decrement remaining iterations
  user_regs_out((CENTROIDS * CENTROID_REGS + 1) * REG_WIDTH - 1 downto CENTROIDS * CENTROID_REGS * REG_WIDTH) <=
      std_logic_vector(
          unsigned(user_regs_in((CENTROIDS * CENTROID_REGS + 1) * REG_WIDTH - 1 downto CENTROIDS * CENTROID_REGS * REG_WIDTH)) - 1
      );


  logic_p: process (acc_reset, state, ctrl_start,
    point_cmd_ready, point_out_valid, point_out_last, point_out_length,
    point_out_dimension_out_data, point_out_dimension_out_dvalid,
    point_out_dimension_out_last, point_out_dimension_out_valid,
    point_forward_ready, accum_valid, centroid_moved,
    divi_ready, divo_valid, divi_valid, div_dimension, div_centroid, div_quotient,
    div_denominator,
    accum_data, accum_counters, user_regs_in)
  begin
    -- Default values

    -- No command to ArrayReader
    point_cmd_valid <= '0';

    -- Do not accept values from the ArrayReader
    point_out_ready <= '0';
    point_out_dimension_out_ready <= '0';

    -- Do not forward a point
    point_forward_valid <= '0';
    point_forward_last  <= '0';
    point_forward_data  <= point_out_dimension_out_data(DIMENSION * DATA_WIDTH - 1 downto 0);

    -- Do not write to user regs
    user_regs_out_en <= (others => '0');

    reset_internal    <= acc_reset;
    accumulator_reset <= acc_reset;

    -- Stay in same state
    state_next          <= state;
    div_dimension_next  <= div_dimension;
    div_centroid_next   <= div_centroid;
    divi_valid_next     <= divi_valid;
    centroid_moved_next <= centroid_moved;

    divo_ready      <= '1';
    div_numerator   <= accum_data((to_integer(div_centroid) * DIMENSION + to_integer(div_dimension) + 1) * ACCUMULATOR_WIDTH - 1 downto (to_integer(div_centroid) * DIMENSION + to_integer(div_dimension)) * ACCUMULATOR_WIDTH);
    div_denominator <= accum_counters((to_integer(div_centroid) + 1) * ACCUMULATOR_WIDTH - 1 downto to_integer(div_centroid) * ACCUMULATOR_WIDTH);

    case state is
      when RESET =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
        reset_internal <= '1';
        accumulator_reset <= '1';
        if ctrl_start = '1' then
          state_next <= SETUP;
        else
          state_next <= WAITING;
        end if;

      -- Wait for start signal
      when WAITING =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '1';
        -- Wait for start signal from UserCore (initiated by software)
        if ctrl_start = '1' then
          state_next <= SETUP;
        end if;

      -- Set up the ArrayReader
      when SETUP =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';

        if unsigned(user_regs_in((CENTROIDS * CENTROID_REGS + 1) * REG_WIDTH - 1 downto CENTROIDS * CENTROID_REGS * REG_WIDTH)) = 0 then
          -- Reached iteration limit
          state_next <= DONE;
        else
          -- Send address and row indices to the ArrayReader
          point_cmd_valid <= '1';
          if point_cmd_ready = '1' then
            -- ArrayReader has received the command
            state_next <= ACCUMULATING;
          end if;
        end if;

      -- Assign point to centroid and accumulate them
      when ACCUMULATING =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';

        point_out_dimension_out_ready <= point_forward_ready;
        point_forward_valid <= point_out_dimension_out_valid;
        point_forward_last  <= point_out_dimension_out_last and point_out_last;

        if point_out_dimension_out_valid = '1' then
          if point_out_dimension_out_last = '1' and point_forward_ready = '1' then
            -- Only advance on list when all elements have been read
            point_out_ready <= '1';
          -- TODO: handle case where EPC < number of elements
          end if;
        end if;

        -- Exit on last element
        if accum_valid = '1' then
          state_next           <= MEAN;
          div_dimension_next   <= (others => '0');
          div_centroid_next    <= (others => '0');
          divi_valid_next      <= '1';
          centroid_moved_next  <= '0';
        end if;

      -- Calculate new centroid positions by dividing accumulator values
      when MEAN =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';

        -- De-assert valid when input is read
        if divi_ready = '1' then
          divi_valid_next <= '0';
        end if;

        -- Go over each dimension in each centroid
        if divo_valid = '1' then
          if unsigned(div_denominator) /= 0 then
            -- There are point assigned to this centroid

            -- Check whether the centroid has moved
            -- TODO: depend on CENTROID_REGS instead of DATA_WIDTH
            if user_regs_in(
                         (to_integer(div_centroid) * DIMENSION + to_integer(div_dimension) + 1) * DATA_WIDTH - 1
                  downto (to_integer(div_centroid) * DIMENSION + to_integer(div_dimension)) * DATA_WIDTH)
                /= div_quotient then
              centroid_moved_next <= '1';
            end if;

            -- Update centroid data
            user_regs_out_en(
                (to_integer(div_centroid) * DIMENSION + to_integer(div_dimension) + 1) * DIMENSION_REGS - 1 downto
                (to_integer(div_centroid) * DIMENSION + to_integer(div_dimension)) * DIMENSION_REGS) <= (others => '1');

            divi_valid_next <= '1';
            if div_dimension = DIMENSION - 1 then
              -- Next centroid
              div_dimension_next <= (others => '0');
              if div_centroid = CENTROIDS - 1 then
                -- It was the last centroid
                state_next <= END_ITERATION;
                divi_valid_next <= '0';
              else
                div_centroid_next  <= div_centroid + 1;
              end if;
            else
              -- Next dimension
              div_dimension_next <= div_dimension + 1;
            end if;

          else
            -- No points assigned; unused centroid
            state_next <= END_ITERATION;
          end if;
        end if;

      when END_ITERATION =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';

        accumulator_reset <= '1';
        -- Decrement remaining iterations
        user_regs_out_en(CENTROIDS * CENTROID_REGS) <= '1';

        if centroid_moved = '1' then
          -- Do another iteration
          state_next <= SETUP;
        else
          -- Reached fixed point
          state_next <= DONE;
        end if;

      -- Calculation finished
      when DONE =>
        ctrl_done <= '1';
        ctrl_busy <= '0';
        ctrl_idle <= '1';

      when others =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
    end case;
  end process;


  state_p: process (acc_clk)
  begin
    -- Control state machine
    if rising_edge(acc_clk) then
      if acc_reset = '1' or ctrl_reset = '1' then
        state <= RESET;
        divi_valid    <= '0';
      else
        state          <= state_next;
        div_dimension  <= div_dimension_next;
        div_centroid   <= div_centroid_next;
        divi_valid     <= divi_valid_next;
        centroid_moved <= centroid_moved_next;
      end if;
    end if;
  end process;

end architecture;

