module check_same_type (
  input [7:0] data_array [0:7],
  output reg result
);

  integer i;
  always @* begin
    result = 1'b1;
    for (i = 1; i < 8; i = i + 1) begin
      if (data_array[i] !== data_array[0]) begin
        result = 1'b0;
      end
    end
  end

endmodule