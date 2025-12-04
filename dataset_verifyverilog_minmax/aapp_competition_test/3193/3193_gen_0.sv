module linear_congruence_solver(
  input clk,
  input rst_n,
  input start,
  input [19:0] a,
  input [19:0] b,
  input [19:0] M,
  input [19:0] P,
  output reg [19:0] x,
  output reg done
);

  // Internal variables
  reg [19:0] r0, r1;   // remainders (r0 = a, r1 = M)
  reg [19:0] s0, s1;   // Bézout coefficients for r0
  reg [19:0] t0, t1;   // Bézout coefficients for r1
  reg [19:0] diff;     // (P - b) mod M
  reg [19:0] x_int;    // candidate solution
  reg valid;           // solution existence flag
  reg [4:0] clk_cnt;   // cycle counter (up to 31 to be safe)
  reg running;         // state flag (1 when computing)

  // FSM states
  reg [1:0] state, next_state;
  localparam S_IDLE = 2'b00;
  localparam S_INIT = 2'b01;
  localparam S_LOOP = 2'b10;
  localparam S_DONE = 2'b11;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      running <= 1'b0;
      done <= 1'b0;
      x <= 20'h0;
    end else begin
      state <= next_state;
      running <= (next_state == S_INIT) || (next_state == S_LOOP);
      done <= (next_state == S_DONE);
      if (next_state == S_DONE) begin
        x <= x_int;
      end
    end
  end

  // Next state logic and datapath updates
  always @(*) begin
    // Default datapath holds
    r0_next = r0;
    r1_next = r1;
    s0_next = s0;
    s1_next = s1;
    t0_next = t0;
    t1_next = t1;
    x_int_next = x_int;
    valid_next = valid;
    diff_next = diff;
    clk_cnt_next = clk_cnt;

    case (state)
      S_IDLE: begin
        clk_cnt_next = 5'd0;
        if (start) begin
          next_state = S_INIT;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_INIT: begin
        // Initialize for extended Euclidean on (a, M)
        r0_next = a;
        r1_next = (M == 20'd0) ? 20'd0 : M;
        s0_next = 20'd1;  // a*1
        s1_next = 20'd0;  // M*0
        t0_next = 20'd0;  // a*0
        t1_next = 20'd1;  // M*1
        // diff = (P - b) mod M
        diff_next = (M == 20'd0) ? 20'd0 : ((P >= b) ? (P - b) : (P - b + M));
        clk_cnt_next = clk_cnt + 1;
        next_state = S_LOOP;
      end

      S_LOOP: begin
        // Perform one iteration of the extended Euclidean algorithm
        // Quotient and remainder
        if (r1_next == 20'd0) begin
          // Already at GCD
          clk_cnt_next = clk_cnt + 1;
          next_state = S_DONE;
        end else begin
          // q = r0 / r1; r2 = r0 % r1
          // Standard updates maintaining Bézout identity
          r0_next = r1_next;
          r1_next = r0 - (r1_next * (r0 / r1_next));
          s0_next = s1_next;
          s1_next = s0 - (s1_next * (r0 / r1_next));
          t0_next = t1_next;
          t1_next = t0 - (t1_next * (r0 / r1_next));

          clk_cnt_next = clk_cnt + 1;

          if ((r1_next == 20'd0) || (clk_cnt >= 5'd19)) begin
            // Finalize on next state to respect 20-cycle latency
            next_state = S_DONE;
          end else begin
            next_state = S_LOOP;
          end
        end
      end

      S_DONE: begin
        // Compute final solution (one-cycle pulse)
        // g = r0 (GCD), s0 such that s0*a + t0*M = g
        // x = ((P-b)/g) * s0 (mod M/g) if g | (P-b), else no solution
        // diff already computed in INIT
        if (r0 == 20'd0) begin
          // Degenerate case: modulus is 0 or a == 0 and M == 0
          if (M == 20'd0) begin
            // Equation becomes a*x + b = P (over integers, no modulus)
            // Minimal non-negative x if a != 0 is (P-b)/a, but we have no division hardware.
            // Fallback: only exact match if (a == 0 and b == P) -> x=0; otherwise no solution.
            if ((a == 20'd0) && (b == P)) begin
              x_int_next = 20'd0;
              valid_next = 1'b1;
            end else begin
              x_int_next = 20'd0;
              valid_next = 1'b0;
            end
          end else begin
            // M != 0, but a == 0 and r0 == 0 means a and M are both 0 (shouldn't happen per constraints)
            // Handle: if b % M == P -> x = 0, else no solution
            if ((b % M) == P) begin
              x_int_next = 20'd0;
              valid_next = 1'b1;
            end else begin
              x_int_next = 20'd0;
              valid_next = 1'b0;
            end
          end
        end else begin
          // Normal case with non-zero GCD
          // Check divisibility: (P-b) % g == 0
          if (diff % r0 == 20'd0) begin
            // There is a solution; scale equation
            // g1 = r0 / r0 = 1; a1 = a / r0; M1 = M / r0
            // inv = s0 (mod M1), but s0 is defined for original (a, M)
            // We can use s0 directly with modulus M1, which is r1 when r1 > 0, or M when r1 == 0.
            // diff1 = (P - b) / g
            // x = (diff1 * s0) mod M1
            // Choose M1 as (r1 == 0) ? M : r1
            if (r1 == 20'd0) begin
              // M1 = M
              x_int_next = ((diff / r0) * s0) % M;
            end else begin
              // M1 = r1
              x_int_next = ((diff / r0) * s0) % r1;
            end
            valid_next = 1'b1;
          end else begin
            x_int_next = 20'd0;
            valid_next = 1'b0;
          end
        end
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Keep diff in scope for DONE state
  reg [19:0] diff_next;
  always @(posedge clk) begin
    diff <= diff_next;
  end

  // Update datapath registers on relevant transitions
  reg [19:0] r0_next, r1_next, s0_next, s1_next, t0_next, t1_next;
  reg [19:0] x_int_next;
  reg valid_next;
  reg [4:0] clk_cnt_next;
  always @(posedge clk) begin
    if (state == S_INIT) begin
      r0 <= r0_next;
      r1 <= r1_next;
      s0 <= s0_next;
      s1 <= s1_next;
      t0 <= t0_next;
      t1 <= t1_next;
      x_int <= x_int_next;
      valid <= valid_next;
      clk_cnt <= clk_cnt_next;
    end else if (state == S_LOOP) begin
      r0 <= r0_next;
      r1 <= r1_next;
      s0 <= s0_next;
      s1 <= s1_next;
      t0 <= t0_next;
      t1 <= t1_next;
      // x_int and valid are updated only in DONE
      clk_cnt <= clk_cnt_next;
    end else if (state == S_DONE) begin
      x_int <= x_int_next;
      valid <= valid_next;
      // Keep others stable
    end else begin
      // S_IDLE: keep registers stable (they are held by the state logic)
    end
  end

  // Override when no solution: drive x to 0 and keep done pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // x, done already reset in top always block
    end else if (state == S_DONE) begin
      if (!valid) begin
        x <= 20'd0;
      end
      // else x is assigned from x_int in top always block
    end
  end

endmodule
