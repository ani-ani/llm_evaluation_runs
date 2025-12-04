module max_diff_calculator (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] arr [7:0],
  output reg [8:0] max_diff,
  output reg done
);

  // Internal state
  typedef enum logic {IDLE, ACTIVE} state_t;
  state_t state, next_state;

  reg [2:0] count, next_count;
  reg signed [7:0] min_val, max_val;
  reg signed [7:0] next_min, next_max;
  reg started_next;

  // State update (sequential)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 3'd0;
      min_val <= 8'sd0;
      max_val <= 8'sd0;
      started_next <= 1'b0;
    end else begin
      state <= next_state;
      count <= next_count;
      min_val <= next_min;
      max_val <= next_max;
      started_next <= start; // capture start for gating next_state
    end
  end

  // Compute next state and update min/max each cycle
  always_comb begin
    // Defaults
    next_state = state;
    next_count = count;
    next_min   = min_val;
    next_max   = max_val;
    done       = 1'b0;
    max_diff   = 9'd0; // keep stable in IDLE

    if (state == IDLE) begin
      if (start && !started_next) begin
        // Begin processing arr[0]
        next_state = ACTIVE;
        next_count = 3'd0;
        next_min   = arr[0];
        next_max   = arr[0];
      end else begin
        next_state = IDLE;
        next_count = 3'd0;
        next_min   = 8'sd0;
        next_max   = 8'sd0;
      end
    end else begin // ACTIVE
      // Process current element (arr[count])
      next_min = (arr[count] < min_val) ? arr[count] : min_val;
      next_max = (arr[count] > max_val) ? arr[count] : max_val;

      if (count == 3'd7) begin
        // After 8 cycles, produce result and assert done for one cycle
        next_state = IDLE;
        next_count = 3'd0;
        max_diff   = $unsigned(max_val - min_val);
        done       = 1'b1;
      end else begin
        next_state = ACTIVE;
        next_count = count + 1;
      end
    end
  end

endmodule
