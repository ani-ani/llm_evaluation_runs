module magical_subarray(
  input [7:0][7:0] arr,
  input [2:0] L,
  input [2:0] R,
  output reg [2:0] max_len
);
  always_comb begin
    reg [3:0] max_val = 4'b0;
    max_val = 0;
    for (int i=0; i<8; i=i+1) begin
      for (int j=i; j<8; j=j+1) begin
        if ((i >= (L - 3'd1)) && (j <= (R - 3'd1))) begin
          reg [7:0] min_ij = arr[i] < arr[j] ? arr[i] : arr[j];
          reg [7:0] max_ij = arr[i] > arr[j] ? arr[i] : arr[j];
          reg valid = 1'b1;
          for (int k=i; k<=j; k=k+1) begin
            valid = valid && (arr[k] >= min_ij) && (arr[k] <= max_ij);
          end
          if (valid) begin
            reg [3:0] len = j - i + 1;
            if (len > max_val) begin
              max_val = len;
            end
          end
        end
      end
    end
    max_len = max_val[2:0];
  end
endmodule