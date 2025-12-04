module max_valid_int (
  input [7:0] data [0:7],
  input [7:0] valid_mask,
  output reg [7:0] max_val
);

  always_comb begin
    max_val = 8'b0;
    for (int i = 0; i < 8; i++) begin
      if (valid_mask[i] && (data[i] > max_val)) begin
        max_val = data[i];
      end
    end
  end

endmodule