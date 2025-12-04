module max_product_finder (
  input [7:0][7:0] arr_input,
  output signed [7:0] num1,
  output signed [7:0] num2
);

  logic signed [15:0] max_product;

  always_comb begin
    max_product = $signed(arr_input[0]) * $signed(arr_input[1]);
    num1 = arr_input[0];
    num2 = arr_input[1];

    for (int i = 0; i < 8; i++) begin
      for (int j = i + 1; j < 8; j++) begin
        logic signed [15:0] product = $signed(arr_input[i]) * $signed(arr_input[j]);
        if (product > max_product) begin
          max_product = product;
          num1 = arr_input[i];
          num2 = arr_input[j];
        end
      end
    end
  end

endmodule