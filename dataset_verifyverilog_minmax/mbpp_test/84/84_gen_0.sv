module newman_conway (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  output reg [3:4] result,
  output reg done
);

  // 16-entry register array for P(1)..P(16). Index 0 unused.
  reg [3:0] P [1:16];

  // State machine
  typedef enum logic { IDLE = 1'b0, RUN = 1'b1 } state_t;
  state_t state, next_state;

  reg [3:0] i;        // current index being computed
  reg [3:0] n_sync;   // latched n_in on start

  // Synchronous update of state, i, and array
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 4'd0;
      n_sync <= 4'd0;
      result <= 4'd0;
      done <= 1'b0;
      // Initialize array to 0 on reset (index 0 unused)
      for (int k = 1; k <= 16; k++) P[k] <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs and prepare for computation
            n_sync <= n_in;
            i <= 4'd3; // start at 3 if n > 2, otherwise no RUN needed
            result <= (n_in == 1) ? 4'd1 : 4'd1; // both 1 and 2 yield 1; keep done registered below
            done <= 1'b0;
            // Base cases
            P[1] <= 4'd1;
            P[2] <= 4'd1;
            if (n_in > 2) state <= RUN;
            else state <= IDLE; // n_in is 1 or 2; stay idle after setting done in same cycle
          end else begin
            // Idle: keep array values (P[0] unused)
            state <= IDLE;
            done <= 1'b0; // ensure done is registered low in idle
          end
        end

        RUN: begin
          // Compute P(i) using recurrence: P(i) = P(P(i-1)) + P(i - P(i-1))
          if (i >= 3 && i <= n_sync) begin
            P[i] <= P[P[i-1]] + P[i - P[i-1]];
          end

          // Check if we are done computing up to n_sync
          if (i >= n_sync) begin
            done <= 1'b1;
            result <= P[n_sync];
            state <= IDLE;
            i <= 4'd0; // clear index for next start
          end else begin
            done <= 1'b0;
            state <= RUN;
            i <= i + 4'd1; // advance to next index
            // result is updated only when done (registered output requirement)
            result <= result; // explicit to emphasize registered result
          end
        end

        default: begin
          state <= IDLE;
          done <= 1'b0;
          i <= 4'd0;
          n_sync <= 4'd0;
          result <= 4'd0;
        end
      endcase
    end
  end

endmodule
