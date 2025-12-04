module char_calculator(input reg [63:0] str_input, output reg [7:0] result_char);
  wire [7:0] chars [7:0] = '{str_input[63:56], str_input[55:48], str_input[47:40], str_input[39:32],
                            str_input[31:24], str_input[23:16], str_input[15:8], str_input[7:0]};
  integer i, sum, mod_result;
  integer vals [7:0];

  always_comb begin
    sum = 0;
    for (i = 0; i < 8; i = i + 1) begin
      vals[i] = (chars[i] != 8'b0) ? (chars[i] - 8'h61 + 1) : 0;
      sum = sum + vals[i];
    end

    mod_result = sum % 26;
    result_char = (mod_result == 0) ? 8'h7A : 8'h61 + (mod_result - 1);
  end

endmodule