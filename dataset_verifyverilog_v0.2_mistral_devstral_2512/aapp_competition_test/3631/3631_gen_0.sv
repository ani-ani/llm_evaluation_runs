module beacon_connectivity (
  input clk,
  input rst_n,
  input start,
  input [13:0] beacon_x [7:0],
  input [13:0] beacon_y [7:0],
  input [13:0] mountain_x [7:0],
  input [13:0] mountain_y [7:0],
  input [13:0] mountain_r [7:0],
  input [3:0] num_beacons,
  input [3:0] num_mountains,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT_DSU,
    OUTER_LOOP,
    INNER_LOOP,
    MOUNTAIN_LOOP,
    CHECK_VISIBILITY,
    UNION,
    COUNT_ROOTS,
    DONE
  } state_t;

  state_t state, next_state;

  // DSU registers
  reg [2:0] parent [7:0];

  // Loop counters
  reg [2:0] i, j, k;
  reg [2:0] root_count;
  reg [7:0] root_mask;

  // Visibility check signals
  reg [31:0] ABx, ABy;
  reg [31:0] APx, APy;
  reg [31:0] L2;
  reg [31:0] numerator;
  reg [31:0] t_q16;
  reg [31:0] Cx, Cy;
  reg [31:0] PCx, PCy;
  reg [31:0] dist_sq;
  reg [31:0] radius_sq;
  reg visible;

  // Divider signals
  reg [31:0] dividend, divisor;
  reg [31:0] quotient;
  reg [4:0] div_cycle;
  reg div_start, div_done;

  // Multiplier signals
  reg [31:0] mul_a, mul_b;
  reg [63:0] mul_result;
  reg [4:0] mul_cycle;
  reg mul_start, mul_done;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_DSU;
      end
      INIT_DSU: begin
        next_state = OUTER_LOOP;
      end
      OUTER_LOOP: begin
        if (i == num_beacons - 1) next_state = COUNT_ROOTS;
        else next_state = INNER_LOOP;
      end
      INNER_LOOP: begin
        if (j == num_beacons - 1) next_state = OUTER_LOOP;
        else next_state = MOUNTAIN_LOOP;
      end
      MOUNTAIN_LOOP: begin
        if (k == num_mountains - 1) next_state = CHECK_VISIBILITY;
        else next_state = MOUNTAIN_LOOP;
      end
      CHECK_VISIBILITY: begin
        if (visible) next_state = UNION;
        else next_state = INNER_LOOP;
      end
      UNION: begin
        next_state = INNER_LOOP;
      end
      COUNT_ROOTS: begin
        if (root_count == 7) next_state = DONE;
        else next_state = COUNT_ROOTS;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // DSU initialization
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int idx = 0; idx < 8; idx++) parent[idx] <= idx;
    end else if (state == INIT_DSU) begin
      for (int idx = 0; idx < 8; idx++) parent[idx] <= idx;
    end
  end

  // Loop counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
      k <= 0;
      root_count <= 0;
      root_mask <= 0;
    end else begin
      case (state)
        INIT_DSU: begin
          i <= 0;
          j <= 0;
          k <= 0;
          root_count <= 0;
          root_mask <= 0;
        end
        OUTER_LOOP: begin
          if (i == num_beacons - 1) i <= 0;
          else i <= i + 1;
        end
        INNER_LOOP: begin
          if (j == num_beacons - 1) j <= i + 1;
          else j <= j + 1;
        end
        MOUNTAIN_LOOP: begin
          if (k == num_mountains - 1) k <= 0;
          else k <= k + 1;
        end
        COUNT_ROOTS: begin
          if (root_count == 7) root_count <= 0;
          else root_count <= root_count + 1;
        end
      endcase
    end
  end

  // Visibility check setup
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ABx <= 0;
      ABy <= 0;
      APx <= 0;
      APy <= 0;
      L2 <= 0;
      numerator <= 0;
      t_q16 <= 0;
      Cx <= 0;
      Cy <= 0;
      PCx <= 0;
      PCy <= 0;
      dist_sq <= 0;
      radius_sq <= 0;
      visible <= 1;
    end else if (state == MOUNTAIN_LOOP) begin
      // Calculate AB vector
      ABx <= {16'd0, beacon_x[j]} - {16'd0, beacon_x[i]};
      ABy <= {16'd0, beacon_y[j]} - {16'd0, beacon_y[i]};
      
      // Calculate AP vector
      APx <= {16'd0, mountain_x[k]} - {16'd0, beacon_x[i]};
      APy <= {16'd0, mountain_y[k]} - {16'd0, beacon_y[i]};
      
      // Calculate L2 (ABx^2 + ABy^2)
      mul_a <= ABx;
      mul_b <= ABx;
      mul_start <= 1;
    end
  end

  // Multiplier
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_result <= 0;
      mul_cycle <= 0;
      mul_done <= 0;
    end else if (mul_start) begin
      mul_result <= 0;
      mul_cycle <= 0;
      mul_done <= 0;
    end else if (mul_cycle < 32) begin
      if (mul_a[0]) mul_result <= mul_result + (mul_b << mul_cycle);
      mul_cycle <= mul_cycle + 1;
      if (mul_cycle == 31) mul_done <= 1;
    end
  end

  // L2 calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      L2 <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      L2 <= mul_result[47:16]; // Q16.16
      mul_a <= ABy;
      mul_b <= ABy;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      L2 <= L2 + mul_result[47:16];
      mul_a <= APx;
      mul_b <= ABx;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      numerator <= mul_result[47:16];
      mul_a <= APy;
      mul_b <= ABy;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      numerator <= numerator + mul_result[47:16];
      dividend <= numerator;
      divisor <= L2;
      div_start <= 1;
      mul_done <= 0;
    end
  end

  // Divider
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      quotient <= 0;
      div_cycle <= 0;
      div_done <= 0;
    end else if (div_start) begin
      quotient <= 0;
      div_cycle <= 0;
      div_done <= 0;
    end else if (div_cycle < 32) begin
      quotient <= quotient << 1;
      if (dividend[31]) begin
        quotient[0] <= 1;
        dividend <= dividend - (divisor << (31 - div_cycle));
      end
      div_cycle <= div_cycle + 1;
      if (div_cycle == 31) div_done <= 1;
    end
  end

  // t calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      t_q16 <= 0;
    end else if (div_done && state == MOUNTAIN_LOOP) begin
      t_q16 <= quotient;
      if (t_q16 < 0) t_q16 <= 0;
      else if (t_q16 > 32'h10000) t_q16 <= 32'h10000;
      div_done <= 0;
      
      // Calculate Cx and Cy
      mul_a <= t_q16;
      mul_b <= ABx;
      mul_start <= 1;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      Cx <= {16'd0, beacon_x[i]} + (mul_result[47:16] >> 16);
      mul_a <= t_q16;
      mul_b <= ABy;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      Cy <= {16'd0, beacon_y[i]} + (mul_result[47:16] >> 16);
      mul_a <= {16'd0, mountain_x[k]} - Cx;
      mul_b <= {16'd0, mountain_x[k]} - Cx;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      PCx <= mul_result[47:16];
      mul_a <= {16'd0, mountain_y[k]} - Cy;
      mul_b <= {16'd0, mountain_y[k]} - Cy;
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      PCy <= mul_result[47:16];
      dist_sq <= PCx + PCy;
      mul_a <= mountain_r[k];
      mul_b <= mountain_r[k];
      mul_start <= 1;
      mul_done <= 0;
    end else if (mul_done && state == MOUNTAIN_LOOP) begin
      radius_sq <= mul_result[47:16];
      if (dist_sq <= radius_sq) visible <= 0;
      mul_done <= 0;
    end
  end

  // DSU find function
  function [2:0] find (input [2:0] x);
    if (parent[x] != x) begin
      parent[x] = find(parent[x]);
    end
    find = parent[x];
  endfunction

  // DSU union function
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Do nothing
    end else if (state == UNION) begin
      [2:0] root_i = find(i);
      [2:0] root_j = find(j);
      if (root_i != root_j) begin
        parent[root_j] <= root_i;
      end
    end
  end

  // Count roots
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      root_mask <= 0;
    end else if (state == COUNT_ROOTS) begin
      [2:0] root = find(root_count);
      root_mask <= root_mask | (1 << root);
    end else if (state == DONE) begin
      result <= $clog2(root_mask) - 1;
      done <= 1;
    end
  end

endmodule