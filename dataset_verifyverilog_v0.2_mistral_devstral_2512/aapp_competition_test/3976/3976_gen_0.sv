module seq_match_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [3:0] p,
  input [3:0] a [0:15],
  input [3:0] b [0:15],
  output reg [3:0] result_count,
  output reg [3:0] result_positions [0:15],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT_HIST,
    COMPARE,
    UPDATE_WINDOW,
    DONE
  } state_t;

  state_t state;
  reg [3:0] current_pos;
  reg [3:0] window_start;
  reg [3:0] window_end;
  reg [3:0] hist_a [0:15];
  reg [3:0] hist_b [0:15];
  reg [3:0] match_count;
  reg [3:0] temp_positions [0:15];
  reg [3:0] i, j, k;
  reg match;

  // Initialize all outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_pos <= 0;
      window_start <= 0;
      window_end <= 0;
      result_count <= 0;
      done <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        hist_a[i] <= 0;
        hist_b[i] <= 0;
        result_positions[i] <= 0;
        temp_positions[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT_HIST;
            current_pos <= 0;
            window_start <= 0;
            window_end <= m - 1;
            match_count <= 0;
            for (i = 0; i < 16; i = i + 1) begin
              hist_a[i] <= 0;
              hist_b[i] <= 0;
              temp_positions[i] <= 0;
            end
          end
        end

        INIT_HIST: begin
          // Initialize histogram for b
          if (j < m) begin
            hist_b[b[j] - 1] <= hist_b[b[j] - 1] + 1;
            j <= j + 1;
          end else if (k < m) begin
            // Initialize histogram for first window of a
            hist_a[a[k] - 1] <= hist_a[a[k] - 1] + 1;
            k <= k + 1;
          end else begin
            state <= COMPARE;
            j <= 0;
            k <= 0;
          end
        end

        COMPARE: begin
          // Compare histograms
          match <= 1;
          for (i = 0; i < 15; i = i + 1) begin
            if (hist_a[i] != hist_b[i]) begin
              match <= 0;
            end
          end

          if (match) begin
            temp_positions[match_count] <= current_pos + 1;
            match_count <= match_count + 1;
          end

          // Check if we need to update window
          if (window_end + p < n) begin
            state <= UPDATE_WINDOW;
          end else begin
            state <= DONE;
          end
        end

        UPDATE_WINDOW: begin
          // Remove element leaving the window
          if (a[window_start] != 0) begin
            hist_a[a[window_start] - 1] <= hist_a[a[window_start] - 1] - 1;
          end

          // Move window
          window_start <= window_start + p;
          window_end <= window_end + p;
          current_pos <= current_pos + p;

          // Add new element to window
          if (a[window_end] != 0) begin
            hist_a[a[window_end] - 1] <= hist_a[a[window_end] - 1] + 1;
          end

          state <= COMPARE;
        end

        DONE: begin
          // Sort the positions (simple bubble sort)
          for (i = 0; i < match_count - 1; i = i + 1) begin
            for (j = 0; j < match_count - i - 1; j = j + 1) begin
              if (temp_positions[j] > temp_positions[j + 1]) begin
                k <= temp_positions[j];
                temp_positions[j] <= temp_positions[j + 1];
                temp_positions[j + 1] <= k;
              end
            end
          end

          // Copy to output
          result_count <= match_count;
          for (i = 0; i < 16; i = i + 1) begin
            result_positions[i] <= temp_positions[i];
          end

          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule