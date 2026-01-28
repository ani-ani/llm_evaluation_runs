module hill_houses (
  input        [2:0]  n,
  input        [31:0] a [0:7],
  output       [31:0] result [0:3]
);

  localparam N_MAX = 8;
  localparam MAX_SUBSETS = 256;
  localparam RESULT_SIZE = 4;

  reg [31:0] result_reg [0:RESULT_SIZE-1];
  reg [N_MAX-1:0] masks [0:MAX_SUBSETS-1];
  reg [N_MAX-1:0] mask;
  integer num_subsets;
  integer subset_size [0:MAX_SUBSETS-1];
  integer cost [0:MAX_SUBSETS-1];
  integer i, j, k, cnt;
  reg is_adjacent;
  integer min_val;
  reg has_neighbor;

  always @(*) begin
    cnt = 0;
    for (i = 0; i < (1 << n); i = i + 1) begin
      mask = i;
      is_adjacent = 0;
      for (j = 0; j < n-1; j = j + 1) begin
        if (mask[j] && mask[j+1]) begin
          is_adjacent = 1;
        end
      end
      if (!is_adjacent) begin
        masks[cnt] = mask;
        subset_size[cnt] = 0;
        for (k = 0; k < n; k = k + 1) begin
          if (mask[k]) subset_size[cnt] = subset_size[cnt] + 1;
        end
        cnt = cnt + 1;
      end
    end
    num_subsets = cnt;

    for (i = 0; i < num_subsets; i = i + 1) begin
      cost[i] = 0;
      mask = masks[i];
      for (j = 0; j < n; j = j + 1) begin
        if (!mask[j]) begin
          min_val = 32'h7FFFFFFF;
          has_neighbor = 0;
          if (j > 0 && mask[j-1]) begin
            has_neighbor = 1;
            if (a[j-1] - 32'd1 < min_val) min_val = a[j-1] - 32'd1;
          end
          if (j < n-1 && mask[j+1]) begin
            has_neighbor = 1;
            if (a[j+1] - 32'd1 < min_val) min_val = a[j+1] - 32'd1;
          end
          if (has_neighbor && a[j] > min_val) begin
            cost[i] = cost[i] + (a[j] - min_val);
          end
        end
      end
    end

    for (k = 1; k <= (n+1)/2; k = k + 1) begin
      result_reg[k-1] = 32'h7FFFFFFF;
      for (i = 0; i < num_subsets; i = i + 1) begin
        if (subset_size[i] >= k && cost[i] < result_reg[k-1]) begin
          result_reg[k-1] = cost[i];
        end
      end
    end
  end

  assign result = result_reg;

endmodule