module hill_houses (
  input        [2:0]  n,
  input        [31:0] a [0:7],
  output       [31:0] result [0:3]
);

  reg [31:0] result_reg [0:3];
  reg [7:0] mask;
  integer i, j, k, l;
  integer cnt;
  reg is_adjacent;
  integer min_val;
  reg has_neighbor;
  integer cost;
  integer subset_size;

  always @(*) begin
    for (k = 0; k < 4; k = k + 1) begin
      result_reg[k] = 32'h7FFFFFFF;
    end

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
        subset_size = 0;
        for (l = 0; l < n; l = l + 1) begin
          if (mask[l]) subset_size = subset_size + 1;
        end
        if (subset_size >= 1 && subset_size <= (n+1)/2) begin
          cost = 0;
          for (j = 0; j < n; j = j + 1) begin
            if (!mask[j]) begin
              min_val = 32'h7FFFFFFF;
              has_neighbor = 0;
              if (j > 0 && mask[j-1]) begin
                has_neighbor = 1;
                if (a[j-1] - 1 < min_val) min_val = a[j-1] - 1;
              end
              if (j < n-1 && mask[j+1]) begin
                has_neighbor = 1;
                if (a[j+1] - 1 < min_val) min_val = a[j+1] - 1;
              end
              if (has_neighbor && a[j] > min_val) begin
                cost = cost + (a[j] - min_val);
              end
            end
          end
          if (cost < result_reg[subset_size-1]) begin
            result_reg[subset_size-1] = cost;
          end
        end
      end
    end
  end

  assign result[0] = result_reg[0];
  assign result[1] = result_reg[1];
  assign result[2] = result_reg[2];
  assign result[3] = result_reg[3];

endmodule