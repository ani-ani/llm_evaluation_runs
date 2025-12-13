module triples_sum_zero(
  input  signed [7:0][7:0] arr,
  output reg               out
);

  integer i, j, k;
  reg found;
  reg signed [9:0] sum_ij;
  reg signed [10:0] sum_ijk;

  always @* begin
    found = 1'b0;

    for (i = 0; i < 8; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        // Partial sum of first two elements (8-bit + 8-bit -> 9 or 10 bits safe); using 10 bits
        sum_ij = arr[i] + arr[j];
        for (k = j + 1; k < 8; k = k + 1) begin
          // Final sum of three elements (needs up to 11 bits: -384..+381)
          sum_ijk = sum_ij + arr[k];
          if (sum_ijk == 0)
            found = 1'b1;
        end
      end
    end

    out = found;
  end

endmodule