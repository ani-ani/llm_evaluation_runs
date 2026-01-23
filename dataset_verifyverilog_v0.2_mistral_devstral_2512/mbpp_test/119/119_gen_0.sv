module find_unique (
  input [7:0] arr [0:7],
  output reg [7:0] unique_val
);
  always @* begin
    unique_val = 8'b0;
    for (int i = 0; i < 8; i = i + 1) begin
      unique_val = unique_val ^ arr[i];
    end
  end
endmodule