module duplicate_checker(input [7:0] array [0:7], output logic has_duplicate);
  wire [27:0] comp;
  genvar i, j;
  generate
    for (i = 0; i <= 6; i = i + 1) begin : gen_i
      for (j = i + 1; j <= 7; j = j + 1) begin : gen_j
        localparam int k = (i * (15 - i)) / 2 + (j - i - 1);
        assign comp[k] = (array[i] == array[j]);
      end
    end
  endgenerate
  assign has_duplicate = |comp;
endmodule