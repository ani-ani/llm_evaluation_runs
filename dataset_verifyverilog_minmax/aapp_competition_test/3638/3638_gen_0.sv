module rival_sequence_sorter(
  input [3:0] n,
  input [1:0] len0, 
  input [7:0] seq0,
  input [1:0] len1, 
  input [7:0] seq1,
  input [1:0] len2, 
  input [7:0] seq2,
  input [1:0] len3, 
  input [7:0] seq3,
  output reg [1:0] sorted_indices [0:3]
);

  // Function to compute power factor based on length
  function [6:0] power_factor;
    input [1:0] len;
    case (len)
      2'd0: power_factor = 7'd0;
      2'd1: power_factor = 7'd81;
      2'd2: power_factor = 7'd27;
      2'd3: power_factor = 7'd9;
      2'd4: power_factor = 7'd3;
      default: power_factor = 7'd0;
    endcase
  endfunction

  // Compute scores for each sequence
  wire [9:0] score0 = (len0 == 0) ? 0 : (n - len0 + 1) * power_factor(len0);
  wire [9:0] score1 = (len1 == 0) ? 0 : (n - len1 + 1) * power_factor(len1);
  wire [9:0] score2 = (len2 == 0) ? 0 : (n - len2 + 1) * power_factor(len2);
  wire [9:0] score3 = (len3 == 0) ? 0 : (n - len3 + 1) * power_factor(len3);

  // Compute ranks for each element (number of elements greater than it)
  reg [2:0] rank0, rank1, rank2, rank3;
  
  always_comb begin
    // For element 0
    rank0 = 0;
    if ((score1 > score0) || (score1 == score0 && 1 < 0)) rank0++;
    if ((score2 > score0) || (score2 == score0 && 2 < 0)) rank0++;
    if ((score3 > score0) || (score3 == score0 && 3 < 0)) rank0++;
    
    // For element 1
    rank1 = 0;
    if ((score0 > score1) || (score0 == score1 && 0 < 1)) rank1++;
    if ((score2 > score1) || (score2 == score1 && 2 < 1)) rank1++;
    if ((score3 > score1) || (score3 == score1 && 3 < 1)) rank1++;
    
    // For element 2
    rank2 = 0;
    if ((score0 > score2) || (score0 == score2 && 0 < 2)) rank2++;
    if ((score1 > score2) || (score1 == score2 && 1 < 2)) rank2++;
    if ((score3 > score2) || (score3 == score2 && 3 < 2)) rank2++;
    
    // For element 3
    rank3 = 0;
    if ((score0 > score3) || (score0 == score3 && 0 < 3)) rank3++;
    if ((score1 > score3) || (score1 == score3 && 1 < 3)) rank3++;
    if ((score2 > score3) || (score2 == score3 && 2 < 3)) rank3++;
  end

  // Assign sorted indices based on ranks
  always_comb begin
    // Initialize to default values
    sorted_indices[0] = 2'd0;
    sorted_indices[1] = 2'd1;
    sorted_indices[2] = 2'd2;
    sorted_indices[3] = 2'd3;
    
    // Assign based on rank0
    if (rank0 == 0) sorted_indices[0] = 0;
    if (rank0 == 1) sorted_indices[1] = 0;
    if (rank0 == 2) sorted_indices[2] = 0;
    if (rank0 == 3) sorted_indices[3] = 0;
    
    // Assign based on rank1
    if (rank1 == 0) sorted_indices[0] = 1;
    if (rank1 == 1) sorted_indices[1] = 1;
    if (rank1 == 2) sorted_indices[2] = 1;
    if (rank1 == 3) sorted_indices[3] = 1;
    
    // Assign based on rank2
    if (rank2 == 0) sorted_indices[0] = 2;
    if (rank2 == 1) sorted_indices[1] = 2;
    if (rank2 == 2) sorted_indices[2] = 2;
    if (rank2 == 3) sorted_indices[3] = 2;
    
    // Assign based on rank3
    if (rank3 == 0) sorted_indices[0] = 3;
    if (rank3 == 1) sorted_indices[1] = 3;
    if (rank3 == 2) sorted_indices[2] = 3;
    if (rank3 == 3) sorted_indices[3] = 3;
  end

endmodule