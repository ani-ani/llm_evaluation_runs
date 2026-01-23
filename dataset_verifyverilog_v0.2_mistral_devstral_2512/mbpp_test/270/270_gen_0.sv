module sum_even_even_pos (
  input [7:0] arr [0:7],
  output reg [15:0] sum
);
  always @* begin
    sum = 16'b0;
    if (arr[0][0] == 0) sum += arr[0];
    if (arr[2][0] == 0) sum += arr[2];
    if (arr[4][0] == 0) sum += arr[4];
    if (arr[6][0] == 0) sum += arr[6];
  end
endmodule