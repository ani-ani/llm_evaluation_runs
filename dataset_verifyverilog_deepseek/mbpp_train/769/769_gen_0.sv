module list_difference(
  input [3:0] list1 [0:3],
  input [3:0] list2 [0:3],
  input [0:3] valid1,
  input [0:3] valid2,
  output reg [3:0] result [0:7],
  output reg [3:0] size
);
  
  wire [3:0] is_list1_diff;
  wire [3:0] is_list2_diff;
  
  generate
    for (genvar i = 0; i < 4; i++) begin: list1_diff_gen
      wire [3:0] matches;
      for (genvar j = 0; j < 4; j++) begin: list1_match
        assign matches[j] = valid2[j] && (list1[i] == list2[j]);
      end
      assign is_list1_diff[i] = valid1[i] && ~(|matches);
    end
    
    for (genvar i = 0; i < 4; i++) begin: list2_diff_gen
      wire [3:0] matches;
      for (genvar j = 0; j < 4; j++) begin: list2_match
        assign matches[j] = valid1[j] && (list2[i] == list1[j]);
      end
      assign is_list2_diff[i] = valid2[i] && ~(|matches);
    end
  endgenerate
  
  wire [2:0] cnt_list1 [0:4];
  assign cnt_list1[0] = 0;
  assign cnt_list1[1] = cnt_list1[0] + is_list1_diff[0];
  assign cnt_list1[2] = cnt_list1[1] + is_list1_diff[1];
  assign cnt_list1[3] = cnt_list1[2] + is_list1_diff[2];
  assign cnt_list1[4] = cnt_list1[3] + is_list1_diff[3];
  
  wire [2:0] cnt_list2 [0:4];
  assign cnt_list2[0] = 0;
  assign cnt_list2[1] = cnt_list2[0] + is_list2_diff[0];
  assign cnt_list2[2] = cnt_list2[1] + is_list2_diff[1];
  assign cnt_list2[3] = cnt_list2[2] + is_list2_diff[2];
  assign cnt_list2[4] = cnt_list2[3] + is_list2_diff[3];
  
  always_comb begin
    size = cnt_list1[4] + cnt_list2[4];
    
    // Initialize result to 0
    foreach (result[i]) result[i] = 4'b0;
    
    // Place list1 unique elements
    for (int i = 0; i < 4; i++) begin
      if (is_list1_diff[i]) begin
        automatic int idx = cnt_list1[i];
        result[idx] = list1[i];
      end
    end
    
    // Place list2 unique elements
    for (int i = 0; i < 4; i++) begin
      if (is_list2_diff[i]) begin
        automatic int idx = cnt_list1[4] + cnt_list2[i];
        result[idx] = list2[i];
      end
    end
  end
endmodule