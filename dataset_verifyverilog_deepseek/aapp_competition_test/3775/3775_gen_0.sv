module participant_deduction(
  input [3:0] n,
  input [3:0] m,
  input [63:0] a_pairs,
  input [63:0] b_pairs,
  output [3:0] result
);

  reg [9:0] candidate_set;
  reg [3:0] a_possible [0:7];
  reg [3:0] b_possible [0:7];
  reg [3:0] result_reg;

  always_comb begin
    integer i, j, k;
    candidate_set = 10'b0;
    for (i=0; i<8; i++) begin
      a_possible[i] = 4'b0;
      b_possible[i] = 4'b0;
    end

    for (i=0; i<8; i++) begin
      for (j=0; j<8; j++) begin
        if (i < n && j < m) begin
          reg [7:0] a_pair = a_pairs[63 - 8*i -: 8];
          reg [7:0] b_pair = b_pairs[63 - 8*j -: 8];
          reg [3:0] a_x = a_pair[7:4];
          reg [3:0] a_y = a_pair[3:0];
          reg [3:0] b_u = b_pair[7:4];
          reg [3:0] b_v = b_pair[3:0];

          wire same_pair = ((a_x == b_u) & (a_y == b_v)) | ((a_x == b_v) & (a_y == b_u));
          wire x_in_uv = (a_x == b_u) | (a_x == b_v);
          wire y_in_uv = (a_y == b_u) | (a_y == b_v);
          wire exactly_one_common = (x_in_uv | y_in_uv) & 
                                   !(x_in_uv & y_in_uv & (a_x != a_y)) & 
                                   !same_pair;

          if (exactly_one_common) begin
            reg [3:0] common_num;
            if (x_in_uv & (!y_in_uv | (a_x == a_y))) begin
              common_num = a_x;
            end else begin
              common_num = a_y;
            end
            if (common_num >= 1 && common_num <= 9) candidate_set[common_num] = 1'b1;
            a_possible[i] = a_possible[i] + 1;
            b_possible[j] = b_possible[j] + 1;
          end
        end
      end
    end

    reg [3:0] candidate_count = 0;
    for (k=1; k<=9; k++) begin
      candidate_count = candidate_count + candidate_set[k];
    end

    logic a_all_le1 = 1'b1;
    logic b_all_le1 = 1'b1;
    for (i=0; i<8; i++) begin
      if (i < n) a_all_le1 = a_all_le1 & (a_possible[i] <= 1);
    end
    for (j=0; j<8; j++) begin
      if (j < m) b_all_le1 = b_all_le1 & (b_possible[j] <= 1);
    end

    result_reg = 15;
    if (candidate_count == 1) begin
      for (k=1; k<=9; k++) begin
        if (candidate_set[k]) result_reg = k;
      end
    end else if (a_all_le1 & b_all_le1) begin
      result_reg = 0;
    end
  end

  assign result = result_reg;
endmodule