module unique_numbers(
  input [7:0][3:0] nums,
  input [2:0] length,
  output [7:0][3:0] unique_nums,
  output [7:0] valid_mask
);
  
  wire [7:0] valid_i;
  assign valid_i = ~(8'hFF << length);
  
  wire [7:0][7:0] matches;
  genvar i, j;
  generate
    for (i = 0; i < 8; i++) begin : outer
      for (j = 0; j < 8; j++) begin : inner
        assign matches[i][j] = (nums[i] == nums[j]) && valid_i[j];
      end
    end
  endgenerate
  
  wire [7:0][3:0] counts;
  generate
    for (i = 0; i < 8; i++) begin : cnt
      assign counts[i] = matches[i][0] + matches[i][1] + matches[i][2] + matches[i][3] +
                         matches[i][4] + matches[i][5] + matches[i][6] + matches[i][7];
    end
  endgenerate
  
  wire [7:0] is_unique;
  assign is_unique = counts == {8{4'h1}} & valid_i;
  
  wire [7:0] prev_taken [0:8];
  assign prev_taken[0] = 8'b0;
  
  genvar k;
  generate
    for (k = 0; k < 8; k++) begin : out_gen
      wire [7:0] curr_mask = is_unique & ~prev_taken[k];
      wire found = |curr_mask;
      wire [2:0] idx;
      
      assign idx = curr_mask[0] ? 3'd0 :
                   curr_mask[1] ? 3'd1 :
                   curr_mask[2] ? 3'd2 :
                   curr_mask[3] ? 3'd3 :
                   curr_mask[4] ? 3'd4 :
                   curr_mask[5] ? 3'd5 :
                   curr_mask[6] ? 3'd6 :
                   curr_mask[7] ? 3'd7 : 3'd0;
      
      assign unique_nums[k] = found ? nums[idx] : 4'b0;
      assign valid_mask[k] = found;
      assign prev_taken[k+1] = prev_taken[k] | (found ? (8'b1 << idx) : 8'b0);
    end
  endgenerate

endmodule