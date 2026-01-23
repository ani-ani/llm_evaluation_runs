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
  integer subset_size [0:MAX_SUBSETS-1];
  integer cost [0:MAX_SUBSETS-1];
  integer i, j, k, cnt, subset_count;
  reg is_adjacent;
  integer min_val;
  reg has_neighbor;
  integer current_size;

  always @(*) begin
    // Initialize counters and intermediate arrays
    cnt = 0;
    
    // Clear result registers
    for (k = 0; k < RESULT_SIZE; k = k + 1) begin
      result_reg[k] = 32'h7FFFFFFF;
    end

    // Generate all non-adjacent masks
    for (i = 0; i < (1 << n); i = i + 1) begin
      is_adjacent = 1'b0;
      for (j = 0; j < (n-1); j = j + 1) begin
        if ((i[j] == 1) && (i[j+1] == 1)) begin
          is_adjacent = 1'b1;
          j = n;  // break loop
        end
      end

      if (!is_adjacent) begin
        masks[cnt] = i;
        
        // Calculate subset size
        current_size = 0;
        for (j = 0; j < n; j = j + 1) begin
          current_size = current_size + ((i >> j) & 1'b1);
        end
        subset_size[cnt] = current_size;
        cnt = cnt + 1;
      end
    end
    subset_count = cnt;

    // Calculate costs
    for (i = 0; i < subset_count; i = i + 1) begin
      cost[i] = 0;
      
      for (j = 0; j < n; j = j + 1) begin
        if (((masks[i] >> j) & 1'b1) == 1'b0) begin
          min_val = 32'h7FFFFFFF;
          has_neighbor = 1'b0;
          
          // Check previous neighbor
          if (j > 0 && ((masks[i] >> (j-1)) & 1'b1)) begin
            if ((a[j-1] - 32'd1) < min_val) begin
              min_val = a[j-1] - 32'd1;
            end
            has_neighbor = 1'b1;
          end
          
          // Check next neighbor
          if (j < (n-1) && ((masks[i] >> (j+1)) & 1'b1)) begin
            if ((a[j+1] - 32'd1) < min_val) begin
              min_val = a[j+1] - 32'd1;
            end
            has_neighbor = 1'b1;
          end
          
          if (has_neighbor && (a[j] > min_val)) begin
            cost[i] = cost[i] + (a[j] - min_val);
          end
        end
      end
    end

    // Find minimum costs for each k
    for (k = 0; k < ((n+1)/2); k = k + 1) begin
      for (i = 0; i < subset_count; i = i + 1) begin
        if (subset_size[i] >= (k+1) && cost[i] < result_reg[k]) begin
          result_reg[k] = cost[i];
        end
      end
    end
  end

  // Assign to output
  assign result = result_reg;

endmodule