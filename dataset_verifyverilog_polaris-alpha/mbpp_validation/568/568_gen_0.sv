module empty_list(
  input  [2:0] length,
  output reg [7:0] arr [0:7]
);

  integer i;
  always @* begin
    // Set first (length + 1) elements to 0 (empty)
    for (i = 0; i <= length; i = i + 1) begin
      arr[i] = 8'b00000000;
    end

    // Set remaining elements to 1 (invalid)
    for (i = length + 1; i < 8; i = i + 1) begin
      arr[i] = 8'b11111111;
    end
  end

endmodule