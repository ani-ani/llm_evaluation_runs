module max_valid_int(
  input  [7:0] data [0:7],
  input  [7:0] valid_mask,
  output reg [7:0] max_val
);

  integer i;
  reg found_valid;

  always @* begin
    max_val     = 8'd0;
    found_valid = 1'b0;

    for (i = 0; i < 8; i = i + 1) begin
      if (valid_mask[i]) begin
        if (!found_valid || (data[i] > max_val)) begin
          max_val     = data[i];
          found_valid = 1'b1;
        end
      end
    end
  end

endmodule