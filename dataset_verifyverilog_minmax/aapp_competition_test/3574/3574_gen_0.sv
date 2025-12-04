module magical_subarray(
  input [7:0][7:0] arr,
  input [2:0] L,
  input [2:0] R,
  output reg [2:0] max_len
);
  integer i, j, k;
  reg [7:0] lo, hi;
  reg valid;
  always @* begin
    max_len = 3'd0;
    if (L <= R) begin
      for (i = L - 1; i <= R - 1; i = i + 1) begin
        for (j = i; j <= R - 1; j = j + 1) begin
          lo = (arr[i] < arr[j]) ? arr[i] : arr[j];
          hi = (arr[i] > arr[j]) ? arr[i] : arr[j];
          valid = 1'b1;
          for (k = i; k <= j; k = k + 1) begin
            if (arr[k] < lo || arr[k] > hi) begin
              valid = 1'b0;
            end
          end
          if (valid) begin
            if ((j - i + 1) > max_len) begin
              max_len = j - i + 1;
            end
          end
        end
      end
    end else begin
      max_len = 3'd0;
    end
  end
endmodule
