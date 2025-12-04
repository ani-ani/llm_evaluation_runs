module sort_third (
  input [95:0] arr_in,
  output [95:0] arr_out
);

  // 12 elements of 8-bit signed integer (two's complement)
  // Index mapping: MSB [95:88] -> index 0, ... , [7:0] -> index 11
  wire signed [7:0] e0  = arr_in[95:88];
  wire signed [7:0] e1  = arr_in[87:80];
  wire signed [7:0] e2  = arr_in[79:72];
  wire signed [7:0] e3  = arr_in[71:64];
  wire signed [7:0] e4  = arr_in[63:56];
  wire signed [7:0] e5  = arr_in[55:48];
  wire signed [7:0] e6  = arr_in[47:40];
  wire signed [7:0] e7  = arr_in[39:32];
  wire signed [7:0] e8  = arr_in[31:24];
  wire signed [7:0] e9  = arr_in[23:16];
  wire signed [7:0] e10 = arr_in[15: 8];
  wire signed [7:0] e11 = arr_in[ 7: 0];

  // Sorting network (depth 3) for 4 signed elements at indices {0,3,6,9}
  // Stage 0
  wire signed [7:0] s0_a0 = (e0 > e3) ? e3 : e0;
  wire signed [7:0] s0_a1 = (e0 > e3) ? e0 : e3;
  wire signed [7:0] s0_b0 = (e6 > e9) ? e9 : e6;
  wire signed [7:0] s0_b1 = (e6 > e9) ? e6 : e9;

  // Stage 1
  wire signed [7:0] s1_a0 = (s0_a0 > e6) ? e6 : s0_a0; // min(e0,e3,e6)
  wire signed [7:0] s1_a1 = (s0_a0 > s0_b0) ? s0_b0 : s0_a0; // med1
  wire signed [7:0] s1_a2 = (s0_a1 > s0_b1) ? s0_b1 : s0_a1; // med2
  wire signed [7:0] s1_a3 = (s0_a1 > e9) ? e9 : s0_a1; // max(e0,e3,e6,e9)

  // Stage 2
  wire signed [7:0] out0 = (s1_a0 > s1_a1) ? s1_a1 : s1_a0; // sorted[0]
  wire signed [7:0] out3 = (s1_a1 > s1_a2) ? s1_a2 : s1_a1; // sorted[1]
  wire signed [7:0] out6 = (s1_a2 > s1_a3) ? s1_a3 : s1_a2; // sorted[2]
  wire signed [7:0] out9 = (s1_a2 > s1_a3) ? s1_a2 : s1_a3; // sorted[3]

  // Reconstruct arr_out: place sorted values at positions 0/3/6/9, keep others
  assign arr_out = {
    out0,        // [95:88] index 0
    e1,          // [87:80] index 1
    e2,          // [79:72] index 2
    out3,        // [71:64] index 3
    e4,          // [63:56] index 4
    e5,          // [55:48] index 5
    out6,        // [47:40] index 6
    e7,          // [39:32] index 7
    e8,          // [31:24] index 8
    out9,        // [23:16] index 9
    e10,         // [15: 8] index 10
    e11          // [ 7: 0] index 11
  };

endmodule
