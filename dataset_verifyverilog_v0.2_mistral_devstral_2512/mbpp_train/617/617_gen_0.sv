module min_jumps (
  input [15:0] step_a,
  input [15:0] step_b,
  input [31:0] target_d,
  output [31:0] jumps
);

  wire [15:0] min_step = (step_a < step_b) ? step_a : step_b;
  wire [15:0] max_step = (step_a > step_b) ? step_a : step_b;
  wire [31:0] ceil_div;
  wire [31:0] result;

  assign ceil_div = (target_d + max_step - 1) / max_step;

  assign result = (target_d >= max_step) ? ceil_div :
                  (target_d == 0) ? 0 :
                  (target_d == min_step) ? 1 : 2;

  assign jumps = result << 16;

endmodule