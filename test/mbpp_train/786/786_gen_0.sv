module right_insertion #(
  parameter int N = 8
)(
  input       [3:0]         value,
  input       [N-1:0][3:0]  array,
  output reg  [3:0]         pos
);

  integer i;
  reg [3:0] best_pos;

  always @* begin
    best_pos = 4'd0;

    // Parallel search for rightmost position where value <= array[i]
    for (i = 0; i < N; i = i + 1) begin
      if (value <= array[i]) begin
        best_pos = i[3:0];
      end
    end

    // If no qualifying element found (all elements < value), output N
    // Otherwise, best_pos holds the rightmost index satisfying value <= array[i]
    if (best_pos == 4'd0 && !(value <= array[0])) begin
      pos = N[3:0];
    end else begin
      pos = best_pos;
    end
  end

endmodule