module swap_first_last(
  input  [2:0] array_size,
  input  [7:0] arr_in  [0:7],
  output [7:0] arr_out [0:7]
);

  integer i;

  always @* begin
    // Default: pass through
    for (i = 0; i < 8; i = i + 1) begin
      arr_out[i] = arr_in[i];
    end

    if (array_size >= 2) begin
      // Swap first and last active elements
      arr_out[0] = arr_in[array_size-1];
      arr_out[array_size-1] = arr_in[0];
      // Middle elements (0 < i < array_size-1) remain as defaulted
      // Elements i >= array_size remain unspecified (left as assigned above)
    end
    // For array_size < 2, arr_out already equals arr_in
  end

endmodule