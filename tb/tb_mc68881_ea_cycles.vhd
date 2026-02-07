library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity tb_mc68881_ea_cycles is
end entity tb_mc68881_ea_cycles;

architecture tb of tb_mc68881_ea_cycles is
begin
  process
    procedure assert_cycles(
      mode : ea_mode_t;
      exp_best : natural;
      exp_cache : natural;
      exp_worst : natural;
      label_text : string
    ) is
      variable got_best : natural;
      variable got_cache : natural;
      variable got_worst : natural;
    begin
      got_best := ea_cycles(mode, EA_CYCLE_BEST);
      got_cache := ea_cycles(mode, EA_CYCLE_CACHE);
      got_worst := ea_cycles(mode, EA_CYCLE_WORST);

      report "EA cycles " & label_text & " best=" & integer'image(got_best) &
        " cache=" & integer'image(got_cache) &
        " worst=" & integer'image(got_worst) severity note;

      assert got_best = exp_best
        report "EA best cycle mismatch for " & label_text severity error;
      assert got_cache = exp_cache
        report "EA cache cycle mismatch for " & label_text severity error;
      assert got_worst = exp_worst
        report "EA worst cycle mismatch for " & label_text severity error;
    end procedure;
  begin
    assert_cycles(EA_MODE_DN_AN, 0, 0, 0, "Dn/An");
    assert_cycles(EA_MODE_AN_INDIRECT, 0, 2, 2, "(An)");
    assert_cycles(EA_MODE_AN_POSTINC, 3, 6, 6, "(An)+");
    assert_cycles(EA_MODE_AN_PREDEC, 3, 6, 6, "-(An)");
    assert_cycles(EA_MODE_D16_AN_PC, 0, 2, 3, "(d16,An/PC)");
    assert_cycles(EA_MODE_ABS_W, 0, 2, 3, "(xxx).W");
    assert_cycles(EA_MODE_ABS_L, 1, 4, 5, "(xxx).L");
    assert_cycles(EA_MODE_IMMEDIATE, 0, 0, 0, "#(data)");
    assert_cycles(EA_MODE_D8_AN_PC_XN, 1, 4, 5, "(d8,An/PC,Xn)");
    assert_cycles(EA_MODE_D16_AN_PC_XN, 3, 6, 7, "(d16,An/PC,Xn)");
    assert_cycles(EA_MODE_B, 3, 6, 7, "(B)");
    assert_cycles(EA_MODE_D16_B, 5, 8, 9, "(d16,B)");
    assert_cycles(EA_MODE_D32_B, 11, 14, 16, "(d32,B)");
    assert_cycles(EA_MODE_B_INDIRECT_I, 8, 11, 12, "([B],I)");
    assert_cycles(EA_MODE_B_INDIRECT_I_D16, 8, 11, 12, "([B],I,d16)");
    assert_cycles(EA_MODE_B_INDIRECT_I_D32, 10, 13, 15, "([B],I,d32)");
    assert_cycles(EA_MODE_D16_B_INDIRECT_I, 10, 13, 14, "([d16,B],I)");
    assert_cycles(EA_MODE_D16_B_INDIRECT_I_D16, 10, 13, 15, "([d16,B],I,d16)");
    assert_cycles(EA_MODE_D16_B_INDIRECT_I_D32, 12, 15, 17, "([d16,B],I,d32)");
    assert_cycles(EA_MODE_D32_B_INDIRECT_I, 16, 19, 21, "([d32,B],I)");
    assert_cycles(EA_MODE_D32_B_INDIRECT_I_D16, 16, 19, 21, "([d32,B],I,d16)");
    assert_cycles(EA_MODE_D32_B_INDIRECT_I_D32, 18, 21, 24, "([d32,B],I,d32)");

    report "EA cycle table checks complete." severity note;
    wait;
  end process;
end architecture tb;
