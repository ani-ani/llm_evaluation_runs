module unequal_pair_counter (
  input [7:0] arr [0:7],
  output [5:0] count
);

  wire [27:0] unequal_bits;

  // Generate all 28 comparisons (i < j)
  genvar i, j;
  generate
    for (i = 0; i < 7; i = i + 1) begin : gen_i
      for (j = i + 1; j < 8; j = j + 1) begin : gen_j
        assign unequal_bits[{i*7 + j - i - 1}] = (arr[i] != arr[j]);
      end
    end
  endgenerate

  // Sum all 28 bits using a tree of adders
  wire [3:0] sum1 [0:6];
  wire [4:0] sum2 [0:2];
  wire [5:0] sum3 [0:1];
  wire [5:0] sum4;

  // First level: 7 groups of 4 bits
  assign sum1[0] = unequal_bits[3:0];
  assign sum1[1] = unequal_bits[7:4];
  assign sum1[2] = unequal_bits[11:8];
  assign sum1[3] = unequal_bits[15:12];
  assign sum1[4] = unequal_bits[19:16];
  assign sum1[5] = unequal_bits[23:20];
  assign sum1[6] = unequal_bits[27:24];

  // Second level: 3 groups of 7 bits (but we have 7 sums of 4 bits)
  assign sum2[0] = sum1[0] + sum1[1] + sum1[2] + sum1[3];
  assign sum2[1] = sum1[4] + sum1[5] + sum1[6];

  // Third level: 2 groups
  assign sum3[0] = sum2[0] + sum2[1];

  // Final sum
  assign count = sum3[0];

endmodule