// Convert 8-byte ASCII string to uppercase
module string_to_upper (
  input  [63:0] str_in,  // 8 bytes (0: most significant byte, 7: least)
  output [63:0] str_out  // Uppercase-converted string
);

  // Process each byte in parallel
  // Convert 'a'..'z' to 'A'..'Z' by subtracting 32, else pass-through
  assign str_out[63:56] = (str_in[63:56] >= 8'h61 && str_in[63:56] <= 8'h7A)
                         ? str_in[63:56] - 8'h20 : str_in[63:56];
  assign str_out[55:48] = (str_in[55:48] >= 8'h61 && str_in[55:48] <= 8'h7A)
                         ? str_in[55:48] - 8'h20 : str_in[55:48];
  assign str_out[47:40] = (str_in[47:40] >= 8'h61 && str_in[47:40] <= 8'h7A)
                         ? str_in[47:40] - 8'h20 : str_in[47:40];
  assign str_out[39:32] = (str_in[39:32] >= 8'h61 && str_in[39:32] <= 8'h7A)
                         ? str_in[39:32] - 8'h20 : str_in[39:32];
  assign str_out[31:24] = (str_in[31:24] >= 8'h61 && str_in[31:24] <= 8'h7A)
                         ? str_in[31:24] - 8'h20 : str_in[31:24];
  assign str_out[23:16] = (str_in[23:16] >= 8'h61 && str_in[23:16] <= 8'h7A)
                         ? str_in[23:16] - 8'h20 : str_in[23:16];
  assign str_out[15:8]  = (str_in[15:8]  >= 8'h61 && str_in[15:8]  <= 8'h7A)
                         ? str_in[15:8]  - 8'h20 : str_in[15:8];
  assign str_out[7:0]   = (str_in[7:0]   >= 8'h61 && str_in[7:0]   <= 8'h7A)
                         ? str_in[7:0]   - 8'h20 : str_in[7:0];

endmodule
