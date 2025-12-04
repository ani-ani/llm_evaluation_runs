module can_arrange (
  input logic [7:0] arr [0:15],
  input logic [3:0] size,
  output logic [4:0] result
);

  always_comb begin
    logic found;
    result = 5'b11111;
    found = 1'b0;
    for (int i = 15; i >= 1; i--) begin
      if (!found && (i < size) && (arr[i] < arr[i-1])) begin
        result = 5'(i);
        found = 1'b1;
      end
    end
  end

endmodule