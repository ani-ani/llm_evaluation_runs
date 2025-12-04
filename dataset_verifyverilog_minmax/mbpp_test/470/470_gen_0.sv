module pairwise_add (
  input [3:0] in_array [0:7],
  output reg [4:0] out_array [0:6]
);

  // Combinational pairwise addition: out_array[i] = in_array[i] + in_array[i+1]
  // For input size N (<=8), only the first N-1 outputs are meaningful.
  integer i;
  always_comb begin
    for (i = 0; i < 7; i = i + 1) begin
      out_array[i] = $unsigned(in_array[i]) + $unsigned(in_array[i + 1]);
    end
  end

endmodule
