module odd_digit_counter(
  input reg [63:0] str_i,
  output [3:0] count
);
  function [3:0] count_odds;
    input [63:0] s;
    integer i;
    begin
      count_odds = 0;
      for (i = 0; i < 8; i++) begin
        case (s[i*8 +: 8])
          8'h31, 8'h33, 8'h35, 8'h37, 8'h39: count_odds = count_odds + 1;
          default: ;
        endcase
      end
    end
  endfunction
  assign count = count_odds(str_i);
endmodule