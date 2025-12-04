module array_min_max_sum (
  input [7:0][15:0] array_input,
  input [2:0] array_size,
  output reg signed [16:0] result
);

  always_comb begin
    if (array_size == 3'b000) begin
      result = 17'sb0;
    end else begin
      logic signed [15:0] min_val;
      logic signed [15:0] max_val;
      min_val = $signed(array_input[0]);
      max_val = $signed(array_input[0]);
      
      for (int i = 1; i < $unsigned(array_size); i++) begin
        if ($signed(array_input[i]) < min_val) begin
          min_val = $signed(array_input[i]);
        end
        if ($signed(array_input[i]) > max_val) begin
          max_val = $signed(array_input[i]);
        end
      end
      
      result = min_val + max_val;
    end
  end

endmodule