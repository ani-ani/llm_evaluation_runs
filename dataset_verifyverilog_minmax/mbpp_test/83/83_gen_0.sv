module char_calculator(input reg [63:0] str_input, output reg [7:0] result_char);
  always_comb begin
    // Extract 8 characters from the 64-bit input
    reg [7:0] chars [0:7];
    chars[0] = str_input[63:56];
    chars[1] = str_input[55:48];
    chars[2] = str_input[47:40];
    chars[3] = str_input[39:32];
    chars[4] = str_input[31:24];
    chars[5] = str_input[23:16];
    chars[6] = str_input[15:8];
    chars[7] = str_input[7:0];
    
    // Calculate sum of character values
    integer sum = 0;
    for (int i = 0; i < 8; i++) begin
      if (chars[i] != 0) begin
        sum = sum + (chars[i] - 8'h61 + 1);  // Convert a-z to 1-26
      end
    end
    
    // Apply modulo 26 calculation
    int mod = sum % 26;
    if (mod == 0) begin
      result_char = 8'h7A;  // 'z'
    end else begin
      result_char = 8'h61 + (mod - 1);  // 'a' to 'y'
    end
  end
endmodule