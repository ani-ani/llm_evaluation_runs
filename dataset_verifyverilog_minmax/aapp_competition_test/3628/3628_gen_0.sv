module permutation_crypto(
  input clk,
  input rst_n,
  input start,
  input [3:0] a [0:7],
  output reg [3:0] pi [0:7],
  output reg [3:0] sigma [0:7],
  output reg valid,
  output reg impossible,
  output reg done
);

  // Internal registers for current permutation and sigma
  reg [2:0] pi_reg [0:7];
  reg [2:0] sigma_reg [0:7];
  
  // Next permutation wires
  wire [2:0] next_pi [0:7];
  
  // Valid sigma flag
  wire valid_sigma;
  
  // Counter for permutations
  reg [15:0] counter;
  
  // State machine
  reg state; // 0: IDLE, 1: SEARCH
  
  // Next permutation generator
  always @(*) begin
    // Find the pivot
    integer i, j;
    reg [2:0] temp;
    
    // Initialize next_pi to current pi
    for (i = 0; i < 8; i++) begin
      next_pi[i] = pi_reg[i];
    end
    
    // Find the largest i such that pi_reg[i] < pi_reg[i+1]
    i = 7;
    if (pi_reg[6] < pi_reg[7]) i = 6;
    else if (pi_reg[5] < pi_reg[6]) i = 5;
    else if (pi_reg[4] < pi_reg[5]) i = 4;
    else if (pi_reg[3] < pi_reg[4]) i = 3;
    else if (pi_reg[2] < pi_reg[3]) i = 2;
    else if (pi_reg[1] < pi_reg[2]) i = 1;
    else if (pi_reg[0] < pi_reg[1]) i = 0;
    else i = 7; // No such i, last permutation
    
    if (i == 7) begin
      // Last permutation, reset to first permutation
      for (j = 0; j < 8; j++) begin
        next_pi[j] = j[2:0];
      end
    end
    else begin
      // Find j: the smallest index in the range [i+1,7] such that next_pi[j] > next_pi[i]
      // Actually, we need the largest index in the suffix that is greater than next_pi[i]
      j = 7;
      for (j = 7; j > i; j--) begin
        if (next_pi[j] > next_pi[i]) break;
      end
      
      // Swap next_pi[i] and next_pi[j]
      temp = next_pi[i];
      next_pi[i] = next_pi[j];
      next_pi[j] = temp;
      
      // Reverse the suffix from i+1 to 7
      for (j = 0; j < (8 - (i+1))/2; j++) begin
        temp = next_pi[i+1+j];
        next_pi[i+1+j] = next_pi[7-j];
        next_pi[7-j] = temp;
      end
    end
  end
  
  // Sigma calculator and validity checker
  always @(*) begin
    integer i, j;
    reg [7:0] seen; // bitmask for seen values
    
    // Calculate sigma_i = (a_i - pi_i) mod 8
    for (i = 0; i < 8; i++) begin
      sigma_reg[i] = (a[i] + 8 - pi_reg[i]) % 8;
    end
    
    // Check if sigma is a valid permutation (all values 0-7 appear exactly once)
    seen = 8'b0;
    for (i = 0; i < 8; i++) begin
      seen[sigma_reg[i]] = 1'b1;
    end
    valid_sigma = (seen == 8'b11111111);
  end
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 1'b0;
      valid <= 1'b0;
      impossible <= 1'b0;
      done <= 1'b0;
      counter <= 16'b0;
      for (int i = 0; i < 8; i++) begin
        pi[i] <= 4'b0;
        sigma[i] <= 4'b0;
        pi_reg[i] <= 3'b0;
      end
    end
    else begin
      case (state)
        1'b0: begin // IDLE
          if (start) begin
            // Initialize to first permutation [0,1,2,3,4,5,6,7]
            for (int i = 0; i < 8; i++) begin
              pi_reg[i] = i[2:0];
            end
            counter <= 16'b0;
            state <= 1'b1;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
          end
        end
        
        1'b1: begin // SEARCH
          if (valid_sigma) begin
            // Found valid solution
            for (int i = 0; i < 8; i++) begin
              pi[i] <= {1'b0, pi_reg[i]};
              sigma[i] <= {1'b0, sigma_reg[i]};
            end
            valid <= 1'b1;
            done <= 1'b1;
            state <= 1'b0;
          end
          else if (counter < 40319) begin
            // Try next permutation
            for (int i = 0; i < 8; i++) begin
              pi_reg[i] <= next_pi[i];
            end
            counter <= counter + 1;
          end
          else begin
            // No solution found
            impossible <= 1'b1;
            done <= 1'b1;
            state <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule