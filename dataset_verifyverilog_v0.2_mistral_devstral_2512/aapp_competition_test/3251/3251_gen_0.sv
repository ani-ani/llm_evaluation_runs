module longest_interval_chain (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_intervals,
  input [7:0] interval_a [0:7],
  input [7:0] interval_b [0:7],
  output reg [2:0] result_length,
  output reg [7:0] result_a [0:7],
  output reg [7:0] result_b [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SORTING,
    FINDING_LENGTH,
    RECONSTRUCTING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] sorted_a [0:7];
  reg [7:0] sorted_b [0:7];
  reg [2:0] dp [0:7];
  reg [2:0] prev [0:7];
  reg [2:0] max_length;
  reg [2:0] max_index;
  reg [2:0] reconstruct_index;
  reg [2:0] i, j, k;
  reg [2:0] temp_length;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_length <= 0;
      for (k = 0; k < 8; k = k + 1) begin
        result_a[k] <= 0;
        result_b[k] <= 0;
      end
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      for (k = 0; k < 8; k = k + 1) begin
        sorted_a[k] <= 0;
        sorted_b[k] <= 0;
        dp[k] <= 0;
        prev[k] <= 0;
      end
      max_length <= 0;
      max_index <= 0;
      reconstruct_index <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      temp_length <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            // Initialize sorting
            for (k = 0; k < 8; k = k + 1) begin
              sorted_a[k] <= interval_a[k];
              sorted_b[k] <= interval_b[k];
            end
            i <= 0;
            j <= 0;
            next_state <= SORTING;
          end else begin
            next_state <= IDLE;
          end
        end

        SORTING: begin
          // Bubble sort implementation
          if (i < num_intervals - 1) begin
            if (j < num_intervals - i - 1) begin
              // Compare and swap if needed
              if (sorted_a[j] > sorted_a[j+1] ||
                  (sorted_a[j] == sorted_a[j+1] && sorted_b[j] < sorted_b[j+1])) begin
                // Swap intervals
                reg [7:0] temp_a, temp_b;
                temp_a = sorted_a[j];
                temp_b = sorted_b[j];
                sorted_a[j] <= sorted_a[j+1];
                sorted_b[j] <= sorted_b[j+1];
                sorted_a[j+1] <= temp_a;
                sorted_b[j+1] <= temp_b;
              end
              j <= j + 1;
            end else begin
              i <= i + 1;
              j <= 0;
            end
          end else begin
            // Sorting complete, move to finding length
            i <= 0;
            j <= 0;
            next_state <= FINDING_LENGTH;
          end
        end

        FINDING_LENGTH: begin
          // Initialize DP arrays
          if (i == 0) begin
            for (k = 0; k < 8; k = k + 1) begin
              dp[k] <= 1;
              prev[k] <= k;
            end
            max_length <= 1;
            max_index <= 0;
          end

          // DP computation
          if (i < num_intervals) begin
            if (j < i) begin
              if (sorted_b[j] > sorted_b[i] && dp[j] + 1 > dp[i]) begin
                dp[i] <= dp[j] + 1;
                prev[i] <= j;
                if (dp[i] > max_length) begin
                  max_length <= dp[i];
                  max_index <= i;
                end
              end
              j <= j + 1;
            end else begin
              i <= i + 1;
              j <= 0;
            end
          end else begin
            // DP complete, move to reconstruction
            result_length <= max_length;
            reconstruct_index <= max_index;
            k <= 0;
            next_state <= RECONSTRUCTING;
          end
        end

        RECONSTRUCTING: begin
          // Reconstruct the sequence
          if (k < max_length) begin
            result_a[k] <= sorted_a[reconstruct_index];
            result_b[k] <= sorted_b[reconstruct_index];
            reconstruct_index <= prev[reconstruct_index];
            k <= k + 1;
          end else begin
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Done signal is only high for one cycle
  always @(posedge clk) begin
    if (done) begin
      done <= 0;
    end
  end

endmodule