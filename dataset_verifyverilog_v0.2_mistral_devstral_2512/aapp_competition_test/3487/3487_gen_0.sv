module flubber_optimizer (
  input clk,
  input rst_n,
  input start,
  input [31:0] v_fixed,
  input [31:0] a_fixed,
  input [5:0][31:0] c_edges,
  output reg done,
  output reg [31:0] f_best,
  output reg [31:0] w_best,
  output reg [31:0] val_best
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] idx;
  reg [31:0] f_current, w_current, val_current;
  reg [31:0] f_max, w_max, val_max;

  // Fixed-point constants
  localparam [31:0] ONE = 32'h00010000; // 1.0 in Q16.16
  localparam [31:0] SIXTEEN = 32'h00100000; // 16.0 in Q16.16

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      idx <= 4'b0;
      f_max <= 32'h0;
      w_max <= 32'h0;
      val_max <= 32'h0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SEARCH;
        else next_state = IDLE;
      end
      SEARCH: begin
        if (idx == 4'd15) next_state = DONE;
        else next_state = SEARCH;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Search logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx <= 4'b0;
      f_current <= 32'h0;
      w_current <= 32'h0;
      val_current <= 32'h0;
    end else if (current_state == SEARCH) begin
      // Calculate F_prop and W_prop
      f_current = idx * ONE; // Q16.16
      w_current = (16 - idx) * ONE; // Q16.16

      // Calculate bottleneck capacity (simplified: use min of edge capacities)
      reg [31:0] c_bottle = c_edges[0]; // Initialize with first edge
      if (c_edges[1] < c_bottle) c_bottle = c_edges[1];
      if (c_edges[2] < c_bottle) c_bottle = c_edges[2];

      // Capacity constraint: v*f + w <= c_bottle
      reg [31:0] vf = $signed(v_fixed) * $signed(f_current) >> 16; // Q16.16
      reg [31:0] total = vf + w_current; // Q16.16

      // Scale flows to fit within bottleneck
      if (total > c_bottle) begin
        reg [31:0] scale = $signed(c_bottle) / $signed(total); // Q16.16
        f_current = $signed(f_current) * $signed(scale) >> 16; // Q16.16
        w_current = $signed(w_current) * $signed(scale) >> 16; // Q16.16
      end

      // Calculate value: F^a * W^(1-a)
      // Simplified approximation using shifts and multiplies
      reg [31:0] a_val = a_fixed;
      reg [31:0] one_minus_a = ONE - a_val;

      // Approximate F^a and W^(1-a) using linear interpolation
      reg [31:0] f_pow = f_current * a_val >> 16; // Q16.16
      reg [31:0] w_pow = w_current * one_minus_a >> 16; // Q16.16

      val_current = f_pow * w_pow >> 16; // Q16.16

      // Update best values
      if (val_current > val_max) begin
        f_max <= f_current;
        w_max <= w_current;
        val_max <= val_current;
      end

      // Increment index
      if (idx == 4'd15) begin
        idx <= 4'b0;
      end else begin
        idx <= idx + 1;
      end
    end
  end

  // Output best values when done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      f_best <= 32'h0;
      w_best <= 32'h0;
      val_best <= 32'h0;
    end else if (current_state == DONE) begin
      done <= 1'b1;
      f_best <= f_max;
      w_best <= w_max;
      val_best <= val_max;
    end else begin
      done <= 1'b0;
    end
  end

endmodule