module smallest_change (
  input [3:0] arr_len,
  input reg [7:0] arr [0:7],
  output reg [2:0] changes
);

  integer i;
  reg [2:0] cnt;

  always @* begin
    cnt = 3'b0;
    // Compare symmetric element pairs arr[i] vs arr[arr_len-1-i]
    for (i = 0; i < (arr_len >> 1); i = i + 1) begin
      if (arr[i] != arr[arr_len - 1 - i]) begin
        cnt = cnt + 1;
      end
    end
    changes = cnt;
  end

endmodule