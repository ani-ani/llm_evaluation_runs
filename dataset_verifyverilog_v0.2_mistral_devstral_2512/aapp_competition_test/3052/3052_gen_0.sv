module conveyor_path_finder(
  input [31:0] ax_q16, ay_q16,
  input [31:0] bx_q16, by_q16,
  input [31:0] cx_q16, cy_q16,
  input [31:0] dx_q16, dy_q16,
  output [31:0] min_time_q16
);

  // Function to compute Euclidean distance in Q16.16 format
  function [31:0] euclidean_distance;
    input [31:0] x1, y1, x2, y2;
    reg [31:0] dx, dy, dx_sq, dy_sq, sum_sq;
    reg [31:0] result;
    reg [31:0] sqrt_val;
    reg [31:0] sqrt_next;
    reg [31:0] sqrt_prev;
    integer i;

    begin
      dx = x1 - x2;
      dy = y1 - y2;
      dx_sq = $signed(dx) * $signed(dx) >> 16; // Scale to avoid overflow
      dy_sq = $signed(dy) * $signed(dy) >> 16;
      sum_sq = dx_sq + dy_sq;

      // Initial guess for sqrt (using sum_sq as initial guess)
      sqrt_val = sum_sq;
      sqrt_prev = 32'h0;

      // Newton-Raphson iteration for sqrt (5 iterations for Q16.16 precision)
      for (i = 0; i < 5; i = i + 1) begin
        if (sqrt_val == 0) begin
          sqrt_next = 0;
        end else begin
          sqrt_next = (sqrt_val + (sum_sq << 16) / sqrt_val) >> 1;
        end
        sqrt_prev = sqrt_val;
        sqrt_val = sqrt_next;
      end

      result = sqrt_val;
      euclidean_distance = result;
    end
  endfunction

  // Compute direct path time (A to B)
  wire [31:0] direct_dist = euclidean_distance(ax_q16, ay_q16, bx_q16, by_q16);
  wire [31:0] direct_time = direct_dist; // time = distance / 1.0

  // Compute assisted path components
  wire [31:0] a_to_c_dist = euclidean_distance(ax_q16, ay_q16, cx_q16, cy_q16);
  wire [31:0] c_to_d_dist = euclidean_distance(cx_q16, cy_q16, dx_q16, dy_q16);
  wire [31:0] d_to_b_dist = euclidean_distance(dx_q16, dy_q16, bx_q16, by_q16);
  
  // Conveyor time is distance/2 (since speed is 2 m/s)
  wire [31:0] conveyor_time = c_to_d_dist >> 1;
  
  // Total assisted path time
  wire [31:0] assisted_time = a_to_c_dist + conveyor_time + d_to_b_dist;

  // Select minimum time
  assign min_time_q16 = (direct_time < assisted_time) ? direct_time : assisted_time;

endmodule