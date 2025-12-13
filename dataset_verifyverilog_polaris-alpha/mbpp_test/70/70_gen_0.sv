module tuple_length_checker(
  input  [127:0] tuples,
  output        match_flag
);

  // Extract 4 tuples, each with 4 bytes
  wire [7:0] t0_0 = tuples[127:120];
  wire [7:0] t0_1 = tuples[119:112];
  wire [7:0] t0_2 = tuples[111:104];
  wire [7:0] t0_3 = tuples[103:96];

  wire [7:0] t1_0 = tuples[95:88];
  wire [7:0] t1_1 = tuples[87:80];
  wire [7:0] t1_2 = tuples[79:72];
  wire [7:0] t1_3 = tuples[71:64];

  wire [7:0] t2_0 = tuples[63:56];
  wire [7:0] t2_1 = tuples[55:48];
  wire [7:0] t2_2 = tuples[47:40];
  wire [7:0] t2_3 = tuples[39:32];

  wire [7:0] t3_0 = tuples[31:24];
  wire [7:0] t3_1 = tuples[23:16];
  wire [7:0] t3_2 = tuples[15:8];
  wire [7:0] t3_3 = tuples[7:0];

  // Function: compute tuple length (1..4), 0 if length==0 (invalid/empty)
  function automatic [2:0] tuple_len;
    input [7:0] b0, b1, b2, b3;
    begin
      if (b0 == 8'd0)
        tuple_len = 3'd0;          // empty tuple -> invalid
      else if (b1 == 8'd0)
        tuple_len = 3'd1;
      else if (b2 == 8'd0)
        tuple_len = 3'd2;
      else if (b3 == 8'd0)
        tuple_len = 3'd3;
      else
        tuple_len = 3'd4;
    end
  endfunction

  wire [2:0] len0 = tuple_len(t0_0, t0_1, t0_2, t0_3);
  wire [2:0] len1 = tuple_len(t1_0, t1_1, t1_2, t1_3);
  wire [2:0] len2 = tuple_len(t2_0, t2_1, t2_2, t2_3);
  wire [2:0] len3 = tuple_len(t3_0, t3_1, t3_2, t3_3);

  // All lengths equal and non-zero
  assign match_flag = (len0 != 3'd0) &&
                      (len0 == len1) &&
                      (len0 == len2) &&
                      (len0 == len3);

endmodule