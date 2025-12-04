module sorted_common_elements(
  input              clk,
  input              rst_n,
  input              start,
  input        [15:0] l1 [0:7],
  input        [15:0] l2 [0:7],
  input        [3:0] len1,
  input        [3:0] len2,
  output reg [15:0] result [0:7],
  output reg [3:0] result_len,
  output reg  done
);

  reg start_reg;
  wire [7:0] exists_in_l2;
  wire [7:0] is_unique;
  wire [7:0] valid_common;
  wire [3:0] prefix_sum [0:8];
  wire [15:0] common_temp [0:7];
  wire [15:0] sorted_common [0:7];

  genvar i, j, k, p;
  generate
    for (i=0; i<8; i++) begin: gen_exists
      wire [7:0] eq_j;
      for (j=0; j<8; j++) begin: gen_eq_j
        assign eq_j[j] = (j < len2) ? (l1[i] == l2[j]) : 1'b0;
      end
      assign exists_in_l2[i] = (i < len1) ? (|eq_j) : 1'b0;
    end
  endgenerate

  generate
    for (i=0; i<8; i=i+1) begin: gen_unique
      wire [7:0] neq_k;
      for (k=0; k<8; k=k+1) begin: gen_neq_k
        assign neq_k[k] = (k < i && k < len1) ? (l1[i] != l1[k]) : 1'b1;
      end
      assign is_unique[i] = (i < len1) ? (&neq_k) : 1'b0;
      
    end
  endgenerate

  assign valid_common = exists_in_l2 & is_unique;
  assign prefix_sum[0] = 4'b0;

  generate
    for (i=0; i<8; i++) begin: gen_prefix
      assign prefix_sum[i+1] = prefix_sum[i] + ((i < 8) ? valid_common[i] : 1'b0);
    end
  endgenerate

  wire [3:0] result_len_count = prefix_sum[8];

  generate
    for (p=0; p<8; p++) begin: gen_common_temp
      wire [15:0] v [8];
      for (i=0; i<8; i++) begin: gen_common_val
        assign v[i] = (valid_common[i] && (prefix_sum[i] == p)) ? l1[i] : 16'hFFFF;
      end
      assign common_temp[p] = v[0] & v[1] & v[2] & v[3] & v[4] & v[5] & v[6] & v[7];
    end
  endgenerate

  function automatic [31:0] cs(input [15:0] a, input [15:0] b);
    cs = (a <= b) ? {a,b} : {b,a};
  endfunction
  
  // Sorting network for 8 elements with 19 comparators
  wire [15:0] s1_0, s1_1, s1_2, s1_3, s1_4, s1_5, s1_6, s1_7;
  wire [15:0] s2_0, s2_1, s2_2, s2_3, s2_4, s2_5, s2_6, s2_7;
  wire [15:0] s3_0, s3_1, s3_2, s3_3, s3_4, s3_5, s3_6, s3_7;
  wire [15:0] s4_0, s4_1, s4_2, s4_3, s4_4, s4_5, s4_6, s4_7;
  wire [15:0] s5_0, s5_1, s5_2, s5_3, s5_4, s5_5, s5_6, s5_7;

  // Stage 1 (4 x 4)
  assign {s1_0, s1_4} = cs(common_temp[0], common_temp[4]);
  assign {s1_1, s1_5} = cs(common_temp[1], common_temp[5]);
  assign {s1_2, s1_6} = cs(common_temp[2], common_temp[6]);
  assign {s1_3, s1_7} = cs(common_temp[3], common_temp[7]);

  // Stage 2 (4 x 2)
  assign {s2_0, s2_2} = cs(s1_0, s1_2);
  assign {s2_1, s2_3} = cs(s1_1, s1_3);
  assign {s2_4, s2_6} = cs(s1_4, s1_6);
  assign {s2_5, s2_7} = cs(s1_5, s1_7);

  // Stage 3 (4 x 1)
  assign {s3_0, s3_1} = cs(s2_0, s2_1);
  assign {s3_2, s3_3} = cs(s2_2, s2_3);
  assign {s3_4, s3_5} = cs(s2_4, s2_5);
  assign {s3_6, s3_7} = cs(s2_6, s2_7);

  // Stage 4 (4 x 2)
  assign {s4_0, s4_4} = cs(s3_0, s3_4);
  assign {s4_1, s4_5} = cs(s3_1, s3_5);
  assign {s4_2, s4_6} = cs(s3_2, s3_6);
  assign {s4_3, s4_7} = cs(s3_3, s3_7);

  // Stage 5 (4 x 1)
  assign {s5_1, s5_3} = cs(s4_1, s4_3);
  assign {s5_5, s5_7} = cs(s4_5, s4_7);

  // Stage 6 (cross compare)
  assign {sorted_common[0], sorted_common[1]} = cs(s4_0, s5_1);
  assign {sorted_common[2], sorted_common[3]} = cs(s4_2, s5_3);
  assign {sorted_common[4], sorted_common[5]} = cs(s4_4, s5_5);
  assign {sorted_common[6], sorted_common[7]} = cs(s4_6, s5_7);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result_len <= 4'b0;
      start_reg <= 1'b0;
      foreach (result[i]) result[i] <= 16'b0;
    end else begin
      start_reg <= start;
      if (start_reg) begin
        done <= 1'b1;
        result <= sorted_common;
        result_len <= result_len_count;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule