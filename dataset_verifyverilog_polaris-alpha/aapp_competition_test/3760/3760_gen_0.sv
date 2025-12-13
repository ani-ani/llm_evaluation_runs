module max_rectangle_finder(
  input  [7:0] n,        // grid width (1-255)
  input  [7:0] m,        // grid height (1-255)
  input  [7:0] x,        // point x-coordinate (0-n)
  input  [7:0] y,        // point y-coordinate (0-m)
  input  [7:0] a,        // ratio numerator (1-255)
  input  [7:0] b,        // ratio denominator (1-255)
  output [7:0] x1,       // rect left
  output [7:0] y1,       // rect bottom
  output [7:0] x2,       // rect right
  output [7:0] y2        // rect top
);

  // Internal signals
  wire [15:0] n_div_a;
  wire [15:0] m_div_b;
  wire [15:0] scale;

  wire [15:0] rect_width;
  wire [15:0] rect_height;

  wire [15:0] cx;
  wire [15:0] cy;

  wire [15:0] half_width;
  wire [15:0] half_height;

  wire [15:0] x1_pre_clamp;
  wire [15:0] y1_pre_clamp;

  wire [15:0] x1_candidate;
  wire [15:0] y1_candidate;

  wire [15:0] x1_plus_w;
  wire [15:0] y1_plus_h;

  wire [15:0] x1_adj;
  wire [15:0] y1_adj;

  // Protect against division by zero for combinational logic robustness.
  // When a or b is zero (though spec says 1-255), force corresponding div to max.
  assign n_div_a = (a != 0) ? (n / a) : 16'hFFFF;
  assign m_div_b = (b != 0) ? (m / b) : 16'hFFFF;

  // scale = min(n/a, m/b)
  assign scale = (n_div_a < m_div_b) ? n_div_a : m_div_b;

  // rect_width = a * scale; rect_height = b * scale
  assign rect_width  = a * scale;
  assign rect_height = b * scale;

  // Ideal center at the point (x, y)
  assign cx = x;
  assign cy = y;

  // half sizes using integer division (floor)
  assign half_width  = rect_width  >> 1;
  assign half_height = rect_height >> 1;

  // Initial position: center rectangle around (cx, cy)
  assign x1_pre_clamp = (cx > half_width) ? (cx - half_width) : 16'd0;
  assign y1_pre_clamp = (cy > half_height) ? (cy - half_height) : 16'd0;

  // Clamp to be within grid on left/bottom side
  assign x1_candidate = x1_pre_clamp;
  assign y1_candidate = y1_pre_clamp;

  // Compute tentative top-right coordinates
  assign x1_plus_w = x1_candidate + rect_width;
  assign y1_plus_h = y1_candidate + rect_height;

  // Adjust x1 if rectangle exceeds right boundary
  assign x1_adj = (x1_plus_w > n) ? ( (n >= rect_width) ? (n - rect_width) : 16'd0 ) : x1_candidate;

  // Adjust y1 if rectangle exceeds top boundary
  assign y1_adj = (y1_plus_h > m) ? ( (m >= rect_height) ? (m - rect_height) : 16'd0 ) : y1_candidate;

  // Final outputs (clamped to 8 bits)
  assign x1 = x1_adj[7:0];
  assign y1 = y1_adj[7:0];
  assign x2 = (x1_adj + rect_width)[7:0];
  assign y2 = (y1_adj + rect_height)[7:0];

endmodule