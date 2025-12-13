module doll_average_counter(
  input  [15:0]       p_value,
  input  [7:0][15:0]  prices,
  output [5:0]        count
);

  // 32-bit intermediate sums
  wire [31:0] s0 = prices[0];
  wire [31:0] s1 = s0 + prices[1];
  wire [31:0] s2 = s1 + prices[2];
  wire [31:0] s3 = s2 + prices[3];
  wire [31:0] s4 = s3 + prices[4];
  wire [31:0] s5 = s4 + prices[5];
  wire [31:0] s6 = s5 + prices[6];
  wire [31:0] s7 = s6 + prices[7];

  // prefix sums: prefix[i] = sum of prices[0..i]
  wire [31:0] prefix [7:0];
  assign prefix[0] = s0;
  assign prefix[1] = s1;
  assign prefix[2] = s2;
  assign prefix[3] = s3;
  assign prefix[4] = s4;
  assign prefix[5] = s5;
  assign prefix[6] = s6;
  assign prefix[7] = s7;

  // 32-bit products: p_value * length (max length 8, safe in 32-bit)
  wire [31:0] p1 = p_value * 32'd1;
  wire [31:0] p2 = p_value * 32'd2;
  wire [31:0] p3 = p_value * 32'd3;
  wire [31:0] p4 = p_value * 32'd4;
  wire [31:0] p5 = p_value * 32'd5;
  wire [31:0] p6 = p_value * 32'd6;
  wire [31:0] p7 = p_value * 32'd7;
  wire [31:0] p8 = p_value * 32'd8;

  // Helper function: subseq_sum(start, length) using prefix sums
  function automatic [31:0] subseq_sum;
    input [3:0] start;
    input [3:0] length;
    reg   [3:0] end_idx;
  begin
    end_idx = start + length - 1;
    if (start == 0)
      subseq_sum = prefix[end_idx];
    else
      subseq_sum = prefix[end_idx] - prefix[start-1];
  end
  endfunction

  // Generate validity bits for all 36 subsequences
  wire [35:0] valid;

  // length 1 (8 subsequences)
  assign valid[0] = (subseq_sum(4'd0,4'd1) >= p1);
  assign valid[1] = (subseq_sum(4'd1,4'd1) >= p1);
  assign valid[2] = (subseq_sum(4'd2,4'd1) >= p1);
  assign valid[3] = (subseq_sum(4'd3,4'd1) >= p1);
  assign valid[4] = (subseq_sum(4'd4,4'd1) >= p1);
  assign valid[5] = (subseq_sum(4'd5,4'd1) >= p1);
  assign valid[6] = (subseq_sum(4'd6,4'd1) >= p1);
  assign valid[7] = (subseq_sum(4'd7,4'd1) >= p1);

  // length 2 (7 subsequences)
  assign valid[8]  = (subseq_sum(4'd0,4'd2) >= p2);
  assign valid[9]  = (subseq_sum(4'd1,4'd2) >= p2);
  assign valid[10] = (subseq_sum(4'd2,4'd2) >= p2);
  assign valid[11] = (subseq_sum(4'd3,4'd2) >= p2);
  assign valid[12] = (subseq_sum(4'd4,4'd2) >= p2);
  assign valid[13] = (subseq_sum(4'd5,4'd2) >= p2);
  assign valid[14] = (subseq_sum(4'd6,4'd2) >= p2);

  // length 3 (6 subsequences)
  assign valid[15] = (subseq_sum(4'd0,4'd3) >= p3);
  assign valid[16] = (subseq_sum(4'd1,4'd3) >= p3);
  assign valid[17] = (subseq_sum(4'd2,4'd3) >= p3);
  assign valid[18] = (subseq_sum(4'd3,4'd3) >= p3);
  assign valid[19] = (subseq_sum(4'd4,4'd3) >= p3);
  assign valid[20] = (subseq_sum(4'd5,4'd3) >= p3);

  // length 4 (5 subsequences)
  assign valid[21] = (subseq_sum(4'd0,4'd4) >= p4);
  assign valid[22] = (subseq_sum(4'd1,4'd4) >= p4);
  assign valid[23] = (subseq_sum(4'd2,4'd4) >= p4);
  assign valid[24] = (subseq_sum(4'd3,4'd4) >= p4);
  assign valid[25] = (subseq_sum(4'd4,4'd4) >= p4);

  // length 5 (4 subsequences)
  assign valid[26] = (subseq_sum(4'd0,4'd5) >= p5);
  assign valid[27] = (subseq_sum(4'd1,4'd5) >= p5);
  assign valid[28] = (subseq_sum(4'd2,4'd5) >= p5);
  assign valid[29] = (subseq_sum(4'd3,4'd5) >= p5);

  // length 6 (3 subsequences)
  assign valid[30] = (subseq_sum(4'd0,4'd6) >= p6);
  assign valid[31] = (subseq_sum(4'd1,4'd6) >= p6);
  assign valid[32] = (subseq_sum(4'd2,4'd6) >= p6);

  // length 7 (2 subsequences)
  assign valid[33] = (subseq_sum(4'd0,4'd7) >= p7);
  assign valid[34] = (subseq_sum(4'd1,4'd7) >= p7);

  // length 8 (1 subsequence)
  assign valid[35] = (subseq_sum(4'd0,4'd8) >= p8);

  // Count total valid subsequences (population count of 36 bits)
  wire [5:0] c0 = valid[0]  + valid[1]  + valid[2]  + valid[3];
  wire [5:0] c1 = valid[4]  + valid[5]  + valid[6]  + valid[7];
  wire [5:0] c2 = valid[8]  + valid[9]  + valid[10] + valid[11];
  wire [5:0] c3 = valid[12] + valid[13] + valid[14] + valid[15];
  wire [5:0] c4 = valid[16] + valid[17] + valid[18] + valid[19];
  wire [5:0] c5 = valid[20] + valid[21] + valid[22] + valid[23];
  wire [5:0] c6 = valid[24] + valid[25] + valid[26] + valid[27];
  wire [5:0] c7 = valid[28] + valid[29] + valid[30] + valid[31];
  wire [5:0] c8 = valid[32] + valid[33] + valid[34] + valid[35];

  wire [5:0] s_a = c0 + c1;
  wire [5:0] s_b = c2 + c3;
  wire [5:0] s_c = c4 + c5;
  wire [5:0] s_d = c6 + c7;
  wire [5:0] s_e = s_a + s_b;
  wire [5:0] s_f = s_c + s_d;
  wire [5:0] s_g = s_e + s_f;
  assign count = s_g + c8;

endmodule