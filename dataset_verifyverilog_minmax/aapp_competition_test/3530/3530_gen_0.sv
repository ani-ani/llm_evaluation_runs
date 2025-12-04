module fun_maximizer(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high for 1 cycle to start computation
  input [3:0] num_coasters, // number of coasters (1-4)
  input [6:0] a1, a2, a3, a4, // a_i parameters (7-bit, max 127)
  input [6:0] b1, b2, b3, b4, // b_i parameters (7-bit, max 127)
  input [3:0] t1, t2, t3, t4, // t_i parameters (4-bit, 1-15 min)
  input [3:0] T, // total available time (4-bit, 1-15 min)
  output reg [15:0] max_fun, // 16-bit unsigned result
  output reg done // goes high when result valid
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  // Internal signals
  reg [1:0] state, state_next;
  reg [3:0] c_index;    // current coaster index (0..3), valid when c_index < num_coasters
  reg [3:0] c_index_next;
  reg [3:0] time_cur;   // time budget being processed (0..T)
  reg [3:0] time_cur_next;

  // DP arrays (time 0..15)
  reg [15:0] dp_next [0:15];
  reg [15:0] dp      [0:15];

  // Coaster params arrays
  wire [6:0] a [0:3];
  wire [6:0] b [0:3];
  wire [3:0] t [0:3];
  assign a[0] = a1; assign a[1] = a2; assign a[2] = a3; assign a[3] = a4;
  assign b[0] = b1; assign b[1] = b2; assign b[2] = b3; assign b[3] = b4;
  assign t[0] = t1; assign t[1] = t2; assign t[2] = t3; assign t[3] = t4;

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      c_index <= 4'd0;
      time_cur <= 4'd0;
    end else begin
      state <= state_next;
      c_index <= c_index_next;
      time_cur <= time_cur_next;
      // Latch DP array after combinatorial compute
      for (int ti = 0; ti <= 15; ti++) begin
        dp[ti] <= dp_next[ti];
      end
    end
  end

  // Compute block (combinatorial)
  integer k;
  reg [15:0] best;
  reg [3:0] T_reg;
  reg [3:0] num_c;
  reg [3:0] ride_k;
  reg [7:0] delta_fun;  // per-ride fun contribution (unsigned)
  reg [15:0] cum_fun;   // cumulative fun for k rides (unsigned)
  reg [3:0] k_max;
  reg [3:0] time_cost;  // t * k

  // Option computation for current coaster and current k
  // cum_fun_i_k = sum_{j=1..k} (a_i - (j-1)^2 * b_i), unsigned, stop when non-positive
  always @(*) begin
    // Defaults to avoid latches
    state_next = state;
    c_index_next = c_index;
    time_cur_next = time_cur;
    done = 1'b0;
    max_fun = 16'd0;

    T_reg = (T > 4'd15) ? 4'd15 : T;
    num_c = (num_coasters > 4'd4) ? 4'd4 : num_coasters;

    // Initialize dp_next
    for (int ti = 0; ti <= 15; ti++) begin
      if (ti == 0) dp_next[ti] = 16'd0;
      else if (ti <= T_reg) dp_next[ti] = dp[ti];
      else dp_next[ti] = 16'd0;
    end

    if (state == IDLE) begin
      // Idle: hold dp at 0, wait for start
      for (int ti = 0; ti <= 15; ti++) dp_next[ti] = (ti == 0) ? 16'd0 : 16'd0;
      c_index_next = 4'd0;
      time_cur_next = 4'd0;
      done = 1'b0;
      max_fun = 16'd0;
      if (start) begin
        state_next = CALC;
        c_index_next = 4'd0;
        time_cur_next = 4'd0;
      end else begin
        state_next = IDLE;
      end
    end
    else if (state == CALC) begin
      // Process next time slot with current coaster
      best = dp[time_cur];
      // Compute cumulative fun for k rides for the current coaster, and try all k
      // Only if this coaster is active (c_index < num_coasters)
      if (c_index < num_c) begin
        // Determine k_max = floor(T_reg / t_i)
        if (t[c_index] == 4'd0) begin
          k_max = 4'd0;
        end else begin
          k_max = T_reg / t[c_index];
        end
        cum_fun = 16'd0;
        for (k = 1; k <= 15; k++) begin: sum_loop
          if (k <= k_max) begin
            ride_k = k[3:0];
            // delta_fun = a - (k-1)^2 * b (unsigned)
            delta_fun = a[c_index] - (((k - 1) * (k - 1)) * b[c_index]);
            if (delta_fun[7] == 1'b0 && delta_fun != 8'd0) begin
              cum_fun = cum_fun + {8'd0, delta_fun};
              time_cost = t[c_index] * ride_k;
              if (time_cur >= time_cost) begin
                // Use previous DP values to avoid in-cycle re-use of updated values
                best = (dp[time_cur - time_cost] + cum_fun > best) ? (dp[time_cur - time_cost] + cum_fun) : best;
              end
            end else begin
              // Non-positive fun for this k: stop considering larger k for this coaster
            end
          end
        end
      end
      dp_next[time_cur] = best;

      // Advance time_cur or move to next coaster
      if (time_cur < T_reg) begin
        time_cur_next = time_cur + 1;
        c_index_next = c_index;
        state_next = CALC;
      end else begin
        // Finished this coaster; move to next one or finish
        if ((c_index + 1) < num_c) begin
          c_index_next = c_index + 1;
          time_cur_next = 4'd0;
          state_next = CALC;
        end else begin
          state_next = DONE;
          done = 1'b1;
          max_fun = dp[T_reg];
        end
      end
    end
    else if (state == DONE) begin
      // Hold result until next start
      done = 1'b1;
      max_fun = dp[T_reg];
      if (start) begin
        // Restart: re-initialize dp
        for (int ti = 0; ti <= 15; ti++) begin
          dp_next[ti] = (ti == 0) ? 16'd0 : 16'd0;
        end
        state_next = CALC;
        c_index_next = 4'd0;
        time_cur_next = 4'd0;
        max_fun = 16'd0;
        done = 1'b0;
      end else begin
        state_next = DONE;
      end
    end
  end
endmodule