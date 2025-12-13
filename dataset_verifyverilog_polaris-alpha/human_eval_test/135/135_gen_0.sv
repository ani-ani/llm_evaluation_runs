module can_arrange(
  input  logic [7:0] arr [0:15],
  input  logic [3:0] size,
  output logic [4:0] result
);

  integer i;
  logic found;
  logic [4:0] best_idx;

  always_comb begin
    // Default result for size < 2 is -1 (5'b11111)
    result   = 5'b11111;
    found    = 1'b0;
    best_idx = 5'b11111;

    if (size >= 2) begin
      // Scan from highest relevant index down to 1 to find largest i with arr[i] < arr[i-1]
      for (i = 15; i >= 1; i = i - 1) begin
        if (!found && (i < size) && (arr[i] < arr[i-1])) begin
          best_idx = i[4:0];
          found    = 1'b1;
        end
      end
      if (found)
        result = best_idx;
      else
        result = 5'b11111;
    end
  end

endmodule