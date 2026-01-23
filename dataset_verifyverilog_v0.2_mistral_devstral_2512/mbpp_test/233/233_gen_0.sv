module lateral_surface_cylinder (
  input [7:0] r,
  input [7:0] h,
  output [31:0] area
);

  // Constants
  localparam [31:0] PI = 32'h3243F;  // Q16.16 representation of π

  // Intermediate signals
  wire [15:0] r_times_h = r * h;
  wire [16:0] two_times_rh = r_times_h * 2;
  wire [31:0] two_rh_times_pi = two_times_rh * PI;

  // Final result (Q16.16 format)
  assign area = two_rh_times_pi >>> 16;

endmodule