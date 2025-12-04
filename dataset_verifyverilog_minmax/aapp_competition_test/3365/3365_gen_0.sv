module max_partition_score(
  input clk,
  input rst_n,
  input start,
  input [7:0] v0,
  input [7:0] v1,
  input [7:0] v2,
  input [7:0] v3,
  input [7:0] v4,
  input [7:0] v5,
  input [7:0] v6,
  input [7:0] v7,
  input [1:0] k,
  output reg [7:0] score,
  output reg done
);

// State machine states
parameter IDLE = 2'b00;
parameter COMPUTE_GCD = 2'b01;
parameter DP_CALC = 2'b10;
parameter DONE = 2'b11;

reg [1:0] state;

// Storage for input values
reg [7:0] values [0:7];

// GCD lookup ROM and prime ROM
reg [7:0] gcd_lookup_rom [0:255][0:255];
reg [7:0] prime_rom [0:255];

// GCD and prime tables for subarrays
reg [7:0] gcd_table [0:7][0:7];
reg [7:0] prime_table [0:7][0:7];

// State variables for COMPUTE_GCD
reg [3:0] gcd_cycle;

// State variables for DP_CALC
reg [7:0] max_score;
reg [2:0] cut;         // For k=2
reg [2:0] cut1, cut2;  // For k=3
reg [2:0] cut1_d, cut2_d, cut3_d;  // For k=4
reg [1:0] k_reg;       // Store k for use in state machine

// Initialize ROMs
integer i, j, x, y;
initial begin
  // Initialize prime_rom
  for (x = 0; x < 256; x++) begin
    prime_rom[x] = compute_largest_prime(x);
  end
  
  // Initialize gcd_lookup_rom
  for (x = 0; x < 256; x++) begin
    for (y = 0; y < 256; y++) begin
      gcd_lookup_rom[x][y] = compute_gcd(x, y);
    end
  end
end

// Function to compute largest prime divisor
function [7:0] compute_largest_prime(input [7:0] n);
  integer i;
  reg [7:0] max_prime;
  if (n < 2) return 0;
  max_prime = 0;
  for (i = 2; i <= n; i++) begin
    if (n % i == 0) begin
      if (is_prime(i)) max_prime = i;
    end
  end
  return max_prime;
endfunction

// Function to check if a number is prime
function is_prime(input integer n);
  integer i;
  if (n < 2) return 0;
  for (i = 2; i*i <= n; i++) begin
    if (n % i == 0) return 0;
  end
  return 1;
endfunction

// Function to compute GCD
function [7:0] compute_gcd(input [7:0] a, input [7:0] b);
  reg [7:0] temp_a, temp_b;
  temp_a = a;
  temp_b = b;
  while (temp_b != 0) begin
    temp_a = temp_b;
    temp_b = a % b;
    a = temp_b;
    b = temp_a;
  end
  return temp_a;
endfunction

// Main state machine
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    score <= 0;
    gcd_cycle <= 0;
    max_score <= 0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          // Store input values
          values[0] <= v0;
          values[1] <= v1;
          values[2] <= v2;
          values[3] <= v3;
          values[4] <= v4;
          values[5] <= v5;
          values[6] <= v6;
          values[7] <= v7;
          
          k_reg <= k;
          gcd_cycle <= 0;
          state <= COMPUTE_GCD;
        end
      end
      
      COMPUTE_GCD: begin
        if (gcd_cycle < 8) begin
          integer current_i, current_j;
          current_i = 7 - gcd_cycle;
          
          for (current_j = current_i; current_j <= 7; current_j++) begin
            if (current_j == current_i) begin
              gcd_table[current_i][current_j] = values[current_i];
            end else begin
              gcd_table[current_i][current_j] = gcd_lookup_rom[values[current_i]][gcd_table[current_i+1][current_j]];
            end
            prime_table[current_i][current_j] = prime_rom[gcd_table[current_i][current_j]];
          end
          
          gcd_cycle <= gcd_cycle + 1;
        end else begin
          state <= DP_CALC;
          max_score <= 0;
          
          // Initialize cut variables based on k
          if (k_reg == 1) begin
            // k=1, will be handled in DP_CALC state
          end else if (k_reg == 2) begin
            cut <= 1;
          end else if (k_reg == 3) begin
            cut1 <= 1;
            cut2 <= 2;
          end else if (k_reg == 4) begin
            cut1_d <= 1;
            cut2_d <= 2;
            cut3_d <= 3;
          end
        end
      end
      
      DP_CALC: begin
        if (k_reg == 1) begin
          score = prime_table[0][7];
          state <= DONE;
        end else if (k_reg == 2) begin
          if (cut <= 6) begin
            reg [7:0] score0, score1, min_score;
            score0 = prime_table[0][cut-1];
            score1 = prime_table[cut][7];
            min_score = (score0 < score1) ? score0 : score1;
            if (min_score > max_score) max_score <= min_score;
            cut <= cut + 1;
          end else begin
            score = max_score;
            state <= DONE;
          end
        end else if (k_reg == 3) begin
          if (cut1 <= 5) begin
            if (cut2 <= 6) begin
              reg [7:0] score0, score1, score2, min_score;
              score0 = prime_table[0][cut1-1];
              score1 = prime_table[cut1][cut2-1];
              score2 = prime_table[cut2][7];
              min_score = (score0 < score1) ? score0 : score1;
              min_score = (min_score < score2) ? min_score : score2;
              if (min_score > max_score) max_score <= min_score;
              cut2 <= cut2 + 1;
            end else begin
              cut1 <= cut1 + 1;
              cut2 = cut1 + 1;
            end
          end else begin
            score = max_score;
            state <= DONE;
          end
        end else if (k_reg == 4) begin
          if (cut1_d <= 4) begin
            if (cut2_d <= 5) begin
              if (cut3_d <= 6) begin
                reg [7:0] score0, score1, score2, score3, min_score;
                score0 = prime_table[0][cut1_d-1];
                score1 = prime_table[cut1_d][cut2_d-1];
                score2 = prime_table[cut2_d][cut3_d-1];
                score3 = prime_table[cut3_d][7];
                min_score = (score0 < score1) ? score0 : score1;
                min_score = (min_score < score2) ? min_score : score2;
                min_score = (min_score < score3) ? min_score : score3;
                if (min_score > max_score) max_score <= min_score;
                cut3_d <= cut3_d + 1;
              end else begin
                cut2_d <= cut2_d + 1;
                cut3_d = cut2_d + 1;
              end
            end else begin
              cut1_d <= cut1_d + 1;
              cut2_d = cut1_d + 1;
              cut3_d = cut2_d + 1;
            end
          end else begin
            score = max_score;
            state <= DONE;
          end
        end
      end
      
      DONE: begin
        done <= 1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule