module pair_sum_counter (
  input signed [7:0] element_0, element_1, element_2, element_3, element_4, element_5, element_6, element_7,
  input signed [7:0] target_sum,
  input [2:0] valid_elements,
  output logic [4:0] pair_count
);
  logic signed [7:0] elements [0:7];
  assign elements[0] = element_0;
  assign elements[1] = element_1;
  assign elements[2] = element_2;
  assign elements[3] = element_3;
  assign elements[4] = element_4;
  assign elements[5] = element_5;
  assign elements[6] = element_6;
  assign elements[7] = element_7;

  logic [27:0] pair_match;

  genvar i, j;
  generate
    for (i = 0; i <= 6; i = i + 1) begin : GEN_I
      for (j = i + 1; j <= 7; j = j + 1) begin : GEN_J
        localparam integer idx = (i * (15 - i)) / 2 + (j - i - 1);
        assign pair_match[idx] = (i < valid_elements) && (j < valid_elements) && (elements[i] + elements[j] == target_sum);
      end
    end
  endgenerate

  always_comb begin
    pair_count = '0;
    for (int k = 0; k < 28; k = k + 1) begin
      pair_count += pair_match[k];
    end
  end
endmodule