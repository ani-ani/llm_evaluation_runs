module majority_checker (
  input [7:0] arr [0:7],
  input [3:0] n,
  input [7:0] x,
  output reg is_majority
);

  reg [3:0] low1, low2, low3;
  reg [3:0] high1, high2, high3;
  reg [3:0] mid1, mid2, mid3;
  reg [3:0] first_occ;
  reg [3:0] check_index;

  always_comb begin
    low1 = 4'd0;
    high1 = (n > 4'd0) ? (n - 4'd1) : 4'd0;
    first_occ = 4'd8;

    // Step 1
    mid1 = (low1 + high1) >> 1;
    low2 = low1;
    high2 = high1;
    if (high1 >= low1) begin
      if (mid1 < n) begin
        if (arr[mid1] == x) begin
          first_occ = mid1;
          high2 = mid1 - 4'd1;
        end else if (arr[mid1] < x) begin
          low2 = mid1 + 4'd1;
        end else begin
          high2 = mid1 - 4'd1;
        end
      end else begin
        high2 = mid1 - 4'd1;
      end
    end

    // Step 2
    mid2 = (low2 + high2) >> 1;
    low3 = low2;
    high3 = high2;
    if (high2 >= low2) begin
      if (mid2 < n) begin
        if (arr[mid2] == x) begin
          if (mid2 < first_occ) first_occ = mid2;
          high3 = mid2 - 4'd1;
        end else if (arr[mid2] < x) begin
          low3 = mid2 + 4'd1;
        end else begin
          high3 = mid2 - 4'd1;
        end
      end else begin
        high3 = mid2 - 4'd1;
      end
    end

    // Step 3
    mid3 = (low3 + high3) >> 1;
    if (high3 >= low3) begin
      if (mid3 < n) begin
        if (arr[mid3] == x && mid3 < first_occ) begin
          first_occ = mid3;
        end
      end
    end

    // Check final low index
    if (high3 >= low3 && low3 < n) begin
      if (arr[low3] == x && low3 < first_occ) begin
        first_occ = low3;
      end
    end

    // Determine majority
    if (first_occ != 4'd8) begin
      check_index = first_occ + (n >> 1);
      if (check_index < n && arr[check_index] == x) begin
        is_majority = 1'b1;
      end else begin
        is_majority = 1'b0;
      end
    end else begin
      is_majority = 1'b0;
    end
  end
endmodule