module permutation_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [5:0] K,
  output reg [31:0] result,
  output reg done
);

  // Precomputed factorials (0! to 7!)
  localparam [31:0] FACTORIAL [0:7] = '{32'd1, 32'd1, 32'd2, 32'd6, 32'd24, 32'd120, 32'd720, 32'd5040};

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    GENERATE_PARTITIONS,
    CHECK_LCM,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] partition_count;
  reg [31:0] temp_result;
  reg [31:0] cycle_lengths [0:6]; // Max 7 cycles
  reg [31:0] cycle_counts [0:6]; // Count of each cycle length
  reg [31:0] current_partition;
  reg [31:0] partition_index;
  reg [31:0] cycle_index;
  reg [31:0] lcm_result;
  reg [31:0] temp_lcm;
  reg [31:0] temp_gcd;
  reg [31:0] i, j, k;
  reg [31:0] temp_prod;
  reg [31:0] temp_fact;
  reg [31:0] temp_div;
  reg [31:0] valid_partition;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      partition_count <= 32'd0;
      temp_result <= 32'd0;
      partition_index <= 32'd0;
      cycle_index <= 32'd0;
      lcm_result <= 32'd0;
      temp_lcm <= 32'd0;
      temp_gcd <= 32'd0;
      i <= 32'd0;
      j <= 32'd0;
      k <= 32'd0;
      temp_prod <= 32'd0;
      temp_fact <= 32'd0;
      temp_div <= 32'd0;
      valid_partition <= 32'd0;
      for (int idx = 0; idx < 7; idx = idx + 1) begin
        cycle_lengths[idx] <= 32'd0;
        cycle_counts[idx] <= 32'd0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = GENERATE_PARTITIONS;
          result = 32'd0;
          done = 1'b0;
          partition_count = 32'd0;
          temp_result = 32'd0;
          partition_index = 32'd0;
          cycle_index = 32'd0;
          lcm_result = 32'd0;
          temp_lcm = 32'd0;
          temp_gcd = 32'd0;
          i = 32'd0;
          j = 32'd0;
          k = 32'd0;
          temp_prod = 32'd0;
          temp_fact = 32'd0;
          temp_div = 32'd0;
          valid_partition = 32'd0;
          for (int idx = 0; idx < 7; idx = idx + 1) begin
            cycle_lengths[idx] = 32'd0;
            cycle_counts[idx] = 32'd0;
          end
        end
      end

      GENERATE_PARTITIONS: begin
        // Generate all partitions of N (simplified for synthesis)
        // This is a placeholder for actual partition generation logic
        // In a real implementation, you would have a more sophisticated approach
        if (partition_index < 32'd100) begin
          // Simulate partition generation (actual implementation would be more complex)
          // For synthesis, we'll use a simplified approach
          current_partition = partition_index;
          next_state = CHECK_LCM;
        end else begin
          next_state = DONE;
          result = temp_result;
          done = 1'b1;
        end
      end

      CHECK_LCM: begin
        // Compute LCM of cycle lengths
        // Simplified LCM computation for synthesis
        temp_lcm = 1;
        for (int idx = 0; idx < 7; idx = idx + 1) begin
          if (cycle_lengths[idx] > 0) begin
            temp_lcm = lcm(temp_lcm, cycle_lengths[idx]);
          end
        end
        lcm_result = temp_lcm;

        // Check if LCM equals K
        if (lcm_result == K) begin
          valid_partition = 1;
        end else begin
          valid_partition = 0;
        end
        next_state = CALCULATE;
      end

      CALCULATE: begin
        if (valid_partition) begin
          // Calculate number of permutations for this partition
          // Formula: N! / (prod(c_i^{m_i} * m_i!))
          temp_prod = 1;
          temp_fact = 1;

          // Compute product of (c_i^{m_i} * m_i!)
          for (int idx = 0; idx < 7; idx = idx + 1) begin
            if (cycle_counts[idx] > 0) begin
              temp_prod = temp_prod * (cycle_lengths[idx] ** cycle_counts[idx]);
              temp_fact = temp_fact * FACTORIAL[cycle_counts[idx]];
            end
          end

          temp_div = temp_prod * temp_fact;
          if (temp_div != 0) begin
            temp_result = temp_result + (FACTORIAL[N] / temp_div);
          end
        end
        next_state = GENERATE_PARTITIONS;
        partition_index = partition_index + 1;
      end

      DONE: begin
        if (start) begin
          next_state = GENERATE_PARTITIONS;
          result = 32'd0;
          done = 1'b0;
          partition_count = 32'd0;
          temp_result = 32'd0;
          partition_index = 32'd0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Helper function for GCD (for LCM computation)
  function [31:0] gcd;
    input [31:0] a, b;
    reg [31:0] x, y;
    begin
      x = a;
      y = b;
      while (y != 0) begin
        if (x > y) begin
          x = x - y;
        end else begin
          y = y - x;
        end
      end
      gcd = x;
    end
  endfunction

  // Helper function for LCM
  function [31:0] lcm;
    input [31:0] a, b;
    begin
      if (a == 0 || b == 0) begin
        lcm = 0;
      end else begin
        lcm = (a * b) / gcd(a, b);
      end
    end
  endfunction

endmodule