module triples_sum_zero(input [7:0][7:0] arr, output reg out);
  wire [55:0] triple_zeros;
  genvar i, j, k;
  generate
    for (i = 0; i <= 5; i = i + 1) begin : gen_i
      for (j = i + 1; j <= 6; j = j + 1) begin : gen_j
        for (k = j + 1; k <= 7; k = k + 1) begin : gen_k
          localparam integer first_sum = 
            (i == 0) ? 0 :
            (i == 1) ? 21 :
            (i == 2) ? 36 :
            (i == 3) ? 46 :
            (i == 4) ? 52 :
            55;
          localparam integer sum_second = (j - i - 1) * (14 - i - j) / 2;
          localparam integer offset_third = (k - j - 1);
          localparam integer idx = first_sum + sum_second + offset_third;
          wire signed [7:0] sum = $signed(arr[i]) + $signed(arr[j]) + $signed(arr[k]);
          assign triple_zeros[idx] = (sum == 8'sb0);
        end
      end
    end
  endgenerate

  always @* begin
    out = |triple_zeros;
  end
endmodule