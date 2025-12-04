module magical_subarray(
  input  [7:0][7:0] arr,
  input  [2:0]      L,
  input  [2:0]      R,
  output reg [2:0]  max_len
);

  // Internal variables
  integer i, j, k;
  reg [2:0] L0, R0;                // 0-based indices
  reg [2:0] len;
  reg [7:0] min_end, max_end;
  reg       is_magical;

  always @* begin
    // Convert 1-based to 0-based
    L0 = L - 3'd1;
    R0 = R - 3'd1;

    // Default max length to 0
    max_len = 3'd0;

    // Iterate over all possible i, j in [L0, R0]
    for (i = 0; i < 8; i = i + 1) begin
      if ((i >= L0) && (i <= R0)) begin
        for (j = i; j < 8; j = j + 1) begin
          if ((j >= L0) && (j <= R0)) begin
            // Compute sub-array length
            len = j[2:0] - i[2:0] + 3'd1;

            // Endpoints
            if (arr[i] <= arr[j]) begin
              min_end = arr[i];
              max_end = arr[j];
            end else begin
              min_end = arr[j];
              max_end = arr[i];
            end

            // Check magical condition for all k in [i, j]
            is_magical = 1'b1;
            for (k = 0; k < 8; k = k + 1) begin
              if (k >= i && k <= j) begin
                if (arr[k] < min_end || arr[k] > max_end)
                  is_magical = 1'b0;
              end
            end

            // Update max_len if magical and longer
            if (is_magical && (len > max_len)) begin
              max_len = len;
            end
          end
        end
      end
    end
  end

endmodule