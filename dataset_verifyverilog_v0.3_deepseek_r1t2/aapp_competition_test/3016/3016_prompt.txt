module ball_arrangement(
  input [1:0] count1, count2,  // Ball counts for colors 1 and 2 (0-2)
  input [1:0] forbidden,       // Bit0: color1 forbidden, bit1: color2 forbidden
  input [1:0] pattern_length,  // 0-2
  input [1:0] pattern0,        // First color in pattern (1 or 2)
  input [1:0] pattern1,        // Second color in pattern (1 or 2)
  output reg [31:0] result     // Result mod 1000000007
);

  // Internal signals
  reg [1:0] permutations [0:11][0:3];  // Up to 12 permutations, max 4 elements
  reg [3:0] valid_perms [0:11];        // Valid flags for each permutation
  reg [3:0] pattern_counts [0:11];     // Pattern counts for each permutation
  reg [3:0] max_pattern_count;
  reg [3:0] count_valid;
  integer i, j, k, perm_count, total_balls;
  
  always @(*) begin
    // Initialize
    perm_count = 0;
    total_balls = count1 + count2;
    result = 0;
    max_pattern_count = 0;
    count_valid = 0;
    
    // Generate permutations based on counts
    case({count1, count2})
      // 0 balls total
      4'b0000: begin
        permutations[0][0] = 0; perm_count = 1; end
      // 1 ball total
      4'b0100: begin permutations[0][0] = 1; perm_count = 1; end
      4'b0001: begin permutations[0][0] = 2; perm_count = 1; end
      // 2 balls total
      4'b1000: begin permutations[0][0]=1; permutations[0][1]=1; perm_count=1; end
      4'b0010: begin permutations[0][0]=2; permutations[0][1]=2; perm_count=1; end
      4'b0101: begin
        permutations[0][0]=1; permutations[0][1]=2; 
        permutations[1][0]=2; permutations[1][1]=1; perm_count=2; end
      // 3 balls total
      4'b1100: begin
        permutations[0][0]=1; permutations[0][1]=1; permutations[0][2]=1; perm_count=1; end
      4'b0011: begin
        permutations[0][0]=2; permutations[0][1]=2; permutations[0][2]=2; perm_count=1; end
      4'b1001: begin
        permutations[0][0]=1; permutations[0][1]=1; permutations[0][2]=2;
        permutations[1][0]=1; permutations[1][1]=2; permutations[1][2]=1;
        permutations[2][0]=2; permutations[2][1]=1; permutations[2][2]=1; perm_count=3; end
      4'b0110: begin
        permutations[0][0]=2; permutations[0][1]=2; permutations[0][2]=1;
        permutations[1][0]=2; permutations[1][1]=1; permutations[1][2]=2;
        permutations[2][0]=1; permutations[2][1]=2; permutations[2][2]=2; perm_count=3; end
      // 4 balls total
      4'b1010: begin
        permutations[0][0]=1; permutations[0][1]=1; permutations[0][2]=2; permutations[0][3]=2;
        permutations[1][0]=1; permutations[1][1]=2; permutations[1][2]=1; permutations[1][3]=2;
        permutations[2][0]=1; permutations[2][1]=2; permutations[2][2]=2; permutations[2][3]=1;
        permutations[3][0]=2; permutations[3][1]=1; permutations[3][2]=1; permutations[3][3]=2;
        permutations[4][0]=2; permutations[4][1]=1; permutations[4][2]=2; permutations[4][3]=1;
        permutations[5][0]=2; permutations[5][1]=2; permutations[5][2]=1; permutations[5][3]=1; perm_count=6; end
      default: perm_count = 0;
    endcase
    
    // Check each permutation
    for (i = 0; i < 11; i = i + 1) begin
      if (i < perm_count) begin
        // Check adjacency constraints
        valid_perms[i] = 1;
        for (j = 0; j < total_balls - 1; j = j + 1) begin
          if (((permutations[i][j] == 1 && forbidden[0]) || 
               (permutations[i][j] == 2 && forbidden[1])) &&
              ((permutations[i][j+1] == 1 && forbidden[0]) ||
               (permutations[i][j+1] == 2 && forbidden[1]))) begin
            valid_perms[i] = 0;
          end
        end
        
        // Count pattern occurrences
        pattern_counts[i] = 0;
        if (pattern_length == 1) begin
          for (j = 0; j < total_balls; j = j + 1) begin
            if (permutations[i][j] == pattern0) begin
              pattern_counts[i] = pattern_counts[i] + 1;
            end
          end
        end else if (pattern_length == 2) begin
          for (j = 0; j < total_balls - 1; j = j + 1) begin
            if (permutations[i][j] == pattern0 && permutations[i][j+1] == pattern1) begin
              pattern_counts[i] = pattern_counts[i] + 1;
            end
          end
        end
        
        // Update max pattern count
        if (valid_perms[i] && pattern_counts[i] > max_pattern_count) begin
          max_pattern_count = pattern_counts[i];
        end
      end else begin
        valid_perms[i] = 0;
      end
    end
    
    // Count arrangements achieving max pattern count
    for (i = 0; i < 11; i = i + 1) begin
      if (i < perm_count && valid_perms[i] && pattern_counts[i] == max_pattern_count) begin
        count_valid = count_valid + 1;
      end
    end
    
    result = count_valid % 1000000007;
  end
endmodule