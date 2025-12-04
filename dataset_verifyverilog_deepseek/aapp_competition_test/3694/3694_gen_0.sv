module stone_game_winner (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [7:0][15:0] stones,
  output reg outcome,
  output reg done
);

  typedef enum {IDLE, PROCESSING, DONE} state_t;
  reg [1:0] state;
  reg [7:0][15:0] sorted_stones;
  reg [15:0] adjusted_sum;
  reg [5:0] cycle_counter;
  reg sort_done;
  reg [3:0] i, j;
  reg swap_flag;
  reg [7:0][15:0] temp_stones;

  // Duplicate detection
  reg [2:0] duplicate_count;
  reg [2:0] zero_count;
  reg has_dup_with_prev;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sorted_stones <= 0;
      outcome <= 0;
      done <= 0;
      cycle_counter <= 0;
      sort_done <= 0;
      i <= 0;
      j <= 0;
      swap_flag <= 0;
      adjusted_sum <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          cycle_counter <= 0;
          sort_done <= 0;
          if (start) begin
            state <= PROCESSING;
            sorted_stones <= stones;
          end
        end

        PROCESSING: begin
          cycle_counter <= cycle_counter + 1;

          // Sorting (Bubble Sort)
          if (!sort_done) begin
            if (i < n-1) begin
              if (j < n-1-i) begin
                if (sorted_stones[j] > sorted_stones[j+1]) begin
                  // Swap
                  temp_stones = sorted_stones;
                  temp_stones[j] = sorted_stones[j+1];
                  temp_stones[j+1] = sorted_stones[j];
                  sorted_stones <= temp_stones;
                  swap_flag <= 1;
                end
                j <= j + 1;
              end else begin
                j <= 0;
                i <= i + 1;
                if (!swap_flag) sort_done <= 1; // Early termination
                swap_flag <= 0;
              end
            end else begin
              sort_done <= 1;
            end
          end else if (cycle_counter < 32) begin
            // Wait until cycle 32 for sorting time budget
          end else begin
            // Conditions check (cycle 32-39)
            if (cycle_counter == 32) begin
              duplicate_count <= 0;
              zero_count <= 0;
              has_dup_with_prev <= 0;
              // Initialize count for first element
              zero_count <= (sorted_stones[0] == 0) ? 1 : 0;
            end else if (cycle_counter < 32 + n) begin
              // Count duplicates and zeros
              if (cycle_counter >= 33 && cycle_counter < 32 + n) begin
                automatic logic [15:0] curr = sorted_stones[cycle_counter-33];
                automatic logic [15:0] next = sorted_stones[cycle_counter-32];
                if (curr == next && curr != 0) begin
                  duplicate_count <= duplicate_count + 1;
                  if (duplicate_count > 0) has_dup_with_prev <= 1; // Multiple duplicates
                  if (cycle_counter > 33 && sorted_stones[cycle_counter-34] == curr-1) begin
                    has_dup_with_prev <= 1;
                  end
                end
                if (next == 0) zero_count <= zero_count + 1;
              end
            end
          end

          // Final computation
          if (cycle_counter == 39) begin
            // Losing conditions
            if ((duplicate_count > 1) ||                // Condition i
                (duplicate_count == 1 && has_dup_with_prev) || // Condition ii
                (zero_count > 1)) begin               // Condition iii
              outcome <= 0;
            end else begin
              // Compute adjusted sum
              adjusted_sum <= 0;
              for (int k = 0; k < n; k++) begin
                adjusted_sum <= adjusted_sum + (sorted_stones[k] - k);
              end
              outcome <= adjusted_sum[0]; // LSB = parity
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          if (start) state <= IDLE;
        end
      endcase
    end
  end

endmodule