module int_to_mini_roman (
  input [9:0] number,
  output reg [95:0] roman_chars
);
  function [7:0][95:0] roman_str(input [9:0] n);
    reg [7:0] th;
    reg [7:0] h;
    reg [7:0] t;
    reg [7:0] u;
    reg [39:0] s;
    begin
      th = (n >= 1000) ? "m" : "";
      case (n % 1000) / 100
        1: h = "c";
        2: h = "cc";
        3: h = "ccc";
        4: h = "cd";
        5: h = "d";
        6: h = "dc";
        7: h = "dcc";
        8: h = "dccc";
        9: h = "cm";
        default: h = "";
      endcase
      case (n % 100) / 10
        1: t = "x";
        2: t = "xx";
        3: t = "xxx";
        4: t = "xl";
        5: t = "l";
        6: t = "lx";
        7: t = "lxx";
        8: t = "lxxx";
        9: t = "xc";
        default: t = "";
      endcase
      case (n % 10)
        1: u = "i";
        2: u = "ii";
        3: u = "iii";
        4: u = "iv";
        5: u = "v";
        6: u = "vi";
        7: u = "vii";
        8: u = "viii";
        9: u = "ix";
        default: u = "";
      endcase
      s = {th, h, t, u};
      roman_str = {s, 96'h0000_0000_0000_0000_0000_0000_0000_0000} >> (8 * (12 - len(s)));
    end
  endfunction
  function [6:0] len(input [39:0] s);
    casez (s)
      40'b00000000_00000000_00000000_00000000_00000000: len = 0;
      40'bzzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzz01: len = 1;
      40'bzzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzz10: len = 1;
      40'bzzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzz11: len = 2;
      40'bzzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzz1z: len = 2;
      default: len = 12;
    endcase
  endfunction
  integer i;
  reg [95:0] tmp;
  always @(*) begin
    tmp = roman_str(number);
    for (i = 0; i < 12; i = i + 1) begin
      roman_chars[8*i +: 8] = tmp[8*i +: 8];
    end
  end
endmodule
