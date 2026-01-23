module max_run_uppercase (
  input [7:0] char0,
  input [7:0] char1,
  input [7:0] char2,
  input [7:0] char3,
  input [7:0] char4,
  input [7:0] char5,
  input [7:0] char6,
  input [7:0] char7,
  output [3:0] max_run
);

  wire [7:0] is_upper;
  wire [3:0] run0, run1, run2, run3, run4, run5, run6, run7;

  // Determine if each character is uppercase
  assign is_upper[0] = (char0 >= 8'd65 && char0 <= 8'd90);
  assign is_upper[1] = (char1 >= 8'd65 && char1 <= 8'd90);
  assign is_upper[2] = (char2 >= 8'd65 && char2 <= 8'd90);
  assign is_upper[3] = (char3 >= 8'd65 && char3 <= 8'd90);
  assign is_upper[4] = (char4 >= 8'd65 && char4 <= 8'd90);
  assign is_upper[5] = (char5 >= 8'd65 && char5 <= 8'd90);
  assign is_upper[6] = (char6 >= 8'd65 && char6 <= 8'd90);
  assign is_upper[7] = (char7 >= 8'd65 && char7 <= 8'd90);

  // Calculate run lengths for each starting position
  assign run0 = is_upper[0] ? (is_upper[1] ? (is_upper[2] ? (is_upper[3] ? (is_upper[4] ? (is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd8 : 8'd7) : 8'd6) : 8'd5) : 8'd4) : 8'd3) : 8'd2) : 8'd1) : 8'd0;
  assign run1 = is_upper[1] ? (is_upper[2] ? (is_upper[3] ? (is_upper[4] ? (is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd7 : 8'd6) : 8'd5) : 8'd4) : 8'd3) : 8'd2) : 8'd1) : 8'd0;
  assign run2 = is_upper[2] ? (is_upper[3] ? (is_upper[4] ? (is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd6 : 8'd5) : 8'd4) : 8'd3) : 8'd2) : 8'd1) : 8'd0;
  assign run3 = is_upper[3] ? (is_upper[4] ? (is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd5 : 8'd4) : 8'd3) : 8'd2) : 8'd1) : 8'd0;
  assign run4 = is_upper[4] ? (is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd4 : 8'd3) : 8'd2) : 8'd1) : 8'd0;
  assign run5 = is_upper[5] ? (is_upper[6] ? (is_upper[7] ? 8'd3 : 8'd2) : 8'd1) : 8'd0;
  assign run6 = is_upper[6] ? (is_upper[7] ? 8'd2 : 8'd1) : 8'd0;
  assign run7 = is_upper[7] ? 8'd1 : 8'd0;

  // Find the maximum run length
  assign max_run = (run0 > run1) ? (run0 > run2) ? (run0 > run3) ? (run0 > run4) ? (run0 > run5) ? (run0 > run6) ? (run0 > run7) ? run0 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run4 > run5) ? (run4 > run6) ? (run4 > run7) ? run4 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run3 > run4) ? (run3 > run5) ? (run3 > run6) ? (run3 > run7) ? run3 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run4 > run5) ? (run4 > run6) ? (run4 > run7) ? run4 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run2 > run3) ? (run2 > run4) ? (run2 > run5) ? (run2 > run6) ? (run2 > run7) ? run2 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run4 > run5) ? (run4 > run6) ? (run4 > run7) ? run4 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run3 > run4) ? (run3 > run5) ? (run3 > run6) ? (run3 > run7) ? run3 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run4 > run5) ? (run4 > run6) ? (run4 > run7) ? run4 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ? run6 : run7 : (run1 > run2) ? (run1 > run3) ? (run1 > run4) ? (run1 > run5) ? (run1 > run6) ? (run1 > run7) ? run1 : run7 : (run6 > run7) ? run6 : run7 : (run5 > run6) ? (run5 > run7) ? run5 : run7 : (run6 > run7) ?