module integer_checker(input [7:0] str [0:7], input [3:0] length, output reg is_integer);
  always_comb begin
    is_integer = 1'b0;
    if (length != 4'd0) begin
      logic first_ok, others_ok;
      first_ok = (str[0] == 8'h2B) || (str[0] == 8'h2D) || ((str[0] >= 8'h30) && (str[0] <= 8'h39));
      others_ok = 1'b1;
      for (int i=1; i<8; i++) begin
        if (i < length) begin
          others_ok = others_ok && ((str[i] >= 8'h30) && (str[i] <= 8'h39));
        end
      end
      is_integer = first_ok && others_ok;
    end
  end
endmodule