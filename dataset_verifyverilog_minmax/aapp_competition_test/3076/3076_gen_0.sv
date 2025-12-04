module knapsack_solver(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] jewel_count,
  input reg [7:0] jewel_sizes [0:7],
  input reg [7:0] jewel_values [0:7],
  output reg [10:0] dp_table [0:7],
  output reg done
);

  // Parameters
  parameter N = 8; // maximum number of jewels
  parameter K = 8; // knapsack sizes (1..8)

  // Internal state and data
  typedef enum logic [1:0] {IDLE, INIT, PROC, WAIT} state_t;
  state_t state, next_state;

  reg [2:0] saved_jewel_count; // copy of jewel_count when start is asserted
  reg [2:0] item_idx;          // index of jewel currently being processed (0-based)

  // DP arrays
  reg [10:0] dp [0:7];         // current DP table
  reg [10:0] dp_next [0:7];    // next DP table (combinational)

  // Combinational block to compute dp_next based on current state and inputs
  always_comb begin
    // Default: keep dp_next the same as current dp
    dp_next = dp; // copy unpacked array

    if (state == INIT) begin
      // Zero out DP on initialization cycle
      dp_next = '0;
    end else if (state == PROC && item_idx < saved_jewel_count) begin
      // Process the current jewel
      logic [7:0] size_i;
      logic [7:0] value_i;
      size_i  = jewel_sizes[item_idx];
      value_i = jewel_values[item_idx];

      if (size_i <= 8) begin
        // 0/1 knapsack update: iterate knapsack capacity from high to low
        for (int w = 8; w >= size_i; w--) begin
          int idx = w - 1;          // dp index for capacity w
          int prev_idx = idx - size_i; // index for capacity w - size_i
          reg [10:0] candidate = dp[prev_idx] + value_i;
          dp_next[idx] = (dp[idx] > candidate) ? dp[idx] : candidate;
        end
      end
      // If size_i > 8, the item cannot fit, dp_next remains unchanged
    end
    // For other states, dp_next stays unchanged (already set above)
  end

  // Sequential block: state machine and register updates
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      saved_jewel_count <= 0;
      item_idx <= 0;
      done <= 0;
      for (int i = 0; i < 8; i++) begin
        dp[i] <= 0;
      end
    end else begin
      // Default: hold current state
      next_state <= state;

      // State machine transitions
      case (state)
        IDLE: begin
          if (start) begin
            // Capture input parameters and start the algorithm
            saved_jewel_count <= jewel_count;
            item_idx <= 0;
            done <= 0;
            next_state <= INIT;
          end
        end

        INIT: begin
          // dp_next already zeroed in combinational block
          next_state <= PROC;
        end

        PROC: begin
          // Check if more jewels remain to be processed
          if (item_idx < saved_jewel_count) begin
            // Increment the item index for the next cycle
            item_idx <= item_idx + 1;
            // Stay in PROC
          end else begin
            // All jewels processed; go to WAIT to assert done
            next_state <= WAIT;
          end
        end

        WAIT: begin
          // One-cycle wait; assert done and return to IDLE
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase

      // Update state
      state <= next_state;

      // Update DP registers and output ports
      for (int i = 0; i < 8; i++) begin
        dp[i] <= dp_next[i];
        dp_table[i] <= dp[i];
      end
    end
  end

endmodule
