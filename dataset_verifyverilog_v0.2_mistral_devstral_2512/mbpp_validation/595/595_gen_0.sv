module min_swaps (
  input [15:0] str1,
  input [15:0] str2,
  input [3:0] length,
  output reg [3:0] swaps,
  output reg possible
);

  wire [15:0] xor_result = str1 ^ str2;
  wire [3:0] mismatch_count = count_mismatches(xor_result, length);

  always @* begin
    if (mismatch_count % 2 == 0) begin
      swaps = mismatch_count >> 1;
      possible = 1'b1;
    end else begin
      swaps = 4'b0;
      possible = 1'b0;
    end
  end

  function [3:0] count_mismatches;
    input [15:0] xor_bits;
    input [3:0] len;
    integer i;
    begin
      count_mismatches = 0;
      for (i = 0; i < len; i = i + 1) begin
        if (xor_bits[i]) begin
          count_mismatches = count_mismatches + 1;
        end
      end
    end
  endfunction

endmodule