module dict_sum (
  input [7:0] num_items,
  input [7:0][15:0] values,
  output [15:0] sum
);

  wire [15:0] sum_array [0:7];
  assign sum_array[0] = values[0];

  genvar i;
  generate
    for (i = 1; i < 8; i = i + 1) begin : sum_gen
      assign sum_array[i] = sum_array[i-1] + values[i];
    end
  endgenerate

  always_comb begin
    case (num_items)
      1: sum = sum_array[0];
      2: sum = sum_array[1];
      3: sum = sum_array[2];
      4: sum = sum_array[3];
      5: sum = sum_array[4];
      6: sum = sum_array[5];
      7: sum = sum_array[6];
      8: sum = sum_array[7];
      default: sum = 0;
    endcase
  end

endmodule