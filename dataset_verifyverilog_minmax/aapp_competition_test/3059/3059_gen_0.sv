module speedrun_optimizer(
  input clk,                   // clock signal
  input rst_n,                 // active-low reset
  input start,                 // start calculation (pulse high)
  input [15:0] n,              // best-case run time (seconds)
  input [15:0] r,              // current record (seconds)
  input [15:0] trick_t [0:3],  // trick timestamps (4 elements)
  input [31:0] trick_p [0:3],  // trick success probabilities (Q16.16 format)
  input [15:0] trick_d [0:3],  // trick recovery times (seconds)
  input [1:0] m,               // actual number of tricks (0-4)
  output reg [31:0] result,    // expected time (Q16.16 format)
  output reg done              // high when calculation complete
);

  // Behavioral description:
  // - Uses Q16.16 fixed-point format (16 integer, 16 fractional bits) for probabilities and result
  // - Implements dynamic programming via iterative state machine
  // - Processes tricks in order from last to first (backward induction)
  // - Takes 4 clock cycles to initialize + 2 cycles per trick + 1 cycle finalize
  // - Internal states: IDLE, INIT, PROCESS, DONE
  // - When done=1, result contains expected time in Q16.16 format (integer part = result[31:16])
  // Latency: 4 + 2*m + 1 clock cycles (50 cycles max for 4 tricks) after start assertion.

  // State machine
  localparam IDLE     = 2'b00;
  localparam INIT     = 2'b01;
  localparam PROCESS  = 2'b10;
  localparam DONE     = 2'b11;

  // Internal signals
  reg [1:0] state, next_state;
  reg [2:0] iter;           // 0..4 (counts tricks to process)
  reg [2:0] next_iter;
  reg [31:0] d_next, next_E;   // dynamic programming values (Q16.16)

  // Registered trick capture (captured at start; processed in reverse)
  reg [15:0] trick_t_r [0:3];
  reg [31:0] trick_p_r [0:3];
  reg [15:0] trick_d_r [0:3];
  reg [1:0] m_r;
  reg [15:0] n_r, r_r;

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      iter  <= 3'd0;
      d_next <= 32'd0;
      next_E <= 32'd0;
      done   <= 1'b0;
    end else begin
      state   <= next_state;
      iter    <= next_iter;
      d_next  <= next_d_next;
      next_E  <= next_d_next;
      done    <= 1'b0; // default; set high only in DONE
    end
  end

  // Registered trick capture
  always @(posedge clk) begin
    trick_t_r <= trick_t;
    trick_p_r <= trick_p;
    trick_d_r <= trick_d;
    m_r <= m;
    n_r <= n;
    r_r <= r;
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    next_iter  = iter;
    next_d_next = d_next;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
          next_iter  = 3'd0;
          next_d_next = 32'd0; // E = 0 at step 4 (no tricks after last)
        end
      end

      INIT: begin
        // Two cycles: capture done and set iter = m
        if (iter == 3'd0) begin
          next_iter  = 3'd1;
          next_state = INIT;
        end else if (iter == 3'd1) begin
          next_iter  = m_r;     // iter will go to m (e.g., 4)
          next_d_next = 32'd0;  // E = 0 (after processing all tricks)
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        if (iter == 3'd0) begin
          next_state = DONE;     // finalize after processing all
        end else begin
          // Two cycles per trick: update E and then decrement iter
          if (iter[0] == 1'b0) begin
            // Cycle 1 of trick: compute new E using current trick index = iter-1
            // e_i = p_i * max(0, E - t_i) + (1 - p_i) * (E + d_i)
            // Simplifies to: E + d_i - p_i * (t_i + E + d_i)
            // We ensure non-negative by clamping if needed.
            reg [31:0] p;
            reg [15:0] t, d;
            reg [31:0] E_plus_d;
            reg [31:0] t_plus_E_plus_d;
            reg [31:0] p_times_sum;
            reg [31:0] E_new_raw;
            reg [31:0] E_new;
            p = trick_p_r[iter - 1];
            t = trick_t_r[iter - 1];
            d = trick_d_r[iter - 1];
            E_plus_d = d_next + {d, 16'd0};           // E + d
            t_plus_E_plus_d = {t, 16'd0} + E_plus_d;  // t + E + d
            p_times_sum = $unsigned(p) * $unsigned(t_plus_E_plus_d);
            E_new_raw = E_plus_d - p_times_sum;       // E + d - p * (t + E + d)
            if (E_new_raw[31] == 1'b1) E_new = 32'd0;
            else E_new = E_new_raw;
            next_d_next = E_new; // hold for cycle 2
            next_iter   = iter;  // stay for second cycle
            next_state  = PROCESS;
          end else begin
            // Cycle 2 of trick: decrement iter to move to previous trick
            next_d_next = d_next;  // unchanged
            next_iter   = iter - 1;
            next_state  = PROCESS;
          end
        end
      end

      DONE: begin
        next_state = IDLE;
        next_iter  = 3'd0;
        next_d_next = 32'd0;
      end

      default: begin
        next_state = IDLE;
        next_iter  = 3'd0;
        next_d_next = 32'd0;
      end
    endcase
  end

  // Result and done assignment (clocked)
  always @(posedge clk) begin
    if (state == DONE) begin
      // Add best-case time 'n' (in Q16.16)
      result <= {n_r, 16'd0} + d_next;
      done   <= 1'b1;
    end else begin
      result <= 32'd0; // don't-care when not done; set to 0 for clean simulation
      done   <= 1'b0;
    end
  end

endmodule
