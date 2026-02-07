library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_top is
  port (
    -- Bus interface
    a_in    : in  std_logic_vector(4 downto 0);
    d_in    : in  std_logic_vector(31 downto 0);
    d_out   : out std_logic_vector(31 downto 0);
    size_n  : in  std_logic_vector(1 downto 0); -- active low
    as_n    : in  std_logic; -- active low
    cs_n    : in  std_logic; -- active low
    rw      : in  std_logic; -- high=read, low=write
    ds_n    : in  std_logic; -- active low
    dsack0_n: out std_logic;
    dsack1_n: out std_logic;
    reset_n : in  std_logic;
    clk     : in  std_logic;
    sense_n : inout std_logic
  );
end entity mc68881_top;

architecture rtl of mc68881_top is
  type reg_array_t is array (0 to 1) of fp80_t;

  signal op_sel    : fpu_op_t := FPU_OP_NOP;
  signal operand   : reg_array_t := (others => (others => '0'));
  signal result    : fp80_t := (others => '0');
  signal result_lo : std_logic_vector(31 downto 0) := (others => '0');
  signal result_hi : std_logic_vector(31 downto 0) := (others => '0');
  signal result_ex : std_logic_vector(15 downto 0) := (others => '0');
  signal valid     : std_logic := '0';
  signal busy      : std_logic := '0';
  signal op_start  : std_logic := '0';
  signal status_valid : std_logic := '0';
  signal status_busy  : std_logic := '0';

  signal dsack0_i  : std_logic := '1';
  signal dsack1_i  : std_logic := '1';

  signal bus_write : std_logic;
  signal bus_read  : std_logic;
  signal addr      : unsigned(4 downto 0);

  constant ADDR_OPSEL  : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L  : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H  : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E  : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_OPB_L  : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_OPB_H  : unsigned(4 downto 0) := to_unsigned(5, 5);
  constant ADDR_OPB_E  : unsigned(4 downto 0) := to_unsigned(6, 5);
  constant ADDR_RES_L  : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H  : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E  : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);

begin
  addr      <= unsigned(a_in);
  bus_write <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '0') else '0';
  bus_read  <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '1') else '0';

  alu_inst : entity work.mc68881_alu
    port map (
      clk    => clk,
      reset_n => reset_n,
      start  => op_start,
      op_sel => op_sel,
      a_in   => operand(0),
      b_in   => operand(1),
      result => result,
      valid  => valid,
      busy   => busy
    );

  process(clk, reset_n)
  begin
    if reset_n = '0' then
      op_sel      <= FPU_OP_NOP;
      operand     <= (others => (others => '0'));
      result_lo   <= (others => '0');
      result_hi   <= (others => '0');
      result_ex   <= (others => '0');
      op_start    <= '0';
      status_valid <= '0';
      status_busy  <= '0';
    elsif rising_edge(clk) then
      op_start <= '0';

      if bus_write = '1' then
        case addr is
          when ADDR_OPSEL =>
            case d_in(2 downto 0) is
              when "001" => op_sel <= FPU_OP_ADD;
              when "010" => op_sel <= FPU_OP_SUB;
              when "011" => op_sel <= FPU_OP_MUL;
              when "100" => op_sel <= FPU_OP_DIV;
              when others => op_sel <= FPU_OP_NOP;
            end case;
            if busy = '0' then
              op_start <= '1';
              status_valid <= '0';
            end if;
          when ADDR_OPA_L => operand(0)(31 downto 0)  <= d_in;
          when ADDR_OPA_H => operand(0)(63 downto 32) <= d_in;
          when ADDR_OPA_E => operand(0)(79 downto 64) <= d_in(15 downto 0);
          when ADDR_OPB_L => operand(1)(31 downto 0)  <= d_in;
          when ADDR_OPB_H => operand(1)(63 downto 32) <= d_in;
          when ADDR_OPB_E => operand(1)(79 downto 64) <= d_in(15 downto 0);
          when others => null;
        end case;
      end if;

      if valid = '1' then
        result_lo <= result(31 downto 0);
        result_hi <= result(63 downto 32);
        result_ex <= result(79 downto 64);
        status_valid <= '1';
      end if;

      status_busy <= busy;
      if bus_read = '1' and addr = ADDR_STATUS then
        status_valid <= '0';
      end if;
    end if;
  end process;

  process(addr, bus_read, result_lo, result_hi, result_ex, status_valid, status_busy)
  begin
    d_out <= (others => '0');
    if bus_read = '1' then
      case addr is
        when ADDR_RES_L => d_out <= result_lo;
        when ADDR_RES_H => d_out <= result_hi;
        when ADDR_RES_E => d_out(15 downto 0) <= result_ex;
        when ADDR_STATUS =>
          d_out(0) <= status_valid;
          d_out(1) <= status_busy;
        when others => d_out <= (others => '0');
      end case;
    end if;
  end process;

  -- DSACK generation placeholder: immediate response based on size and A4.
  process(cs_n, as_n, ds_n, size_n, a_in)
    variable size_code : std_logic_vector(1 downto 0);
  begin
    dsack0_i <= '1';
    dsack1_i <= '1';

    if (cs_n = '0' and as_n = '0' and ds_n = '0') then
      size_code := not size_n;
      case size_code is
        when "00" =>
          if a_in(4) = '1' then
            dsack1_i <= '0';
            dsack0_i <= '0';
          else
            dsack1_i <= '0';
            dsack0_i <= '1';
          end if;
        when "01" =>
          dsack1_i <= '0';
          dsack0_i <= '1';
        when "10" =>
          dsack1_i <= '1';
          dsack0_i <= '0';
        when others =>
          dsack1_i <= '1';
          dsack0_i <= '1';
      end case;
    end if;
  end process;

  dsack0_n <= dsack0_i;
  dsack1_n <= dsack1_i;
  sense_n  <= 'Z';
end architecture rtl;
