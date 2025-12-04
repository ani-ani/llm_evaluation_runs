module sort_third (
  input [95:0] arr_in,
  output [95:0] arr_out
);

  logic signed [7:0] A, B, C, D;
  logic signed [7:0] s1_A, s1_B, s1_C, s1_D;
  logic signed [7:0] s2_A, s2_B, s2_C, s2_D;
  logic signed [7:0] s3_B, s3_C;

  assign A = arr_in[95:88];
  assign B = arr_in[71:64];
  assign C = arr_in[47:40];
  assign D = arr_in[23:16];

  assign s1_A = (A <= B) ? A : B;
  assign s1_B = (A <= B) ? B : A;
  assign s1_C = (C <= D) ? C : D;
  assign s1_D = (C <= D) ? D : C;

  assign s2_A = (s1_A <= s1_C) ? s1_A : s1_C;
  assign s2_C = (s1_A <= s1_C) ? s1_C : s1_A;
  assign s2_B = (s1_B <= s1_D) ? s1_B : s1_D;
  assign s2_D = (s1_B <= s1_D) ? s1_D : s1_B;

  assign s3_B = (s2_B <= s2_C) ? s2_B : s2_C;
  assign s3_C = (s2_B <= s2_C) ? s2_C : s2_B;

  assign arr_out = {s2_A, arr_in[87:80], arr_in[79:72],
                   s3_B, arr_in[63:56], arr_in[55:48],
                   s3_C, arr_in[39:32], arr_in[31:24],
                   s2_D, arr_in[15:8], arr_in[7:0]};

endmodule