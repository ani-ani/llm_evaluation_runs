module smallest_change(
  input      [3:0]  arr_len,
  input      [7:0]  arr [0:7],
  output reg [2:0]  changes
);

  integer i;
  reg [3:0] half_len;

  always @* begin
    half_len = arr_len >> 1;
    changes = 3'd0;
    for (i = 0; i < half_len; i = i + 1) begin
      if (arr[i] != arr[arr_len - 1 - i]) begin
        changes = changes + 3'd1;
      end
    end
  end

endmodule