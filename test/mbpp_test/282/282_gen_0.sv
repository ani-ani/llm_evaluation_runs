module elementwise_sub(
  input  signed [3:0][7:0] a,
  input  signed [3:0][7:0] b,
  input        [1:0]       valid_entries,
  output logic signed [3:0][7:0] diff
);

  logic [2:0] active_count;

  // Determine number of active elements: 0 means all 4
  always_comb begin
    if (valid_entries == 2'b00)
      active_count = 3'd4;
    else
      active_count = {1'b0, valid_entries};
  end

  // Combinational element-wise subtraction with masking beyond active_count
  always_comb begin
    diff = '0;
    if (active_count > 0) begin
      if (active_count > 0) diff[0] = a[0] - b[0];
      if (active_count > 1) diff[1] = a[1] - b[1];
      if (active_count > 2) diff[2] = a[2] - b[2];
      if (active_count > 3) diff[3] = a[3] - b[3];
    end
  end

endmodule