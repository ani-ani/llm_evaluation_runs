module filter_odds(
  input  [7:0] data [0:7],
  output [7:0] result [0:7],
  output [7:0] valid_mask
);

  integer i;
  integer idx;

  // Combinational logic: pack odd numbers contiguously at start of result
  always @* begin
    idx = 0;

    // Initialize outputs to zero
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 8'b0;
    end

    // Collect odds in order
    for (i = 0; i < 8; i = i + 1) begin
      if (data[i][0] == 1'b1) begin
        result[idx] = data[i];
        idx = idx + 1;
      end
    end
  end

  // Generate valid_mask based on how many odds were found
  assign valid_mask = (idx > 0) ? ((8'hFF >> (8 - idx))) : 8'h00;

endmodule