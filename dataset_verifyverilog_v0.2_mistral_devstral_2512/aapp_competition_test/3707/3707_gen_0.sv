module oven_decision (
  input [15:0] n,
  input [15:0] t,
  input [15:0] k,
  input [15:0] d,
  output build_second
);

  wire [15:0] batches = (n + k - 1) / k;
  wire [15:0] single_time = batches * t;
  wire [15:0] threshold = d + t;

  assign build_second = (single_time > threshold) ? 1'b1 : 1'b0;

endmodule