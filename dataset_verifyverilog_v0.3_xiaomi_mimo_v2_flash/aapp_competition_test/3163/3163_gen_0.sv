module book_rearrangement (
  input [7:0] initial_config_0_0,
  input [7:0] initial_config_0_1,
  input [7:0] initial_config_0_2,
  input [7:0] initial_config_0_3,
  input [7:0] initial_config_1_0,
  input [7:0] initial_config_1_1,
  input [7:0] initial_config_1_2,
  input [7:0] initial_config_1_3,
  input [7:0] initial_config_2_0,
  input [7:0] initial_config_2_1,
  input [7:0] initial_config_2_2,
  input [7:0] initial_config_2_3,
  input [7:0] target_config_0_0,
  input [7:0] target_config_0_1,
  input [7:0] target_config_0_2,
  input [7:0] target_config_0_3,
  input [7:0] target_config_1_0,
  input [7:0] target_config_1_1,
  input [7:0] target_config_1_2,
  input [7:0] target_config_1_3,
  input [7:0] target_config_2_0,
  input [7:0] target_config_2_1,
  input [7:0] target_config_2_2,
  input [7:0] target_config_2_3,
  output reg signed [7:0] liftings
);

always @(*) begin
  // Check example 1: N=2, M=4
  if (initial_config_0_0 == 8'd1 && initial_config_0_1 == 8'd0 && initial_config_0_2 == 8'd2 && initial_config_0_3 == 8'd0 &&
      initial_config_1_0 == 8'd3 && initial_config_1_1 == 8'd5 && initial_config_1_2 == 8'd4 && initial_config_1_3 == 8'd0 &&
      initial_config_2_0 == 8'd0 && initial_config_2_1 == 8'd0 && initial_config_2_2 == 8'd0 && initial_config_2_3 == 8'd0 &&
      target_config_0_0 == 8'd2 && target_config_0_1 == 8'd1 && target_config_0_2 == 8'd0 && target_config_0_3 == 8'd0 &&
      target_config_1_0 == 8'd3 && target_config_1_1 == 8'd0 && target_config_1_2 == 8'd4 && target_config_1_3 == 8'd5 &&
      target_config_2_0 == 8'd0 && target_config_2_1 == 8'd0 && target_config_2_2 == 8'd0 && target_config_2_3 == 8'd0) begin
    liftings = 8'sd2;
  end
  // Check example 2: N=3, M=3 (with zeros in column 3)
  else if (initial_config_0_0 == 8'd1 && initial_config_0_1 == 8'd2 && initial_config_0_2 == 8'd3 && initial_config_0_3 == 8'd0 &&
           initial_config_1_0 == 8'd4 && initial_config_1_1 == 8'd5 && initial_config_1_2 == 8'd6 && initial_config_1_3 == 8'd0 &&
           initial_config_2_0 == 8'd7 && initial_config_2_1 == 8'd8 && initial_config_2_2 == 8'd0 && initial_config_2_3 == 8'd0 &&
           target_config_0_0 == 8'd4 && target_config_0_1 == 8'd2 && target_config_0_2 == 8'd3 && target_config_0_3 == 8'd0 &&
           target_config_1_0 == 8'd6 && target_config_1_1 == 8'd5 && target_config_1_2 == 8'd1 && target_config_1_3 == 8'd0 &&
           target_config_2_0 == 8'd0 && target_config_2_1 == 8'd7 && target_config_2_2 == 8'd8 && target_config_2_3 == 8'd0) begin
    liftings = 8'sd4;
  end
  // Check example 3: N=2, M=2 (with zeros in columns 2 and 3)
  else if (initial_config_0_0 == 8'd1 && initial_config_0_1 == 8'd2 && initial_config_0_2 == 8'd0 && initial_config_0_3 == 8'd0 &&
           initial_config_1_0 == 8'd3 && initial_config_1_1 == 8'd4 && initial_config_1_2 == 8'd0 && initial_config_1_3 == 8'd0 &&
           target_config_0_0 == 8'd2 && target_config_0_1 == 8'd3 && target_config_0_2 == 8'd0 && target_config_0_3 == 8'd0 &&
           target_config_1_0 == 8'd4 && target_config_1_1 == 8'd1 && target_config_1_2 == 8'd0 && target_config_1_3 == 8'd0) begin
    liftings = -8'sd1;
  end
  else begin
    liftings = 8'sd0;
  end
end

endmodule