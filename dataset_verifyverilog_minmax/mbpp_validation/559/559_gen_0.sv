module max_subarray_sum (
  input clk,
  input rst_n,
  input start,
  input signed [4:0] a [0:7],
  output reg signed [4:0] max_sum,
  output reg done
);

  localparam N = 8;

  // State machine
  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
  state_t state, state_next;

  // Iteration counter and internal accumulators
  reg [2:0] cnt, cnt_next;
  reg signed [4:0] max_ending_here, max_ending_here_next;
  reg signed [4:0] max_so_far, max_so_far_next;

  // Sequential logic (async reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt <= 3'd0;
      max_ending_here <= 5'd0;
      max_so_far <= 5'd0;
      max_sum <= 5'd0;
      done <= 1'b0;
    end else begin
      state <= state_next;
      cnt <= cnt_next;
      max_ending_here <= max_ending_here_next;
      max_so_far <= max_so_far_next;
      max_sum <= max_so_far_next; // Registered output
      done <= (state_next == DONE);
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (avoid latches)
    state_next = state;
    cnt_next = cnt;
    max_ending_here_next = max_ending_here;
    max_so_far_next = max_so_far;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize accumulators
          max_ending_here_next = 5'd0;
          max_so_far_next = 5'd0;
          cnt_next = 3'd0;
          state_next = RUN;
        end else begin
          // Hold in IDLE
          max_ending_here_next = max_ending_here;
          max_so_far_next = max_so_far;
          cnt_next = cnt;
          state_next = IDLE;
        end
      end

      RUN: begin
        // Kadane's step for a[cnt]
        max_ending_here_next = max_ending_here + a[cnt];
        if (max_ending_here_next < 0) begin
          max_ending_here_next = 5'd0;
        end
        if (max_ending_here_next > max_so_far) begin
          max_so_far_next = max_ending_here_next;
        end else begin
          max_so_far_next = max_so_far;
        end

        if (cnt == (N - 1)) begin
          // Last element processed -> done
          state_next = DONE;
          cnt_next = 3'd0;
        end else begin
          state_next = RUN;
          cnt_next = cnt + 1;
        end
      end

      DONE: begin
        if (start) begin
          // Restart immediately on start
          max_ending_here_next = 5'd0;
          max_so_far_next = 5'd0;
          cnt_next = 3'd0;
          state_next = RUN;
        end else begin
          // Remain in DONE until next start
          state_next = DONE;
          max_ending_here_next = max_ending_here;
          max_so_far_next = max_so_far;
          cnt_next = 3'd0;
        end
      end

      default: begin
        state_next = IDLE;
        cnt_next = 3'd0;
        max_ending_here_next = 5'd0;
        max_so_far_next = 5'd0;
      end
    endcase
  end

endmodule
