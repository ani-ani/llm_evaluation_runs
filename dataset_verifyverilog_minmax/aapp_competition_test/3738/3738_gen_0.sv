module robot_position_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input signed [15:0] a, // target x coordinate (16-bit signed)
  input signed [15:0] b, // target y coordinate (16-bit signed)
  input [15:0][1:0] cmd_string, // 16 command characters (2 bits each: U=00,D=01,L=10,R=11)
  output reg result, // 1 if reachable, 0 otherwise
  output reg done // high when computation complete
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE             = 2'b00,
    COMPUTE_STEPS    = 2'b01,
    CHECK_CONDITIONS = 2'b10,
    DONE             = 2'b11
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg signed [16:0] x_steps [0:15]; // cumulative x positions after each step (extend 1 bit to avoid overflow on +/-1)
  reg signed [16:0] y_steps [0:15]; // cumulative y positions after each step
  reg signed [16:0] x_next, y_next; // next positions during compute
  reg [4:0] idx;                    // step index (0..15)
  reg [4:0] idx_next;
  reg signed [16:0] dx, dy;         // total displacement (dx, dy)
  reg signed [16:0] dx_next, dy_next;
  reg next_done;
  reg next_result;

  // Helper: safe equality for signed vectors with possibly different widths
  function automatic logic eq_s(input signed [16:0] s, input signed [15:0] t);
    eq_s = (s == t);
  endfunction

  // Helper: check existence of non-negative integer k such that:
  //   x_steps[i] + k*dx = a AND y_steps[i] + k*dy = b
  // with x_steps[i], y_steps[i], dx, dy as 17-bit signed, a,b as 16-bit signed
  function automatic logic k_valid(
    input signed [16:0] xs,
    input signed [16:0] ys,
    input signed [16:0] dx,
    input signed [16:0] dy,
    input signed [15:0] a,
    input signed [15:0] b
  );
    logic found;
    logic signed [33:0] num_x, num_y; // 17+16 = 33 bits; 34 for sign-extend if needed
    logic signed [33:0] k_x, k_y;
    logic k_is_int;
    logic k_ge0;
    begin
      found = 1'b0;
      if (dx == 0 && dy == 0) begin
        // Robot never moves: must already be at target after this step
        found = eq_s(xs, a) && eq_s(ys, b);
      end else if (dx == 0) begin
        // x is constant: must match target x at this step; y must be reachable by some k
        if (eq_s(xs, a)) begin
          num_y = { {17{b[15]}}, b } - { {17{ys[16]}}, ys };
          k_is_int = (dy != 0) && (num_y % dy == 0);
          k_y      = num_y / dy;
          k_ge0    = (k_y >= 0);
          found    = k_is_int && k_ge0;
        end else begin
          found = 1'b0;
        end
      end else if (dy == 0) begin
        // y is constant: must match target y at this step; x must be reachable by some k
        if (eq_s(ys, b)) begin
          num_x = { {17{a[15]}}, a } - { {17{xs[16]}}, xs };
          k_is_int = (dx != 0) && (num_x % dx == 0);
          k_x      = num_x / dx;
          k_ge0    = (k_x >= 0);
          found    = k_is_int && k_ge0;
        end else begin
          found = 1'b0;
        end
      end else begin
        // Both dx and dy are non-zero
        num_x = { {17{a[15]}}, a } - { {17{xs[16]}}, xs };
        num_y = { {17{b[15]}}, b } - { {17{ys[16]}}, ys };
        k_is_int = (num_x % dx == 0) && (num_y % dy == 0);
        k_x      = num_x / dx;
        k_y      = num_y / dy;
        found    = k_is_int && (k_x == k_y) && (k_x >= 0);
      end
      return found;
    end
  endfunction

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result        <= 1'b0;
      done          <= 1'b0;
      dx            <= 17'sd0;
      dy            <= 17'sd0;
      idx           <= 5'd0;
      x_next        <= 17'sd0;
      y_next        <= 17'sd0;
    end else begin
      current_state <= next_state;
      result        <= next_result;
      done          <= next_done;
      idx           <= idx_next;
      dx            <= dx_next;
      dy            <= dy_next;
      x_next        <= (current_state == COMPUTE_STEPS) ? x_next : 17'sd0; // hold in COMPUTE_STEPS
      y_next        <= (current_state == COMPUTE_STEPS) ? y_next : 17'sd0;
    end
  end

  // Compute next state and outputs
  always_comb begin
    // defaults
    next_state   = current_state;
    next_result  = result;
    next_done    = done;
    idx_next     = idx;
    dx_next      = dx;
    dy_next      = dy;

    case (current_state)
      IDLE: begin
        next_done = 1'b0;
        next_result = 1'b0;
        dx_next = 17'sd0;
        dy_next = 17'sd0;
        idx_next = 5'd0;
        x_next = 17'sd0;
        y_next = 17'sd0;
        if (start) begin
          next_state = COMPUTE_STEPS;
        end
      end

      COMPUTE_STEPS: begin
        // Single-cycle per step: compute cumulative positions and store
        if (idx < 16) begin
          // Update cumulative positions based on command
          case (cmd_string[idx][1:0])
            2'b00: begin // U
              x_next = x_next;
              y_next = y_next + 1;
            end
            2'b01: begin // D
              x_next = x_next;
              y_next = y_next - 1;
            end
            2'b10: begin // L
              x_next = x_next - 1;
              y_next = y_next;
            end
            2'b11: begin // R
              x_next = x_next + 1;
              y_next = y_next;
            end
            default: begin
              x_next = x_next;
              y_next = y_next;
            end
          endcase

          x_steps[idx] = x_next;
          y_steps[idx] = y_next;

          dx_next = x_next; // dx accumulates as current cumulative x after idx
          dy_next = y_next; // dy accumulates as current cumulative y after idx

          idx_next = idx + 1;
          next_state = COMPUTE_STEPS;
        end else begin
          // Finished computing all steps: total displacement is (dx, dy)
          dx_next = dx; // already final
          dy_next = dy; // already final
          idx_next = 5'd0;
          next_state = CHECK_CONDITIONS;
        end
      end

      CHECK_CONDITIONS: begin
        if (idx < 16) begin
          // Check current step's intermediate position
          if (k_valid(x_steps[idx], y_steps[idx], dx, dy, a, b)) begin
            next_result = 1'b1;
          end
          idx_next = idx + 1;
          next_state = CHECK_CONDITIONS;
        end else begin
          next_done = 1'b1;
          next_state = DONE;
        end
      end

      DONE: begin
        next_done = 1'b1;
        next_result = result; // hold
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
