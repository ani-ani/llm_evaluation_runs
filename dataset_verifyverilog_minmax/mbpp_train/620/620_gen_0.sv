module divisible_subset (
  input logic clk,
  input logic rst_n,
  input logic start,
  input logic [7:0] numbers [7:0],
  input logic [2:0] size,
  output reg [3:0] max_size,
  output reg done
);

  // Internal state
  reg [3:0] dp [7:0];
  logic [3:0] max_reg;
  logic [2:0] size_reg;
  int i;
  int j;
  logic [3:0] best;

  // State encoding
  typedef enum logic [1:0] {IDLE=2'b00, PROCESS=2'b01, DONE=2'b10} state_t;
  state_t state;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      done <= 1'b0;
      max_size <= 4'b0;
      for (int k = 0; k < 8; k++) dp[k] <= 4'b0;
      max_reg <= 4'b0;
      size_reg <= 3'b0;
      i <= 0;
      j <= 0;
      best <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          // Clear internal state
          done <= 1'b0;
          max_size <= 4'b0;
          for (int k = 0; k < 8; k++) dp[k] <= 4'b0;
          max_reg <= 4'b0;
          best <= 4'b0;
          size_reg <= 3'b0;
          i <= 0;
          j <= 0;
          if (start) begin
            size_reg <= size;
            i <= size - 1; // may become -1 if size=0
            j <= i + 1;   // could be out of range (>= size)
            state <= PROCESS;
          end
        end
        PROCESS: begin
          // Finish if all i processed
          if (i < 0) begin
            state <= DONE;
          end else begin
            if (j >= size_reg) begin
              // No j to compare, dp[i] = 1
              dp[i] <= 4'b1;
              max_reg <= (4'b1 > max_reg) ? 4'b1 : max_reg;
              i <= i - 1;
              j <= i; // after decrement, this is the next j
              best <= 4'b0;
            end else begin
              // There is a j to compare
              // Determine if numbers[i] and numbers[j] are divisible
              if (numbers[i] == 0 || numbers[j] == 0) begin
                // Zero is divisible by any number
                if (dp[j] > best) best <= dp[j];
              end else if (numbers[j] % numbers[i] == 0) begin
                if (dp[j] > best) best <= dp[j];
              end else if (numbers[i] % numbers[j] == 0) begin
                if (dp[j] > best) best <= dp[j];
              end
              // Last j for this i?
              if (j == size_reg - 1) begin
                // Compute dp[i]
                dp[i] <= 1 + best;
                max_reg <= ((1 + best) > max_reg) ? (1 + best) : max_reg;
                // Move to next i
                i <= i - 1;
                j <= i; // old i
                best <= 4'b0;
              end else begin
                // Advance j
                j <= j + 1;
              end
            end
          end
        end
        DONE: begin
          done <= 1'b1;
          max_size <= max_reg;
          // Remain in DONE until reset or start is deasserted
          // No transition needed here for this simple implementation
        end
      endcase
    end
  end

endmodule