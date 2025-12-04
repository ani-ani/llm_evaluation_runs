module string_to_upper(
  input  [63:0] str_in,
  output [63:0] str_out
);

  assign str_out[7:0]   = (str_in[7:0]   >= 8'h61 && str_in[7:0]   <= 8'h7A) ? (str_in[7:0]   - 8'd32) : str_in[7:0];
  assign str_out[15:8]  = (str_in[15:8]  >= 8'h61 && str_in[15:8]  <= 8'h7A) ? (str_in[15:8]  - 8'd32) : str_in[15:8];
  assign str_out[23:16] = (str_in[23:16] >= 8'h61 && str_in[23:16] <= 8'h7A) ? (str_in[23:16] - 8'd32) : str_in[23:16];
  assign str_out[31:24] = (str_in[31:24] >= 8'h61 && str_in[31:24] <= 8'h7A) ? (str_in[31:24] - 8'd32) : str_in[31:24];
  assign str_out[39:32] = (str_in[39:32] >= 8'h61 && str_in[39:32] <= 8'h7A) ? (str_in[39:32] - 8'd32) : str_in[39:32];
  assign str_out[47:40] = (str_in[47:40] >= 8'h61 && str_in[47:40] <= 8'h7A) ? (str_in[47:40] - 8'd32) : str_in[47:40];
  assign str_out[55:48] = (str_in[55:48] >= 8'h61 && str_in[55:48] <= 8'h7A) ? (str_in[55:48] - 8'd32) : str_in[55:48];
  assign str_out[63:56] = (str_in[63:56] >= 8'h61 && str_in[63:56] <= 8'h7A) ? (str_in[63:56] - 8'd32) : str_in[63:56];

endmodule