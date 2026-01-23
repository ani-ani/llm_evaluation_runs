module star_number (
  input [15:0] n,
  output [31:0] result
);
  
  wire [15:0] n_minus_1;
  wire [31:0] n_times_n_minus_1;
  wire [31:0] six_times_n_times_n_minus_1;
  
  assign n_minus_1 = n - 1'b1;
  assign n_times_n_minus_1 = $signed(n) * $signed(n_minus_1);
  assign six_times_n_times_n_minus_1 = n_times_n_minus_1 * 6'd6;
  assign result = six_times_n_times_n_minus_1 + 32'd1;
  
endmodule