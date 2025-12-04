module longest_interesting_subsequence(
  input [15:0] S,
  input [15:0] A [0:7],
  output reg [3:0] result [0:7]
);

  wire [15:0] sum1 [0:7];
  wire [15:0] sum2 [0:6];
  wire [15:0] sum3 [0:5];
  wire [15:0] sum4 [0:4];

  assign sum1[0] = A[0];
  assign sum1[1] = A[1];
  assign sum1[2] = A[2];
  assign sum1[3] = A[3];
  assign sum1[4] = A[4];
  assign sum1[5] = A[5];
  assign sum1[6] = A[6];
  assign sum1[7] = A[7];

  assign sum2[0] = A[0] + A[1];
  assign sum2[1] = A[1] + A[2];
  assign sum2[2] = A[2] + A[3];
  assign sum2[3] = A[3] + A[4];
  assign sum2[4] = A[4] + A[5];
  assign sum2[5] = A[5] + A[6];
  assign sum2[6] = A[6] + A[7];

  assign sum3[0] = A[0] + A[1] + A[2];
  assign sum3[1] = A[1] + A[2] + A[3];
  assign sum3[2] = A[2] + A[3] + A[4];
  assign sum3[3] = A[3] + A[4] + A[5];
  assign sum3[4] = A[4] + A[5] + A[6];
  assign sum3[5] = A[5] + A[6] + A[7];

  assign sum4[0] = A[0] + A[1] + A[2] + A[3];
  assign sum4[1] = A[1] + A[2] + A[3] + A[4];
  assign sum4[2] = A[2] + A[3] + A[4] + A[5];
  assign sum4[3] = A[3] + A[4] + A[5] + A[6];
  assign sum4[4] = A[4] + A[5] + A[6] + A[7];

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      result[i] = 4'b0;

      if (i <= 0 && (sum4[i] <= S && sum4[i+4] <= S))
        result[i] = 4'd8;
      else if ((result[i] == 0) && (i <= 2) && (sum3[i] <= S && sum3[i+3] <= S))
        result[i] = 4'd6;
      else if ((result[i] == 0) && (i <= 4) && (sum2[i] <= S && sum2[i+2] <= S))
        result[i] = 4'd4;
      else if ((result[i] == 0) && (i <= 6) && (sum1[i] <= S && sum1[i+1] <= S))
        result[i] = 4'd2;
    end
  end
endmodule