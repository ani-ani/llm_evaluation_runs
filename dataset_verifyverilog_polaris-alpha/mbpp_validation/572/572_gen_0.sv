module unique_numbers(
  input      [7:0][3:0] nums,
  input      [2:0]     length,
  output reg [7:0][3:0] unique_nums,
  output reg [7:0]      valid_mask
);

  // Combinational implementation
  integer i, j, u_idx;
  reg [3:0] cnt [7:0];

  always @* begin
    // Initialize counts
    for (i = 0; i < 8; i = i + 1) begin
      cnt[i] = 4'd0;
    end

    // Count occurrences only within [0 .. length-1]
    for (i = 0; i < 8; i = i + 1) begin
      if (i < length) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (j < length) begin
            if (nums[i] == nums[j]) begin
              cnt[i] = cnt[i] + 4'd1;
            end
          end
        end
      end
    end

    // Collect unique numbers (count == 1)
    u_idx = 0;
    valid_mask = 8'b0;
    for (i = 0; i < 8; i = i + 1) begin
      unique_nums[i] = 4'd0;
    end

    for (i = 0; i < 8; i = i + 1) begin
      if (i < length) begin
        if (cnt[i] == 4'd1) begin
          unique_nums[u_idx] = nums[i];
          valid_mask[u_idx] = 1'b1;
          u_idx = u_idx + 1;
        end
      end
    end
  end

endmodule